//
//  EdgeCaseTests.swift
//  verbaTests
//
//  Created by Chandu Korubilli on 7/5/25.
//

import XCTest
import SwiftData
@testable import verba

final class EdgeCaseTests: XCTestCase {

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

    func testEmptyFileNameInSession() {
        let session = RecordingSession(fileName: "", createdAt: Date())
        context.insert(session)

        XCTAssertEqual(session.fileName, "")
    }

    func testInvalidFutureDateInSession() {
        let futureDate = Calendar.current.date(byAdding: .year, value: 10, to: Date())!
        let session = RecordingSession(fileName: "FutureSession", createdAt: futureDate)
        context.insert(session)

        XCTAssertTrue(session.createdAt > Date(), "Date should be in the future")
    }

    func testLargeNumberOfSegmentsInSession() {
        let session = RecordingSession(fileName: "BulkSession", createdAt: Date())
        context.insert(session)

        for i in 0..<10_000 {
            let seg = RecordingSegment(
                fileName: "segment\(i).caf",
                transcription: "transcription \(i)",
                createdAt: Date(),
                session: session
            )
            context.insert(seg)
        }

        do {
            try context.save()
            XCTAssertEqual(session.segments.count, 10_000)
        } catch {
            XCTFail("Failed to save large number of segments: \(error)")
        }
    }

    func testDuplicateSessionFileNames() {
        let session1 = RecordingSession(fileName: "DuplicateName", createdAt: Date())
        let session2 = RecordingSession(fileName: "DuplicateName", createdAt: Date())
        context.insert(session1)
        context.insert(session2)

        do {
            try context.save()
            let results = try context.fetch(FetchDescriptor<RecordingSession>())
            XCTAssertEqual(results.filter { $0.fileName == "DuplicateName" }.count, 2)
        } catch {
            XCTFail("Failed to insert duplicate file names: \(error)")
        }
    }

    func testSegmentWithNilSession() {
        let segment = RecordingSegment(
            fileName: "orphan.caf",
            transcription: "orphan segment",
            createdAt: Date(),
            session: nil
        )
        context.insert(segment)

        XCTAssertNil(segment.session)
    }

    func testVeryLongTranscription() {
        let longText = String(repeating: "lorem ipsum ", count: 10_000)
        let segment = RecordingSegment(
            fileName: "long.caf",
            transcription: longText,
            createdAt: Date(),
            session: nil
        )
        context.insert(segment)

        XCTAssertTrue(segment.transcription.count > 100_000)
    }

    func testSegmentWithoutTranscription() {
        let segment = RecordingSegment(
            fileName: "no_trans.caf",
            transcription: "",
            createdAt: Date(),
            session: nil
        )
        context.insert(segment)

        XCTAssertEqual(segment.transcription, "")
    }

    func testEmptySegmentsListInSession() {
        let session = RecordingSession(fileName: "EmptySegments", createdAt: Date())
        context.insert(session)

        XCTAssertTrue(session.segments.isEmpty)
    }
}

