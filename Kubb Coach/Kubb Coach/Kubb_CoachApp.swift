//
//  Kubb_CoachApp.swift
//  Kubb Coach
//
//  Created by Scott Thompson on 2/20/26.
//

import SwiftUI
import SwiftData

@main
struct Kubb_CoachApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            DatabaseContainerView(appDelegate: appDelegate)
        }
    }
}

/// Wrapper view that handles database initialization with graceful error handling
struct DatabaseContainerView: View {
    let appDelegate: AppDelegate

    @State private var container: ModelContainer?
    @State private var error: Error?
    @State private var isLoading = true
    @State private var isInitializingAggregates = false
    @State private var showOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if let container = container {
                MainTabView()
                    .modelContainer(container)
                    .environment(CloudKitSyncService.shared)
                    .sheet(isPresented: $showOnboarding) {
                        OnboardingCoordinatorView()
                            .modelContainer(container)
                            .interactiveDismissDisabled()
                    }
                    .overlay {
                        if isInitializingAggregates {
                            ZStack {
                                Color.black.opacity(0.3)
                                    .ignoresSafeArea()

                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                    Text("Preparing statistics...")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                                .padding(32)
                                .background(Color(uiColor: .systemBackground))
                                .cornerRadius(16)
                                .shadow(radius: 20)
                            }
                        }
                    }
                    .onOpenURL { url in
                        guard url.scheme == "kubbcoach" else { return }
                        NotificationCenter.default.post(
                            name: .handleDeepLink,
                            object: nil,
                            userInfo: [DeepLinkRouter.urlKey: url.absoluteString]
                        )
                    }
                    .onAppear {
                        // Check onboarding status on appear
                        showOnboarding = !hasCompletedOnboarding

                        // Pass container to AppDelegate after initialization
                        appDelegate.modelContainer = container
                    }
                    .task {
                        await initializeAggregatesIfNeeded(container: container)
                    }
            } else if let error = error {
                DatabaseErrorView(error: error, retry: loadContainer)
            } else {
                ProgressView("Initializing database...")
                    .task {
                        await loadContainer()
                    }
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, newValue in
            // Dismiss onboarding when user completes it
            if newValue {
                showOnboarding = false
            }
        }
    }

    private func loadContainer() async {
        // Skip database initialization during tests
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            AppLogger.database.info("Skipping database initialization in test environment")
            isLoading = false
            return
        }

        AppLogger.database.info("Starting database initialization...")

        // Disable automatic CloudKit sync - we use custom CloudKitSyncService instead
        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        let schema = Schema(versionedSchema: SchemaV12.self)

        // Attempt 1: normal staged migration (handles all V2→V9 upgrade paths).
        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: KubbCoachMigrationPlan.self,
                configurations: [modelConfiguration]
            )
            error = nil
            AppLogger.database.info("Database initialized successfully")
            isLoading = false
            return
        } catch {
            // Staged migration can become permanently unrecoverable when live @Model
            // properties are added between builds — the store's recorded checksum no longer
            // matches any version SwiftData knows about, and SwiftData permanently opts the
            // store into staged migration mode (even plain Schema([...]) uses staged migration
            // once a store has migration history). There is no public API to bypass this.
            //
            // Recovery: delete the store files and recreate. Training sessions are preserved
            // in CloudKit and re-sync on next launch. Game-tracker test data is lost.
            AppLogger.database.warning(
                "Staged migration failed — deleting store for recovery. Error: \(error.localizedDescription)"
            )
        }

        // Attempt 2: delete store files and open fresh with a clean migration.
        Self.deleteDefaultStoreFiles()

        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: KubbCoachMigrationPlan.self,
                configurations: [modelConfiguration]
            )
            error = nil
            AppLogger.database.info("Database initialized successfully after store recovery")
        } catch {
            self.error = error
            AppLogger.logDatabaseError(error, context: "Database initialization failed after recovery")
        }
        isLoading = false
    }

    /// Deletes the SwiftData store files so the next open creates a fresh database.
    /// Covers both the App Group container (used when an App Group is configured in
    /// entitlements) and the app's own Application Support directory.
    private static func deleteDefaultStoreFiles() {
        var candidateDirs: [URL] = []

        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.sathomps.kubbcoach"
        ) {
            candidateDirs.append(groupURL.appendingPathComponent("Library/Application Support"))
        }

        if let ownURL = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first {
            candidateDirs.append(ownURL)
        }

        for dir in candidateDirs {
            for suffix in ["default.store", "default.store-shm", "default.store-wal"] {
                let fileURL = dir.appendingPathComponent(suffix)
                guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    AppLogger.database.warning("Deleted unrecoverable store file: \(fileURL.lastPathComponent)")
                } catch {
                    AppLogger.database.error("Failed to delete store file \(suffix): \(error)")
                }
            }
        }
    }

    /// Initialize statistics aggregates on first launch or migration
    @MainActor
    private func initializeAggregatesIfNeeded(container: ModelContainer) async {
        let context = container.mainContext

        // Check if aggregates exist
        let descriptor = FetchDescriptor<SessionStatisticsAggregate>()

        do {
            let count = try context.fetchCount(descriptor)

            if count == 0 {
                // First launch or migration needed - rebuild aggregates from existing sessions
                AppLogger.statistics.info("No statistics aggregates found - initializing...")
                isInitializingAggregates = true

                await StatisticsAggregator.rebuildAggregates(context: context)

                isInitializingAggregates = false
                AppLogger.statistics.info("Statistics aggregates initialized successfully")
            } else {
                AppLogger.statistics.debug("Found \(count) existing aggregates - skipping initialization")
            }
        } catch {
            // Log error but don't block app launch
            AppLogger.logStatisticsError(error, operation: "Check aggregate count")

            // Decision: Attempt rebuild on error to ensure aggregates exist
            // This is safer than skipping, as missing aggregates could cause UI issues
            AppLogger.statistics.warning("Error checking aggregates - attempting rebuild as safety measure")
            isInitializingAggregates = true

            await StatisticsAggregator.rebuildAggregates(context: context)

            isInitializingAggregates = false
        }
    }
}

/// Error view displayed when database initialization fails
struct DatabaseErrorView: View {
    let error: Error
    let retry: () async -> Void

    @State private var showDetails = false

    // Read support configuration from Info.plist
    private var supportEmail: String {
        Bundle.main.object(forInfoDictionaryKey: "SupportEmail") as? String ?? "support@kubbcoach.com"
    }

    private var supportEmailSubject: String {
        Bundle.main.object(forInfoDictionaryKey: "SupportEmailSubject") as? String ?? "Kubb Coach Support"
    }

    private var supportEmailURL: URL? {
        // Sanitize error message for email (remove newlines, limit length)
        let errorMessage = error.localizedDescription
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(200)
        let subject = "\(supportEmailSubject) - Database Error"
        let body = "I encountered a database error:\n\n\(errorMessage)"

        let urlString = "mailto:\(supportEmail)?subject=\(subject)&body=\(body)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        return urlString.flatMap { URL(string: $0) }
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
                .accessibilityLabel("Error icon")

            Text("Database Error")
                .font(.title.bold())

            Text("The app encountered an error initializing its database. This may be due to a corrupted database or insufficient storage space.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if showDetails {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .accessibilityLabel("Error details: \(error.localizedDescription)")
            }

            VStack(spacing: 12) {
                Button {
                    Task {
                        await retry()
                    }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showDetails.toggle()
                } label: {
                    Text(showDetails ? "Hide Details" : "Show Details")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let emailURL = supportEmailURL {
                    Link(destination: emailURL) {
                        Text("Contact Support")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
}
