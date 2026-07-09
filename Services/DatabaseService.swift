import Foundation
import SQLite3

final class DatabaseService {
    static let shared = DatabaseService()

    private var db: OpaquePointer?
    private let queue: DispatchQueue

    private init() {
        queue = DispatchQueue(label: "com.dirxplore.database", qos: .background)
    }

    func open() async throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = docs.appendingPathComponent("dirxplore_downloads.db").path

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                if sqlite3_open(dbPath, &self.db) != SQLITE_OK {
                    let err = String(cString: sqlite3_errmsg(self.db))
                    continuation.resume(throwing: DatabaseError.openFailed(err))
                    return
                }
                do {
                    try self.migrate()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func migrate() throws {
        let version = userVersion
        if version < 1 {
            try execute("""
                CREATE TABLE downloads(
                    id TEXT PRIMARY KEY,
                    url TEXT,
                    fileName TEXT,
                    savePath TEXT,
                    batchId TEXT,
                    batchName TEXT,
                    status INTEGER,
                    totalBytes INTEGER,
                    downloadedBytes INTEGER,
                    retryCount INTEGER,
                    maxRetries INTEGER DEFAULT 3,
                    errorMessage TEXT,
                    addedAt TEXT,
                    originalUrl TEXT,
                    customHeadersJson TEXT,
                    mirrorUrlsJson TEXT,
                    category INTEGER DEFAULT 7,
                    scheduleType INTEGER DEFAULT 0,
                    scheduledAt TEXT,
                    expectedMd5 TEXT,
                    expectedSha1 TEXT,
                    expectedSha256 TEXT,
                    calculatedMd5 TEXT,
                    calculatedSha1 TEXT,
                    calculatedSha256 TEXT,
                    redirectCount INTEGER DEFAULT 0,
                    resolvedUrl TEXT
                )
            """)
            try createClipboardTable()
            userVersion = 1
        }
        if version < 2 {
            try createClipboardTable()
            userVersion = 2
        }
        if version < 3 {
            try execute("ALTER TABLE downloads ADD COLUMN originalUrl TEXT")
            userVersion = 3
        }
        if version < 4 {
            try execute("ALTER TABLE downloads ADD COLUMN maxRetries INTEGER DEFAULT 3")
            try execute("ALTER TABLE downloads ADD COLUMN customHeadersJson TEXT")
            try execute("ALTER TABLE downloads ADD COLUMN mirrorUrlsJson TEXT")
            try execute("ALTER TABLE downloads ADD COLUMN category INTEGER DEFAULT 7")
            try execute("ALTER TABLE downloads ADD COLUMN scheduleType INTEGER DEFAULT 0")
            try execute("ALTER TABLE downloads ADD COLUMN scheduledAt TEXT")
            try execute("ALTER TABLE downloads ADD COLUMN expectedMd5 TEXT")
            try execute("ALTER TABLE downloads ADD COLUMN expectedSha1 TEXT")
            try execute("ALTER TABLE downloads ADD COLUMN expectedSha256 TEXT")
            try execute("ALTER TABLE downloads ADD COLUMN calculatedMd5 TEXT")
            try execute("ALTER TABLE downloads ADD COLUMN calculatedSha1 TEXT")
            try execute("ALTER TABLE downloads ADD COLUMN calculatedSha256 TEXT")
            try execute("ALTER TABLE downloads ADD COLUMN redirectCount INTEGER DEFAULT 0")
            try execute("ALTER TABLE downloads ADD COLUMN resolvedUrl TEXT")
            userVersion = 4
        }
        if version < 5 {
            try createClipboardTable()
            userVersion = 5
        }
    }

    private func createClipboardTable() throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS clipboard_items(
                id TEXT PRIMARY KEY,
                type INTEGER,
                preview TEXT,
                content TEXT,
                createdAt TEXT,
                isFavorite INTEGER DEFAULT 0,
                isPinned INTEGER DEFAULT 0,
                tags TEXT,
                characterCount INTEGER,
                wordCount INTEGER,
                domain TEXT,
                fileExtension TEXT,
                language TEXT,
                imagePath TEXT
            )
        """)
    }

    // MARK: - Downloads CRUD

    func insertDownload(_ item: DownloadItem) async throws {
        try await write { db in
            try self.execute("""
                INSERT OR REPLACE INTO downloads(
                    id, url, fileName, savePath, batchId, batchName, status, totalBytes,
                    downloadedBytes, retryCount, maxRetries, errorMessage, addedAt, originalUrl,
                    customHeadersJson, mirrorUrlsJson, category, scheduleType, scheduledAt,
                    expectedMd5, expectedSha1, expectedSha256, calculatedMd5, calculatedSha1,
                    calculatedSha256, redirectCount, resolvedUrl
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, params: item.toBindings())
        }
    }

    func getDownloads() async throws -> [DownloadItem] {
        try await read { db in
            try self.queryDownloads("SELECT * FROM downloads ORDER BY addedAt DESC")
        }
    }

    func updateDownload(_ item: DownloadItem) async throws {
        try await insertDownload(item)
    }

    func deleteDownload(_ id: String) async throws {
        try await write { db in
            try self.execute("DELETE FROM downloads WHERE id = ?", params: [id])
        }
    }

    func deleteAllDownloads() async throws {
        try await write { db in
            try self.execute("DELETE FROM downloads")
        }
    }

    // MARK: - Clipboard CRUD

    func insertClipboardItem(_ item: ClipboardItem) async throws {
        try await write { db in
            let tagsJson = item.tags.isEmpty ? nil : (try? JSONEncoder().encode(item.tags)).flatMap { String(data: $0, encoding: .utf8) }
            try self.execute("""
                INSERT OR REPLACE INTO clipboard_items(
                    id, type, preview, content, createdAt, isFavorite, isPinned, tags,
                    characterCount, wordCount, domain, fileExtension, language, imagePath
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, params: [
                item.id, item.type.rawValue, item.preview, item.content,
                ISO8601DateFormatter().string(from: item.createdAt),
                item.isFavorite ? 1 : 0, item.isPinned ? 1 : 0,
                tagsJson, item.characterCount, item.wordCount,
                item.domain, item.fileExtension, item.language, item.imagePath
            ] as [Any])
        }
    }

    func getClipboardItems() async throws -> [ClipboardItem] {
        try await read { db in
            try self.queryClipboard("SELECT * FROM clipboard_items ORDER BY createdAt DESC")
        }
    }

    func updateClipboardItem(_ item: ClipboardItem) async throws {
        try await insertClipboardItem(item)
    }

    func deleteClipboardItem(_ id: String) async throws {
        try await write { db in
            try self.execute("DELETE FROM clipboard_items WHERE id = ?", params: [id])
        }
    }

    func clearClipboardItems() async throws {
        try await write { db in
            try self.execute("DELETE FROM clipboard_items")
        }
    }

    func deleteAll() async throws {
        try await write { db in
            try self.execute("DELETE FROM downloads")
            try self.execute("DELETE FROM clipboard_items")
        }
    }

    // MARK: - Proxy CRUD

    func insertProxy(_ proxy: ProxyModel) async throws {
        try await write { db in
            try self.execute("""
                INSERT OR REPLACE INTO proxies(id, protocol, host, port, username, password, isActive)
                VALUES (?,?,?,?,?,?,?)
            """, params: [proxy.id, proxy.protocol.rawValue, proxy.host, proxy.port,
                         proxy.username as Any, proxy.password as Any, proxy.isActive ? 1 : 0])
        }
    }

    func getProxies() async throws -> [ProxyModel] {
        try await read { db in
            try self.queryProxies("SELECT * FROM proxies")
        }
    }

    func updateProxy(_ proxy: ProxyModel) async throws {
        try await insertProxy(proxy)
    }

    func deleteProxy(_ id: String) async throws {
        try await write { db in
            try self.execute("DELETE FROM proxies WHERE id = ?", params: [id])
        }
    }

    func deactivateAllProxies() async throws {
        try await write { db in
            try self.execute("UPDATE proxies SET isActive = 0")
        }
    }

    func createProxiesTable() throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS proxies(
                id TEXT PRIMARY KEY,
                protocol INTEGER,
                host TEXT,
                port INTEGER,
                username TEXT,
                password TEXT,
                isActive INTEGER DEFAULT 0
            )
        """)
    }

    // MARK: - Internal

    private var userVersion: Int32 {
        get {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            var version: Int32 = 0
            if sqlite3_step(stmt) == SQLITE_ROW {
                version = sqlite3_column_int(stmt, 0)
            }
            return version
        }
        set {
            var stmt: OpaquePointer?
            let pragma = "PRAGMA user_version = \(newValue)"
            if sqlite3_prepare_v2(db, pragma, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    private func execute(_ sql: String, params: [Any] = []) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(stmt)
            throw DatabaseError.execFailed(err)
        }
        defer { sqlite3_finalize(stmt) }

        for (i, param) in params.enumerated() {
            let idx = Int32(i + 1)
            if param is NSNull || param is Void? {
                sqlite3_bind_null(stmt, idx)
            } else if let v = param as? Int {
                sqlite3_bind_int64(stmt, idx, Int64(v))
            } else if let v = param as? Int64 {
                sqlite3_bind_int64(stmt, idx, v)
            } else if let v = param as? Double {
                sqlite3_bind_double(stmt, idx, v)
            } else if let v = param as? String {
                sqlite3_bind_text(stmt, idx, (v as NSString).utf8String, -1, nil)
            } else if let v = param as? Bool {
                sqlite3_bind_int(stmt, idx, v ? 1 : 0)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
        }

        if sqlite3_step(stmt) != SQLITE_DONE {
            let err = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.execFailed(err)
        }
    }

    private func queryDownloads(_ sql: String) throws -> [DownloadItem] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(stmt)
            throw DatabaseError.execFailed(err)
        }
        defer { sqlite3_finalize(stmt) }

        var results: [DownloadItem] = []
        let columnCount = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var dict: [String: Any] = [:]
            for i in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_NULL: break
                case SQLITE_INTEGER: dict[name] = sqlite3_column_int64(stmt, i)
                case SQLITE_FLOAT: dict[name] = sqlite3_column_double(stmt, i)
                case SQLITE_TEXT: dict[name] = String(cString: sqlite3_column_text(stmt, i))
                default: break
                }
            }
            results.append(DownloadItem(from: dict))
        }
        return results
    }

    private func queryProxies(_ sql: String) throws -> [ProxyModel] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(stmt)
            throw DatabaseError.execFailed(err)
        }
        defer { sqlite3_finalize(stmt) }

        var results: [ProxyModel] = []
        let columnCount = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var dict: [String: Any] = [:]
            for i in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_NULL: break
                case SQLITE_INTEGER: dict[name] = sqlite3_column_int64(stmt, i)
                case SQLITE_FLOAT: dict[name] = sqlite3_column_double(stmt, i)
                case SQLITE_TEXT: dict[name] = String(cString: sqlite3_column_text(stmt, i))
                default: break
                }
            }
            results.append(ProxyModel(from: dict))
        }
        return results
    }

    private func queryClipboard(_ sql: String) throws -> [ClipboardItem] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(stmt)
            throw DatabaseError.execFailed(err)
        }
        defer { sqlite3_finalize(stmt) }

        var results: [ClipboardItem] = []
        let columnCount = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var dict: [String: Any] = [:]
            for i in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_NULL: break
                case SQLITE_INTEGER: dict[name] = sqlite3_column_int64(stmt, i)
                case SQLITE_FLOAT: dict[name] = sqlite3_column_double(stmt, i)
                case SQLITE_TEXT: dict[name] = String(cString: sqlite3_column_text(stmt, i))
                default: break
                }
            }
            results.append(ClipboardItem(from: dict))
        }
        return results
    }

    private func write(_ block: @escaping (OpaquePointer?) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try block(self.db)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func read<T>(_ block: @escaping (OpaquePointer?) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try block(self.db)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum DatabaseError: Error, LocalizedError {
    case openFailed(String)
    case execFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "Database open failed: \(msg)"
        case .execFailed(let msg): return "Database exec failed: \(msg)"
        }
    }
}

extension DownloadItem {
    func toBindings() -> [Any] {
        let formatter = ISO8601DateFormatter()
        var headersJson: String?
        if !customHeaders.isEmpty {
            headersJson = (try? JSONSerialization.data(withJSONObject: customHeaders)).flatMap { String(data: $0, encoding: .utf8) }
        }
        var mirrorsJson: String?
        if !mirrorUrls.isEmpty {
            mirrorsJson = (try? JSONSerialization.data(withJSONObject: mirrorUrls)).flatMap { String(data: $0, encoding: .utf8) }
        }
        return [
            id, url, fileName, savePath, batchId as Any, batchName as Any,
            status.rawValue, totalBytes, downloadedBytes, retryCount, maxRetries,
            errorMessage as Any, formatter.string(from: addedAt), originalUrl as Any,
            headersJson as Any, mirrorsJson as Any,
            category.rawValue, scheduleType.rawValue, scheduledAt.map { formatter.string(from: $0) } as Any,
            expectedMd5 as Any, expectedSha1 as Any, expectedSha256 as Any,
            calculatedMd5 as Any, calculatedSha1 as Any, calculatedSha256 as Any,
            redirectCount, resolvedUrl as Any
        ]
    }
}
