import SwiftUI

enum SchoolityStyle {
    static let accent = Color.accentColor
    static let muted = Color.primary.opacity(0.65)
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
