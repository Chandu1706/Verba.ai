//
//  AudioManager.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//

import Foundation
import AVFoundation
import SwiftData

class AudioManager: ObservableObject {
    private var engine = AVAudioEngine()
    private var file: AVAudioFile?
    private let session = AVAudioSession.sharedInstance()
    private var fileURL: URL?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var modelContext: ModelContext?

    @Published var isRecording = false
    @Published var currentInputLevel: Float = 0.0
    @Published var transcriptionStatus: String = ""
    @Published var canPlay: Bool = false


    func startRecording(with context: ModelContext) {
        self.modelContext = context

        do {
            try configureAudioSession()

            let format = engine.inputNode.outputFormat(forBus: 0)
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let timestamp = ISO8601DateFormatter().string(from: Date())
            fileURL = docDir.appendingPathComponent("recording_\(timestamp).caf")
            guard let fileURL else { return }

            file = try AVAudioFile(forWriting: fileURL, settings: format.settings)

            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                try? self.file?.write(from: buffer)

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
            transcriptionStatus = " Recording..."
            canPlay = false

            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                self.segmentAndSend()
            }

        } catch {
            print(" Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        timer?.invalidate()
        isRecording = false
        transcriptionStatus = " Recording stopped"
        canPlay = true

        if let fileURL = fileURL {
            segmentAndSend(urlOverride: fileURL)
        }
    }

    func playRecording() {
        guard let fileURL else {
            print(" No file to play")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: fileURL)
            player?.prepareToPlay()
            player?.play()
            print(" Playing: \(fileURL.lastPathComponent)")
        } catch {
            print(" Playback failed: \(error)")
        }
    }

    
    private func configureAudioSession() throws {
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { notification in
            if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               let reasonEnum = AVAudioSession.RouteChangeReason(rawValue: reason) {
                print(" Audio route changed: \(reasonEnum)")
            }
        }

        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { notification in
            guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                print("⏸ Interrupted — stopping...")
                self.stopRecording()
            case .ended:
                print(" Interruption ended")
            default:
                break
            }
        }
    }



    private func segmentAndSend(urlOverride: URL? = nil) {
        guard let modelContext else {
            print(" No SwiftData context available")
            return
        }

        guard let apiKey = Bundle.main.infoDictionary?["ASSEMBLY_API_KEY"] as? String, !apiKey.isEmpty else {
            print(" Missing or invalid ASSEMBLY_API_KEY in Info.plist")
            transcriptionStatus = "Missing API Key"
            return
        }

        // 🔍 DEBUG: Print masked key
        let maskedKey = String(apiKey.prefix(4)) + "••••" + String(apiKey.suffix(2))
        print(" Loaded API Key: \(maskedKey)")

        guard let segmentURL = urlOverride ?? fileURL else {
            print(" No segment file found.")
            return
        }

        print(" Sending segment for transcription: \(segmentURL.lastPathComponent)")
        transcriptionStatus = "Transcribing..."

        TranscriptionService.shared.transcribeWithAssemblyAI(audioURL: segmentURL, apiKey: apiKey) { transcriptionText in
            DispatchQueue.main.async {
                let session = RecordingSegment(fileName: segmentURL.lastPathComponent, transcription: transcriptionText ?? "Transcription failed")
                modelContext.insert(session)

                self.transcriptionStatus = transcriptionText ?? " Transcription failed"
                print(" Saved session: \(session.fileName)")
            }
        }
    }
}

