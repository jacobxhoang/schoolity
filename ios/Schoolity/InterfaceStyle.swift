import SwiftUI

enum SchoolityStyle {
    static let accent = Color.accentColor
    static let muted = Color.primary.opacity(0.65)
}

/// Shared motion tokens. Every spring tier is named for the moment it covers, and
/// Reduce Motion swaps each one for a short fade instead of removing the change.
enum SchoolityMotion {
    /// Something arriving or opening.
    static let reveal = Animation.spring(duration: 0.4, bounce: 0.14)
    /// A number people read moving to its new value. Never overshoots, so it never
    /// shows a value that is not true.
    static let value = Animation.spring(duration: 0.35, bounce: 0)
    /// A shape or ring growing into a new proportion, with a little give at the end.
    static let shape = Animation.spring(duration: 0.45, bounce: 0.15)

    /// The same motion, or a plain fade when Reduce Motion is on.
    static func calm(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : animation
    }
}

/// A plain canvas with true black in Dark Mode.
struct SchoolityBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        (colorScheme == .dark ? Color.black : Color(uiColor: .systemGroupedBackground))
            .ignoresSafeArea()
    }
}

private struct SchoolityListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .scrollContentBackground(.hidden)
            .background { SchoolityBackdrop() }
            .environment(\.defaultMinListRowHeight, 52)
    }
}

extension View {
    func schoolityList() -> some View { modifier(SchoolityListStyle()) }
}

/// A floating Liquid Glass surface on iOS 26, and a translucent surface that keeps
/// the same shape and tint on earlier versions. System chrome, such as the tab bar
/// and navigation bars, becomes Liquid Glass on its own when the app is built with
/// the iOS 26 SDK.
struct GlassSurface: ViewModifier {
    let tint: Color
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(tint.opacity(0.4)), in: .rect(cornerRadius: cornerRadius))
        } else {
            translucent(content)
        }
        #else
        translucent(content)
        #endif
    }

    private func translucent(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.18), tint.opacity(0.03)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    /// A floating glass surface, tinted by the reader's grade colors.
    func schoolityGlass(tint: Color, cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassSurface(tint: tint, cornerRadius: cornerRadius))
    }
}

/// The prominent action on a screen: Liquid Glass on iOS 26, a bordered button before it.
struct GlassButtonAppearance: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            bordered(content)
        }
        #else
        bordered(content)
        #endif
    }

    private func bordered(_ content: Content) -> some View {
        content
            .buttonStyle(.bordered)
            .tint(.primary)
            .buttonBorderShape(.roundedRectangle(radius: 14))
    }
}

extension View {
    func schoolityGlassButton() -> some View { modifier(GlassButtonAppearance()) }
}

/// The small count the website puts beside a section heading.
struct CountBadge: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.14), in: Capsule())
            .accessibilityLabel(count == 1 ? "1 item" : "\(count) items")
    }
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
                Label("Last updated \(date.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .schoolityGlass(tint: SchoolityStyle.accent, cornerRadius: 100)
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
