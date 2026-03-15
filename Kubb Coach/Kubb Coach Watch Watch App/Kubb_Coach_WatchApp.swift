//
//  Kubb_Coach_WatchApp.swift
//  Kubb Coach Watch Watch App
//
//  Created by Scott Thompson on 2/20/26.
//

import SwiftUI
import SwiftData

@main
struct Kubb_Coach_Watch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            WatchDatabaseContainerView()
        }
    }
}

/// Wrapper view that handles database initialization with graceful error handling
struct WatchDatabaseContainerView: View {
    @State private var container: ModelContainer?
    @State private var error: Error?

    var body: some View {
        Group {
            if let container = container {
                TrainingModeSelectionView()
                    .modelContainer(container)
                    .environment(CloudKitSyncService.shared)
            } else if error != nil {
                WatchDatabaseErrorView(retry: loadContainer)
            } else {
                ProgressView("Loading...")
                    .task {
                        await loadContainer()
                    }
            }
        }
    }

    private func loadContainer() async {
        do {
            // Disable automatic CloudKit sync - we use custom CloudKitSyncService instead
            let modelConfiguration = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )

            // Use same migration plan as iOS to ensure schema consistency
            // SchemaV7 already handles platform-specific models with #if os(iOS)
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
    }
}

/// Error view displayed when database initialization fails on watchOS
struct WatchDatabaseErrorView: View {
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)

            Text("Database Error")
                .font(.headline)

            Text("Please restart the app or contact support.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button(action: {
                Task {
                    await retry()
                }
            }) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
