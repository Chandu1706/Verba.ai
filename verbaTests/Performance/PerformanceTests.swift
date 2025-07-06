//
//  PerformanceTests.swift
//  verbaTests
//
//  Created by Chandu Korubilli on 7/5/25.
//

import XCTest
import SwiftData
@testable import verba

final class PerformanceTests: XCTestCase {

    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([RecordingSession.self, RecordingSegment.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    func testInsertThousandSessionsPerformance() throws {
        measure {
            for i in 0..<1000 {
                let session = RecordingSession(fileName: "Session_\(i)", createdAt: Date())
                context.insert(session)
                for j in 0..<10 {
                    let segment = RecordingSegment(fileName: "seg_\(j)", transcription: "Transcript \(j)", createdAt: Date(), session: session)
                    context.insert(segment)
                }
            }

            try? context.save()
        }
    }

    func testFetchLargeDatasetPerformance() throws {
        // Preload data
        for i in 0..<500 {
            let session = RecordingSession(fileName: "Session_\(i)", createdAt: Date())
            context.insert(session)
            for j in 0..<20 {
                let segment = RecordingSegment(fileName: "segment_\(i)_\(j)", transcription: "Text", createdAt: Date(), session: session)
                context.insert(segment)
            }
        }
        try context.save()

        measure {
            let sessions = try? context.fetch(FetchDescriptor<RecordingSession>())
            XCTAssertNotNil(sessions)
            XCTAssertGreaterThanOrEqual(sessions?.count ?? 0, 500)
        }
    }

    func testTranscriptionLoopPerformance() {
        let dummyURL = FileManager.default.temporaryDirectory.appendingPathComponent("dummy.caf")
        FileManager.default.createFile(atPath: dummyURL.path, contents: Data(count: 1024 * 10))

        measure {
            for _ in 0..<20 {
                let exp = expectation(description: "Transcribe")
                TranscriptionService.shared.transcribeWithAssemblyAI(audioURL: dummyURL, apiKey: "dummy") { text in
                    XCTAssertNotNil(text)
                    exp.fulfill()
                }
                wait(for: [exp], timeout: 2)
            }
        }
    }
}

