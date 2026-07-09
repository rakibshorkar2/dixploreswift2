import SwiftUI

struct ItemOptionsView: View {
    let item: DirectoryItem
    let onDismiss: () -> Void
    let onPlayInApp: () -> Void
    let onPlayWithVLC: () -> Void
    let onQueueInApp: () -> Void
    let onSaveToFiles: () -> Void
    let onCopyURL: () -> Void
    let onShare: () -> Void

    var isMedia: Bool {
        let ext = (item.name as NSString).pathExtension.lowercased()
        return ["mp4", "mkv", "avi", "mov", "webm"].contains(ext)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: iconName)
                                .foregroundColor(iconColor)
                                .font(.title3)
                            Text(item.name)
                                .font(.headline)
                                .lineLimit(2)
                        }
                        if let size = item.size, !size.isEmpty {
                            Text(size)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    if isMedia {
                        Button {
                            onPlayInApp()
                        } label: {
                            Label("Play in App", systemImage: "play.circle.fill")
                                .foregroundColor(.blue)
                        }

                        Button {
                            onPlayWithVLC()
                        } label: {
                            Label("Play with VLC", systemImage: "play.rectangle")
                                .foregroundColor(.orange)
                        }
                    }

                    Button {
                        onQueueInApp()
                    } label: {
                        Label("Queue in App", systemImage: "arrow.down.doc")
                            .foregroundColor(.green)
                    }

                    Button {
                        onSaveToFiles()
                    } label: {
                        Label("Save to Files", systemImage: "folder.badge.plus")
                            .foregroundColor(.blue)
                    }

                    Button {
                        onCopyURL()
                    } label: {
                        Label("Copy URL", systemImage: "doc.on.doc")
                            .foregroundColor(.secondary)
                    }

                    Button {
                        onShare()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choose Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }

    private var iconName: String {
        if item.isDirectory { return "folder.fill" }
        let ext = (item.name as NSString).pathExtension.lowercased()
        if ["mp4", "mkv", "avi", "mov", "webm", "wmv", "flv", "m4v"].contains(ext) { return "video.fill" }
        if ["mp3", "flac", "wav", "aac", "ogg", "wma", "m4a"].contains(ext) { return "music.note" }
        if ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic"].contains(ext) { return "photo.fill" }
        if ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso"].contains(ext) { return "doc.zipper" }
        if ["pdf", "doc", "docx", "xls", "xlsx", "txt", "rtf", "csv"].contains(ext) { return "doc.text.fill" }
        if ["apk", "ipa", "exe", "dmg"].contains(ext) { return "app.fill" }
        if ["srt", "vtt", "sub", "ass", "ssa", "nfo"].contains(ext) { return "text.bubble.fill" }
        return "doc.fill"
    }

    private var iconColor: Color {
        if item.isDirectory { return .yellow }
        let ext = (item.name as NSString).pathExtension.lowercased()
        if ["mp4", "mkv", "avi", "mov", "webm", "wmv", "flv", "m4v"].contains(ext) { return .purple }
        if ["mp3", "flac", "wav", "aac", "ogg", "wma", "m4a"].contains(ext) { return .orange }
        if ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic"].contains(ext) { return .green }
        if ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso"].contains(ext) { return .red }
        if ["pdf", "doc", "docx", "xls", "xlsx", "txt", "rtf", "csv"].contains(ext) { return .blue }
        if ["apk", "ipa"].contains(ext) { return Color.green }
        return .gray
    }
}

struct ItemOptionsModifier: ViewModifier {
    @Binding var isPresented: Bool
    let item: DirectoryItem
    let onPlayInApp: () -> Void
    let onPlayWithVLC: () -> Void
    let onQueueInApp: () -> Void
    let onSaveToFiles: () -> Void
    let onCopyURL: () -> Void
    let onShare: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ItemOptionsView(
                    item: item,
                    onDismiss: { isPresented = false },
                    onPlayInApp: {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onPlayInApp()
                        }
                    },
                    onPlayWithVLC: {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onPlayWithVLC()
                        }
                    },
                    onQueueInApp: {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onQueueInApp()
                        }
                    },
                    onSaveToFiles: {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSaveToFiles()
                        }
                    },
                    onCopyURL: {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onCopyURL()
                        }
                    },
                    onShare: {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onShare()
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
    }
}

extension View {
    func itemOptionsSheet(
        isPresented: Binding<Bool>,
        item: DirectoryItem,
        onPlayInApp: @escaping () -> Void,
        onPlayWithVLC: @escaping () -> Void,
        onQueueInApp: @escaping () -> Void,
        onSaveToFiles: @escaping () -> Void,
        onCopyURL: @escaping () -> Void,
        onShare: @escaping () -> Void
    ) -> some View {
        modifier(ItemOptionsModifier(
            isPresented: isPresented,
            item: item,
            onPlayInApp: onPlayInApp,
            onPlayWithVLC: onPlayWithVLC,
            onQueueInApp: onQueueInApp,
            onSaveToFiles: onSaveToFiles,
            onCopyURL: onCopyURL,
            onShare: onShare
        ))
    }
}