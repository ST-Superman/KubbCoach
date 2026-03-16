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
    var body: some Scene {
        WindowGroup {
            DatabaseContainerView()
        }
    }
}

/// Wrapper view that handles database initialization with graceful error handling
struct DatabaseContainerView: View {
    @State private var container: ModelContainer?
    @State private var error: Error?
    @State private var isLoading = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if let container = container {
                MainTabView()
                    .modelContainer(container)
                    .environment(CloudKitSyncService.shared)
                    .sheet(isPresented: .constant(!hasCompletedOnboarding)) {
                        OnboardingCoordinatorView()
                            .modelContainer(container)
                            .interactiveDismissDisabled()
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
    }

    private func loadContainer() async {
        // Skip database initialization during tests
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            isLoading = false
            return
        }

        do {
            // Disable automatic CloudKit sync - we use custom CloudKitSyncService instead
            let modelConfiguration = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )

            // Use migration plan to safely upgrade from any previous schema version
            let schema = Schema(versionedSchema: SchemaV7.self)
            container = try ModelContainer(
                for: schema,
                migrationPlan: KubbCoachMigrationPlan.self,
                configurations: [modelConfiguration]
            )
            error = nil
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Initialize statistics aggregates on first launch or migration
    @MainActor
    private func initializeAggregatesIfNeeded(container: ModelContainer) async {
        let context = container.mainContext

        // Check if aggregates exist
        let descriptor = FetchDescriptor<SessionStatisticsAggregate>()
        let count = (try? context.fetchCount(descriptor)) ?? 0

        if count == 0 {
            // First launch or migration needed - rebuild aggregates from existing sessions
            await StatisticsAggregator.rebuildAggregates(context: context)
        }
    }
}

/// Error view displayed when database initialization fails
struct DatabaseErrorView: View {
    let error: Error
    let retry: () async -> Void

    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

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
            }

            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await retry()
                    }
                }) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    showDetails.toggle()
                }) {
                    Text(showDetails ? "Hide Details" : "Show Details")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let emailURL = URL(string: "mailto:sathomps@gmail.com?subject=Kubb%20Coach%20Database%20Error") {
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
