//
//  AudioManager.swift
//  verba
//

import Foundation
import AVFoundation
import SwiftData

class AudioManager: ObservableObject {
    private var engine = AVAudioEngine()
    private var eqNode = AVAudioUnitEQ(numberOfBands: 1)
    private var file: AVAudioFile?
    private let session = AVAudioSession.sharedInstance()
    private var fileURL: URL?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var modelContext: ModelContext?
    private var currentSession: RecordingSession?

    @Published var isRecording = false
    @Published var currentInputLevel: Float = 0.0
    @Published var transcriptionStatus: String = ""
    @Published var canPlay: Bool = false
    @Published var isPaused = false
    @Published var isTranscribing: Bool = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isEQEnabled: Bool = false


    func startRecording(with context: ModelContext) {
        self.modelContext = context
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let session = RecordingSession(fileName: "Session_\(timestamp)", createdAt: Date())
        self.currentSession = session
        context.insert(session)

        do {
            try configureAudioSession()
            try checkStorageSpace()

            let format = engine.inputNode.outputFormat(forBus: 0)
            fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("recording_\(timestamp).caf")
            guard let fileURL else { return }

            file = try AVAudioFile(forWriting: fileURL, settings: format.settings)

            setupEqualizer()
            engine.attach(eqNode)

            engine.connect(engine.inputNode, to: eqNode, format: format)
            engine.connect(eqNode, to: engine.mainMixerNode, format: format)

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
            transcriptionStatus = "Recording..."
            canPlay = false

            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                self.segmentAndSend()
            }

        } catch {
            showError = true
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print(" \(error)")
        }
    }

    func pauseRecording() {
        engine.pause()
        isPaused = true
        transcriptionStatus = "Paused"
        print("⏸ Paused recording")
    }

    func resumeRecording() {
        do {
            try engine.start()
            isPaused = false
            transcriptionStatus = "Resumed"
            print(" Resumed recording")
        } catch {
            showError = true
            errorMessage = "Failed to resume: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        timer?.invalidate()
        isRecording = false
        isPaused = false
        transcriptionStatus = "Recording stopped"
        canPlay = true

        if let fileURL = fileURL {
            segmentAndSend(urlOverride: fileURL)
        }

        currentSession = nil
    }

    func playRecording() {
        guard let fileURL else {
            print("No file to play")
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

    private func setupEqualizer() {
        let band = eqNode.bands[0]
        band.filterType = .lowPass
        band.frequency = 1200 // Hz
        band.bandwidth = 0.5
        band.gain = 0
        band.bypass = false
        eqNode.globalGain = 0
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
                print(" Interrupted — stopping...")
                self.stopRecording()
            case .ended:
                print(" Interruption ended")
            default:
                break
            }
        }
    }

    private func checkStorageSpace() throws {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let values = try docDir.resourceValues(forKeys: [.volumeAvailableCapacityKey])

        guard let available = values.volumeAvailableCapacity, available > 10 * 1024 * 1024 else {
            throw NSError(domain: "AudioManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not enough disk space to record audio."])
        }
    }

    private func segmentAndSend(urlOverride: URL? = nil) {
        guard let modelContext, let currentSession else {
            print("SwiftData context or session missing")
            return
        }

        guard let apiKey = Bundle.main.infoDictionary?["ASSEMBLY_API_KEY"] as? String, !apiKey.isEmpty else {
            transcriptionStatus = "Missing API Key"
            print(" Missing or invalid ASSEMBLY_API_KEY in Info.plist")
            return
        }

        guard let segmentURL = urlOverride ?? fileURL else {
            print(" No segment file found.")
            return
        }

        let maskedKey = String(apiKey.prefix(4)) + "...." + String(apiKey.suffix(2))
        print(" Loaded API Key: \(maskedKey)")
        print(" Sending segment for transcription: \(segmentURL.lastPathComponent)")

        transcriptionStatus = "Transcribing..."
        isTranscribing = true

        TranscriptionService.shared.transcribeWithAssemblyAI(audioURL: segmentURL, apiKey: apiKey) { transcriptionText in
            DispatchQueue.main.async {
                let segment = RecordingSegment(
                    fileName: segmentURL.lastPathComponent,
                    transcription: transcriptionText ?? "Transcription failed",
                    createdAt: Date(),
                    session: currentSession
                )
                modelContext.insert(segment)

                self.transcriptionStatus = transcriptionText ?? "Transcription failed"
                self.isTranscribing = false
                print(" Saved segment: \(segment.fileName)")
            }
        }
    }
}

