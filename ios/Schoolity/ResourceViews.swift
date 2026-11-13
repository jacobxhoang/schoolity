import SwiftUI
import QuickLook

struct ResourceView: View {
    @EnvironmentObject private var store: AppStore
    let resource: SchoolResource
    @State private var previewURL: URL?
    @State private var pendingDownload: String?
    @State private var downloadError: String?

    var body: some View {
        List {
            if let error = store.failures[resource] {
                Section { FailureRow(message: error) { Task { await store.load(resource, refresh: true) } } }
            }
            if let items = store.records[resource] {
                if items.isEmpty {
                    ContentUnavailableView(resource == .mail ? "No messages" : "No \(resource.title.lowercased())", systemImage: resource.symbol,
                                           description: Text("Nothing to show from your district yet."))
                }
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    switch resource {
                    case .schedule: scheduleRow(item)
                    case .mail: mailRow(item, index: index)
                    case .documents: documentRow(item, index: index)
                    }
                }
            } else if store.loadingResources.contains(resource) {
                ProgressView("Loading \(resource.title.lowercased())…")
            }
        }
        .listStyle(.inset)
        .navigationTitle(resource.title)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AccountButton() } }
        .task { await store.load(resource) }
        .refreshable { await store.load(resource, refresh: true) }
        .quickLookPreview($previewURL)
        .alert("Download failed", isPresented: Binding(get: { downloadError != nil }, set: { if !$0 { downloadError = nil } })) {
            Button("OK") { downloadError = nil }
        } message: { Text(downloadError ?? "Try downloading this file again.") }
    }

    private func scheduleRow(_ item: SchoolEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title).font(.headline)
            if !item.detail.isEmpty { Text(item.detail).font(.subheadline).foregroundStyle(.secondary) }
            if !item.date.isEmpty { Text(item.date).font(.subheadline).foregroundStyle(.secondary) }
        }.padding(.vertical, 8).accessibilityElement(children: .combine)
    }

    private func mailRow(_ item: SchoolEvent, index: Int) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 16) {
                if !item.date.isEmpty { Text(item.date).font(.caption).foregroundStyle(.secondary) }
                Text(item.detail.isEmpty ? "No message text." : item.detail)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                ForEach(Array((item.attachments ?? []).enumerated()), id: \.offset) { attachmentIndex, attachment in
                    let key = "mail-\(index)-\(attachmentIndex)"
                    Button {
                        download(id: attachment.id, filename: attachment.filename, messageID: item.id, key: key)
                    } label: {
                        downloadLabel(attachment.filename, detail: nil, key: key)
                    }
                    .buttonStyle(.borderless)
                    .disabled(pendingDownload != nil || attachment.id.isEmpty || (item.id ?? "").isEmpty)
                    .accessibilityHint("Download attachment, then preview or share")
                }
            }.padding(.vertical, 12)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title.isEmpty ? "Untitled message" : item.title).font(.headline).foregroundStyle(.primary)
                if let author = item.author, !author.isEmpty { Text(author).font(.footnote).foregroundStyle(SchoolityStyle.muted) }
            }.padding(.vertical, 8)
        }
    }

    private func documentRow(_ item: SchoolEvent, index: Int) -> some View {
        let key = "document-\(index)"
        return Button {
            download(id: item.id ?? "", filename: item.filename ?? item.title, key: key)
        } label: {
            downloadLabel(item.title.isEmpty ? "Document" : item.title,
                          detail: [item.detail, item.date].filter { !$0.isEmpty }.joined(separator: " · "), key: key)
        }
        .disabled(pendingDownload != nil || (item.id ?? "").isEmpty)
        .accessibilityHint("Download document, then preview or share")
    }

    private func downloadLabel(_ title: String, detail: String?, key: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "doc").font(.title2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                if let detail, !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
            }
            Spacer(minLength: 0)
            if pendingDownload == key { ProgressView().accessibilityLabel("Downloading") }
            else { Image(systemName: "arrow.down").foregroundStyle(.secondary).accessibilityHidden(true) }
        }.frame(minHeight: 44).padding(.vertical, 8).contentShape(Rectangle())
    }

    private func download(id: String, filename: String, messageID: String? = nil, key: String) {
        guard pendingDownload == nil, !id.isEmpty else { return }
        pendingDownload = key
        Task {
            defer { pendingDownload = nil }
            do { previewURL = try await store.download(id: id, filename: filename, messageID: messageID) }
            catch { downloadError = error.localizedDescription }
        }
    }
}
