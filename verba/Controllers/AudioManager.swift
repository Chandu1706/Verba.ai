//
//  AudioManager.swift
//  verba
//

import Foundation
import AVFoundation
import SwiftData

/// Manages audio recording, playback, live waveform monitoring,
/// transcription triggering, and session/segment persistence.
@MainActor
class AudioManager: ObservableObject {
   

    private var engine = AVAudioEngine()
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
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var recentTranscriptions: [String] = []



    /// Begins recording a new session and creates a file + session entry
    func startRecording(with context: ModelContext) async {
        self.modelContext = context
        let nextIndex = DataManager.shared.nextSessionIndex(context: context)
        let fileName = "Session \(nextIndex)"

        // Create and store session
        let session = RecordingSession(fileName: fileName, createdAt: Date())
        self.currentSession = session
        context.insert(session)

        do {
            try configureAudioSession()
            try checkDiskSpace()

            // Set up file for writing
            let format = engine.inputNode.outputFormat(forBus: 0)
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            fileURL = docDir.appendingPathComponent("\(fileName).caf")
            guard let fileURL else { return }

            file = try AVAudioFile(forWriting: fileURL, settings: format.settings)

            // Install tap to capture audio buffers and write to file
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                guard let self else { return }

                try? self.file?.write(from: buffer)

                // Calculate input level for waveform animation
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
            canPlay = false
            transcriptionStatus = "Recording..."

            // Schedule periodic segmenting + transcription
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                Task { @MainActor in
                    self.segmentAndSend()
                }
            }

        } catch {
            transcriptionStatus = "Failed to record: \(error.localizedDescription)"
            print("Failed to start recording: \(error)")
        }
    }

    /// Pauses the current recording session (audio engine only).
    func pauseRecording() {
        engine.pause()
        isPaused = true
        transcriptionStatus = "Paused"
        print("⏸ Paused recording")
    }

    /// Resumes a paused recording session.
    func resumeRecording() {
        do {
            try engine.start()
            isPaused = false
            transcriptionStatus = "Resumed"
            print(" Resumed recording")
        } catch {
            transcriptionStatus = "Failed to resume: \(error.localizedDescription)"
            print(" Failed to resume: \(error)")
        }
    }

    /// Stops recording, finalizes the audio file, and triggers final transcription.
    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        timer?.invalidate()
        isRecording = false
        isPaused = false
        canPlay = true
        transcriptionStatus = "Recording stopped"

        // Remove audio session observers
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)

        if let fileURL = fileURL {
            segmentAndSend(urlOverride: fileURL)
        }

        currentSession = nil
    }


    /// Plays the last recorded session using AVAudioPlayer.
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
            transcriptionStatus = "Playback failed"
            print(" Playback failed: \(error)")
        }
    }


    /// Configures AVAudioSession and sets up route/interruption notifications.
    private func configureAudioSession() throws {
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
    }

    /// Handles audio route changes like plugging/unplugging headphones.
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        print("Audio route changed: \(reason)")

        switch reason {
        case .oldDeviceUnavailable:
            if isRecording && !isPaused {
                pauseRecording()
            }
        case .newDeviceAvailable:
            if isPaused {
                resumeRecording()
            }
        default:
            break
        }
    }

    /// Handles interruptions like phone calls or alarms.
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            print(" Interruption began")
            if isRecording {
                pauseRecording()
            }
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume), isPaused {
                    resumeRecording()
                }
            }
        @unknown default:
            break
        }
    }

    /// Ensures at least ~10MB free space is available.
    private func checkDiskSpace() throws {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let resourceValues = try docDir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let availableSpace = resourceValues.volumeAvailableCapacityForImportantUsage,
           availableSpace < 10_000_000 {
            throw NSError(domain: "AudioManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Insufficient disk space"])
        }
    }

    /// Sends the last recorded audio segment to the transcription service.
    private func segmentAndSend(urlOverride: URL? = nil) {
        guard let modelContext, let currentSession else {
            print(" SwiftData context or session missing")
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

                // Update UI state
                self.transcriptionStatus = transcriptionText ?? "Transcription failed"
                self.isTranscribing = false

                // Save to recent list (up to 5)
                self.recentTranscriptions.insert(segment.transcription, at: 0)
                self.recentTranscriptions = Array(self.recentTranscriptions.prefix(5))

                print(" Saved segment: \(segment.fileName)")
            }
        }
    }
}

