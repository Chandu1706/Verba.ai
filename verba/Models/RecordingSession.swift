import Foundation
import SwiftData

@Model
class RecordingSession {
    @Attribute(.unique) var id = UUID()
    var fileName: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \RecordingSegment.session)
    var segments: [RecordingSegment] = []

    init(fileName: String, createdAt: Date = Date()) {
        self.fileName = fileName
        self.createdAt = createdAt
    }

    // Optional: Convenience method to add a segment
    func addSegment(fileName: String, transcription: String) {
        let segment = RecordingSegment(fileName: fileName, transcription: transcription, session: self)
        segments.append(segment)
    }

    // Optional: Concatenated transcription string
    var fullTranscription: String {
        segments.map { $0.transcription }.joined(separator: "\n")
    }
}

