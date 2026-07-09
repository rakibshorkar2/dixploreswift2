import SwiftUI
import WidgetKit

struct DownloadEntry: TimelineEntry {
    let date: Date
    let fileName: String
    let progress: Double
    let speed: String
    let eta: String
    let downloadedSize: String
    let totalSize: String
    let isActive: Bool
    let activeCount: Int
}

struct DownloadProvider: TimelineProvider {
    func placeholder(in context: Context) -> DownloadEntry {
        DownloadEntry(
            date: Date(),
            fileName: "Downloading...",
            progress: 0.45,
            speed: "5.2 MB/s",
            eta: "2:30",
            downloadedSize: "45 MB",
            totalSize: "100 MB",
            isActive: true,
            activeCount: 1
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DownloadEntry) -> Void) {
        let entry = DownloadEntry(
            date: Date(),
            fileName: "example-file.mp4",
            progress: 0.6,
            speed: "3.1 MB/s",
            eta: "1:45",
            downloadedSize: "60 MB",
            totalSize: "100 MB",
            isActive: true,
            activeCount: 2
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DownloadEntry>) -> Void) {
        let userDefaults = UserDefaults(suiteName: "group.com.dirxplore")
        let fileName = userDefaults?.string(forKey: "activeFileName") ?? "No active downloads"
        let progress = userDefaults?.double(forKey: "activeProgress") ?? 0
        let speed = userDefaults?.string(forKey: "activeSpeed") ?? ""
        let eta = userDefaults?.string(forKey: "activeEta") ?? "--"
        let downloadedSize = userDefaults?.string(forKey: "activeDownloadedSize") ?? ""
        let totalSize = userDefaults?.string(forKey: "activeTotalSize") ?? ""
        let activeCount = userDefaults?.integer(forKey: "activeDownloadCount") ?? 0
        let isActive = activeCount > 0

        let entry = DownloadEntry(
            date: Date(),
            fileName: fileName,
            progress: progress,
            speed: speed,
            eta: eta,
            downloadedSize: downloadedSize,
            totalSize: totalSize,
            isActive: isActive,
            activeCount: activeCount
        )

        let refreshDate = Calendar.current.date(byAdding: .second, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

struct DownloadWidgetEntryView: View {
    var entry: DownloadEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if entry.isActive {
            switch family {
            case .systemSmall:
                compactView
            default:
                expandedView
            }
        } else {
            noDownloadsView
        }
    }

    private var compactView: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 4)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            Text(entry.fileName)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)

            Text("\(Int(entry.progress * 100))%")
                .font(.caption)
                .fontWeight(.bold)

            if entry.activeCount > 1 {
                Text("+\(entry.activeCount - 1) more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var expandedView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
                Text(entry.fileName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                if entry.activeCount > 1 {
                    Text("+\(entry.activeCount - 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            ProgressView(value: entry.progress)
                .tint(.blue)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption2)
                    Text(entry.speed)
                        .font(.caption2)
                }
                .foregroundColor(.green)

                Spacer()

                Text("\(entry.downloadedSize) / \(entry.totalSize)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(entry.eta)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var noDownloadsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            Text("No Active Downloads")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

@available(iOS 16.0, *)
struct DownloadWidget: Widget {
    let kind: String = "com.dirxplore.DownloadWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DownloadProvider()) { entry in
            DownloadWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Downloads")
        .description("Track your active downloads.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
