import SwiftUI

enum SchoolityStyle {
    static let accent = Color.accentColor
    static let muted = Color.primary.opacity(0.65)
}

private struct SchoolityListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .environment(\.defaultMinListRowHeight, 52)
    }
}

extension View {
    func schoolityList() -> some View { modifier(SchoolityListStyle()) }
}

/// Section footer text for the time a section last loaded from the district.
struct LastUpdatedText: View {
    let date: Date?
    var body: some View {
        if let date {
            Text("Last updated \(date.formatted(date: .omitted, time: .shortened))")
        }
    }
}

/// The same caption as a trailing list row, for screens without a section footer.
struct LastUpdatedFooter: View {
    let date: Date?
    var body: some View {
        if let date {
            HStack {
                Spacer(minLength: 0)
                Text("Last updated \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isStaticText)
                Spacer(minLength: 0)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}

/// Shared icon treatment for signed-in information and destination rows.
struct InformationIcon: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.background)
            .frame(width: 30, height: 30)
            .background(SchoolityStyle.accent, in: RoundedRectangle(cornerRadius: 7))
            .accessibilityHidden(true)
    }
}

struct InformationRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InformationIcon(symbol: symbol)
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                    Text(value).foregroundStyle(.secondary).textSelection(.enabled)
                }
            } else {
                LabeledContent(title) {
                    Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
                }
                .padding(.top, 4)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
    }
}
