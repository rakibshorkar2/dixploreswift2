import SwiftUI
import UniformTypeIdentifiers

struct DownloadCardView: View {
    let item: DownloadItem
    let index: Int
    let isNested: Bool

    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onRefreshLink: (String) -> Void
    let onRetry: () -> Void
    let onReveal: () -> Void
    let onSaveToFiles: () -> Void
    let onShare: () -> Void
    let onVerifyHash: (String, String) -> Void

    @State private var showDeleteConfirm = false
    @State private var deleteFile = false
    @State private var showRefreshDialog = false
    @State private var refreshUrl: String = ""
    @State private var showVerifyDialog = false
    @State private var verifyAlgo: String = ""
    @State private var verifyHash: String = ""
    @State private var verifyResult: Bool?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(index). \(item.fileName)")
                        .font(isNested ? .caption.bold() : .subheadline.bold())
                        .lineLimit(1)

                    if item.category != .other {
                        Text(item.categoryLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                ProgressView(value: item.progress)
                    .tint(.blue)

                HStack(spacing: 4) {
                    Text(sizeText)
                        .font(.caption2.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(speedAndETAText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(item.statusLabel)
                        .font(.caption2.bold())
                        .foregroundStyle(statusColor)
                }

                if let error = item.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    actionButtons
                }
            }
        }
        .padding(isNested ? 8 : 12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator.opacity(0.3), lineWidth: 1)
        )
        .confirmationDialog("Delete Task?", isPresented: $showDeleteConfirm) {
            Toggle("Delete file from storage", isOn: $deleteFile)
            Button("Delete", role: .destructive) {
                if deleteFile {
                    try? FileManager.default.removeItem(atPath: item.savePath)
                }
                onStop()
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Refresh Download Link", isPresented: $showRefreshDialog) {
            TextField("New URL", text: $refreshUrl)
            Button("Cancel", role: .cancel) { }
            Button("Update & Resume") {
                onRefreshLink(refreshUrl)
            }
        } message: {
            Text("Enter a new URL for this download. Progress will be preserved if the server supports resume.")
        }
        .alert("Verify File Hash", isPresented: $showVerifyDialog) {
            TextField("Expected hash value", text: $verifyHash)
            Picker("Algorithm", selection: $verifyAlgo) {
                Text("MD5").tag("MD5")
                Text("SHA1").tag("SHA1")
                Text("SHA256").tag("SHA256")
            }
            Button("Cancel", role: .cancel) { }
            Button("Verify") {
                onVerifyHash(verifyAlgo, verifyHash)
            }
        }
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .overlay(
                Group {
                    if let thumb = getThumbnail() {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "doc")
                            .foregroundStyle(.blue.opacity(0.5))
                    }
                }
            )
            .clipped()
    }

    private func getThumbnail() -> UIImage? {
        let url = URL(fileURLWithPath: item.savePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(ext) {
            return UIImage(contentsOfFile: url.path)
        }
        if ["mp4", "mkv", "mov", "m4v"].contains(ext) {
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            if let cgImage = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }

    // MARK: - Text helpers

    private var sizeText: String {
        if item.status == .downloading {
            return "\(DownloadItem.formatCompactBytes(item.downloadedBytes))/\(DownloadItem.formatCompactBytes(item.totalBytes)) (\(Int(item.progress * 100))%)"
        }
        return "\(DownloadItem.formatBytes(item.downloadedBytes)) / \(DownloadItem.formatBytes(item.totalBytes))"
    }

    private var speedAndETAText: String {
        switch item.status {
        case .done: return "Completed"
        case .error: return "Failed"
        default:
            if item.speedBytesPerSec <= 0 { return "0 B/s" }
            let speed = DownloadItem.formatSpeed(item.speedBytesPerSec)
            let eta = DownloadItem.formatEta(item.etaSeconds)
            return "\(speed) \u{00B7} \(eta)"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .error: return .red
        case .done: return .green
        case .downloading: return .blue
        case .paused: return .orange
        case .queued: return .secondary
        }
    }

    // MARK: - Action buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch item.status {
        case .done:
            Button { onShare() } label: { Image(systemName: "square.and.arrow.up").font(.caption) }
            if #available(iOS 16.0, *) {
                Button { onReveal() } label: { Image(systemName: "folder").font(.caption) }
            }
            Button { onSaveToFiles() } label: { Image(systemName: "tray.and.arrow.down").font(.caption) }
            Button { showVerifyDialog = true } label: { Image(systemName: "checkmark.shield").font(.caption) }
        case .downloading, .queued:
            Button { onPause() } label: { Image(systemName: "pause.circle").font(.title3).foregroundStyle(.orange) }
        case .paused:
            Button { onResume() } label: { Image(systemName: "play.circle").font(.title3).foregroundStyle(.green) }
        case .error:
            Menu {
                Button { onRetry() } label: { Label("Retry", systemImage: "arrow.circlepath") }
                Button { showRefreshDialog = true } label: { Label("Refresh Link", systemImage: "link") }
            } label: {
                Image(systemName: "arrow.circlepath")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }
            Button { onResume() } label: { Image(systemName: "play.circle").font(.title3).foregroundStyle(.green) }
        }
        Button { showDeleteConfirm = true } label: {
            Image(systemName: "xmark.circle").font(.caption).foregroundStyle(.red)
        }
    }
}

private extension UIImage {
    convenience init?(from path: String) {
        self.init(contentsOfFile: path)
    }
}

import AVFoundation