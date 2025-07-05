import Foundation
import SwiftData

@Model
class RecordingSegment {
    @Attribute(.unique) var id = UUID()
    var fileName: String
    var transcription: String
    var createdAt: Date

    @Relationship var session: RecordingSession?
    var sessionID: UUID?

    init(fileName: String, transcription: String, createdAt: Date = Date(), session: RecordingSession? = nil) {
        self.fileName = fileName
        self.transcription = transcription
        self.createdAt = createdAt
        self.session = session
        self.sessionID = session?.id
    }
}


