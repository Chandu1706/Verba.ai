//
//  DataPersistenceTests.swift
//  verbaTests
//
//  Created by Chandu Korubilli on 7/5/25.
//

import XCTest
import SwiftData
@testable import verba

final class DataPersistenceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([RecordingSession.self, RecordingSegment.self])
        container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(isStoredInMemoryOnly: true)
        ])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testInsertAndFetchSession() throws {
        let session = RecordingSession(fileName: "Test_Session", createdAt: Date())
        context.insert(session)
        try context.save()

        let fetch = FetchDescriptor<RecordingSession>()
        let results = try context.fetch(fetch)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.fileName, "Test_Session")
    }

    func testInsertSegmentIntoSession() throws {
        let session = RecordingSession(fileName: "ParentSession", createdAt: Date())
        context.insert(session)

        let segment = RecordingSegment(
            fileName: "seg1.caf",
            transcription: "hello world",
            createdAt: Date(),
            session: session
        )
        context.insert(segment)
        try context.save()

        let fetch = FetchDescriptor<RecordingSegment>()
        let segments = try context.fetch(fetch)

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.transcription, "hello world")
        XCTAssertEqual(segments.first?.session?.fileName, "ParentSession")
    }

    func testDeleteSessionCascadesToSegments() throws {
        let session = RecordingSession(fileName: "CascadeSession", createdAt: Date())
        let segment = RecordingSegment(
            fileName: "seg.caf",
            transcription: "test",
            createdAt: Date(),
            session: session
        )

        context.insert(session)
        context.insert(segment)
        try context.save()

        context.delete(session)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<RecordingSession>())
        let segments = try context.fetch(FetchDescriptor<RecordingSegment>())

        XCTAssertEqual(sessions.count, 0)
        XCTAssertEqual(segments.count, 0)
    }

    func testSearchSegmentByKeyword() throws {
        let session = RecordingSession(fileName: "SearchSession", createdAt: Date())
        let segment1 = RecordingSegment(fileName: "a.caf", transcription: "hello test", session: session)
        let segment2 = RecordingSegment(fileName: "b.caf", transcription: "unrelated", session: session)
        context.insert(session)
        context.insert(segment1)
        context.insert(segment2)
        try context.save()

        let fetch = FetchDescriptor<RecordingSegment>(
            predicate: #Predicate { $0.transcription.localizedStandardContains("test") }
        )
        let results = try context.fetch(fetch)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.fileName, "a.caf")
    }

    func testExportToCSV() throws {
        let session = RecordingSession(fileName: "ExportSession", createdAt: Date())
        let segment = RecordingSegment(fileName: "export.caf", transcription: "export text", session: session)
        context.insert(session)
        context.insert(segment)
        try context.save()

        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_export.csv")
        let allSessions = try context.fetch(FetchDescriptor<RecordingSession>())

        var csv = "File Name,Transcription\n"
        for session in allSessions {
            for segment in session.segments {
                csv += "\(segment.fileName),\"\(segment.transcription)\"\n"
            }
        }

        try csv.write(to: exportURL, atomically: true, encoding: .utf8)

        let contents = try String(contentsOf: exportURL)
        XCTAssertTrue(contents.contains("export.caf"))
        XCTAssertTrue(contents.contains("export text"))
    }

    func testImportFromCSV_mocked() throws {
        let mockCSV = "File Name,Transcription\nfile1.caf,\"hello\"\nfile2.caf,\"world\""
        let lines = mockCSV.split(separator: "\n").dropFirst() // skip header

        let session = RecordingSession(fileName: "ImportSession", createdAt: Date())
        context.insert(session)

        for line in lines {
            let components = line.split(separator: ",", maxSplits: 1)
            guard components.count == 2 else { continue }
            let file = String(components[0])
            let transcription = String(components[1].replacingOccurrences(of: "\"", with: ""))

            let segment = RecordingSegment(fileName: file, transcription: transcription, session: session)
            context.insert(segment)
        }

        try context.save()

        let segments = try context.fetch(FetchDescriptor<RecordingSegment>())
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments.first?.session?.fileName, "ImportSession")
    }

    func testSimulateLowStorage_warningOnly() throws {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let values = try docDir.resourceValues(forKeys: [.volumeAvailableCapacityKey])

        if let freeSpace = values.volumeAvailableCapacity {
            print("Available capacity: \(freeSpace / (1024 * 1024)) MB")
            XCTAssertTrue(freeSpace > 1_000_000, "⚠️ Simulated low storage scenario.")
        } else {
            XCTFail("Failed to check volumeAvailableCapacity.")
        }
    }
}

