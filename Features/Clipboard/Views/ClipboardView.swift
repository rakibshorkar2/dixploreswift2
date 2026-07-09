import SwiftUI
import UIKit

struct ClipboardView: View {
    @StateObject private var viewModel = ClipboardViewModel.shared
    @State private var showDetail: ClipboardItem?
    @State private var showExportOptions = false
    @State private var showImportPicker = false
    @State private var showClearConfirmation = false
    @State private var showStatistics = false
    @State private var importText = ""

    var body: some View {
        ZStack {
            backgroundView

            if viewModel.filteredItems.isEmpty {
                emptyState
            } else {
                clipboardContent
            }

            if viewModel.showDetectionBanner, let item = viewModel.newlyDetectedItem {
                VStack {
                    detectionBanner(item: item)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .animation(.spring(), value: viewModel.showDetectionBanner)
            }
        }
        .navigationTitle("Clipboard")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if viewModel.isMultiSelectMode {
                    Button("Done") { viewModel.toggleMultiSelectMode() }
                } else {
                    Button { viewModel.setShowFavoritesOnly(!viewModel.showFavoritesOnly) } label: {
                        Image(systemName: viewModel.showFavoritesOnly ? "star.fill" : "star")
                    }
                    Button { showStatistics = true } label: {
                        Image(systemName: "chart.bar")
                    }
                    Menu {
                        Button { showExportOptions = true } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        Button { showImportPicker = true } label: {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }
                        Button(role: .destructive) { showClearConfirmation = true } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(item: $showDetail) { item in
            ClipboardDetailView(item: item)
        }
        .sheet(isPresented: $showExportOptions) {
            exportSheet
        }
        .sheet(isPresented: $showImportPicker) {
            importSheet
        }
        .sheet(isPresented: $showStatistics) {
            statisticsSheet
        }
        .alert("Clear All", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task { try? await viewModel.clearAll() }
            }
        } message: {
            Text("This will permanently delete all clipboard history items.")
        }
        .task { await viewModel.load() }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.8)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.showFavoritesOnly ? "star" : viewModel.searchQuery.isEmpty ? "doc.text" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(emptyMessage)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyMessage: String {
        if viewModel.showFavoritesOnly { return "No favorites yet" }
        if !viewModel.searchQuery.isEmpty { return "No results found" }
        return "Your clipboard history is empty"
    }

    private var clipboardContent: some View {
        VStack(spacing: 0) {
            searchAndFilterBar

            if viewModel.isMultiSelectMode {
                multiSelectBar
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredItems) { item in
                        ClipboardCard(item: item)
                            .onTapGesture {
                                if viewModel.isMultiSelectMode {
                                    viewModel.toggleSelection(item.id)
                                } else {
                                    showDetail = item
                                }
                            }
                            .onLongPressGesture {
                                if !viewModel.isMultiSelectMode {
                                    viewModel.toggleMultiSelectMode()
                                    viewModel.toggleSelection(item.id)
                                }
                            }
                            .contextMenu {
                                Button { Task { try? await viewModel.toggleFavorite(item.id) } } label: {
                                    Label(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: item.isFavorite ? "star.fill" : "star")
                                }
                                Button { Task { try? await viewModel.togglePin(item.id) } } label: {
                                    Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.fill" : "pin")
                                }
                                Button { UIPasteboard.general.string = item.content } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                Button(role: .destructive) { Task { try? await viewModel.deleteItem(item.id) } } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { Task { try? await viewModel.toggleFavorite(item.id) } } label: {
                                    Label("Favorite", systemImage: "star")
                                }.tint(.yellow)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { Task { try? await viewModel.deleteItem(item.id) } } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onChange(of: viewModel.searchQuery) { _, new in
                        viewModel.setSearchQuery(new)
                    }
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.setSearchQuery("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "All", isSelected: viewModel.selectedFilter == nil) {
                        viewModel.setFilter(nil)
                    }
                    FilterChip(label: "Links", isSelected: viewModel.selectedFilter == .url) {
                        viewModel.setFilter(.url)
                    }
                    FilterChip(label: "Code", isSelected: viewModel.selectedFilter == .code) {
                        viewModel.setFilter(.code)
                    }
                    FilterChip(label: "JSON", isSelected: viewModel.selectedFilter == .json) {
                        viewModel.setFilter(.json)
                    }
                    FilterChip(label: "Colors", isSelected: viewModel.selectedFilter == .color) {
                        viewModel.setFilter(.color)
                    }
                    FilterChip(label: "Emails", isSelected: viewModel.selectedFilter == .email) {
                        viewModel.setFilter(.email)
                    }
                    FilterChip(label: "Phones", isSelected: viewModel.selectedFilter == .phone) {
                        viewModel.setFilter(.phone)
                    }
                    FilterChip(label: "Files", isSelected: viewModel.selectedFilter == .filePath) {
                        viewModel.setFilter(.filePath)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Material.ultraThin)
    }

    private var multiSelectBar: some View {
        HStack {
            Text("\(viewModel.selectedIds.count) selected")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button { viewModel.selectAll() } label: {
                Image(systemName: "checkmark.square")
            }
            Button { Task { try? await viewModel.toggleFavoriteSelected() } } label: {
                Image(systemName: "star")
            }
            Button { Task { try? await viewModel.deleteSelected() } } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .disabled(viewModel.selectedIds.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
    }

    private func detectionBanner(item: ClipboardItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "radar")
                .foregroundStyle(.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("New clipboard detected")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.accent)
                Text(item.preview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button { viewModel.dismissNewlyDetected() } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.3)))
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private var exportSheet: some View {
        NavigationStack {
            List {
                Button("Export as JSON") { share(viewModel.exportAsJson) }
                Button("Export as Text") { share(viewModel.exportAsText) }
                Button("Export as CSV") { share(viewModel.exportAsCsv) }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var importSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $importText)
                    .font(.body.monospaced())
                    .frame(minHeight: 200)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.separator.opacity(0.3)))
                    .padding(.horizontal)

                Button("Import JSON") {
                    Task {
                        let count = await viewModel.importFromJson(importText)
                        importText = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(importText.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Import Text") {
                    Task {
                        let count = await viewModel.importFromText(importText)
                        importText = ""
                    }
                }
                .buttonStyle(.bordered)
                .disabled(importText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var statisticsSheet: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    StatRow("Total Items", value: "\(viewModel.totalItems)")
                    StatRow("Favorites", value: "\(viewModel.favoriteCount)")
                    StatRow("Storage Used", value: viewModel.storageFormatted)
                }
                Section("By Type") {
                    ForEach(ClipboardContentType.allCases, id: \.self) { type in
                        let count = viewModel.typeDistribution[type] ?? 0
                        if count > 0 {
                            StatRow(typeLabel(type), value: "\(count)")
                        }
                    }
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func share(_ text: String) {
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func typeLabel(_ type: ClipboardContentType) -> String {
        switch type {
        case .text: return "Text"
        case .url: return "URL"
        case .image: return "Image"
        case .richText: return "Rich Text"
        case .phone: return "Phone"
        case .email: return "Email"
        case .json: return "JSON"
        case .code: return "Code"
        case .color: return "Color"
        case .filePath: return "File Path"
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                        .overlay(Capsule().stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.separator.opacity(0.3), lineWidth: 1))
                )
        }
    }
}

struct ClipboardCard: View {
    let item: ClipboardItem
    @StateObject private var viewModel = ClipboardViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                typeIcon
                Text(typeLabel(item.type))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(typeColor(item.type).opacity(0.8))
                Spacer()
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow)
                }
                if viewModel.isMultiSelectMode {
                    Image(systemName: viewModel.selectedIds.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(viewModel.selectedIds.contains(item.id) ? .accent : .secondary)
                }
            }

            Text(item.preview)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(item.type == .url ? 2 : 3)

            HStack(spacing: 12) {
                Label(formatTimestamp(item.createdAt), systemImage: "clock")
                Label("\(item.characterCount) chars", systemImage: "textformat")
                if let domain = item.domain {
                    Label(domain, systemImage: "globe")
                        .lineLimit(1)
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(viewModel.selectedIds.contains(item.id) ? Color.accentColor.opacity(0.5) : Color.separator.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var typeIcon: some View {
        ZStack {
            Circle()
                .fill(typeColor(item.type).opacity(0.12))
                .frame(width: 28, height: 28)
            Image(systemName: typeIconName(item.type))
                .font(.system(size: 12))
                .foregroundStyle(typeColor(item.type))
        }
    }

    private func typeIconName(_ type: ClipboardContentType) -> String {
        switch type {
        case .url: return "link"
        case .image: return "photo"
        case .email: return "envelope"
        case .phone: return "phone"
        case .json: return "curlybraces"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette"
        case .filePath: return "folder"
        case .richText: return "textformat"
        case .text: return "text.alignleft"
        }
    }

    private func typeColor(_ type: ClipboardContentType) -> Color {
        switch type {
        case .url: return .blue
        case .image: return .purple
        case .email: return .teal
        case .phone: return .green
        case .json: return .orange
        case .code: return .green
        case .color: return .pink
        case .filePath: return .yellow
        case .richText: return .indigo
        case .text: return .accentColor
        }
    }

    private func typeLabel(_ type: ClipboardContentType) -> String {
        switch type {
        case .text: return "TEXT"
        case .url: return "URL"
        case .image: return "IMAGE"
        case .richText: return "RICH TEXT"
        case .phone: return "PHONE"
        case .email: return "EMAIL"
        case .json: return "JSON"
        case .code: return "CODE"
        case .color: return "COLOR"
        case .filePath: return "FILE PATH"
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        if diff < 604800 { return "\(Int(diff / 86400))d ago" }
        return date.formatted(date: .numeric, time: .omitted)
    }
}

struct StatRow: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}

struct ClipboardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ClipboardViewModel.shared
    let item: ClipboardItem
    @State private var showEdit = false
    @State private var showTagInput = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection

                    if item.type == .url {
                        urlPreview
                    }
                    if item.type == .code || item.type == .json {
                        codePreview
                    }
                    if item.type == .color {
                        colorPreview
                    }

                    contentSection
                    metadataSection

                    if !item.tags.isEmpty {
                        tagsSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showEdit) {
                editSheet
            }
            .sheet(isPresented: $showTagInput) {
                tagInputSheet
            }
            .safeAreaInset(edge: .bottom) {
                detailActions
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(typeColor.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: typeIconName).font(.title3).foregroundStyle(typeColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(typeLabel).font(.headline.weight(.bold)).foregroundStyle(typeColor)
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { try? await viewModel.toggleFavorite(item.id) } } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(item.isFavorite ? .yellow : .secondary)
            }
            Button { Task { try? await viewModel.togglePin(item.id) } } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(item.isPinned ? .orange : .secondary)
            }
        }
        .padding(16)
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var urlPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let domain = item.domain {
                Label(domain, systemImage: "globe").font(.title3.weight(.bold)).foregroundStyle(.accent)
            }
            HStack(spacing: 8) {
                miniActionButton("Open", icon: "arrow.up.forward.app") {
                    if let url = URL(string: item.content) {
                        UIApplication.shared.open(url)
                        dismiss()
                    }
                }
                miniActionButton("Copy", icon: "doc.on.doc") {
                    UIPasteboard.general.string = item.content
                }
                if item.content.hasPrefix("http") {
                    miniActionButton("Download", icon: "arrow.down.to.line") {
                        dismiss()
                    }
                }
            }
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor.opacity(0.2)))
    }

    private var codePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chevron.left.forwardslash.chevron.right").foregroundStyle(.green)
                Text((item.language ?? "code").uppercased()).font(.caption.weight(.bold)).foregroundStyle(.green)
                Spacer()
                Button { UIPasteboard.general.string = item.content } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
            }
            Text(item.content)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color(white: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var colorPreview: some View {
        let parsedColor = parseColor(item.content)
        return HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(parsedColor ?? .gray)
                .frame(width: 60, height: 60)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.separator.opacity(0.3)))
            VStack(alignment: .leading) {
                Text(item.content).font(.body.monospaced().weight(.bold))
                if let c = parsedColor {
                    let r = Int(c.cgColor.components?[0].rounded() * 255)
                    let g = Int(c.cgColor.components?[1].rounded() * 255)
                    let b = Int(c.cgColor.components?[2].rounded() * 255)
                    Text("R: \(r)  G: \(g)  B: \(b)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var contentSection: some View {
        Text(item.content)
            .font(item.type == .code || item.type == .json ? .system(.subheadline, design: .monospaced) : .subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Material.ultraThin)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .textSelection(.enabled)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details").font(.headline)
            Group {
                metaRow("Type", value: typeLabel)
                metaRow("Created", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                metaRow("Characters", value: "\(item.characterCount)")
                metaRow("Words", value: "\(item.wordCount)")
                metaRow("Lines", value: "\(item.lineCount)")
                if let domain = item.domain { metaRow("Domain", value: domain) }
                if let lang = item.language { metaRow("Language", value: lang.uppercased()) }
            }
        }
        .padding(16)
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func metaRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).font(.caption)
            Spacer()
            Text(value).font(.caption.weight(.medium))
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag").font(.caption).foregroundStyle(.secondary)
                Text("Tags").font(.headline)
            }
            FlowLayout(spacing: 6) {
                ForEach(item.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag).font(.caption)
                        Button { Task { try? await viewModel.removeTag(item.id, tag: tag) } } label: {
                            Image(systemName: "xmark").font(.system(size: 8))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var detailActions: some View {
        HStack(spacing: 0) {
            detailAction("Copy", icon: "doc.on.doc") { UIPasteboard.general.string = item.content; dismiss() }
            detailAction("Edit", icon: "pencil") { showEdit = true }
            detailAction("Tag", icon: "tag") { showTagInput = true }
            detailAction(item.isFavorite ? "Unfavorite" : "Favorite", icon: item.isFavorite ? "star.fill" : "star") {
                Task { try? await viewModel.toggleFavorite(item.id) }
            }
            detailAction("Delete", icon: "trash", color: .red) {
                Task { try? await viewModel.deleteItem(item.id); dismiss() }
            }
        }
        .padding(.vertical, 8)
        .background(Material.ultraThin)
    }

    private func detailAction(_ label: String, icon: String, color: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.body)
                Text(label).font(.system(size: 9))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
        }
    }

    private func miniActionButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.2)))
        }
    }

    private var editSheet: some View {
        NavigationStack {
            TextEditor(text: .constant(item.content))
                .padding()
                .navigationTitle("Edit Content")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { showEdit = false }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showEdit = false }
                    }
                }
        }
    }

    private var tagInputSheet: some View {
        NavigationStack {
            TextField("Enter tag...", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .padding()
                .navigationTitle("Add Tag")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { showTagInput = false }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showTagInput = false }
                    }
                }
        }
    }

    private var typeLabel: String {
        switch item.type {
        case .text: return "Text"
        case .url: return "URL"
        case .image: return "Image"
        case .richText: return "Rich Text"
        case .phone: return "Phone"
        case .email: return "Email"
        case .json: return "JSON"
        case .code: return "Code"
        case .color: return "Color"
        case .filePath: return "File Path"
        }
    }

    private var typeIconName: String {
        switch item.type {
        case .url: return "link"
        case .image: return "photo"
        case .email: return "envelope"
        case .phone: return "phone"
        case .json: return "curlybraces"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette"
        case .filePath: return "folder"
        case .richText: return "textformat"
        case .text: return "text.alignleft"
        }
    }

    private var typeColor: Color {
        switch item.type {
        case .url: return .blue
        case .image: return .purple
        case .email: return .teal
        case .phone: return .green
        case .json: return .orange
        case .code: return .green
        case .color: return .pink
        case .filePath: return .yellow
        case .richText: return .indigo
        case .text: return .accentColor
        }
    }

    private func parseColor(_ hex: String) -> Color? {
        var str = hex.trimmingCharacters(in: .whitespaces)
        if str.hasPrefix("#") { str = String(str.dropFirst()) }
        guard str.count == 6, let value = UInt64(str, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += size.height + spacing
            }
            x += size.width + spacing
            height = y + size.height
        }
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = bounds.minX
                y += size.height + spacing
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
        }
    }
}

extension ClipboardContentType: CaseIterable {}
