import Foundation
import AVFoundation
import Speech

class TranscriptionService {
    static let shared = TranscriptionService()

    func transcribeWithAssemblyAI(audioURL: URL, apiKey: String, completion: @escaping (String?) -> Void) {
        print("🔐 Loaded API Key: \(String(apiKey.prefix(4)))••••\(String(apiKey.suffix(2)))")
        print("📤 Sending segment for transcription: \(audioURL.lastPathComponent)")

        // Step 1: Upload
        var uploadRequest = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/upload")!)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue(apiKey, forHTTPHeaderField: "Authorization")
        uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        guard let audioData = try? Data(contentsOf: audioURL) else {
            print("❌ Failed to read audio data")
            completion(nil)
            return
        }

        uploadRequest.httpBody = audioData

        URLSession.shared.dataTask(with: uploadRequest) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let uploadURL = json["upload_url"] as? String else {
                print("❌ Upload failed")
                completion(nil)
                return
            }

            print("✅ Upload complete, received URL: \(uploadURL)")

            // Step 2: Transcribe
            var transcribeRequest = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/transcript")!)
            transcribeRequest.httpMethod = "POST"
            transcribeRequest.setValue(apiKey, forHTTPHeaderField: "Authorization")
            transcribeRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let requestBody: [String: Any] = ["audio_url": uploadURL]
            transcribeRequest.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

            URLSession.shared.dataTask(with: transcribeRequest) { data, _, error in
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let transcriptId = json["id"] as? String else {
                    print("❌ Transcription request failed")
                    RetryManager.shared.recordFailure()
                    completion(nil)
                    return
                }

                print("🟡 Transcription started with ID: \(transcriptId)")
                self.pollStatus(for: transcriptId, apiKey: apiKey, retries: 0, completion: completion)
            }.resume()
        }.resume()
    }

    private func pollStatus(for id: String, apiKey: String, retries: Int, completion: @escaping (String?) -> Void) {
        if RetryManager.shared.shouldFallback() {
            print("⚠️ Too many failures, falling back to Apple Speech Recognizer")
            AppleTranscriptionService.transcribe(audioURL: nil) { fallbackText in
                completion(fallbackText ?? "Fallback transcription failed")
            }
            return
        }

        let url = URL(string: "https://api.assemblyai.com/v2/transcript/\(id)")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        print("⏲ Scheduling polling every 3 seconds for ID: \(id)")

        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            URLSession.shared.dataTask(with: request) { data, _, error in
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let status = json["status"] as? String else {
                    print("❌ Polling failed")
                    RetryManager.shared.recordFailure()
                    self.pollStatus(for: id, apiKey: apiKey, retries: retries + 1, completion: completion)
                    return
                }

                print("📡 Polling result: \(status)")

                switch status {
                case "completed":
                    RetryManager.shared.resetFailures()
                    completion(json["text"] as? String)
                case "error":
                    RetryManager.shared.recordFailure()
                    completion("❌ Transcription failed")
                default:
                    self.pollStatus(for: id, apiKey: apiKey, retries: retries + 1, completion: completion)
                }
            }.resume()
        }
    }
}

