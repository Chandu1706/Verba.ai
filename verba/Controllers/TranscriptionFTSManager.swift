//
//  TranscriptionFTSManager.swift
//  verba
//
//  Created by Chandu Korubilli on 7/6/25.
//
import Foundation
import SQLite3

struct TranscriptionFTSManager {
    static let shared = TranscriptionFTSManager()
    private let dbURL: URL

    private init() {
        dbURL = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("TranscriptionSearch.sqlite")
        createFTSTableIfNeeded()
    }

    private func createFTSTableIfNeeded() {
        var db: OpaquePointer?
        if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
            let createSQL = """
            CREATE VIRTUAL TABLE IF NOT EXISTS transcriptions USING fts5(segmentID, content);
            """
            sqlite3_exec(db, createSQL, nil, nil, nil)
            sqlite3_close(db)
        }
    }

    func indexSegment(segmentID: String, transcription: String) {
        var db: OpaquePointer?
        if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
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

    func search(query: String) -> Set<String> {
        var db: OpaquePointer?
        var results = Set<String>()

        if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
            let searchSQL = "SELECT segmentID FROM transcriptions WHERE content MATCH ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, searchSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, query, -1, nil)
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let cString = sqlite3_column_text(stmt, 0) {
                        results.insert(String(cString: cString))
                    }
                }
            }
            sqlite3_finalize(stmt)
            sqlite3_close(db)
        }

        return results
    }
}

