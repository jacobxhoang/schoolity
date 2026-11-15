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
            SchoolityPageHeader(
                title: resource.title,
                updated: store.lastUpdated[resource.rawValue],
                isRefreshing: store.loadingResources.contains(resource),
                refresh: { Task { await store.load(resource, refresh: true) } }
            )
            .schoolityPageRow(top: 8, bottom: 18)

            if let error = store.failures[resource] {
                FailureCard(message: error, dismiss: { store.failures[resource] = nil }) {
                    Task { await store.load(resource, refresh: true) }
                }
                .schoolityPageRow(bottom: 12)
            }

            if let items = store.records[resource] {
                if items.isEmpty {
                    SchoolityEmptyState(
                        title: resource == .mail ? "No messages" : "No \(resource.title.lowercased())",
                        description: "Nothing to show from your district yet.",
                        symbol: resource.symbol
                    )
                    .schoolityPageRow(bottom: 12)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        switch resource {
                        case .mail: mailRow(item, index: index)
                        case .documents: documentRow(item, index: index)
                        }
                    }
                }
            } else if store.loadingResources.contains(resource) {
                ForEach(0..<3, id: \.self) { _ in
                    ResourceSkeletonRow()
                        .schoolityPageRow(bottom: 10)
                }
            }
        }
        .schoolityPageList()
        .navigationTitle(resource.title)
        .schoolityNavigationChrome()
        .task { await store.load(resource) }
        .refreshable { await store.load(resource, refresh: true) }
        .quickLookPreview($previewURL)
        .alert("Download failed", isPresented: Binding(get: { downloadError != nil }, set: { if !$0 { downloadError = nil } })) {
            Button("OK") { downloadError = nil }
        } message: { Text(downloadError ?? "Try downloading this file again.") }
    }

    private func mailRow(_ item: SchoolEvent, index: Int) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 16) {
                HairlineDivider()
                if !item.date.isEmpty {
                    Text(item.date)
                        .font(.caption)
                        .foregroundStyle(SchoolityPalette.faint)
                }
                Text(item.detail.isEmpty ? "No message text." : item.detail)
                    .font(.subheadline)
                    .foregroundStyle(SchoolityPalette.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let attachments = item.attachments, !attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Attachments")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(SchoolityPalette.ink)
                            .padding(.bottom, 8)
                        ForEach(Array(attachments.enumerated()), id: \.offset) { attachmentIndex, attachment in
                            let key = "mail-\(index)-\(attachmentIndex)"
                            if attachmentIndex > 0 { HairlineDivider() }
                            Button {
                                download(id: attachment.id, filename: attachment.filename, messageID: item.id, key: key)
                            } label: {
                                HStack(spacing: 12) {
                                    IconTile(symbol: "paperclip", size: 32, background: .field)
                                    Text(attachment.filename)
                                        .font(.subheadline)
                                        .foregroundStyle(SchoolityPalette.ink)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 8)
                                    if pendingDownload == key {
                                        ProgressView().accessibilityLabel("Downloading")
                                    } else {
                                        Text("Open")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(SchoolityPalette.ink)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(SchoolityPalette.field, in: Capsule())
                                            .overlay { Capsule().strokeBorder(SchoolityPalette.line, lineWidth: 1) }
                                    }
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(pendingDownload != nil || attachment.id.isEmpty || (item.id ?? "").isEmpty)
                            .accessibilityHint("Download attachment, then preview or share")
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.bottom, 6)
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: "envelope.fill", size: 36, background: .field)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title.isEmpty ? "Untitled message" : item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SchoolityPalette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let author = item.author, !author.isEmpty {
                        Text(author)
                            .font(SchoolityText.meta)
                            .foregroundStyle(SchoolityPalette.muted)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .tint(SchoolityPalette.muted)
        .schoolityCard(padding: 16)
        .schoolityPageRow(bottom: 10)
    }

    private func documentRow(_ item: SchoolEvent, index: Int) -> some View {
        let key = "document-\(index)"
        return Button {
            download(id: item.id ?? "", filename: item.filename ?? item.title, key: key)
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: "doc.fill", size: 36, background: .field)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title.isEmpty ? "Document" : item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SchoolityPalette.ink)
                        .multilineTextAlignment(.leading)
                    let detail = [item.detail, item.date].filter { !$0.isEmpty }.joined(separator: " · ")
                    if !detail.isEmpty {
                        Text(detail)
                            .font(SchoolityText.meta)
                            .foregroundStyle(SchoolityPalette.muted)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                if pendingDownload == key {
                    ProgressView().accessibilityLabel("Downloading")
                } else {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SchoolityPalette.muted)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(SchoolityCardButtonStyle())
        .disabled(pendingDownload != nil || (item.id ?? "").isEmpty)
        .accessibilityHint("Download document, then preview or share")
        .schoolityCard(padding: 16)
        .schoolityPageRow(bottom: 10)
    }

    private func download(id: String, filename: String, messageID: String? = nil, key: String) {
        guard pendingDownload == nil, !id.isEmpty else { return }
        pendingDownload = key
        Task {
            defer { pendingDownload = nil }
            do {
                previewURL = try await store.download(id: id, filename: filename, messageID: messageID)
            } catch {
                guard !PortalFailure.isCancellation(error) else { return }
                downloadError = error.localizedDescription
            }
        }
    }
}

private struct ResourceSkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SchoolityPalette.soft)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 9) {
                SkeletonBlock(width: 180, height: 14)
                SkeletonBlock(width: 120, height: 11)
            }
            Spacer(minLength: 0)
        }
        .schoolityCard(padding: 16)
        .accessibilityHidden(true)
    }
}
