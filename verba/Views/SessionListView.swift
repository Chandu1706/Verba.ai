import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation

/// Displays a list of recorded sessions, allows search, selection, and export.
struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext



    @State private var allSessions: [RecordingSession] = []     // Unfiltered dataset
    @State private var sessions: [RecordingSession] = []        // Filtered sessions for display
    @State private var isLoading = false
    @State private var offset = 0
    @State private var searchText = ""
    @State private var exportFileURL: URL? = nil
    @State private var selectedSession: RecordingSession? = nil
    @State private var expandedSessionIDs: Set<PersistentIdentifier> = []
    @State private var showAlert = false

    private let pageSize = 50

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NetworkStatusBanner() // Custom banner for online/offline status

                List {
                    // Group sessions by date
                    ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { date in
                        Section(header: Text(formatted(date))) {
                            ForEach(groupedSessions[date] ?? [], id: \.persistentModelID) { session in
                                VStack(alignment: .leading, spacing: 8) {
                                    // Session summary row
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(session.fileName)
                                                    .font(.headline)
                                                    .accessibilityLabel("Session filename \(session.fileName)")

                                                Spacer()

                                                BadgeView(count: session.segments.count)
                                            }

                                            Text(session.createdAt.formatted(date: .omitted, time: .shortened))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .accessibilityLabel("Created at \(session.createdAt.formatted(date: .long, time: .shortened))")
                                        }

                                        // Highlight selected session
                                        if selectedSession?.persistentModelID == session.persistentModelID {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .accessibilityLabel("Selected for export")
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        toggleExpansion(for: session)
                                    }
                                    .onLongPressGesture {
                                        // Toggle session selection
                                        if selectedSession?.persistentModelID == session.persistentModelID {
                                            selectedSession = nil
                                        } else {
                                            selectedSession = session
                                        }
                                    }

                                    // Show transcription segments if expanded
                                    if isExpanded(session) {
                                        ForEach(session.segments, id: \.persistentModelID) { segment in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(segment.fileName)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                    .accessibilityLabel("Segment \(segment.fileName)")

                                                Text(segment.transcription)
                                                    .font(.body)
                                                    .accessibilityLabel("Transcription \(segment.transcription)")
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                                .onAppear {
                                    // Load more sessions when reaching end
                                    if session == sessions.last {
                                        Task { await loadMoreSessions() }
                                    }
                                }
                            }
                            .onDelete { indices in
                                deleteSessions(at: indices, in: groupedSessions[date] ?? [])
                            }
                        }
                    }

                    // Show loading spinner if fetching more
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading...")
                            Spacer()
                        }
                    }
                }
                .navigationTitle("Recorded Sessions")
                .searchable(text: $searchText, prompt: "Search transcriptions or filenames")
                .onChange(of: searchText) { _, _ in
                    filterSessions()
                }
                .onAppear {
                    if allSessions.isEmpty {
                        Task { await loadMoreSessions() }
                    }
                }
                .refreshable {
                    await refreshSessions()
                }

                Divider()

                // Export & Share Button
                Button(action: {
                    if let session = selectedSession {
                        exportAndShare(session)
                    } else {
                        showAlert = true
                    }
                }) {
                    Text(" Export & Share")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .padding(.horizontal)
                }
                .padding(.bottom, 12)
                .alert("Please select a session to export", isPresented: $showAlert) {
                    Button("OK", role: .cancel) { }
                }
            }
        }
    }



    /// Determines whether a session's details should be expanded.
    private func isExpanded(_ session: RecordingSession) -> Bool {
        expandedSessionIDs.contains(session.persistentModelID)
    }

    /// Toggles expanded state for a session row.
    private func toggleExpansion(for session: RecordingSession) {
        if isExpanded(session) {
            expandedSessionIDs.remove(session.persistentModelID)
        } else {
            expandedSessionIDs.insert(session.persistentModelID)
        }
    }

    /// Groups sessions by date (year/month/day).
    private var groupedSessions: [Date: [RecordingSession]] {
        Dictionary(grouping: sessions) { session in
            let components = Calendar.current.dateComponents([.year, .month, .day], from: session.createdAt)
            return Calendar.current.date(from: components) ?? session.createdAt
        }
    }

    /// Loads additional sessions (paged) from storage.
    private func loadMoreSessions() async {
        guard !isLoading else { return }
        isLoading = true

        let newSessions = DataManager.shared.fetchSessions(offset: offset, limit: pageSize, context: modelContext)

        await MainActor.run {
            allSessions.append(contentsOf: newSessions)
            offset += newSessions.count
            isLoading = false
            filterSessions()
        }
    }

    /// Reloads all sessions (e.g. after search or pull-to-refresh).
    private func refreshSessions() async {
        await MainActor.run {
            offset = 0
            allSessions.removeAll()
            sessions.removeAll()
            selectedSession = nil
            exportFileURL = nil
            expandedSessionIDs.removeAll()
        }
        await loadMoreSessions()
    }

    /// Filters sessions by filename or transcription content.
    private func filterSessions() {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            sessions = allSessions
        } else {
            let lowercased = searchText.lowercased()
            sessions = allSessions.filter { session in
                session.fileName.lowercased().contains(lowercased) ||
                session.segments.contains { segment in
                    segment.transcription.lowercased().contains(lowercased) ||
                    segment.fileName.lowercased().contains(lowercased)
                }
            }
        }
    }

    /// Deletes sessions both from storage and UI.
    private func deleteSessions(at offsets: IndexSet, in group: [RecordingSession]) {
        for index in offsets {
            let session = group[index]
            DataManager.shared.deleteSession(session, context: modelContext)
            allSessions.removeAll { $0.persistentModelID == session.persistentModelID }
            sessions.removeAll { $0.persistentModelID == session.persistentModelID }
            if selectedSession?.persistentModelID == session.persistentModelID {
                selectedSession = nil
                exportFileURL = nil
            }
        }
    }

    /// Exports a session's transcription data to a CSV and opens share sheet.
    private func exportAndShare(_ session: RecordingSession) {
        let fileName = session.fileName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).csv")

        var csv = "File Name,Transcription\n"
        for segment in session.segments {
            let safeText = segment.transcription.replacingOccurrences(of: "\"", with: "''")
            csv += "\(segment.fileName),\"\(safeText)\"\n"
        }

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            exportFileURL = url

            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let topController = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                .first?.rootViewController {
                topController.present(activityVC, animated: true)
            }
        } catch {
            print("Failed to export session: \(error)")
        }
    }

    /// Formats a Date object into a display string.
    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

/// Displays a rounded badge with the number of segments in a session.
struct BadgeView: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .padding(6)
            .background(Capsule().fill(Color.blue.opacity(0.8)))
            .foregroundColor(.white)
            .accessibilityLabel("\(count) segments")
    }
}

