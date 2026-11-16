import SwiftUI
import UIKit

/// The website's one palette, carried into the app. Every surface reads these
/// values instead of naming colors locally.
enum SchoolityPalette {
    static let canvas = adaptive(light: 0xF7F7F8, dark: 0x111113)
    static let panel = adaptive(light: 0xFFFFFF, dark: 0x1A1A1D)
    static let ink = adaptive(light: 0x0F0F0F, dark: 0xF2F2F2)
    static let muted = adaptive(light: 0x5C5C5C, dark: 0xA8A8A8)
    static let faint = adaptive(light: 0x6E6E6E, dark: 0x909090)
    static let line = adaptive(light: 0xE6E6E8, dark: 0x2A2A2A)
    static let lineStrong = adaptive(light: 0xCFCFCF, dark: 0x3D3D3D)
    static let field = adaptive(light: 0xF5F5F5, dark: 0x1C1C1C)
    static let soft = adaptive(light: 0xECECEC, dark: 0x242424)
    /// Text that sits on an ink-filled control: white in Light Mode, near-black in Dark Mode.
    static let onInk = adaptive(light: 0xFFFFFF, dark: 0x111111)

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// A fixed sRGB value for surfaces that do not follow the interface appearance.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// The sign-in surface keeps the workspace's dark palette in every appearance,
/// the way the website keeps its sign-in surface fixed in both themes.
enum SchoolityLoginPalette {
    static let canvas = Color(hex: 0x111113)
    static let panel = Color(hex: 0x1A1A1D)
    static let ink = Color(hex: 0xF2F2F2)
    static let muted = Color(hex: 0xA8A8A8)
    static let faint = Color(hex: 0x909090)
    static let line = Color(hex: 0x2A2A2A)
    static let lineStrong = Color(hex: 0x3D3D3D)
    static let field = Color(hex: 0x1C1C1C)
    static let soft = Color(hex: 0x242424)
    static let onInk = Color(hex: 0x111111)
}

enum SchoolityRadius {
    static let chip: CGFloat = 8
    static let panel: CGFloat = 10
    static let card: CGFloat = 16
    static let large: CGFloat = 20
}

enum SchoolitySpace {
    static let s1: CGFloat = 8
    static let s2: CGFloat = 12
    static let s3: CGFloat = 16
    static let s4: CGFloat = 24
    static let s5: CGFloat = 32
}

/// The website's type scale in the system face, so Dynamic Type still applies.
enum SchoolityText {
    static let pageTitle = Font.system(.largeTitle, weight: .semibold)
    static let sectionTitle = Font.system(.title3, weight: .semibold)
    static let cardTitle = Font.headline
    static let body = Font.subheadline
    static let meta = Font.footnote
    static let stat = Font.system(.title, weight: .semibold)
    static let statSmall = Font.system(.title3, weight: .semibold)
}

/// The sign-in screens keep the original teal accent; the signed-in workspace
/// uses the website's ink accent unless the reader chose their own.
enum SchoolityStyle {
    static let accent = Color.accentColor
    static let muted = SchoolityPalette.muted
}

/// Shared motion tokens. Every spring tier is named for the moment it covers, and
/// Reduce Motion swaps each one for a short fade instead of removing the change.
enum SchoolityMotion {
    /// Frequent inline disclosures settle quickly without overshooting row height.
    static let disclosure = Animation.snappy(duration: 0.2, extraBounce: 0)
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

/// The signed-in canvas: the website's lightly tinted surface, near-black in Dark Mode.
struct SchoolityBackdrop: View {
    var body: some View {
        SchoolityPalette.canvas.ignoresSafeArea()
    }
}

// MARK: - Surfaces

struct SchoolityCardSurface: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = SchoolityRadius.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SchoolityPalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(SchoolityPalette.line, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }
}

extension View {
    /// A flat panel card with a fine border, the website's only surface level.
    func schoolityCard(padding: CGFloat = 18, radius: CGFloat = SchoolityRadius.card) -> some View {
        modifier(SchoolityCardSurface(padding: padding, radius: radius))
    }

    /// A full-bleed card row inside a plain `List`.
    func schoolityPageRow(top: CGFloat = 0, bottom: CGFloat = 12, horizontal: CGFloat = 20) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: horizontal, bottom: bottom, trailing: horizontal))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    /// A card with the page's equal gutters already applied.
    func schoolityCardRow(top: CGFloat = 0, bottom: CGFloat = 12, padding: CGFloat = 18) -> some View {
        schoolityCard(padding: padding)
            .schoolityPageRow(top: top, bottom: bottom)
    }
}

/// Website-style grouped list for settings and forms: inset group cards on the canvas.
private struct SchoolityListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .listSectionSpacing(16)
            .scrollContentBackground(.hidden)
            .background { SchoolityBackdrop() }
            .environment(\.defaultMinListRowHeight, 48)
    }
}

/// The signed-in pages: one flat column of bordered cards, like the workspace.
private struct SchoolityPageListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .background { SchoolityBackdrop() }
            .environment(\.defaultMinListRowHeight, 1)
    }
}

extension View {
    func schoolityList() -> some View { modifier(SchoolityListStyle()) }
    func schoolityPageList() -> some View { modifier(SchoolityPageListStyle()) }

    /// Use the native navigation bar so newer iOS releases can provide their
    /// system material while older releases keep the app's canvas treatment.
    func schoolityNavigationChrome() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .modifier(SchoolityNavigationBarBackground())
    }
}

private struct SchoolityNavigationBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.toolbarBackground(.automatic, for: .navigationBar)
        } else {
            content
                .toolbarBackground(SchoolityPalette.canvas, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Controls

struct SchoolityPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration)
    }

    private struct Content: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SchoolityPalette.onInk)
                .padding(.horizontal, SchoolitySpace.s3)
                .frame(minHeight: 44)
                .background(SchoolityPalette.ink, in: RoundedRectangle(cornerRadius: SchoolityRadius.chip, style: .continuous))
                .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.5)
        }
    }
}

struct SchoolitySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration)
    }

    private struct Content: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SchoolityPalette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(SchoolityPalette.panel, in: RoundedRectangle(cornerRadius: SchoolityRadius.panel, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SchoolityRadius.panel, style: .continuous)
                        .strokeBorder(SchoolityPalette.line, lineWidth: 1)
                }
                .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.5)
        }
    }
}

/// A pressed state for whole-card links, without moving text at accessibility sizes.
struct SchoolityCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration)
    }

    private struct Content: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.995 : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

// MARK: - Menus

/// One choice in a `SchoolityMenu`.
struct SchoolityMenuOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String

    var id: Value { value }
}

/// A dropdown that shows its options in a floating popover instead of a native
/// `Menu` or `.menu` picker. Both of those render inside the scrolling row that
/// owns them: the row resizes under the label while the menu opens, and a card
/// that clips its rounded corners can cut the menu off as it leaves the row.
/// A popover is presented in its own layer, so it cannot be clipped, and the
/// trigger keeps the exact size it had before the tap.
struct SchoolityMenu<Value: Hashable, Trigger: View>: View {
    let title: String
    let options: [SchoolityMenuOption<Value>]
    @Binding var value: Value
    var isEnabled: Bool
    var trigger: (Bool) -> Trigger

    @State private var isOpen = false

    init(
        title: String,
        options: [SchoolityMenuOption<Value>],
        value: Binding<Value>,
        isEnabled: Bool = true,
        @ViewBuilder trigger: @escaping (Bool) -> Trigger
    ) {
        self.title = title
        self.options = options
        self._value = value
        self.isEnabled = isEnabled
        self.trigger = trigger
    }

    private var selected: SchoolityMenuOption<Value>? {
        options.first { $0.value == value }
    }

    var body: some View {
        Button {
            isOpen = true
        } label: {
            trigger(isOpen)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || options.isEmpty)
        .accessibilityLabel(title)
        .accessibilityValue(selected?.label ?? "None")
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            SchoolityMenuList(options: options, selected: value) { next in
                value = next
                isOpen = false
            }
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// The floating list itself. It keeps one fixed width, so a long reporting
/// period or school name wraps inside the panel instead of changing the page
/// layout behind it.
private struct SchoolityMenuList<Value: Hashable>: View {
    let options: [SchoolityMenuOption<Value>]
    let selected: Value
    let choose: (Value) -> Void

    private var height: CGFloat {
        min(CGFloat(options.count) * 44 + 12, 340)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(options) { option in
                    Button {
                        choose(option.value)
                    } label: {
                        HStack(spacing: 10) {
                            Text(option.label)
                                .font(.subheadline.weight(option.value == selected ? .semibold : .regular))
                                .foregroundStyle(SchoolityPalette.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            if option.value == selected {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(SchoolityPalette.ink)
                            }
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(
                            option.value == selected ? SchoolityPalette.field : Color.clear,
                            in: RoundedRectangle(cornerRadius: SchoolityRadius.chip, style: .continuous)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option.value == selected ? [.isSelected] : [])
                }
            }
            .padding(6)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 250, height: max(56, height))
    }
}

/// The menu's chevron turns to show the list is open. Under Reduce Motion it
/// swaps instantly instead of rotating.
struct SchoolityMenuChevron: View {
    var isOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(SchoolityPalette.muted)
            .rotationEffect(.degrees(isOpen ? 180 : 0))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isOpen)
            .accessibilityHidden(true)
    }
}

/// The website's outlined select used by the Course History filters. The label
/// and value share one fixed-height row, so choosing a longer year can never
/// change the row's height or push the cards around it.
struct SchoolitySelectField: View {
    let title: String
    let options: [SchoolityMenuOption<String>]
    @Binding var value: String

    private var selectedLabel: String {
        options.first { $0.value == value }?.label ?? title
    }

    var body: some View {
        SchoolityMenu(title: title, options: options, value: $value) { isOpen in
            HStack(spacing: 10) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(SchoolityPalette.muted)
                Spacer(minLength: 8)
                Text(selectedLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(SchoolityPalette.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                SchoolityMenuChevron(isOpen: isOpen)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(SchoolityPalette.field, in: RoundedRectangle(cornerRadius: SchoolityRadius.chip, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SchoolityRadius.chip, style: .continuous)
                    .strokeBorder(SchoolityPalette.line, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
    }
}

/// A section heading with the website's small count badge.
struct SectionHeading: View {
    let title: String
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(SchoolityText.sectionTitle)
                .tracking(-0.4)
                .foregroundStyle(SchoolityPalette.ink)
                .accessibilityAddTraits(.isHeader)
            if let count { CountBadge(count: count) }
            Spacer(minLength: 0)
        }
    }
}

struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(SchoolityPalette.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(SchoolityPalette.field, in: Capsule())
            .overlay { Capsule().strokeBorder(SchoolityPalette.line, lineWidth: 1) }
            .accessibilityLabel(count == 1 ? "1 item" : "\(count) items")
    }
}

/// The website's small outlined chip for a category, letter grade, or status.
struct SchoolityTag: View {
    let text: String
    var emphasis = false

    var body: some View {
        Text(text)
            .font(.caption.weight(emphasis ? .semibold : .medium))
            .foregroundStyle(emphasis ? SchoolityPalette.ink : SchoolityPalette.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(SchoolityPalette.field, in: Capsule())
            .overlay { Capsule().strokeBorder(SchoolityPalette.line, lineWidth: 1) }
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(SchoolityPalette.line)
            .frame(height: 1)
    }
}

/// The website's subject and record icon tile.
struct IconTile: View {
    enum Background: Equatable { case field, soft, ink }

    let symbol: String
    var size: CGFloat = 44
    var background: Background = .field

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(background == .ink ? SchoolityPalette.onInk : SchoolityPalette.ink)
            .frame(width: size, height: size)
            .background(fill, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }

    private var fill: Color {
        switch background {
        case .field: return SchoolityPalette.field
        case .soft: return SchoolityPalette.soft
        case .ink: return SchoolityPalette.ink
        }
    }
}

/// A quiet progress line that uses the reader's grade color.
struct SchoolityBar: View {
    let value: Double
    var tint: Color = SchoolityPalette.ink
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(SchoolityPalette.soft)
                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - States

/// The website's dashed empty card.
struct SchoolityEmptyState: View {
    let title: String
    let description: String
    var symbol: String = "books.vertical"

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(SchoolityPalette.muted)
                .accessibilityHidden(true)
            Text(title)
                .font(SchoolityText.sectionTitle)
                .foregroundStyle(SchoolityPalette.ink)
                .multilineTextAlignment(.center)
            Text(description)
                .font(SchoolityText.meta)
                .foregroundStyle(SchoolityPalette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background(SchoolityPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: SchoolityRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SchoolityRadius.card, style: .continuous)
                .strokeBorder(SchoolityPalette.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
    }
}

/// Loading placeholders reserve the card's space while a section loads.
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(SchoolityPalette.soft)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .accessibilityHidden(true)
    }
}

struct FailureRow: View {
    let message: String
    var dismiss: (() -> Void)? = nil
    var retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(SchoolityText.body)
                .foregroundStyle(SchoolityPalette.ink)
            HStack(spacing: 14) {
                Button("Try again", action: retry)
                    .buttonStyle(SchoolityPrimaryButtonStyle())
                if let dismiss {
                    Button("Dismiss", action: dismiss)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SchoolityPalette.muted)
                        .frame(minHeight: 44)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A failure as the website presents it: a panel card with a visible edge.
struct FailureCard: View {
    let message: String
    var dismiss: (() -> Void)? = nil
    var retry: () -> Void

    var body: some View {
        FailureRow(message: message, dismiss: dismiss, retry: retry)
            .schoolityCard(padding: 16)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(SchoolityPalette.ink)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                    .padding(.vertical, 1)
            }
    }
}

// MARK: - Shared rows

/// Section footer text for the time a section last loaded from the district.
struct LastUpdatedText: View {
    let date: Date?

    var body: some View {
        if let date {
            Text("Last updated \(date.formatted(date: .omitted, time: .shortened))")
        }
    }
}

/// A plain trailing freshness line for screens built as cards.
struct LastUpdatedFooter: View {
    let date: Date?

    var body: some View {
        if let date {
            HStack {
                Spacer(minLength: 0)
                Label("Last updated \(date.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(SchoolityPalette.faint)
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
        IconTile(symbol: symbol, size: 36, background: .field)
    }
}

struct InformationRow: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InformationIcon(symbol: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                Text(value)
                    .font(SchoolityText.body)
                    .foregroundStyle(SchoolityPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
