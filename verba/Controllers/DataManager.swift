//
//  DataManager.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//

import Foundation
import SwiftData

@MainActor
class DataManager {
    static let shared = DataManager()
    private init() {}

    func fetchSessions(offset: Int = 0, limit: Int = 50, context: ModelContext) -> [RecordingSession] {
        var fetch = FetchDescriptor<RecordingSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        fetch.fetchLimit = limit
        fetch.fetchOffset = offset

        do {
            return try context.fetch(fetch)
        } catch {
            print(" Failed to fetch sessions: \(error)")
            return []
        }
    }

    func deleteSession(_ session: RecordingSession, context: ModelContext) {
        context.delete(session)
        do {
            try context.save()
            print(" Deleted session: \(session.fileName)")
        } catch {
            print(" Failed to delete session: \(error)")
        }
    }

    func deleteAllSessions(context: ModelContext) {
        let allSessions = fetchSessions(offset: 0, limit: Int.max, context: context)
        allSessions.forEach { context.delete($0) }

        do {
            try context.save()
            print(" Deleted all sessions")
        } catch {
            print("Failed to delete all sessions: \(error)")
        }
    }

    func searchSessions(matching keyword: String, context: ModelContext) -> [RecordingSession] {
        do {
            let segmentFetch = FetchDescriptor<RecordingSegment>(
                predicate: #Predicate { $0.transcription.localizedStandardContains(keyword) }
            )
            let segments = try context.fetch(segmentFetch)

            let matchedSessions = Set(segments.compactMap { $0.session })
            return matchedSessions.sorted(by: { $0.createdAt > $1.createdAt })
        } catch {
            print(" Failed to search segments: \(error)")
            return []
        }
    }

    func exportSessions(to url: URL, context: ModelContext) {
        let allSessions = fetchSessions(offset: 0, limit: Int.max, context: context)
        var csv = "File Name,Segment Count\n"

        for session in allSessions {
            let segmentCount = session.segments.count
            csv += "\(session.fileName),\(segmentCount)\n"
        }

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            print(" Exported sessions to \(url.lastPathComponent)")
        } catch {
            print(" Failed to export: \(error)")
        }
    }
}

