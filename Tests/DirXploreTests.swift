import XCTest
@testable import DirXplore

final class DirXploreTests: XCTestCase {

    func testDownloadItemFormatBytes() {
        XCTAssertEqual(DownloadItem.formatBytes(0), "0 B")
        XCTAssertEqual(DownloadItem.formatBytes(1023), "1023 B")
        XCTAssertEqual(DownloadItem.formatBytes(1024), "1.0 KB")
        XCTAssertEqual(DownloadItem.formatBytes(1_048_576), "1.00 MB")
        XCTAssertEqual(DownloadItem.formatBytes(1_073_741_824), "1.00 GB")
    }

    func testDownloadItemFormatSpeed() {
        XCTAssertEqual(DownloadItem.formatSpeed(0), "0 B/s")
        XCTAssertEqual(DownloadItem.formatSpeed(500), "500 B/s")
        XCTAssertEqual(DownloadItem.formatSpeed(1500), "1.5 KB/s")
        XCTAssertEqual(DownloadItem.formatSpeed(2_000_000), "1.91 MB/s")
    }

    func testDownloadItemFormatEta() {
        XCTAssertEqual(DownloadItem.formatEta(0), "--")
        XCTAssertEqual(DownloadItem.formatEta(30), "0:30")
        XCTAssertEqual(DownloadItem.formatEta(90), "1:30")
        XCTAssertEqual(DownloadItem.formatEta(3661), "1:01:01")
    }

    func testDownloadCategoryFromFileName() {
        XCTAssertEqual(DownloadCategory.from(fileName: "movie.mp4"), .movies)
        XCTAssertEqual(DownloadCategory.from(fileName: "song.mp3"), .music)
        XCTAssertEqual(DownloadCategory.from(fileName: "photo.jpg"), .images)
        XCTAssertEqual(DownloadCategory.from(fileName: "doc.pdf"), .documents)
        XCTAssertEqual(DownloadCategory.from(fileName: "archive.zip"), .archives)
        XCTAssertEqual(DownloadCategory.from(fileName: "app.ipa"), .apps)
        XCTAssertEqual(DownloadCategory.from(fileName: "unknown.xyz"), .other)
    }

    func testDownloadCategoryFromMimeType() {
        XCTAssertEqual(DownloadCategory.from(mimeType: "video/mp4"), .movies)
        XCTAssertEqual(DownloadCategory.from(mimeType: "audio/mpeg"), .music)
        XCTAssertEqual(DownloadCategory.from(mimeType: "image/jpeg"), .images)
        XCTAssertEqual(DownloadCategory.from(mimeType: "text/plain"), .documents)
        XCTAssertEqual(DownloadCategory.from(mimeType: "application/zip"), .archives)
        XCTAssertEqual(DownloadCategory.from(mimeType: "application/octet-stream"), .other)
    }

    func testClipboardContentTypeDetection() {
        XCTAssertEqual(ClipboardItem.detectType("https://example.com"), .url)
        XCTAssertEqual(ClipboardItem.detectType("user@example.com"), .email)
        XCTAssertEqual(ClipboardItem.detectType("+1234567890"), .phone)
        XCTAssertEqual(ClipboardItem.detectType(#"{"key": "value"}"#), .json)
        XCTAssertEqual(ClipboardItem.detectType("#ff0000"), .color)
        XCTAssertEqual(ClipboardItem.detectType("/usr/local/bin"), .filePath)
        XCTAssertEqual(ClipboardItem.detectType("hello world"), .text)
    }

    func testProxyModelUri() {
        let proxy = ProxyModel(id: "1", protocolType: .http, host: "192.168.1.1", port: 8080,
                               username: "user", password: "pass")
        XCTAssertEqual(proxy.uri, "http://user:pass@192.168.1.1:8080")
        XCTAssertTrue(proxy.displayUri.contains("***"))
    }

    func testProxyModelFromUri() {
        let proxy = ProxyModel.fromUri("socks5://user:pass@192.168.1.1:1080")
        XCTAssertNotNil(proxy)
        XCTAssertEqual(proxy?.protocolType, .socsk5)
        XCTAssertEqual(proxy?.host, "192.168.1.1")
        XCTAssertEqual(proxy?.port, 1080)
        XCTAssertEqual(proxy?.username, "user")
    }

    func testDownloadItemCodable() {
        let item = DownloadItem(id: "test1", url: "https://example.com/file.zip",
                                fileName: "file.zip", savePath: "/tmp/file.zip")
        let dict = item.toDictionary()
        let restored = DownloadItem(from: dict)
        XCTAssertEqual(restored.id, item.id)
        XCTAssertEqual(restored.url, item.url)
        XCTAssertEqual(restored.fileName, item.fileName)
        XCTAssertEqual(restored.savePath, item.savePath)
    }

    func testClipboardItemCodable() {
        let item = ClipboardItem(id: "clip1", type: .url, preview: "test",
                                 content: "https://example.com", createdAt: Date())
        let dict = item.toDictionary()
        let restored = ClipboardItem(from: dict)
        XCTAssertEqual(restored.id, item.id)
        XCTAssertEqual(restored.type, item.type)
        XCTAssertEqual(restored.content, item.content)
    }

    func testFormattingHelpers() {
        XCTAssertEqual(FormattingHelpers.formatBytes(0), "0 B")
        XCTAssertEqual(FormattingHelpers.formatBytes(1024), "1.0 KB")
        XCTAssertEqual(FormattingHelpers.formatDuration(90), "1 m 30 s")
    }
}
