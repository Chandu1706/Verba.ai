//
//  AudioRecorder.swift
//  verba
//
//  Created by Chandu Korubilli on 7/6/25.
//
import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    let engine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let eq = AVAudioUnitEQ(numberOfBands: 1)
    private let reverb = AVAudioUnitReverb()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    
    @Published var isRecording = false

    override init() {
        inputNode = engine.inputNode
        super.init()
        configureAudioPipeline()
    }

    private func configureAudioPipeline() {
        let format = inputNode.outputFormat(forBus: 0)

        // Configure EQ for noise reduction (high-pass filter)
        let band = eq.bands[0]
        band.filterType = .highPass
        band.frequency = 120.0      // Removes low-frequency rumble
        band.bandwidth = 0.5
        band.gain = 0.0
        band.bypass = false

        // Configure light reverb for natural tone
        reverb.loadFactoryPreset(.mediumRoom)
        reverb.wetDryMix = 20.0

        // Attach and connect nodes
        engine.attach(eq)
        engine.attach(reverb)

        engine.connect(inputNode, to: eq, format: format)
        engine.connect(eq, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
    }

    func startRecording(to url: URL) throws {
        if engine.isRunning {
            stopRecording()
        }

        recordingURL = url
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self, let file = self.audioFile else { return }
            do {
                try file.write(from: buffer)
            } catch {
                print("Failed to write buffer: \(error)")
            }
        }

        try engine.start()
        isRecording = true
        print("Started recording to \(url.lastPathComponent)")
    }

    func stopRecording() {
        guard isRecording else { return }
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        isRecording = false
        print("Stopped recording")
    }

    func getRecordingURL() -> URL? {
        return recordingURL
    }
}

