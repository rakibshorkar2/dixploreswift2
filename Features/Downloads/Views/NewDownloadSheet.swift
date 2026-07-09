import SwiftUI

struct NewDownloadSheet: View {
    @ObservedObject var viewModel: DownloadsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var fileName = ""
    @State private var batchText = ""
    @State private var isBatchMode = false
    @State private var showAdvanced = false
    @State private var showLinkAnalysis = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoFetched = false
    @State private var metadataFailed = false
    @State private var fileSize: Int64 = -1
    @State private var fileType = ""
    @State private var resumeSupported: Bool?
    @State private var detectedFileName = ""
    @State private var resolvedUrl = ""
    @State private var originalUrl = ""
    @State private var redirectCount = 0
    @State private var host = ""
    @State private var customHeaders: [String: String] = [:]
    @State private var headerInput = ""
    @State private var selectedCategory: DownloadCategory = .other
    @State private var scheduleType: ScheduleType = .immediate
    @State private var maxRetries: Int = 3
    @State private var expectedMd5 = ""
    @State private var expectedSha1 = ""
    @State private var expectedSha256 = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("New Download")
                        .font(.title2.bold())
                    Spacer()
                    Picker("Mode", selection: $isBatchMode) {
                        Text("Single").tag(false)
                        Text("Batch").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 12) {
                        if !isBatchMode {
                            urlSection
                            actionRow
                            if showAdvanced { advancedSection }
                            filenameSection
                            if infoFetched && !metadataFailed { linkAnalysisSection }
                            if metadataFailed { metadataWarning }
                        } else {
                            batchSection
                        }
                    }
                    .padding()
                }

                bottomActions
            }
            .interactiveDismissDisabled()
        }
    }

    // MARK: - URL Section

    private var urlSection: some View {
        HStack {
            TextField("https://example.com/file.zip", text: $urlText)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(.quaternary.opacity(0.5))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.3)))
                .onChange(of: urlText) { _, _ in
                    if infoFetched { infoFetched = false; errorMessage = nil }
                }
        }
    }

    // MARK: - Action Row

    private var actionRow: some View {
        HStack {
            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = urlText.isEmpty ? nil : urlText
                #endif
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard").font(.caption)
            }

            Spacer()

            Button {
                withAnimation { showAdvanced.toggle() }
            } label: {
                Label(showAdvanced ? "Hide Advanced" : "Advanced",
                      systemImage: showAdvanced ? "chevron.up" : "chevron.down")
                    .font(.caption)
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Headers").font(.caption.bold())

            if !customHeaders.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(customHeaders.sorted(by: { $0.key < $1.key }), id: \.key) { key, val in
                        HStack(spacing: 4) {
                            Text("\(key): \(val)").font(.system(size: 10))
                            Button { customHeaders.removeValue(forKey: key) } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 12))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            HStack {
                TextField("Header: Value", text: $headerInput)
                    .font(.caption)
                    .padding(8)
                    .background(.quaternary.opacity(0.5))
                    .cornerRadius(8)
                    .onSubmit { addHeader() }
                Button { addHeader() } label: { Image(systemName: "plus.circle").font(.title3) }
            }

            Picker("Category", selection: $selectedCategory) {
                ForEach([
                    (.other, "Other"), (.movies, "Movies"), (.tvShows, "TV Shows"),
                    (.music, "Music"), (.images, "Images"), (.documents, "Documents"),
                    (.archives, "Archives"), (.apps, "Apps")
                ], id: \.0) { cat, label in
                    Text(label).tag(cat)
                }
            }

            Picker("Schedule", selection: $scheduleType) {
                Text("Immediate").tag(ScheduleType.immediate)
                Text("Queue Only").tag(ScheduleType.queueOnly)
                Text("Wi-Fi Only").tag(ScheduleType.wifiOnly)
                Text("Charging Only").tag(ScheduleType.chargingOnly)
                Text("Scheduled").tag(ScheduleType.scheduled)
            }

            HStack {
                Text("Max Retries:")
                TextField("3", value: $maxRetries, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }

            Text("Expected Hashes").font(.caption.bold())
            TextField("MD5", text: $expectedMd5).font(.caption).textFieldStyle(.roundedBorder)
            TextField("SHA1", text: $expectedSha1).font(.caption).textFieldStyle(.roundedBorder)
            TextField("SHA256", text: $expectedSha256).font(.caption).textFieldStyle(.roundedBorder)
        }
        .padding(12)
        .background(.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.2)))
    }

    private func addHeader() {
        let parts = headerInput.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        customHeaders[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
        headerInput = ""
    }

    // MARK: - Filename

    private var filenameSection: some View {
        TextField("Filename (auto-detected from URL)", text: $fileName)
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator.opacity(0.3)))
            .onChange(of: fileName) { _, _ in
                if infoFetched { infoFetched = false }
            }
    }

    // MARK: - Link Analysis

    private var linkAnalysisSection: some View {
        DisclosureGroup(isExpanded: $showLinkAnalysis) {
            VStack(alignment: .leading, spacing: 6) {
                infoRow(icon: "doc.text", label: "Filename", value: detectedFileName)
                infoRow(icon: "externaldrive", label: "Size", value: fileSize > 0 ? formatFileSize(fileSize) : "Unknown")
                infoRow(icon: "doc.badge.gearshape", label: "MIME Type", value: fileType.isEmpty ? "Unknown" : fileType)
                infoRow(icon: "globe", label: "Host", value: host)
                infoRow(icon: "arrow.triangle.branch", label: "Final URL",
                       value: resolvedUrl != originalUrl ? "\(resolvedUrl.prefix(40))..." : "Same as original")
                infoRow(icon: "arrow.forward", label: "Redirects", value: "\(redirectCount)")
                infoRow(icon: resumeSupported == true ? "arrow.circlepath" : "xmark.circle",
                       label: "Resume Support",
                       value: resumeSupported == true ? "Yes" : (resumeSupported == false ? "No" : "Unknown"),
                       color: resumeSupported == true ? .green : (resumeSupported == false ? .red : .secondary))
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Image(systemName: "magnifyingglass.circle")
                    .foregroundStyle(.blue)
                Text("Link Analysis").font(.caption.bold())
                Spacer()
                Text(linkAnalysisSummary).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.blue.opacity(0.15)))
    }

    private var linkAnalysisSummary: String {
        var parts: [String] = []
        if !fileType.isEmpty { parts.append(fileType.split(separator: "/").last?.uppercased() ?? "") }
        if fileSize > 0 { parts.append(formatFileSize(fileSize)) }
        if resumeSupported == true { parts.append("Resume Supported") } else if resumeSupported == false { parts.append("No Resume") }
        return parts.isEmpty ? "Metadata unavailable" : parts.joined(separator: " · ")
    }

    private func infoRow(icon: String, label: String, value: String, color: Color? = nil) -> some View {
        HStack {
            Image(systemName: icon).font(.caption2).foregroundStyle(.blue.opacity(0.7))
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption2).foregroundStyle(color ?? .primary)
                .lineLimit(1)
        }
    }

    // MARK: - Metadata Warning

    private var metadataWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
            Text("Metadata could not be retrieved. Download anyway?")
                .font(.caption)
        }
        .padding(10)
        .background(.orange.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Batch Section

    private var batchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $batchText)
                .font(.caption)
                .frame(minHeight: 120)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator))
                .overlay(alignment: .topLeading) {
                    if batchText.isEmpty {
                        Text("Paste URLs (one per line)")
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(12)
                    }
                }

            Button {
                #if canImport(UIKit)
                if let str = UIPasteboard.general.string {
                    if isBatchMode { batchText = str }
                    else { urlText = str }
                }
                #endif
            } label: {
                Label("Paste from Clipboard", systemImage: "doc.on.clipboard").font(.caption)
            }
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.large)

            Button {
                if isBatchMode { startBatchDownload() }
                else if infoFetched || metadataFailed { startDownload() }
                else { fetchInfo() }
            } label: {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else if isBatchMode {
                    Label("Add All", systemImage: "tray.and.arrow.down").frame(maxWidth: .infinity)
                } else if infoFetched || metadataFailed {
                    Label("Download", systemImage: "tray.and.arrow.down").frame(maxWidth: .infinity)
                } else {
                    Label("Fetch Info", systemImage: "magnifyingglass").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoading)
        }
        .padding()
    }

    // MARK: - Actions

    private func fetchInfo() {
        let trimmed = urlText.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            errorMessage = "Invalid URL"
            return
        }

        isLoading = true
        errorMessage = nil
        infoFetched = false
        metadataFailed = false
        fileSize = -1
        fileType = ""
        resumeSupported = nil
        showLinkAnalysis = false

        originalUrl = trimmed
        host = url.host ?? ""
        redirectCount = 0

        Task {
            var resUrl = trimmed
            var headReq = URLRequest(url: url)
            headReq.httpMethod = "HEAD"
            headReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

            do {
                let (_, response) = try await URLSession.shared.data(for: headReq)
                if let httpResp = response as? HTTPURLResponse {
                    redirectCount = httpResp.statusCode / 100 == 3 ? 1 : 0
                    if let loc = httpResp.allHeaderFields["Location"] as? String {
                        resUrl = loc
                    }
                    let cl = httpResp.expectedContentLength
                    if cl > 0 { fileSize = cl }
                    if let ct = httpResp.allHeaderFields["Content-Type"] as? String {
                        fileType = ct.components(separatedBy: ";").first ?? ct
                    }
                    let ranges = (httpResp.allHeaderFields["Accept-Ranges"] as? String ?? "").lowercased()
                    resumeSupported = ranges == "bytes" ? true : (ranges.isEmpty ? nil : false)
                }
                resolvedUrl = resUrl

                if detectedFileName.isEmpty {
                    detectedFileName = (resUrl as NSString).lastPathComponent
                }
                if detectedFileName.isEmpty {
                    detectedFileName = (trimmed as NSString).lastPathComponent
                }
                if fileName.trimmingCharacters(in: .whitespaces).isEmpty && !detectedFileName.isEmpty {
                    fileName = detectedFileName
                }

                infoFetched = true
                isLoading = false
            } catch {
                detectedFileName = (trimmed as NSString).lastPathComponent
                if fileName.trimmingCharacters(in: .whitespaces).isEmpty && !detectedFileName.isEmpty {
                    fileName = detectedFileName
                }
                metadataFailed = true
                isLoading = false
                errorMessage = "Metadata could not be retrieved."
            }
        }
    }

    private func startDownload() {
        let url = resolvedUrl.isEmpty ? urlText.trimmingCharacters(in: .whitespaces) : resolvedUrl
        let name = fileName.trimmingCharacters(in: .whitespaces).isEmpty
            ? detectedFileName
            : fileName.trimmingCharacters(in: .whitespaces)
        let orig = originalUrl.isEmpty ? url : originalUrl

        let md5 = expectedMd5.trimmingCharacters(in: .whitespaces).isEmpty ? nil : expectedMd5.trimmingCharacters(in: .whitespaces)
        let sha1 = expectedSha1.trimmingCharacters(in: .whitespaces).isEmpty ? nil : expectedSha1.trimmingCharacters(in: .whitespaces)
        let sha256 = expectedSha256.trimmingCharacters(in: .whitespaces).isEmpty ? nil : expectedSha256.trimmingCharacters(in: .whitespaces)

        viewModel.addDownload(
            url: url, fileName: name,
            saveDir: SettingsManager.shared.defaultSavePath,
            originalUrl: orig,
            customHeaders: customHeaders,
            category: selectedCategory == .other ? nil : selectedCategory,
            scheduleType: scheduleType,
            maxRetries: maxRetries,
            expectedMd5: md5,
            expectedSha1: sha1,
            expectedSha256: sha256,
            redirectCount: redirectCount,
            resolvedUrl: resolvedUrl.isEmpty ? nil : resolvedUrl
        )
        dismiss()
    }

    private func startBatchDownload() {
        Task {
            let result = await viewModel.batchAddDownloads(urlsText: batchText, saveDir: SettingsManager.shared.defaultSavePath)
            dismiss()
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        DownloadItem.formatBytes(bytes)
    }
}

// MARK: - WrapLayout

private struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var width: CGFloat = 0
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0
        for size in sizes {
            if currentX + size.width > (proposal.width ?? .infinity) {
                currentX = 0
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
            width = max(width, currentX)
            height = currentY + maxHeight
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var currentX = bounds.minX
        var currentY = bounds.minY
        var maxHeight: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            subviews[index].place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}