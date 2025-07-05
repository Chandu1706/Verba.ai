//
//  verbaApp.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//

import SwiftUI
import SwiftData

@main
struct verbaApp: App {
    // Shared SwiftData container including both models
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RecordingSession.self,
            RecordingSegment.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContext(sharedModelContainer.mainContext) // Inject context for view access
        }
        .modelContainer(sharedModelContainer)
    }
}

