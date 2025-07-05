//
//  AudioManager.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//



import Foundation
import AVFoundation

class AudioManager: ObservableObject {
    private var engine = AVAudioEngine()
    private var file: AVAudioFile?
    private let session = AVAudioSession.sharedInstance()
    private var fileURL: URL?
    private var player: AVAudioPlayer?
    private var timer: Timer?

    @Published var isRecording = false
    @Published var currentInputLevel: Float = 0.0  // 0.0 to 1.0 for waveform
    @Published var transcriptionStatus: String = ""
    @Published var canPlay: Bool = false


    func startRecording() {
        do {
            try configureAudioSession()
            
            let format = engine.inputNode.outputFormat(forBus: 0)
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let timestamp = ISO8601DateFormatter().string(from: Date())
            fileURL = docDir.appendingPathComponent("recording_\(timestamp).caf")
            guard let fileURL = fileURL else { return }

            file = try AVAudioFile(forWriting: fileURL, settings: format.settings)

            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                try? self.file?.write(from: buffer)

                // Update audio level for waveform
                if let channelData = buffer.floatChannelData?[0] {
                    let frameLength = Int(buffer.frameLength)
                    let rms = sqrt((0..<frameLength).map { pow(channelData[$0], 2) }.reduce(0, +) / Float(frameLength))
                    let normalizedLevel = max(min(rms * 20, 1), 0)
                    DispatchQueue.main.async {
                        self.currentInputLevel = normalizedLevel
                    }
                }
            }

            try engine.start()
            isRecording = true
            transcriptionStatus = "Recording..."
            canPlay = false

        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        transcriptionStatus = "⏹ Recording stopped"
        canPlay = true
    }


    func playRecording() {
        guard let fileURL = fileURL else {
            print("No file to play")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: fileURL)
            player?.prepareToPlay()
            player?.play()
            print("Playing: \(fileURL.lastPathComponent)")
        } catch {
            print("Playback failed: \(error)")
        }
    }

    private func configureAudioSession() throws {
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        // Listen for route changes
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { notification in
            if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               let reasonEnum = AVAudioSession.RouteChangeReason(rawValue: reason) {
                print("Audio route changed: \(reasonEnum)")
            }
        }

        // Handle interruptions
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                print("⏸ Audio session interrupted")
                self.stopRecording()
            case .ended:
                print("xAudio session interruption ended")
                // Optionally resume
            @unknown default:
                break
            }
        }
    }
}
