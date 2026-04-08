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

            // On watchOS, every schema version (V2–V8) contains the same 3 models because
            // all other models are iOS-only (#if os(iOS)). Passing KubbCoachMigrationPlan
            // causes a fatal "Duplicate version checksums detected" crash since SwiftData
            // sees identical model lists across all versions. Skip the migration plan on
            // watchOS — the schema has never actually changed on this platform.
            container = try ModelContainer(
                for: TrainingSession.self, TrainingRound.self, ThrowRecord.self,
                configurations: modelConfiguration
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
