import Foundation
import UIKit

@MainActor
final class ClipboardViewModel: ObservableObject {
    static let shared = ClipboardViewModel()

    @Published private(set) var filteredItems: [ClipboardItem] = []
    @Published var selectedFilter: ClipboardContentType?
    @Published var searchQuery = ""
    @Published var showFavoritesOnly = false
    @Published var isMultiSelectMode = false
    @Published var selectedIds: Set<String> = []
    @Published var newlyDetectedItem: ClipboardItem?
    @Published var isLoading = false
    @Published var showDetectionBanner = false

    private let service = ClipboardService.shared
    private var timer: Timer?

    private init() {}

    var allItems: [ClipboardItem] { service.items }

    var totalItems: Int { service.totalItems }
    var favoriteCount: Int { service.favoriteCount }
    var storageFormatted: String { service.storageFormatted }

    var typeDistribution: [ClipboardContentType: Int] {
        Dictionary(grouping: service.items, by: { $0.type }).mapValues { $0.count }
    }

    func load() async {
        isLoading = true
        await service.load()
        applyFilters()
        startMonitoring()
        isLoading = false
    }

    private func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                _ = await self?.checkForNewClipboard()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func checkForNewClipboard() async -> ClipboardItem? {
        let item = await service.detectNewClipboardItem()
        if let item = item {
            newlyDetectedItem = item
            showDetectionBanner = true
            applyFilters()
        }
        return item
    }

    func captureCurrentClipboard() async {
        if let item = await service.getLatestClipboard() {
            try? await service.saveItem(item)
            newlyDetectedItem = nil
            showDetectionBanner = false
            applyFilters()
        }
    }

    func dismissNewlyDetected() {
        if let item = newlyDetectedItem {
            service.dismissItem(item.content)
            newlyDetectedItem = nil
            showDetectionBanner = false
        }
    }

    func saveNewlyDetected() async {
        if let item = newlyDetectedItem {
            try? await service.saveItem(item)
            newlyDetectedItem = nil
            showDetectionBanner = false
            applyFilters()
        }
    }

    func applyFilters() {
        var items = service.items

        if let filter = selectedFilter {
            items = items.filter { $0.type == filter }
        }

        if showFavoritesOnly {
            items = items.filter { $0.isFavorite }
        }

        if !searchQuery.isEmpty {
            let lower = searchQuery.lowercased()
            items = items.filter { item in
                item.content.lowercased().contains(lower) ||
                (item.domain?.lowercased().contains(lower) ?? false) ||
                item.tags.contains { $0.lowercased().contains(lower) }
            }
        }

        items.sort { a, b in
            if a.isPinned && !b.isPinned { return true }
            if !a.isPinned && b.isPinned { return false }
            return a.createdAt > b.createdAt
        }

        filteredItems = items
    }

    func setFilter(_ type: ClipboardContentType?) {
        selectedFilter = type
        showFavoritesOnly = false
        applyFilters()
    }

    func setSearchQuery(_ query: String) {
        searchQuery = query
        applyFilters()
    }

    func setShowFavoritesOnly(_ val: Bool) {
        showFavoritesOnly = val
        if val { selectedFilter = nil }
        applyFilters()
    }

    func saveItem(_ item: ClipboardItem) async throws {
        try await service.saveItem(item)
        applyFilters()
    }

    func deleteItem(_ id: String) async throws {
        try await service.deleteItem(id)
        selectedIds.remove(id)
        applyFilters()
    }

    func toggleFavorite(_ id: String) async throws {
        try await service.toggleFavorite(id)
        applyFilters()
    }

    func togglePin(_ id: String) async throws {
        try await service.togglePin(id)
        applyFilters()
    }

    func updateItem(_ item: ClipboardItem) async throws {
        try await service.updateItem(item)
        applyFilters()
    }

    func updateItemContent(_ id: String, newContent: String) async throws {
        try await service.updateItemContent(id, newContent: newContent)
        applyFilters()
    }

    func addTags(_ id: String, tags: [String]) async throws {
        try await service.addTags(id, newTags: tags)
        applyFilters()
    }

    func removeTag(_ id: String, tag: String) async throws {
        try await service.removeTag(id, tag: tag)
        applyFilters()
    }

    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode { selectedIds.removeAll() }
    }

    func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
            if selectedIds.isEmpty { isMultiSelectMode = false }
        } else {
            selectedIds.insert(id)
            isMultiSelectMode = true
        }
    }

    func selectAll() {
        selectedIds = Set(filteredItems.map { $0.id })
        isMultiSelectMode = true
    }

    func clearSelection() {
        selectedIds.removeAll()
        isMultiSelectMode = false
    }

    func deleteSelected() async throws {
        let ids = Array(selectedIds)
        try await service.deleteMultiple(ids)
        selectedIds.removeAll()
        isMultiSelectMode = false
        applyFilters()
    }

    func toggleFavoriteSelected() async throws {
        let ids = Array(selectedIds)
        for id in ids {
            try await service.toggleFavorite(id)
        }
        selectedIds.removeAll()
        isMultiSelectMode = false
        applyFilters()
    }

    func clearAll() async throws {
        try await service.clearAll()
        applyFilters()
    }

    func clearByType(_ type: ClipboardContentType) async throws {
        try await service.clearByType(type)
        applyFilters()
    }

    func getItemById(_ id: String) -> ClipboardItem? {
        service.items.first { $0.id == id }
    }

    var exportAsText: String { service.exportAsText }
    var exportAsJson: String { service.exportAsJson }
    var exportAsCsv: String { service.exportAsCsv }

    func importFromJson(_ json: String) async -> Int {
        let count = await service.importFromJson(json)
        applyFilters()
        return count
    }

    func importFromText(_ text: String) async -> Int {
        let count = await service.importFromText(text)
        applyFilters()
        return count
    }

    deinit {
        timer?.invalidate()
    }
}
