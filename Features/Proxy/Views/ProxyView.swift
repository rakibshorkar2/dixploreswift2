import SwiftUI
import UniformTypeIdentifiers

struct ProxyView: View {
    @StateObject private var viewModel = ProxyViewModel.shared
    @State private var showAddSheet = false
    @State private var showYamlPicker = false
    @State private var showBulkImport = false
    @State private var editingProxy: ProxyModel?
    @State private var showDetail = false

    var body: some View {
        ZStack {
            backgroundGradient

            if viewModel.proxies.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                proxyList
            }

            loadingOverlay

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addButton
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Proxy Manager")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { Task { await viewModel.testAllProxies() } } label: {
                    Image(systemName: "speedometer")
                }
                Button { showYamlPicker = true } label: {
                    Image(systemName: "doc.badge.plus")
                }
                Button { showBulkImport = true } label: {
                    Image(systemName: "list.bullet.rectangle")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddProxySheet { host, port, username, password, proto in
                try? await viewModel.addProxy(host: host, port: port, username: username, password: password, protocolType: proto)
            }
        }
        .sheet(isPresented: $showYamlPicker) {
            YamlImporterView { url in
                try? await viewModel.importFromYamlFile(url: url)
            }
        }
        .sheet(isPresented: $showBulkImport) {
            BulkImportView { uris in
                try? await viewModel.bulkImport(uris: uris)
            }
        }
        .sheet(isPresented: $showDetail) {
            if let proxy = editingProxy {
                ProxyDetailView(proxy: proxy) { updated in
                    try? await viewModel.updateProxy(updated)
                    showDetail = false
                } onDelete: {
                    try? await viewModel.deleteProxy(proxy.id)
                    showDetail = false
                }
            }
        }
        .alert("Error", isPresented: .init(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Text(viewModel.errorMessage ?? "")
        }
        .task { await viewModel.load() }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.8)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No proxies added")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Traffic goes DIRECT")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    private var proxyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.proxies) { proxy in
                    ProxyCard(proxy: proxy, viewModel: viewModel)
                        .onTapGesture {
                            editingProxy = proxy
                            showDetail = true
                        }
                        .contextMenu {
                            Button { Task { await viewModel.testLatency(for: proxy.id) } } label: {
                                Label("Test Ping", systemImage: "antenna.radiowaves.left.and.right")
                            }
                            Button(role: .destructive) { Task { try? await viewModel.deleteProxy(proxy.id) } } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 100)
        }
        .refreshable {
            await viewModel.testAllProxies()
        }
    }

    private var loadingOverlay: some View {
        Group {
            if viewModel.isLoading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView()
            }
        }
    }

    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: Circle())
                .shadow(radius: 8)
        }
    }
}

struct ProxyCard: View {
    let proxy: ProxyModel
    @ObservedObject var viewModel: ProxyViewModel

    var body: some View {
        HStack(spacing: 12) {
            protocolIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(proxy.displayUri)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                latencyLabel
            }
            Spacer()
            Toggle("", isOn: .init(get: { proxy.isActive }, set: { newVal in
                Task { try? await viewModel.toggleProxy(proxy.id, active: newVal) }
            }))
            .labelsHidden()
            .tint(.accentColor)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(proxy.isActive ? Color.accentColor.opacity(0.5) : Color.separator.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var protocolIcon: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: proxy.protocolType == .socsk5 || proxy.protocolType == .socks4 ? "lock.shield" : "network")
                .font(.system(size: 16))
                .foregroundStyle(.accent)
        }
    }

    @ViewBuilder
    private var latencyLabel: some View {
        if viewModel.testingProxyId == proxy.id {
            ProgressView()
                .scaleEffect(0.7)
        } else if let ms = proxy.latencyMs {
            Label(
                ms == -1 ? "Connection Failed" : "Latency: \(ms)ms",
                systemImage: ms == -1 ? "xmark.circle" : (ms < 500 ? "checkmark.circle" : "exclamationmark.circle")
            )
            .font(.caption)
            .foregroundStyle(ms == -1 ? .red : (ms < 500 ? .green : .orange))
        } else {
            Text("Not tested")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

struct AddProxySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var host = ""
    @State private var port = "1080"
    @State private var username = ""
    @State private var password = ""
    @State private var selectedProtocol: ProxyProtocol = .socsk5
    @State private var errorMessage: String?

    let onSave: (String, Int, String?, String?, ProxyProtocol) async throws -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Protocol") {
                    Picker("Protocol", selection: $selectedProtocol) {
                        ForEach([ProxyProtocol.socsk5, .socks4, .http, .https], id: \.self) { proto in
                            Text(proto.label).tag(proto)
                        }
                    }
                }
                Section("Server") {
                    TextField("Host IP/Domain", text: $host)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
                Section("Authentication (Optional)") {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                    SecureField("Password", text: $password)
                }
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Add Proxy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                }
            }
        }
    }

    private func save() {
        guard !host.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Host cannot be empty"
            return
        }
        guard let portNum = Int(port.trimmingCharacters(in: .whitespaces)), portNum > 0, portNum <= 65535 else {
            errorMessage = "Invalid port number"
            return
        }
        Task {
            try? await onSave(
                host.trimmingCharacters(in: .whitespaces),
                portNum,
                username.trimmingCharacters(in: .whitespaces).isEmpty ? nil : username.trimmingCharacters(in: .whitespaces),
                password.isEmpty ? nil : password,
                selectedProtocol
            )
            dismiss()
        }
    }
}

struct YamlImporterView: UIViewControllerRepresentable {
    let onImport: (URL) async throws -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.yaml])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImport: onImport)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onImport: (URL) async throws -> Void
        init(onImport: @escaping (URL) async throws -> Void) { self.onImport = onImport }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            Task { try? await onImport(url) }
        }
    }
}

struct BulkImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    let onImport: ([String]) async throws -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Paste one or more proxy URIs (one per line):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                TextEditor(text: $text)
                    .font(.body.monospaced())
                    .frame(minHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.separator.opacity(0.3))
                    )
                    .padding(.horizontal)

                Text("socks5://host:port\nsocks5://user:pass@host:port")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Bulk Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        Task {
                            try? await onImport(lines)
                            dismiss()
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct ProxyDetailView: View {
    @State private var host: String
    @State private var port: String
    @State private var username: String
    @State private var password: String
    @State private var selectedProtocol: ProxyProtocol
    let proxy: ProxyModel
    let onSave: (ProxyModel) async throws -> Void
    let onDelete: () async throws -> Void

    init(proxy: ProxyModel, onSave: @escaping (ProxyModel) async throws -> Void, onDelete: @escaping () async throws -> Void) {
        self.proxy = proxy
        _host = State(initialValue: proxy.host)
        _port = State(initialValue: "\(proxy.port)")
        _username = State(initialValue: proxy.username ?? "")
        _password = State(initialValue: proxy.password ?? "")
        _selectedProtocol = State(initialValue: proxy.protocolType)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Protocol") {
                    Picker("Protocol", selection: $selectedProtocol) {
                        ForEach([ProxyProtocol.socsk5, .socks4, .http, .https], id: \.self) { proto in
                            Text(proto.label).tag(proto)
                        }
                    }
                }
                Section("Server") {
                    TextField("Host", text: $host)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
                Section("Authentication") {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                }
                Section {
                    Button("Delete Proxy", role: .destructive) {
                        Task { try? await onDelete() }
                    }
                }
            }
            .navigationTitle("Edit Proxy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let portNum = Int(port) ?? proxy.port
                        let updated = ProxyModel(
                            id: proxy.id,
                            protocolType: selectedProtocol,
                            host: host,
                            port: portNum,
                            username: username.trimmingCharacters(in: .whitespaces).isEmpty ? nil : username.trimmingCharacters(in: .whitespaces),
                            password: password.isEmpty ? nil : password,
                            isActive: proxy.isActive,
                            latencyMs: proxy.latencyMs
                        )
                        Task { try? await onSave(updated) }
                    }
                }
            }
        }
    }
}

extension UTType {
    static let yaml = UTType(filenameExtension: "yaml") ?? .plainText
}
