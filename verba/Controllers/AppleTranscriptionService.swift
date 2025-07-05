//
//  AppleTranscriptionService.swift
//  verba
//
//  Created by Chandu korubilli on 7/5/25.
//
import Foundation
import Speech

class AppleTranscriptionService {
    static func transcribe(audioURL: URL?, completion: @escaping (String?) -> Void) {
        guard let audioURL = audioURL ?? getLatestRecording() else {
            print("❌ No audio file found for Apple fallback")
            completion(nil)
            return
        }

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        let request = SFSpeechURLRecognitionRequest(url: audioURL)

        recognizer?.recognitionTask(with: request) { result, error in
            if let error = error {
                print("❌ Apple transcription failed: \(error.localizedDescription)")
                completion("Apple transcription failed")
                return
            }

            if let result = result, result.isFinal {
                print("🍎 Apple transcription result: \(result.bestTranscription.formattedString)")
                completion(result.bestTranscription.formattedString)
            }
        }
    }

    private static func getLatestRecording() -> URL? {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let files = try? FileManager.default.contentsOfDirectory(at: docDir!, includingPropertiesForKeys: nil) else {
            return nil
        }

        let recordings = files.filter { $0.pathExtension == "caf" }
        return recordings.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first
    }
}

