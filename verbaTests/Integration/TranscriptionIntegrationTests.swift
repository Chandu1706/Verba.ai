//
//  TranscriptionIntegrationTests.swift
//  verbaTests
//
//  Created by Chandu Korubilli on 7/5/25.
//

import XCTest
@testable import verba

final class TranscriptionIntegrationTests: XCTestCase {

    /// This dummy file simulates a recorded audio file
    var dummyAudioURL: URL!

    override func setUpWithError() throws {
        // Create a small dummy .caf file
        let data = Data(repeating: 0, count: 1024)  // Empty audio content (silent)
        dummyAudioURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.caf")
        try data.write(to: dummyAudioURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dummyAudioURL)
    }

    func testTranscriptionSuccess() {
        let apiKey = Bundle.main.infoDictionary?["ASSEMBLY_API_KEY"] as? String ?? ""
        XCTAssertFalse(apiKey.isEmpty, " Assembly API key missing for integration test")

        let expectation = self.expectation(description: "Transcription should succeed")

        TranscriptionService.shared.transcribeWithAssemblyAI(audioURL: dummyAudioURL, apiKey: apiKey) { result in
            XCTAssertNotNil(result)
            print("Transcription result: \(result!)")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 30, handler: nil)
    }

    func testTranscriptionWithInvalidAPIKey() {
        let expectation = self.expectation(description: "Should fail with invalid key")

        TranscriptionService.shared.transcribeWithAssemblyAI(audioURL: dummyAudioURL, apiKey: "INVALID_KEY") { result in
            XCTAssertNil(result, "Expected nil result for invalid API key")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 30, handler: nil)
    }

    func testTranscriptionWithMissingFile() {
        let nonexistentURL = dummyAudioURL.deletingLastPathComponent().appendingPathComponent("nonexistent.caf")
        let expectation = self.expectation(description: "Should fail with missing file")

        let apiKey = Bundle.main.infoDictionary?["ASSEMBLY_API_KEY"] as? String ?? ""

        TranscriptionService.shared.transcribeWithAssemblyAI(audioURL: nonexistentURL, apiKey: apiKey) { result in
            XCTAssertNil(result, " Expected nil result for missing file")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 30, handler: nil)
    }
}

