//
//  RetryQueue.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//

import Foundation
import SwiftData

@MainActor
class RetryQueue {
    static let shared = RetryQueue()
    private var pendingSegments: [URL] = []
    private var isFlushing = false

    private init() {}

    func add(_ url: URL) {
        guard !pendingSegments.contains(url) else { return }
        pendingSegments.append(url)
        print("Queued failed segment: \(url.lastPathComponent)")
    }

    func flush(using apiKey: String, context: ModelContext) {
        guard NetworkMonitor.shared.isConnected else {
            print(" No internet. Retry postponed.")
            return
        }

        guard !isFlushing else {
            print(" Already flushing retry queue.")
            return
        }

        isFlushing = true

        Task {
            for url in pendingSegments {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    print("Missing file. Skipping: \(url.lastPathComponent)")
                    continue
                }

                // Fallback session
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let fallbackSession = RecordingSession(fileName: "Retry_Session_\(timestamp)", createdAt: Date())
                context.insert(fallbackSession)

                await withCheckedContinuation { continuation in
                    TranscriptionService.shared.transcribeWithAssemblyAI(audioURL: url, apiKey: apiKey) { transcriptionText in
                        let transcription = transcriptionText ?? "Transcription failed (retry)"

                        let segment = RecordingSegment(
                            fileName: url.lastPathComponent,
                            transcription: transcription,
                            createdAt: Date(),
                            session: fallbackSession
                        )

                        context.insert(segment)
                        print(" Retried and saved segment: \(segment.fileName)")
                        continuation.resume()
                    }
                }
            }

            pendingSegments.removeAll()
            isFlushing = false
            do {
                try context.save()
                print("Retry flush completed and saved.")
            } catch {
                print(" Failed to save after retry flush: \(error.localizedDescription)")
            }
        }
    }
}

