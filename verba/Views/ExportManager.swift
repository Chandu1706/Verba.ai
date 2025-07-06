//
//  ExportManager.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//

import Foundation
import SwiftData
import UIKit

class ExportManager {
    static func exportSessions(context: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<RecordingSession>()
        guard let sessions = try? context.fetch(descriptor) else { return nil }

        var csv = "Session,CreatedAt,Segment,Transcription\n"
        for session in sessions {
            for segment in session.segments {
                csv += "\(session.fileName),\(session.createdAt),\(segment.fileName),\"\(segment.transcription.replacingOccurrences(of: "\"", with: "\"\""))\"\n"
            }
        }

        let fileName = "Verba_Export_\(Date().timeIntervalSince1970).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Export failed: \(error)")
            return nil
        }
    }

    static func shareExport(from controller: UIViewController, context: ModelContext) {
        guard let url = exportSessions(context: context) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.present(activityVC, animated: true)
    }
}
