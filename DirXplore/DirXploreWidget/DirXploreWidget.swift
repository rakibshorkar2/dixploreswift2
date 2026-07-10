import WidgetKit
import SwiftUI
import ActivityKit

struct DirXploreWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            // Lock Screen / Notification Banner UI
            DownloadActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(Color.blue)
        } dynamicIsland: { context in
            DynamicIsland {
                // Dynamic Island Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.progressPercentage)
                        .font(.subheadline.bold())
                        .foregroundColor(.blue)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.fileName)
                            .font(.footnote.bold())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        // Mini progress bar
                        ProgressView(value: context.state.progress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                            .background(Color.white.opacity(0.15))
                            .scaleEffect(x: 1, y: 0.8, anchor: .center)
                        
                        HStack {
                            Text(context.state.formattedSpeed)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(context.state.formattedETA)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Empty bottom region
                }
            } compactLeading: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                Text(context.state.progressPercentage)
                    .font(.caption2.bold())
                    .foregroundColor(.blue)
            } minimal: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
            }
            .keylineTint(Color.blue)
        }
    }
}

struct DownloadActivityView: View {
    let context: ActivityViewContext<DownloadActivityAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: context.state.status == "Paused" ? "pause.circle.fill" : "arrow.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.fileName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(context.state.status)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(context.state.progressPercentage)
                    .font(.headline.bold())
                    .foregroundColor(.blue)
            }
            
            // Linear Progress Bar
            ProgressView(value: context.state.progress)
                .progressViewStyle(.linear)
                .tint(.blue)
                .background(Color.white.opacity(0.1))
            
            HStack {
                Text("\(formattedSize(context.state.downloadedBytes)) of \(formattedSize(context.state.fileSize))")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if context.state.downloadSpeed > 0 {
                        Text(context.state.formattedSpeed)
                            .font(.caption2.bold())
                            .foregroundColor(.blue)
                    }
                    Text(context.state.formattedETA)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
    }
    
    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(0, bytes))
    }
}

extension DownloadActivityAttributes.ContentState {
    var progressPercentage: String {
        String(format: "%.0f%%", progress * 100)
    }
    
    var formattedSpeed: String {
        if downloadSpeed <= 0 { return "0 KB/s" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(downloadSpeed)))/s"
    }
    
    var formattedETA: String {
        if status == "Paused" { return "Paused" }
        if status == "Completed" { return "Finished" }
        if status == "Failed" { return "Failed" }
        return formattedTimeRemaining
    }
}

@main
struct DirXploreWidgetBundle: WidgetBundle {
    var body: some Widget {
        DirXploreWidgetLiveActivity()
    }
}
