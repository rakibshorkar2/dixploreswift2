# DirXplore - Flutter to Native iOS (Swift) Migration Report

## 1. Complete Flutter Project Analysis

### Project Overview
- **App Name:** DirXplore
- **Version:** 2.0.0+11
- **Description:** HTTP/FTP Open Directory Browser & Download Manager
- **Architecture:** Provider-based state management (ChangeNotifier pattern)
- **Platforms:** Android + iOS (Flutter cross-platform)

### Screens (10 total)
| Screen | File | Description |
|--------|------|-------------|
| BrowserTab | `lib/screens/browser_tab.dart` | HTTP/FTP directory browser with grid/list view, WebView fallback, bookmarks, filtering |
| DownloadTab | `lib/screens/download_tab.dart` | Download queue with batch grouping, progress, ETA, storage analyzer |
| ClipboardTab | `lib/screens/clipboard_tab.dart` | Clipboard history manager with type detection, favorites, tags, search |
| ProxyTab | `lib/screens/proxy_tab.dart` | SOCKS4/5, HTTP/HTTPS proxy manager with YAML import |
| SettingsTab | `lib/screens/settings_tab.dart` | Full settings UI with 30+ configurable options |
| MediaPlayerScreen | `lib/screens/media_player_screen.dart` | Custom video player with gesture controls, AB repeat, playlist |
| DownloadPreviewScreen | `lib/screens/download_preview_screen.dart` | Folder crawl preview with regex filtering before queuing |
| NewDownloadSheet | `lib/screens/new_download_sheet.dart` | URL input with link analysis, batch import, custom headers |
| PinLockScreen | `lib/screens/pin_lock_screen.dart` | Custom PIN code entry with numpad |
| SecuritySetupScreen | `lib/screens/security_setup_screen.dart` | PIN setup with security question recovery |

### Services (9 total)
| Service | File | Description |
|---------|------|-------------|
| DioClient | `lib/services/dio_client.dart` | Singleton HTTP client with proxy support, SOCKS5 tunnel, redirect resolving |
| HtmlParser | `lib/services/html_parser.dart` | Apache/Nginx directory listing HTML parser (Isolate-based) |
| DatabaseHelper | `lib/services/database_helper.dart` | SQLite database for downloads and clipboard items |
| ClipboardService | `lib/services/clipboard_service.dart` | Clipboard monitoring, type detection, export/import |
| ProxyTunnel | `lib/services/proxy_tunnel.dart` | Local HTTP proxy tunnel for media streaming through SOCKS |
| HapticService | `lib/services/haptic_service.dart` | Haptic feedback wrapper |
| GithubUpdater | `lib/services/github_updater.dart` | Version check via GitHub releases API |
| NativeHashService | `lib/services/native_hash_service.dart` | FFI-based native hash computation (Android only) |
| ThumbnailService | `lib/services/thumbnail_service.dart` | Video thumbnail generation (placeholder) |

### Providers (5 total)
| Provider | File | Description |
|----------|------|-------------|
| AppState | `lib/providers/app_state.dart` | Global app settings (theme, downloads, security, clipboard, haptics, retry, scheduler) |
| BrowserProvider | `lib/providers/browser_provider.dart` | Directory browsing state, bookmarks, search, filtering, fallback mode |
| DownloadProvider | `lib/providers/download_provider.dart` | Download queue management, NSURLSession integration, Live Activities, checksums |
| AppProxyProvider | `lib/providers/proxy_provider.dart` | Proxy list management, YAML import, latency testing |
| ClipboardProvider | `lib/providers/clipboard_provider.dart` | Clipboard history state, filtering, multi-select |

### Models (4 total)
| Model | File | Description |
|-------|------|-------------|
| DirectoryItem | `lib/models/directory_item.dart` | Directory listing item with type detection by extension |
| DownloadItem | `lib/models/download_item.dart` | Download with status, progress, category, checksums, mirrors, scheduling |
| ClipboardItem | `lib/models/clipboard_item.dart` | Clipboard entry with type detection, tags, metadata |
| ProxyModel | `lib/models/proxy_model.dart` | Proxy configuration with protocol, auth, latency |

### Flutter Packages Used
| Package | Purpose | Native iOS Replacement |
|---------|---------|----------------------|
| dio | HTTP client | URLSession |
| html | HTML parsing | SwiftSoup / Fuzi |
| provider | State management | ObservableObject / @Published |
| shared_preferences | Key-value storage | UserDefaults |
| sqflite | SQLite database | CoreData / GRDB / SQLite.swift |
| path | Path utilities | Foundation NSString/URL |
| permission_handler | Permissions | Info.plist + CLLocationManager/PHPhotoLibrary |
| url_launcher | URL launching | UIApplication.shared.open |
| package_info_plus | App version | Bundle.main |
| path_provider | Directory paths | FileManager.default.urls |
| file_picker | File picking | UIDocumentPickerViewController |
| http | HTTP client | URLSession |
| socks5_proxy | SOCKS5 proxy | Network.framework / NEProxySettings |
| flutter_inappwebview | WebView fallback | WKWebView |
| flutter_displaymode | Display mode | Not needed (iOS native) |
| dynamic_color | Dynamic theming | UIColorWell / systemColors |
| wakelock_plus | Screen wake lock | UIApplication.shared.isIdleTimerDisabled |
| battery_plus | Battery monitoring | UIDevice.current.batteryLevel |
| connectivity_plus | Network connectivity | NWPathMonitor |
| screen_brightness | Screen brightness | UIScreen.brightness |
| flutter_local_notifications | Local notifications | UNUserNotificationCenter |
| flutter_background_service | Background service | BGTaskScheduler |
| flutter_slidable | Swipe actions | UICollectionViewCompositionalLayout / SwipeCellKit |
| crypto | Hashing (MD5/SHA) | CommonCrypto / CryptoKit |
| share_plus | Share sheet | UIActivityViewController |
| disk_space_2 | Disk space | UIDevice/FileAttributeKey.systemSize |
| yaml | YAML parsing | Yams |
| local_auth | Biometric auth | LocalAuthentication (LAContext) |
| media_kit / media_kit_video | Video player | AVPlayer / AVKit |
| ffi | Native FFI | Not needed (native Swift) |
| workmanager | Background tasks | BGTaskScheduler |
| intl | Date formatting | DateFormatter |

---

## 2. Native Replacements for Every Flutter Plugin

### Networking
| Flutter | Native iOS |
|---------|-----------|
| dio | `URLSession` with `URLSessionConfiguration.ephemeral` for proxy support |
| http | `URLSession.dataTask` |
| socks5_proxy | `NWConnection` with SOCKS5 `NWProtocolSOCKS.Options` via Network.framework |
| flutter_inappwebview | `WKWebView` with `WKNavigationDelegate` |

### Parsing & Data
| Flutter | Native iOS |
|---------|-----------|
| html | `SwiftSoup` (CocoaPod/SPM) for HTML parsing |
| sqflite | `GRDB.swift` (SPM) or `CoreData` with NSPersistentContainer |
| shared_preferences | `UserDefaults.standard` |
| path | `NSString.pathComponents`, `URL.lastPathComponent` |
| yaml | `Yams` (SPM) for YAML parsing |
| crypto | `CryptoKit` (built-in) for MD5, SHA1, SHA256 |
| intl | `DateFormatter`, `RelativeDateTimeFormatter` |

### Media
| Flutter | Native iOS |
|---------|-----------|
| media_kit | `AVPlayer` + `AVPlayerViewController` |
| media_kit_video | `AVPlayerLayer` with custom controls |
| screen_brightness | `UIScreen.main.brightness` |
| thumbnail_service | `AVAssetImageGenerator` for video thumbnails |

### Device & System
| Flutter | Native iOS |
|---------|-----------|
| path_provider | `FileManager.default.urls(for: .documentDirectory)` |
| permission_handler | `AVCaptureDevice`, `PHPhotoLibrary`, `CLLocationManager` |
| url_launcher | `UIApplication.shared.open(url:)` |
| package_info_plus | `Bundle.main.infoDictionary` keys |
| flutter_displaymode | Not needed |
| dynamic_color | `UIColor.tintColor`, `UITraitCollection.userInterfaceStyle` |
| wakelock_plus | `UIApplication.shared.isIdleTimerDisabled` |
| battery_plus | `UIDevice.current.isBatteryMonitoringEnabled` |
| connectivity_plus | `NWPathMonitor` |
| flutter_local_notifications | `UNUserNotificationCenter` |
| share_plus | `UIActivityViewController` |
| disk_space_2 | `URLResourceKey.volumeTotalCapacityKey` |
| local_auth | `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` |
| file_picker | `UIDocumentPickerViewController` |
| flutter_background_service | `BGTaskScheduler.register(forTaskWithIdentifier:)` |

### State Management
| Flutter | Native iOS |
|---------|-----------|
| provider | `ObservableObject` + `@Published` + `@StateObject` |

---

## 3. Architecture Design Proposal (MVVM+Coordinator)

```
┌─────────────────────────────────────────────────────────────────┐
│                         App Layer                               │
├─────────────────────────────────────────────────────────────────┤
│  App.swift (Entry Point)                                        │
│  DirXploreApp.swift (SwiftUI App)                               │
├─────────────────────────────────────────────────────────────────┤
│                     Coordinator Layer                           │
├─────────────────────────────────────────────────────────────────┤
│  AppCoordinator                                                 │
│  ├── BrowserCoordinator                                         │
│  ├── DownloadsCoordinator                                       │
│  ├── ClipboardCoordinator                                       │
│  ├── ProxyCoordinator                                           │
│  ├── SettingsCoordinator                                        │
│  └── MediaPlayerCoordinator                                     │
├─────────────────────────────────────────────────────────────────┤
│                      View Layer (SwiftUI)                       │
├─────────────────────────────────────────────────────────────────┤
│  Views:                                                        │
│  ├── BrowserView (Tab)                                          │
│  ├── DownloadsView (Tab)                                        │
│  ├── ClipboardView (Tab)                                        │
│  ├── ProxyView (Tab)                                            │
│  ├── SettingsView (Tab)                                         │
│  ├── MediaPlayerView                                            │
│  ├── DownloadPreviewView                                        │
│  ├── NewDownloadSheet                                           │
│  ├── PinLockView                                                │
│  └── SecuritySetupView                                          │
├─────────────────────────────────────────────────────────────────┤
│                     ViewModel Layer                             │
├─────────────────────────────────────────────────────────────────┤
│  ViewModels:                                                    │
│  ├── BrowserViewModel                                           │
│  ├── DownloadsViewModel                                         │
│  ├── ClipboardViewModel                                         │
│  ├── ProxyViewModel                                             │
│  ├── SettingsViewModel                                          │
│  ├── MediaPlayerViewModel                                       │
│  └── NewDownloadViewModel                                       │
├─────────────────────────────────────────────────────────────────┤
│                      Service Layer                              │
├─────────────────────────────────────────────────────────────────┤
│  Services:                                                      │
│  ├── NetworkService (URLSession + NWConnection)                 │
│  ├── HTMLParserService (SwiftSoup)                              │
│  ├── DatabaseService (GRDB / CoreData)                          │
│  ├── ClipboardService                                            │
│  ├── ProxyTunnelService                                          │
│  ├── HapticService                                               │
│  ├── ThumbnailService                                            │
│  ├── GitHubUpdateService                                         │
│  └── LiveActivityService                                         │
├─────────────────────────────────────────────────────────────────┤
│                      Manager Layer                              │
├─────────────────────────────────────────────────────────────────┤
│  Managers:                                                      │
│  ├── DownloadManager (URLSession + background tasks)            │
│  ├── CacheManager                                                │
│  ├── FileManager + SecurityScopedBookmarks                      │
│  └── ProxyManager                                                │
├─────────────────────────────────────────────────────────────────┤
│                      Model Layer                                │
├─────────────────────────────────────────────────────────────────┤
│  Models:                                                        │
│  ├── DirectoryItem                                              │
│  ├── DownloadItem + DownloadStatus / Category / ScheduleType    │
│  ├── ClipboardItem + ClipboardContentType                       │
│  └── ProxyModel + ProxyProtocol                                 │
├─────────────────────────────────────────────────────────────────┤
│                      Core / Extensions                          │
├─────────────────────────────────────────────────────────────────┤
│  Extensions: String, URL, UIColor, Date, FileManager            │
│  Utilities: Formatters, HashHelper, Constants                   │
│  Widgets: LiveActivity, WidgetExtension                         │
└─────────────────────────────────────────────────────────────────┘
```

### Directory Structure
```
NativeSwift/
├── App/
│   └── DirXploreApp.swift
├── Features/
│   ├── Browser/
│   ├── Downloads/
│   ├── Clipboard/
│   ├── Proxy/
│   ├── Settings/
│   └── MediaPlayer/
├── Core/
│   ├── Coordinator/
│   ├── Extensions/
│   └── Utilities/
├── Services/
├── Managers/
├── Models/
├── Networking/
├── Storage/
├── LiveActivity/
├── Widgets/
├── Assets/
└── Resources/
```

---

## 4. Migration Phases and Timeline

### Phase 1: Foundation (Weeks 1-2)
- Set up Xcode project with SPM
- Create MVVM+Coordinator skeleton
- Implement Core Data / GRDB models
- Port all models (DirectoryItem, DownloadItem, ClipboardItem, ProxyModel)
- Implement Networking layer (URLSession + HTML parser)
- Set up dependency injection container

### Phase 2: Core Features (Weeks 3-4)
- Browser tab: directory listing, navigation, bookmarks, filtering
- Download tab: queue management, NSURLSessionDownloadTask, progress tracking
- File management: save/download to Files app with security-scoped bookmarks
- Proxy tab: SOCKS5 via Network.framework, YAML import
- Settings tab: UserDefaults persistence, all 30+ toggles

### Phase 3: Media & Advanced (Weeks 5-6)
- Media player: AVPlayer with custom gesture controls, AB repeat, playlist
- Clipboard tab: UIPasteboard monitoring, type detection, history
- Live Activities: ActivityKit for download progress on Dynamic Island
- Widget: iOS WidgetKit for download overview
- Background downloads: BGTaskScheduler + URLSession background config

### Phase 4: Polish & Release (Weeks 7-8)
- Biometric auth (Face ID / Touch ID) via LocalAuthentication
- Custom PIN lock screen
- Workmanager replacement (BGProcessingTask)
- Haptic feedback (UIImpactFeedbackGenerator)
- Thumbnail generation (AVAssetImageGenerator)
- Checksum verification (CryptoKit)
- Export/Import queue (JSON)
- GitHub release update checker
- App icon, launch screen, accessibility
- TestFlight beta, App Store submission

---

## 5. Feature Inventory (30+ Features)

### Browser (8 features)
1. HTTP/FTP directory listing with Apache/Nginx HTML parsing
2. Grid/List view toggle
3. Breadcrumb navigation
4. Search/filter by name
5. Category filtering (Movies, Series, Games, Software, Anime, Images)
6. Folders-first sorting
7. Bookmarks management with defaults
8. InAppWebView fallback mode for non-directory sites

### Downloads (14 features)
9. Download queue with add/pause/resume/stop
10. Concurrent download limiting (1-10)
11. Progress tracking with speed (B/s, KB/s, MB/s) and ETA
12. Batch downloads with folder crawling (recursive)
13. Batch management (resume/pause/remove all in batch)
14. Multi-select mode for queue management
15. Auto-categorization by file type
16. Smart folder routing (Movies/, Music/, etc.)
17. Mirror URL switching on failure
18. Download link refresh (dead link replacement)
19. Checksum verification (MD5, SHA1, SHA256) via CryptoKit
20. Export/import queue as JSON
21. Scheduled downloads (immediate, queue-only, wifi-only, charging-only, scheduled time)
22. Auto-retry with configurable count/delay and mirror fallback

### Media Player (9 features)
23. Video/audio playback with playlist support
24. Gesture controls: vertical brightness/volume, horizontal seek
25. Playback speed (0.25x-2.0x)
26. A-B repeat mode
27. HW/SW decoder toggle
28. Rocket mode (extra-sensitive seek)
29. Audio track and subtitle track selection
30. Aspect ratio cycling (contain/cover/fill)
31. Orientation lock toggle

### Clipboard (7 features)
32. Clipboard monitoring (3-second polling)
33. Auto-detect content type (URL, code, JSON, color, email, phone, file path)
34. Favorites and pinned items
35. Tags management
36. Search, filter by type
37. Export/import (text, JSON, CSV)
38. Multi-select operations

### Proxy (5 features)
39. SOCKS4, SOCKS5, HTTP, HTTPS proxy support
40. YAML/bulk import (bypassempire.yaml format)
41. Latency testing for each proxy
42. Per-proxy activation toggle
43. Automatic proxy sync to downloads

### Security (5 features)
44. Biometric authentication (Face ID / Touch ID)
45. Custom PIN lock with recovery question
46. Inactivity auto-lock (instant, 30s, 1m, 2m)
47. App lifecycle-based relocking
48. Security-scoped bookmark for persistent folder access

### Settings & Automation (9 features)
49. Theme: System/Light/Dark with True AMOLED black
50. Download notifications toggle
51. Speed limiter (per-download KB/s cap)
52. Keep screen awake with timer
53. Wi-Fi only download mode
54. Low battery pause (< 15%)
55. Scheduler (wifi-only, charging-only)
56. Haptic feedback toggle
57. Auto-delete clipboard history by age

### Background Features (4 features)
58. Background URLSession downloads
59. BGTaskScheduler for periodic resume tasks
60. Live Activities for Dynamic Island download progress
61. Widget for at-a-glance download status

---

## 6. Native iOS APIs for Each Feature

| Feature | Native iOS API |
|---------|---------------|
| Directory browsing | URLSession + SwiftSoup |
| HTML parsing | SwiftSoup |
| Download manager | URLSessionDownloadTask + background configuration |
| File storage | FileManager + UIDocumentPickerViewController |
| Proxy (SOCKS) | NWConnection with NWProtocolSOCKS |
| Proxy (HTTP) | URLSessionConfiguration.connectionProxyDictionary |
| Media playback | AVPlayer + AVPlayerViewController |
| Thumbnails | AVAssetImageGenerator |
| Clipboard monitoring | UIPasteboard.general.changeCount |
| Local notifications | UNUserNotificationCenter |
| Background tasks | BGProcessingTask + BGDownloadTask |
| Face ID / Touch ID | LAContext (LocalAuthentication) |
| Live Activities | ActivityKit (ActivityAttributes) |
| Widget | WidgetKit (TimelineProvider) |
| Haptics | UIImpactFeedbackGenerator / UINotificationFeedbackGenerator |
| Disk space | FileManager.default.attributesOfFileSystem |
| Battery | UIDevice.current.batteryLevel |
| Network status | NWPathMonitor |
| App version | Bundle.main.infoDictionary |
| Share sheet | UIActivityViewController |
| File picker | UIDocumentPickerViewController |
| Screen brightness | UIScreen.main.brightness |
| Date formatting | DateFormatter |
| Hashing | CryptoKit (MD5, SHA1, SHA256) |
| Key-value storage | UserDefaults |
| SQLite database | GRDB.swift |
| Dynamic theming | UIColorWell + traitCollection.userInterfaceStyle |
| In-app WebView | WKWebView |

---

## 7. Dependencies and Libraries Needed (SPM)

| Package | URL | Purpose |
|---------|-----|---------|
| SwiftSoup | https://github.com/scinfu/SwiftSoup.git | HTML parsing for directory listings |
| GRDB.swift | https://github.com/groue/GRDB.swift.git | SQLite database for downloads/clipboard |
| Yams | https://github.com/jpsim/Yams.git | YAML proxy file parsing |
| KeychainAccess | https://github.com/kishikawakatsumi/KeychainAccess.git | Secure proxy password storage |

Note: Most functionality uses built-in iOS SDK frameworks.

---

## 8. Potential Challenges and Solutions

| Challenge | Solution |
|-----------|----------|
| SOCKS5 proxy via URLSession | Use Network.framework (NWConnection) directly with SOCKS protocol options; bypass URLSession for SOCKS connections |
| Persistent file access across app reinstalls | Use `UIDocumentPickerViewController` with security-scoped bookmarks stored in Keychain |
| Background download completion | Use `URLSession` background configuration with `BGTaskScheduler` for reconnecting |
| Live Activities on older iOS | Check `ActivityKit` availability; fall back to local notifications on iOS < 16.1 |
| Clipboard monitoring restriction | iOS 14+ shows paste indicator; use `UIPasteboard.general.changeCount` polling with user consent |
| WKWebView fallback content blocking | Configure `WKWebViewConfiguration` with appropriate `WKContentRuleList` |
| Arduino/embedded device directory parsing | Strengthen SwiftSoup parsing to handle non-standard HTML listings |
| Large directory listings (10,000+ files) | Implement paginated/batched parsing on background queue |
| App Store review for background modes | Provide clear usage descriptions in Info.plist; demonstrate legitimate download use |
| iCloud + Files app integration | Use `NSMetadataQuery` for iCloud Drive access; `UIDocumentPickerViewController` for external folders |
