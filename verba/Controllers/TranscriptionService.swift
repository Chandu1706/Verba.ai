//
//  TranscriptionService.swift
//  verba
//

import Foundation
import Speech
class TranscriptionService {
    static let shared = TranscriptionService()

    private let uploadURL = "https://api.assemblyai.com/v2/upload"
    private let transcriptURL = "https://api.assemblyai.com/v2/transcript"

    private let session: URLSession = .shared
    private let pollingInterval: TimeInterval = 3
    private let maxRetries = 5

    func transcribeWithAssemblyAI(audioURL: URL, apiKey: String, completion: @escaping (String?) -> Void) {
        uploadAudio(audioURL: audioURL, apiKey: apiKey) { [weak self] uploadResult in
            switch uploadResult {
            case .success(let uploadedURL):
                self?.startTranscription(apiKey: apiKey, audioURL: uploadedURL, completion: completion)
            case .failure(let error):
                print(" Upload failed: \(error.localizedDescription)")
                completion("Upload failed")
            }
        }
    }
    func transcribeWithAppleSpeech(audioURL: URL, completion: @escaping (String?) -> Void) {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer = recognizer, recognizer.isAvailable else {
            completion("Apple speech recognition not available")
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                print(" Apple speech error: \(error)")
                completion(nil)
            } else if let result = result, result.isFinal {
                completion(result.bestTranscription.formattedString)
            }
        }
    }


    private func uploadAudio(audioURL: URL, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let audioData = try? Data(contentsOf: audioURL) else {
            completion(.failure(NSError(domain: "TranscriptionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to read audio file."])))
            return
        }

        var request = URLRequest(url: URL(string: uploadURL)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let uploadedURL = json["upload_url"] as? String else {
                completion(.failure(NSError(domain: "TranscriptionService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Upload URL not received"])))
                return
            }

            completion(.success(uploadedURL))
        }.resume()
    }

    private func startTranscription(apiKey: String, audioURL: String, completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: URL(string: transcriptURL)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["audio_url": audioURL]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Transcription request failed: \(error.localizedDescription)")
                completion("Transcription request failed")
                return
            }

            guard let data = data,
                  let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = responseJSON["id"] as? String else {
                completion("Invalid transcription response")
                return
            }

            print("Transcription started with ID: \(id)")
            self?.pollTranscription(apiKey: apiKey, id: id, retries: 0, completion: completion)
        }.resume()
    }

    private func pollTranscription(apiKey: String, id: String, retries: Int, completion: @escaping (String?) -> Void) {
        guard retries < maxRetries else {
            print(" Max retries reached for transcription ID: \(id)")
            completion("Timed out")
            return
        }

        let pollingURL = "\(transcriptURL)/\(id)"
        var request = URLRequest(url: URL(string: pollingURL)!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print(" Polling error: \(error.localizedDescription)")
                completion("Polling failed")
                return
            }

            guard let data = data,
                  let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = responseJSON["status"] as? String else {
                completion("Invalid polling response")
                return
            }

            if status == "completed", let text = responseJSON["text"] as? String {
                print(" Transcription complete: \(text.prefix(60))...")
                completion(text)
            } else if status == "error" {
                let errorMsg = responseJSON["error"] as? String ?? "Unknown error"
                print(" Transcription failed: \(errorMsg)")
                completion("Transcription error: \(errorMsg)")
            } else {
                print("Status: \(status). Retrying in \(self?.pollingInterval ?? 3)s...")
                DispatchQueue.global().asyncAfter(deadline: .now() + (self?.pollingInterval ?? 3)) {
                    self?.pollTranscription(apiKey: apiKey, id: id, retries: retries + 1, completion: completion)
                }
            }
        }.resume()
    }
}

