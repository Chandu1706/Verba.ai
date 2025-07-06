//
//  RecordingSessionModelTests.swift
//  verbaTests
//
//  Created by Chandu Korubilli on 7/5/25.
//

import XCTest
import SwiftData
@testable import verba

final class RecordingSessionModelTests: XCTestCase {

    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([RecordingSession.self, RecordingSegment.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }


    func testSessionInitialization() {
        let session = RecordingSession(fileName: "testSession.caf", createdAt: Date())
        XCTAssertEqual(session.fileName, "testSession.caf")
        XCTAssertTrue(session.segments.isEmpty)
    }

    func testInsertSessionIntoContext() throws {
        let session = RecordingSession(fileName: "insertTest.caf", createdAt: Date())
        context.insert(session)

        let fetch = FetchDescriptor<RecordingSession>()
        let results = try context.fetch(fetch)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.fileName, "insertTest.caf")
    }

    func testDeleteSession() throws {
        let session = RecordingSession(fileName: "toDelete.caf", createdAt: Date())
        context.insert(session)
        context.delete(session)

        let results = try context.fetch(FetchDescriptor<RecordingSession>())
        XCTAssertTrue(results.isEmpty)
    }


    func testAddSegmentToSession() {
        let session = RecordingSession(fileName: "testSession", createdAt: Date())
        let segment = RecordingSegment(fileName: "seg1.caf", transcription: "Hello", createdAt: Date(), session: session)

        XCTAssertEqual(segment.session?.fileName, session.fileName)
        XCTAssertEqual(segment.transcription, "Hello")
    }

 
    func testEmptyFileNameShouldStillCreateSession() {
        let session = RecordingSession(fileName: "", createdAt: Date())
        XCTAssertEqual(session.fileName, "")
    }

    func testFutureDateSessionIsAcceptedButLogged() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let session = RecordingSession(fileName: "future.caf", createdAt: futureDate)
        XCTAssertTrue(session.createdAt > Date())
    }

    func testLargeNumberOfSessionsPerformance() throws {
        measure {
            for i in 0..<1_000 {
                let session = RecordingSession(fileName: "bulk_\(i).caf", createdAt: Date())
                context.insert(session)
            }

            let count = try? context.fetch(FetchDescriptor<RecordingSession>()).count
            XCTAssertEqual(count, 1_000)
        }
    }

    func testLargeSessionWithSegments() throws {
        let session = RecordingSession(fileName: "bigSession", createdAt: Date())
        context.insert(session)

        for i in 0..<10_000 {
            let segment = RecordingSegment(fileName: "seg_\(i).caf", transcription: "Transcript \(i)", createdAt: Date(), session: session)
            context.insert(segment)
        }

        let fetch = FetchDescriptor<RecordingSegment>()
        let segments = try context.fetch(fetch)

        XCTAssertEqual(segments.count, 10_000)
        XCTAssertTrue(segments.allSatisfy { $0.session?.fileName == "bigSession" })
    }
}
