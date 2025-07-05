//
//  RecordingSegment.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//
import Foundation
import SwiftData

@Model
class RecordingSegment {
    var id: UUID
    var fileName: String
    var transcription: String?
    var retryCount: Int

    init(fileName: String, transcription: String? = nil, retryCount: Int = 0) {
        self.id = UUID()
        self.fileName = fileName
        self.transcription = transcription
        self.retryCount = retryCount
    }
}
