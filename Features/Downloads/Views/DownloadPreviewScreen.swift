import SwiftUI

struct DownloadPreviewScreen: View {
    let folderUrl: String
    let folderName: String
    let baseSaveDir: String
    let initialItems: [DirectoryItem]

    @ObservedObject var viewModel: DownloadsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var items: [DirectoryItem] = []
    @State private var selectedIndices: Set<Int> = []
    @State private var filterQuery = ""
    @State private var useRegex = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        TextField(useRegex ? "Regex filter (e.g. .*720p.*)" : "Filter files...",
                                  text: $filterQuery)
                            .font(.caption)
                            .autocorrectionDisabled()
                        if !filterQuery.isEmpty {
                            Button { filterQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.5))
                    .cornerRadius(10)

                    Toggle("Regex", isOn: $useRegex)
                        .toggleStyle(.button)
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)

                // Quick filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        quickChip("All", "")
                        quickChip("Videos", "mp4|mkv|avi|webm")
                        quickChip("Archives", "zip|rar|7z")
                        quickChip("1080p", "1080p")
                        quickChip("720p", "720p")
                        quickChip("High Res", "bluray|bdrip|imax")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }

                // Item list
                List {
                    ForEach(filteredItems.indices, id: \.self) { idx in
                        let item = filteredItems[idx]
                        let originalIndex = items.firstIndex(where: { $0.url == item.url }) ?? idx
                        let isSelected = selectedIndices.contains(originalIndex)

                        HStack {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? .blue : .secondary)
                                .onTapGesture {
                                    toggleSelection(originalIndex)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(item.size ?? "Unknown size")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(item.typeTag)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.blue)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { toggleSelection(originalIndex) }
                    }
                }
                .listStyle(.plain)

                // Bottom bar
                HStack {
                    Text(filterQuery.isEmpty
                         ? "\(selectedIndices.count) files selected"
                         : "\(visibleSelectedCount) / \(filteredItems.count) filtered (\(selectedIndices.count) total)")
                        .font(.caption)

                    Spacer()

                    Button("SELECT \(filterQuery.isEmpty ? "ALL" : "FILTERED")") {
                        let filteredSet = Set(filteredItems.compactMap { item in
                            items.firstIndex(where: { $0.url == item.url })
                        })
                        if filteredSet.isSubset(of: selectedIndices) {
                            selectedIndices.subtract(filteredSet)
                        } else {
                            selectedIndices.formUnion(filteredSet)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.ultraThinMaterial)

                // Start button
                Button {
                    startDownloads()
                } label: {
                    Label("Add to Queue", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .font(.headline)
                .buttonStyle(.borderedProminent)
                .disabled(selectedIndices.isEmpty)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Preview: \(folderName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Deselect All") {
                        selectedIndices.removeAll()
                    }
                    .font(.caption)
                }
            }
            .onAppear {
                items = initialItems
                selectSmartDefaults()
            }
        }
    }

    // MARK: - Computed

    private var filteredItems: [DirectoryItem] {
        if filterQuery.isEmpty { return items }
        do {
            if useRegex {
                let regex = try Regex(filterQuery)
                return items.filter { $0.name.contains(regex) }
            } else {
                return items.filter { $0.name.localizedCaseInsensitiveContains(filterQuery) }
            }
        } catch {
            return items
        }
    }

    private var visibleSelectedCount: Int {
        let filteredSet = Set(filteredItems.compactMap { item in
            items.firstIndex(where: { $0.url == item.url })
        })
        return selectedIndices.intersection(filteredSet).count
    }

    // MARK: - Functions

    private func quickChip(_ label: String, _ query: String) -> some View {
        let isActive = filterQuery == query
        return Button {
            if isActive {
                filterQuery = ""
            } else {
                filterQuery = query
                useRegex = !query.isEmpty && (query.contains("|") || query == "1080p" || query == "720p")
            }
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? Color.blue : .quaternary.opacity(0.5))
                .foregroundStyle(isActive ? .white : .primary)
                .cornerRadius(8)
        }
    }

    private func toggleSelection(_ index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
    }

    private func selectSmartDefaults() {
        for (i, item) in items.enumerated() {
            let name = item.name.lowercased()
            if item.type == .video || item.type == .archive ||
                name.contains("1080p") || name.contains("720p") || name.contains("bluray") {
                selectedIndices.insert(i)
            }
        }
    }

    private func startDownloads() {
        let batchId = "\(Int64(Date().timeIntervalSince1970 * 1000))"
        for idx in selectedIndices {
            guard idx < items.count else { continue }
            let item = items[idx]
            viewModel.addDownload(
                url: item.url,
                fileName: item.name,
                saveDir: baseSaveDir,
                batchId: batchId,
                batchName: folderName
            )
        }
        dismiss()
    }
}

private extension String {
    func contains(_ regex: Regex<AnyRegexOutput>) -> Bool {
        (try? regex.firstMatch(in: self)) != nil
    }
}

private extension Regex where Output == AnyRegexOutput {
    init(_ pattern: String) throws {
        self = try Regex(pattern)
    }
}

private extension [DirectoryItem] {
    func indexOf(where predicate: (DirectoryItem) -> Bool) -> Int? {
        firstIndex(where: predicate)
    }
}