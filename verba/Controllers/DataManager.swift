//
//  DataManager.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//

import Foundation
import SwiftData
import SQLite3

@MainActor
class DataManager {
    static let shared = DataManager()
    private init() {
        createFTSTableIfNeeded()
    }

    private let ftsDBPath: URL = {
        try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("TranscriptionSearch.sqlite")
    }()

    private func createFTSTableIfNeeded() {
        var db: OpaquePointer?
        if sqlite3_open(ftsDBPath.path, &db) == SQLITE_OK {
            let sql = "CREATE VIRTUAL TABLE IF NOT EXISTS transcriptions USING fts5(segmentID, content);"
            sqlite3_exec(db, sql, nil, nil, nil)
            sqlite3_close(db)
        }
    }

    private func saveSegmentFTS(segmentID: String, transcription: String) {
        var db: OpaquePointer?
        if sqlite3_open(ftsDBPath.path, &db) == SQLITE_OK {
            let insertSQL = """
            INSERT INTO transcriptions (segmentID, content)
            VALUES (?, ?)
            ON CONFLICT(segmentID) DO UPDATE SET content = excluded.content;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, segmentID, -1, nil)
                sqlite3_bind_text(stmt, 2, transcription, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            sqlite3_close(db)
        }
    }

    func searchSegmentsFTS(_ query: String) -> Set<String> {
        var results = Set<String>()
        var db: OpaquePointer?
        if sqlite3_open(ftsDBPath.path, &db) == SQLITE_OK {
            let searchSQL = "SELECT segmentID FROM transcriptions WHERE content MATCH ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, searchSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, query, -1, nil)
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let cStr = sqlite3_column_text(stmt, 0) {
                        results.insert(String(cString: cStr))
                    }
                }
            }
            sqlite3_finalize(stmt)
            sqlite3_close(db)
        }
        return results
    }

    func reindexAllSegments(context: ModelContext) {
        let allSessions = fetchAllSessions(context: context)
        for session in allSessions {
            for segment in session.segments {
                let segmentID = segment.persistentModelID.hashValue.description
                saveSegmentFTS(segmentID: segmentID, transcription: segment.transcription)
            }
        }
        print("✅ Reindexed all segments into FTS")
    }

    func fetchSessions(offset: Int = 0, limit: Int = 50, context: ModelContext) -> [RecordingSession] {
        var fetch = FetchDescriptor<RecordingSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        fetch.fetchLimit = limit
        fetch.fetchOffset = offset

        do {
            return try context.fetch(fetch)
        } catch {
            print("❌ Failed to fetch sessions: \(error)")
            return []
        }
    }

    func nextSessionIndex(context: ModelContext) -> Int {
        let allSessions = fetchAllSessions(context: context)
        let numbers = allSessions.compactMap { session in
            Int(session.fileName.replacingOccurrences(of: "Session ", with: ""))
        }
        return (numbers.max() ?? 0) + 1
    }

    func fetchAllSessions(context: ModelContext) -> [RecordingSession] {
        let descriptor = FetchDescriptor<RecordingSession>(sortBy: [.init(\.createdAt, order: .forward)])
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch sessions: \(error)")
            return []
        }
    }

    func deleteSession(_ session: RecordingSession, context: ModelContext) {
        context.delete(session)
        do {
            try context.save()
            print("🗑️ Deleted session: \(session.fileName)")
        } catch {
            print("❌ Failed to delete session: \(error)")
        }
    }

    func deleteAllSessions(context: ModelContext) {
        let allSessions = fetchSessions(offset: 0, limit: Int.max, context: context)
        allSessions.forEach { context.delete($0) }

        do {
            try context.save()
            print("🧹 Deleted all sessions")
        } catch {
            print("❌ Failed to delete all sessions: \(error)")
        }
    }

    /// Search for sessions by session name OR segment transcription content
    func searchSessions(matching keyword: String, context: ModelContext) -> [RecordingSession] {
        do {
            let sessionFetch = FetchDescriptor<RecordingSession>(
                predicate: #Predicate {
                    $0.fileName.localizedStandardContains(keyword)
                },
                sortBy: [.init(\.createdAt, order: .reverse)]
            )

            let matchingSessions = try context.fetch(sessionFetch)

            let segmentFetch = FetchDescriptor<RecordingSegment>(
                predicate: #Predicate {
                    $0.transcription.localizedStandardContains(keyword)
                }
            )

            let segments = try context.fetch(segmentFetch)
            let sessionsFromSegments = Set(segments.compactMap { $0.session })

            // 🔍 FTS segment IDs
            let matchedFTSIDs = searchSegmentsFTS(keyword)
            let sessionsFromFTS = fetchAllSessions(context: context).filter { session in
                session.segments.contains { matchedFTSIDs.contains($0.persistentModelID.hashValue.description) }
            }

            // Combine all sources
            let allMatches = Set(matchingSessions)
                .union(sessionsFromSegments)
                .union(sessionsFromFTS)

            return allMatches.sorted(by: { $0.createdAt > $1.createdAt })

        } catch {
            print("❌ Failed to search: \(error)")
            return []
        }
    }

    /// Advanced Search with keyword + date range
    func advancedSearch(keyword: String?, startDate: Date?, endDate: Date?, context: ModelContext) -> [RecordingSession] {
        do {
            var predicate: Predicate<RecordingSegment> = #Predicate { _ in true }

            if let keyword = keyword, !keyword.isEmpty {
                predicate = #Predicate { $0.transcription.localizedStandardContains(keyword) }
            }

            var fetch = FetchDescriptor<RecordingSegment>(predicate: predicate)

            if let start = startDate, let end = endDate {
                fetch.predicate = #Predicate {
                    $0.transcription.localizedStandardContains(keyword ?? "") &&
                    $0.createdAt >= start &&
                    $0.createdAt <= end
                }
            } else if let start = startDate {
                fetch.predicate = #Predicate {
                    $0.transcription.localizedStandardContains(keyword ?? "") &&
                    $0.createdAt >= start
                }
            } else if let end = endDate {
                fetch.predicate = #Predicate {
                    $0.transcription.localizedStandardContains(keyword ?? "") &&
                    $0.createdAt <= end
                }
            }

            let matchedSegments = try context.fetch(fetch)
            let sessions = Set(matchedSegments.compactMap { $0.session })

            return sessions.sorted(by: { $0.createdAt > $1.createdAt })
        } catch {
            print("❌ Failed advanced search: \(error)")
            return []
        }
    }

    func exportSessions(to url: URL, context: ModelContext) {
        let allSessions = fetchSessions(offset: 0, limit: Int.max, context: context)
        var csv = "File Name,Transcription Count\n"

        for session in allSessions {
            csv += "\(session.fileName),\"\(session.segments.count)\"\n"
        }

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            print("📤 Exported sessions to \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to export: \(error)")
        }
    }
}

