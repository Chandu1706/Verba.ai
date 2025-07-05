//
//  SessionDetailView.swift
//  verba
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let session: RecordingSession
    @State private var segments: [RecordingSegment] = []

    var body: some View {
        List {
            Section(header: Text("Session: \(session.fileName)")
                .font(.headline)
                .padding(.vertical, 8)) {
                    ForEach(segments, id: \.id) { segment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(segment.fileName)
                                .font(.subheadline)
                                .bold()
                            Text(segment.transcription)
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Recording segment \(segment.fileName)")
                        .accessibilityValue(segment.transcription)
                    }
                }
        }
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSegments()
        }
    }

    private func loadSegments() {
        let descriptor = FetchDescriptor<RecordingSegment>(
            predicate: #Predicate { $0.session != nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        do {
            let allSegments = try modelContext.fetch(descriptor)
            self.segments = allSegments.filter { $0.session?.fileName == session.fileName }
        } catch {
            print("Failed to fetch segments: \(error)")
            self.segments = []
        }
    }
}

