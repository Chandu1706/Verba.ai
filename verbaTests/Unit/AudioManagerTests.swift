//
//  AudioManagerTests.swift
//  verbaTests
//
//  Created by Chandu Korubilli on 7/5/25.
//

import XCTest
import SwiftData
import AVFoundation
@testable import verba

final class AudioManagerTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var audioManager: AudioManager!

    override func setUpWithError() throws {
        modelContainer = try ModelContainer(
            for: RecordingSession.self, RecordingSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = ModelContext(modelContainer)
        audioManager = AudioManager()
    }

    override func tearDownWithError() throws {
        modelContext = nil
        modelContainer = nil
        audioManager = nil
    }

    func testStartRecording_initialState() throws {
        audioManager.startRecording(with: modelContext)

        let expectation = XCTestExpectation(description: "Wait for recording to start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(audioManager.isRecording)
        XCTAssertFalse(audioManager.canPlay)
        XCTAssertEqual(audioManager.transcriptionStatus, " Recording...")
    }

    func testPauseResumeRecording() throws {
        audioManager.startRecording(with: modelContext)

        audioManager.pauseRecording()
        XCTAssertTrue(audioManager.isPaused)
        XCTAssertEqual(audioManager.transcriptionStatus, "Paused")

        audioManager.resumeRecording()
        XCTAssertFalse(audioManager.isPaused)
        XCTAssertEqual(audioManager.transcriptionStatus, "Resumed")
    }

    func testStopRecording_shouldEnablePlayback() throws {
        audioManager.startRecording(with: modelContext)

        let startExpectation = XCTestExpectation(description: "Wait for recording to start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.audioManager.stopRecording()
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 2.0)

        XCTAssertFalse(audioManager.isRecording)
        XCTAssertTrue(audioManager.canPlay)
        XCTAssertEqual(audioManager.transcriptionStatus, " Recording stopped")
    }

    func testPlayRecording_withoutError() throws {
        audioManager.startRecording(with: modelContext)

        let expectation = XCTestExpectation(description: "Allow recording and stop")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.audioManager.stopRecording()
            self.audioManager.playRecording()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        XCTAssertTrue(audioManager.canPlay, "Should allow playback")
        // Optionally validate player is playing
    }
}

