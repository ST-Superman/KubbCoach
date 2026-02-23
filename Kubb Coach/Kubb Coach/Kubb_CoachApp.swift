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
        let schema = Schema([
            TrainingSession.self,
            TrainingRound.self,
            ThrowRecord.self,
            CachedCloudSession.self,
            CachedCloudRound.self,
            CachedCloudThrow.self,
        ])
        // Disable automatic CloudKit sync - we use custom CloudKitSyncService instead
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
