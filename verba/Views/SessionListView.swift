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
        NavigationStack {
            VStack(spacing: 0) {
                NetworkStatusBanner()

                List {
                    ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { date in
                        Section(header: Text(formatted(date))) {
                            ForEach(groupedSessions[date] ?? [], id: \.persistentModelID) { session in
                                NavigationLink(destination: SessionDetailView(session: session)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(session.fileName)
                                                .font(.headline)
                                            Spacer()
                                            BadgeView(count: session.segments.count)
                                        }
                                        Text(session.createdAt.formatted(date: .omitted, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .onAppear {
                                        if session == sessions.last {
                                            Task { await loadMoreSessions() }
                                        }
                                    }
                                }
                            }
                            .onDelete { indices in
                                deleteSessions(at: indices, in: groupedSessions[date] ?? [])
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
                .onChange(of: searchText) { _, _ in
                    Task { await refreshSessions() }
                }
                .onAppear {
                    if sessions.isEmpty {
                        Task { await loadMoreSessions() }
                    }
                }
                .refreshable {
                    await refreshSessions()
                }
            }
        }
    }

    private var groupedSessions: [Date: [RecordingSession]] {
        Dictionary(grouping: sessions) { session in
            let components = Calendar.current.dateComponents([.year, .month, .day], from: session.createdAt)
            return Calendar.current.date(from: components) ?? session.createdAt
        }
    }

    private func loadMoreSessions() async {
        guard !isLoading else { return }
        isLoading = true

        let newSessions: [RecordingSession]
        if searchText.isEmpty {
            newSessions = DataManager.shared.fetchSessions(offset: offset, limit: pageSize, context: modelContext)
        } else {
            newSessions = DataManager.shared.searchSessions(matching: searchText, context: modelContext)
        }

        await MainActor.run {
            sessions.append(contentsOf: newSessions)
            offset += newSessions.count
            isLoading = false
        }
    }

    private func refreshSessions() async {
        await MainActor.run {
            offset = 0
            sessions.removeAll()
        }
        await loadMoreSessions()
    }

    private func deleteSessions(at offsets: IndexSet, in group: [RecordingSession]) {
        for index in offsets {
            let session = group[index]
            DataManager.shared.deleteSession(session, context: modelContext)
            sessions.removeAll { $0.persistentModelID == session.persistentModelID }
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct BadgeView: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .padding(6)
            .background(Capsule().fill(Color.blue.opacity(0.8)))
            .foregroundColor(.white)
    }
}

