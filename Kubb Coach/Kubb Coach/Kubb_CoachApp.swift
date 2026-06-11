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
    /// Set when the catastrophic fallback path runs (rename the store and
    /// recreate). Drives the user-facing "Local Data Reset" alert. Local
    /// state — resets on every launch, so the alert only fires once per
    /// recovery event.
    @State private var didRecoverFromMigrationFailure = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("didFixBlastingRoundCounts") private var didFixBlastingRoundCounts = false
    @AppStorage("appearancePreference") private var appearancePreference: String = AppearancePreference.auto.rawValue
    @AppStorage("accentColorChoice")    private var accentColorChoice: String = AppearanceAccent.swedishBlue.hex

    private var resolvedAppearance: AppearancePreference {
        AppearancePreference(rawValue: appearancePreference) ?? .auto
    }

    private var resolvedAccent: AppearanceAccent {
        AppearanceAccent(hexStorage: accentColorChoice)
    }

    var body: some View {
        Group {
            if let container = container {
                MainTabView()
                    .modelContainer(container)
                    .environment(CloudKitSyncService.shared)
                    .environment(SupportService.shared)
                    .environment(\.kubbAccent, resolvedAccent.color)
                    .emailReportComposerHost()
                    .alert(
                        "Local Data Reset",
                        isPresented: $didRecoverFromMigrationFailure
                    ) {
                        Button("Continue") { didRecoverFromMigrationFailure = false }
                    } message: {
                        Text("Kubb Coach couldn't read your existing local data after this update and started fresh. Your iCloud-synced sessions will reappear shortly. Sessions that were never uploaded to iCloud (most iPhone-only sessions) are not recoverable. The previous data file has been preserved on your device for diagnostic purposes.")
                    }
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

                        // Apply the user's stored appearance preference to the
                        // key window before the first frame paints. Subsequent
                        // changes are picked up by the .onChange below.
                        AppearanceService.apply(resolvedAppearance)
                    }
                    .onChange(of: appearancePreference) { _, _ in
                        AppearanceService.apply(resolvedAppearance)
                    }
                    .task {
                        await initializeAggregatesIfNeeded(container: container)
                        await fixBlastingRoundCountsIfNeeded(container: container)
                        await reconcileEmailReportSchedule(container: container)
                        await SupportService.shared.loadProducts()
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
        // SchemaV14 (added 2026-06-11) introduces AppMetadata to re-anchor the
        // schema after live @Model property additions (cloud-sync fields,
        // session conditions) drifted V13's checksum from what App Store 1.x
        // users wrote to disk. See SchemaV14.swift for the full backstory.
        let schema = Schema(versionedSchema: SchemaV14.self)

        // Attempt 1: normal staged migration (handles all V2→V14 upgrade paths).
        do {
            let createdContainer = try ModelContainer(
                for: schema,
                migrationPlan: KubbCoachMigrationPlan.self,
                configurations: [modelConfiguration]
            )
            container = createdContainer
            error = nil
            AppLogger.database.info("Database initialized successfully")
            await seedAppMetadata(container: createdContainer, recoveredFromFailure: false)
            isLoading = false
            return
        } catch {
            // Staged migration can become permanently unrecoverable when live @Model
            // properties are added between builds — the store's recorded checksum no longer
            // matches any version SwiftData knows about, and SwiftData permanently opts the
            // store into staged migration mode (even plain Schema([...]) uses staged migration
            // once a store has migration history). There is no public API to bypass this.
            //
            // Recovery (2026-06-11 change): instead of DELETING the broken store, RENAME
            // it with a timestamp suffix so the user's data is preserved on-disk for
            // possible later recovery. The user is informed via the "Local Data Reset"
            // alert wired up to `didRecoverFromMigrationFailure`. CloudKit-synced sessions
            // restore automatically on the next sync; iPhone-only sessions that never
            // uploaded are unrecoverable but at least the data file isn't destroyed.
            AppLogger.database.warning(
                "Staged migration failed — preserving store and starting fresh. Error: \(error.localizedDescription)"
            )
        }

        // Attempt 2: rename the broken store aside and open a fresh one.
        Self.renameDefaultStoreFiles()

        do {
            let createdContainer = try ModelContainer(
                for: schema,
                migrationPlan: KubbCoachMigrationPlan.self,
                configurations: [modelConfiguration]
            )
            container = createdContainer
            error = nil
            didRecoverFromMigrationFailure = true
            AppLogger.database.info("Database initialized successfully after store recovery")
            await seedAppMetadata(container: createdContainer, recoveredFromFailure: true)
        } catch {
            self.error = error
            AppLogger.logDatabaseError(error, context: "Database initialization failed after recovery")
        }
        isLoading = false
    }

    /// Renames the SwiftData store files (prepending a timestamp) so the next
    /// open creates a fresh database without destroying the user's data. The
    /// renamed file is left in place and can be inspected by support /
    /// diagnostics or recovered manually in extreme cases.
    ///
    /// Covers both the App Group container (used when an App Group is configured
    /// in entitlements) and the app's own Application Support directory.
    private static func renameDefaultStoreFiles() {
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

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        for dir in candidateDirs {
            for suffix in ["default.store", "default.store-shm", "default.store-wal"] {
                let fileURL = dir.appendingPathComponent(suffix)
                guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
                let renamedURL = dir.appendingPathComponent("\(suffix).broken-\(timestamp)")
                do {
                    try FileManager.default.moveItem(at: fileURL, to: renamedURL)
                    AppLogger.database.warning("Preserved unrecoverable store as: \(renamedURL.lastPathComponent)")
                } catch {
                    AppLogger.database.error("Failed to rename store file \(suffix): \(error)")
                    // As a last resort if rename fails (e.g. permissions, name clash),
                    // delete so we can at least create a fresh store. Without this,
                    // attempt 2 would also fail and the user would be stuck.
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }

    /// Inserts or updates the singleton `AppMetadata` record after a successful
    /// container initialization. Provides forensic breadcrumbs for future
    /// migration debugging — particularly which schema version the store
    /// last reached intact and whether the user landed on a recovery path.
    @MainActor
    private func seedAppMetadata(container: ModelContainer, recoveredFromFailure: Bool) async {
        let context = container.mainContext
        let descriptor = FetchDescriptor<AppMetadata>()
        let existing = (try? context.fetch(descriptor)) ?? []

        let noteSuffix = recoveredFromFailure
            ? "recovered after migration failure on \(Date())"
            : "migration succeeded on \(Date())"

        if existing.isEmpty {
            let metadata = AppMetadata(
                lastSchemaVersion: "14.0.0",
                firstLaunchedAt: Date(),
                migrationNotes: "v2.0 first launch — \(noteSuffix)"
            )
            context.insert(metadata)
        } else if let first = existing.first {
            first.lastSchemaVersion = "14.0.0"
            let prior = first.migrationNotes.map { "\($0)\n" } ?? ""
            first.migrationNotes = "\(prior)\(noteSuffix)"
        }
        try? context.save()
    }

    /// One-time fixup for blasting sessions previously stored with
    /// configuredRounds = 10 due to the old validator silently coercing 9 → 10.
    /// Idempotent; runs once gated by AppStorage flag.
    @MainActor
    private func fixBlastingRoundCountsIfNeeded(container: ModelContainer) async {
        guard !didFixBlastingRoundCounts else { return }
        let context = container.mainContext
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.configuredRounds == 10 }
        )
        do {
            let candidates = try context.fetch(descriptor)
            var fixed = 0
            for session in candidates where session.phase == .fourMetersBlasting {
                session.configuredRounds = SessionConstants.blastingRoundCount
                fixed += 1
            }
            if fixed > 0 {
                try context.save()
                AppLogger.database.info("Migrated \(fixed) blasting sessions from configuredRounds 10 → 9")
            }
            didFixBlastingRoundCounts = true
        } catch {
            AppLogger.database.error("Blasting round-count migration failed: \(error.localizedDescription)")
        }
    }

    /// If email reports are enabled but no notification is currently pending
    /// (e.g. the last one already fired without being tapped, or the app was
    /// reinstalled), schedule the next one. Does NOT request notification
    /// permission — if it was previously revoked, the user will be re-prompted
    /// next time they save in Settings.
    @MainActor
    private func reconcileEmailReportSchedule(container: ModelContainer) async {
        let context = container.mainContext
        let descriptor = FetchDescriptor<EmailReportSettings>()
        guard let settings = (try? context.fetch(descriptor))?.first,
              settings.isEnabled else {
            return
        }
        let hasPending = await EmailReportScheduler.shared.hasPendingNotification()
        if !hasPending {
            AppLogger.general.info("No pending email-report notification — reconciling on launch")
            await EmailReportScheduler.shared.scheduleNext(for: settings)
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
