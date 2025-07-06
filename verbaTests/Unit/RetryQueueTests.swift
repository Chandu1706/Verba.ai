//
//  RetryQueueTests.swift
//  verbaTests
//
//  Created by Chandu Korubilli on 7/5/25.
//

import XCTest
import SwiftData
@testable import verba

final class RetryQueueTests: XCTestCase {

    var context: ModelContext!
    var dummyURL: URL!

    override func setUpWithError() throws {
        let schema = Schema([RecordingSession.self, RecordingSegment.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)

        // Create a dummy audio file URL
        let dir = FileManager.default.temporaryDirectory
        dummyURL = dir.appendingPathComponent("dummy_audio.caf")
        FileManager.default.createFile(atPath: dummyURL.path, contents: Data(), attributes: nil)

        // Reset the queue
        RetryQueue.shared.clear()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dummyURL)
        RetryQueue.shared.clear()
    }

    func testAddToQueue() {
        RetryQueue.shared.add(dummyURL)
        XCTAssertEqual(RetryQueue.shared.pendingCount, 1)
    }

    func testFlushWhenOffline() {
        NetworkMonitor.shared.isConnected = false
        RetryQueue.shared.add(dummyURL)

        RetryQueue.shared.flush(using: "dummy-key", context: context)
        XCTAssertEqual(RetryQueue.shared.pendingCount, 1) // Still in queue
    }

    func testFlushWhenOnline_EmptyQueue() {
        NetworkMonitor.shared.isConnected = true
        RetryQueue.shared.flush(using: "dummy-key", context: context)

        XCTAssertEqual(RetryQueue.shared.pendingCount, 0)
    }

    func testFlushWhenOnlineWithItem() {
        NetworkMonitor.shared.isConnected = true
        RetryQueue.shared.add(dummyURL)

        let expectation = XCTestExpectation(description: "Flush completes")
        TranscriptionService.shared.mockTranscription = "Test Transcript"

        RetryQueue.shared.flush(using: "dummy-key", context: context)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let segments = try? context.fetch(FetchDescriptor<RecordingSegment>())
            XCTAssertEqual(segments?.count, 1)
            XCTAssertEqual(segments?.first?.transcription, "Test Transcript")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testClearQueue() {
        RetryQueue.shared.add(dummyURL)
        RetryQueue.shared.clear()
        XCTAssertEqual(RetryQueue.shared.pendingCount, 0)
    }
}

