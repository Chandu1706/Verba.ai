import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sessions: [RecordingSession] = []
    @State private var isLoading = false
    @State private var offset = 0
    @State private var searchText = ""

    private let pageSize = 50

    var filteredSessions: [RecordingSession] {
        if searchText.isEmpty {
            return sessions
        } else {
            return sessions.filter {
                $0.fileName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSessions, id: \.id) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.fileName)
                                .font(.headline)

                            Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.gray)

                            if let badge = badgeFor(session: session) {
                                Text(badge.label)
                                    .font(.caption2)
                                    .padding(4)
                                    .background(badge.color)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .onAppear {
                            if session == filteredSessions.last {
                                loadMoreSessions()
                            }
                        }
                    }
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading more...")
                        Spacer()
                    }
                }
            }
            .navigationTitle("Recorded Sessions")
            .searchable(text: $searchText)
            .refreshable {
                refreshSessions()
            }
            .onAppear {
                if sessions.isEmpty {
                    loadMoreSessions()
                }
            }
        }
    }

    // MARK: - Load & Refresh

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

    private func refreshSessions() {
        Task { @MainActor in
            self.sessions = DataManager.shared.fetchSessions(offset: 0, limit: offset + pageSize, context: modelContext)
        }
    }

    // MARK: - Badge Logic

    private func badgeFor(session: RecordingSession) -> (label: String, color: Color)? {
        let segments = session.segments

        if segments.isEmpty {
            return ("Pending", .yellow)
        } else if segments.contains(where: { $0.transcription.lowercased().contains("failed") }) {
            return ("Failed", .red)
        } else {
            return ("Complete", .green)
        }
    }
}

