//
//  RetryQueue.swift
//  verba
//
//  Created by Chandu korubilli on 7/5/25.
//

import Foundation
import SwiftData 

class RetryQueue {
    static let shared = RetryQueue()
    private var pendingSegments: [URL] = []

    func add(_ url: URL) {
        pendingSegments.append(url)
    }

    func flush(using apiKey: String, context: ModelContext) {
        guard NetworkMonitor.shared.isConnected else { return }

        for url in pendingSegments {
            TranscriptionService.shared.transcribeWithAssemblyAI(audioURL: url, apiKey: apiKey) { text in
                let session = RecordingSegment(fileName: url.lastPathComponent, transcription: text)
                context.insert(session)
            }
        }

        pendingSegments.removeAll()
    }
}

