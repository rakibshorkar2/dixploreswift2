import Foundation
import UIKit

@MainActor
final class ClipboardService: ObservableObject {
    static let shared = ClipboardService()

    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var monitoring: Bool = false
    @Published private(set) var popupEnabled: Bool = true
    @Published private(set) var autoSave: Bool = false
    @Published private(set) var maxHistorySize: Int = 5000
    @Published var showPopup: Bool = false
    @Published var pendingPopupItem: ClipboardItem?

    private var monitorTimer: Timer?
    private var lastClipboardContent: String = ""
    private var lastClipboardImage: UIImage?
    private var dismissedItems: Set<String> = []
    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults.standard
    }

    func load() async {
        monitoring = defaults.bool(forKey: "clipboardMonitoring")
        popupEnabled = defaults.bool(forKey: "clipboardPopupEnabled")
        autoSave = defaults.bool(forKey: "clipboardAutoSave")
        maxHistorySize = defaults.integer(forKey: "clipboardMaxHistory")
        if maxHistorySize == 0 { maxHistorySize = 5000 }

        let dismissed = defaults.stringArray(forKey: "clipboardDismissed") ?? []
        dismissedItems = Set(dismissed)

        if let saved = try? await DatabaseService.shared.getClipboardItems() {
            items = saved
        }

        if monitoring { startMonitoring() }
    }

    func setMonitoring(_ val: Bool) {
        monitoring = val
        defaults.set(val, forKey: "clipboardMonitoring")
        if val { startMonitoring() } else { stopMonitoring() }
    }

    func setPopupEnabled(_ val: Bool) {
        popupEnabled = val
        defaults.set(val, forKey: "clipboardPopupEnabled")
    }

    func setAutoSave(_ val: Bool) {
        autoSave = val
        defaults.set(val, forKey: "clipboardAutoSave")
    }

    func setMaxHistorySize(_ val: Int) {
        maxHistorySize = val
        defaults.set(val, forKey: "clipboardMaxHistory")
        trimHistory()
    }

    func startMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                _ = await self?.checkClipboard()
            }
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    func checkClipboard() async -> ClipboardItem? {
        let pasteboard = UIPasteboard.general

        if let image = pasteboard.image {
            if image != lastClipboardImage {
                lastClipboardImage = image
                if let item = createImageItem(image) {
                    if items.contains(where: { $0.content == item.content }) { return nil }
                    if dismissedItems.contains(item.content) { return nil }
                    if autoSave {
                        try? await saveItem(item)
                        return nil
                    }
                    if popupEnabled {
                        pendingPopupItem = item
                        showPopup = true
                    }
                    return item
                }
            }
            return nil
        }

        guard let text = pasteboard.string, !text.isEmpty, text != lastClipboardContent else { return nil }
        lastClipboardContent = text

        if items.contains(where: { $0.content == text }) { return nil }
        if dismissedItems.contains(text) { return nil }

        let item = createItem(text)
        if autoSave {
            try? await saveItem(item)
            return nil
        }
        if popupEnabled {
            pendingPopupItem = item
            showPopup = true
        }
        return item
    }

    func detectNewClipboardItem() async -> ClipboardItem? {
        await checkClipboard()
    }

    func dismissPopup() {
        if let item = pendingPopupItem {
            dismissItem(item.content)
        }
        showPopup = false
        pendingPopupItem = nil
    }

    func acceptPopup() {
        if let item = pendingPopupItem {
            Task { try? await saveItem(item) }
        }
        showPopup = false
        pendingPopupItem = nil
    }

    private func createImageItem(_ image: UIImage) -> ClipboardItem? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) ?? image.pngData() else { return nil }
        let base64Content = imageData.base64EncodedString()
        let id = "\(Date().timeIntervalSince1970.milliseconds)\(Int.random(in: 0..<99999))"
        return ClipboardItem(
            id: id,
            type: .image,
            preview: "[Image]",
            content: base64Content,
            createdAt: Date(),
            characterCount: base64Content.count,
            wordCount: 0,
            lineCount: 0,
            imagePath: nil
        )
    }

    private func createItem(_ text: String) -> ClipboardItem {
        let type = ClipboardItem.detectType(text)
        let id = "\(Date().timeIntervalSince1970.milliseconds)\(Int.random(in: 0..<99999))"
        return ClipboardItem(
            id: id,
            type: type,
            preview: ClipboardItem.generatePreview(text),
            content: text,
            createdAt: Date(),
            domain: type == .url ? ClipboardItem.extractDomain(text) : nil,
            fileExtension: type == .filePath ? ClipboardItem.extractFileExtension(text) : nil,
            language: type == .code ? ClipboardItem.detectLanguage(text) : nil
        )
    }

    func saveItem(_ item: ClipboardItem) async throws {
        items.insert(item, at: 0)
        try await DatabaseService.shared.insertClipboardItem(item)
        trimHistory()
    }

    func dismissItem(_ content: String) {
        dismissedItems.insert(content)
        defaults.set(Array(dismissedItems), forKey: "clipboardDismissed")
    }

    func deleteItem(_ id: String) async throws {
        items.removeAll { $0.id == id }
        try await DatabaseService.shared.deleteClipboardItem(id)
    }

    func toggleFavorite(_ id: String) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isFavorite.toggle()
        try await DatabaseService.shared.updateClipboardItem(items[idx])
    }

    func togglePin(_ id: String) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isPinned.toggle()
        try await DatabaseService.shared.updateClipboardItem(items[idx])
    }

    func updateItem(_ item: ClipboardItem) async throws {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        }
        try await DatabaseService.shared.updateClipboardItem(item)
    }

    func updateItemContent(_ id: String, newContent: String) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let existing = items[idx]
        let updated = ClipboardItem(
            id: existing.id,
            type: ClipboardItem.detectType(newContent),
            preview: ClipboardItem.generatePreview(newContent),
            content: newContent,
            createdAt: existing.createdAt,
            isFavorite: existing.isFavorite,
            isPinned: existing.isPinned,
            tags: existing.tags,
            characterCount: newContent.count,
            wordCount: newContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count,
            domain: ClipboardItem.detectType(newContent) == .url ? ClipboardItem.extractDomain(newContent) : nil,
            language: ClipboardItem.detectType(newContent) == .code ? ClipboardItem.detectLanguage(newContent) : existing.language
        )
        items[idx] = updated
        try await DatabaseService.shared.updateClipboardItem(updated)
    }

    func addTags(_ id: String, newTags: [String]) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let existing = Set(items[idx].tags)
        let merged = existing.union(newTags.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        items[idx].tags = Array(merged)
        try await DatabaseService.shared.updateClipboardItem(items[idx])
    }

    func removeTag(_ id: String, tag: String) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].tags.removeAll { $0 == tag }
        try await DatabaseService.shared.updateClipboardItem(items[idx])
    }

    func getLatestClipboard() async -> ClipboardItem? {
        let pasteboard = UIPasteboard.general
        if let image = pasteboard.image, let item = createImageItem(image) {
            if items.contains(where: { $0.content == item.content }) { return nil }
            return item
        }
        guard let text = pasteboard.string, !text.isEmpty else { return nil }
        if items.contains(where: { $0.content == text }) { return nil }
        return createItem(text)
    }

    func search(_ query: String) -> [ClipboardItem] {
        guard !query.isEmpty else { return items }
        let lower = query.lowercased()
        return items.filter { item in
            item.content.lowercased().contains(lower) ||
            (item.domain?.lowercased().contains(lower) ?? false) ||
            item.type.rawValue.description.lowercased().contains(lower) ||
            item.tags.contains { $0.lowercased().contains(lower) }
        }
    }

    func filterByType(_ type: ClipboardContentType) -> [ClipboardItem] {
        items.filter { $0.type == type }
    }

    func getFavorites() -> [ClipboardItem] {
        items.filter { $0.isFavorite }
    }

    func getPinned() -> [ClipboardItem] {
        items.filter { $0.isPinned }
    }

    func deleteMultiple(_ ids: [String]) async throws {
        items.removeAll { ids.contains($0.id) }
        for id in ids {
            try await DatabaseService.shared.deleteClipboardItem(id)
        }
    }

    func clearAll() async throws {
        items.removeAll()
        try await DatabaseService.shared.clearClipboardItems()
    }

    func clearByType(_ type: ClipboardContentType) async throws {
        let ids = items.filter { $0.type == type }.map { $0.id }
        for id in ids {
            try await deleteItem(id)
        }
    }

    var exportAsText: String {
        items.map { item in
            "[\(item.type.rawValue)] \(ISO8601DateFormatter().string(from: item.createdAt))\n\(item.content)\n---"
        }.joined(separator: "\n")
    }

    var exportAsJson: String {
        let dicts = items.map { $0.toDictionary() }
        return (try? JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted, .sortedKeys]).flatMap { String(data: $0, encoding: .utf8) }) ?? "[]"
    }

    var exportAsCsv: String {
        var csv = "Type,Preview,Content,Created At,Favorite,Pinned\n"
        for item in items {
            let escapedContent = item.content.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedPreview = item.preview.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(item.type.rawValue),\"\(escapedPreview)\",\"\(escapedContent)\",\(ISO8601DateFormatter().string(from: item.createdAt)),\(item.isFavorite),\(item.isPinned)\n"
        }
        return csv
    }

    func importFromJson(_ json: String) async -> Int {
        guard let data = json.data(using: .utf8),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return 0 }
        var count = 0
        for dict in list {
            let item = ClipboardItem(from: dict)
            if !items.contains(where: { $0.content == item.content }) {
                try? await saveItem(item)
                count += 1
            }
        }
        return count
    }

    func importFromText(_ text: String) async -> Int {
        let lines = text.components(separatedBy: "\n")
        var count = 0
        var currentContent = ""
        for line in lines {
            if line == "---" {
                if !currentContent.isEmpty {
                    let item = createItem(currentContent.trimmingCharacters(in: .newlines))
                    if !items.contains(where: { $0.content == item.content }) {
                        try? await saveItem(item)
                        count += 1
                    }
                    currentContent = ""
                }
            } else if !line.hasPrefix("[") {
                currentContent += line + "\n"
            }
        }
        return count
    }

    var totalItems: Int { items.count }
    var imageCount: Int { items.filter { $0.type == .image }.count }
    var linkCount: Int { items.filter { $0.type == .url }.count }
    var textCount: Int { items.filter { $0.type == .text }.count }
    var favoriteCount: Int { items.filter { $0.isFavorite }.count }
    var storageBytes: Int { items.reduce(0) { $0 + $1.content.utf8.count } }
    var storageFormatted: String {
        let bytes = storageBytes
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
    }

    private func trimHistory() {
        guard items.count > maxHistorySize else { return }
        items.sort { $0.createdAt > $1.createdAt }
        while items.count > maxHistorySize {
            let removed = items.removeLast()
            Task { try? await DatabaseService.shared.deleteClipboardItem(removed.id) }
        }
    }

    deinit {
        monitorTimer?.invalidate()
    }
}

extension TimeInterval {
    var milliseconds: Int64 { Int64(self * 1000) }
}
