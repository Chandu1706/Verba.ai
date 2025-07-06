import WidgetKit
import SwiftUI
import SwiftData

struct SessionEntry: TimelineEntry {
    let date: Date
    let fileName: String?
    let createdAt: Date?
}

struct VerbaWidgetEntryView: View {
    var entry: SessionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let fileName = entry.fileName, let createdAt = entry.createdAt {
                Text("Last Session")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(fileName)
                    .font(.headline)
                    .lineLimit(1)

                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
            } else {
                Text("No sessions found")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
    }
}

struct VerbaWidget: Widget {
    let kind: String = "VerbaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SessionTimelineProvider()) { entry in
            VerbaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Verba Recent Session")
        .description("View your latest recording session.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SessionTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionEntry {
        SessionEntry(date: Date(), fileName: "Loading...", createdAt: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionEntry) -> Void) {
        Task {
            let summary = await SessionDataFetcher.fetchLatestSummary()
            let entry = SessionEntry(date: Date(), fileName: summary?.fileName, createdAt: summary?.createdAt)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionEntry>) -> Void) {
        Task {
            let summary = await SessionDataFetcher.fetchLatestSummary()
            let entry = SessionEntry(date: Date(), fileName: summary?.fileName, createdAt: summary?.createdAt)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? .now.addingTimeInterval(900)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

@MainActor
class SessionDataFetcher {
    struct SessionSummary {
        let fileName: String
        let createdAt: Date
    }

    static func fetchLatestSummary() async -> SessionSummary? {
        do {
            let container = try ModelContainer(for: RecordingSession.self)
            let context = container.mainContext
            var fetch = FetchDescriptor<RecordingSession>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            fetch.fetchLimit = 1
            let sessions = try context.fetch(fetch)

            if let latest = sessions.first {
                return SessionSummary(fileName: latest.fileName, createdAt: latest.createdAt)
            }
        } catch {
            print("Widget fetch error: \(error)")
        }
        return nil
    }
}

