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
    var sharedModelContainer: ModelContainer = {
        do {
            // Use versioned schema for proper migration
            let schema = Schema(versionedSchema: SchemaV4.self)

            // Disable automatic CloudKit sync - we use custom CloudKitSyncService instead
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )

            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    await initializeAggregatesIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Initialize statistics aggregates on first launch or migration
    @MainActor
    private func initializeAggregatesIfNeeded() async {
        let context = sharedModelContainer.mainContext

        // Check if aggregates exist
        let descriptor = FetchDescriptor<SessionStatisticsAggregate>()
        let count = (try? context.fetchCount(descriptor)) ?? 0

        if count == 0 {
            // First launch or migration needed - rebuild aggregates from existing sessions
            await StatisticsAggregator.rebuildAggregates(context: context)
        }
    }
}
