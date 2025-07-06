//
//  SessionListViewModel.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//



import Foundation
import SwiftData

@MainActor
class SessionListViewModel: ObservableObject {
    @Published var sessions: [RecordingSession] = []
    @Published var isLoading = false
    @Published var offset = 0
    @Published var searchText = ""
    @Published var selectedSession: RecordingSession?
    
    let pageSize = 50

    func groupedSessions() -> [Date: [RecordingSession]] {
        Dictionary(grouping: sessions) { session in
            Calendar.current.startOfDay(for: session.createdAt)
        }
    }

    func sortedDates() -> [Date] {
        groupedSessions().keys.sorted(by: >)
    }

    func loadMore(context: ModelContext) async {
        guard !isLoading else { return }
        isLoading = true

        let newSessions = searchText.isEmpty
            ? DataManager.shared.fetchSessions(offset: offset, limit: pageSize, context: context)
            : DataManager.shared.searchSessions(matching: searchText, context: context)

        await MainActor.run {
            sessions.append(contentsOf: newSessions)
            offset += newSessions.count
            isLoading = false
        }
    }

    func refresh(context: ModelContext) async {
        await MainActor.run {
            sessions.removeAll()
            offset = 0
        }
        await loadMore(context: context)
    }

    func delete(session: RecordingSession, context: ModelContext) {
        DataManager.shared.deleteSession(session, context: context)
        sessions.removeAll { $0.persistentModelID == session.persistentModelID }
    }
}
