//
//  SessionListView.swift
//  verba
//

import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sessions: [RecordingSession] = []
    @State private var isLoading = false
    @State private var offset = 0
    @State private var searchText = ""
    private let pageSize = 50

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredSessions(), id: \ .id) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.fileName)
                                .font(.headline)
                            Text("\(session.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .onAppear {
                            if session == sessions.last {
                                loadMoreSessions()
                            }
                        }
                    }
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading...")
                        Spacer()
                    }
                }
            }
            .navigationTitle("Recorded Sessions")
            .searchable(text: $searchText, prompt: "Search transcriptions")
            .onAppear {
                if sessions.isEmpty {
                    loadMoreSessions()
                }
            }
        }
    }

    private func filteredSessions() -> [RecordingSession] {
        guard !searchText.isEmpty else { return sessions }
        return DataManager.shared.searchSessions(matching: searchText, context: modelContext)
    }

    private func loadMoreSessions() {
        guard !isLoading else { return }
        isLoading = true

        Task { @MainActor in
            let newSessions = DataManager.shared.fetchSessions(
                offset: offset,
                limit: pageSize,
                context: modelContext
            )

            self.sessions.append(contentsOf: newSessions)
            self.offset += newSessions.count
            self.isLoading = false
        }
    }
}

