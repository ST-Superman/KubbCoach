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

        do {
            // Disable automatic CloudKit sync - we use custom CloudKitSyncService instead
            let modelConfiguration = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )

            // Use migration plan to safely upgrade from any previous schema version
            let schema = Schema(versionedSchema: SchemaV9.self)
            container = try ModelContainer(
                for: schema,
                migrationPlan: KubbCoachMigrationPlan.self,
                configurations: [modelConfiguration]
            )

            error = nil
            AppLogger.database.info("Database initialized successfully")
        } catch {
            self.error = error
            // Log telemetry for database initialization failures
            AppLogger.logDatabaseError(error, context: "Database initialization failed")

            // In a production app, you might send this to an analytics service:
            // Analytics.logError("database_init_failed", error: error)
        }
        isLoading = false
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
