import SwiftUI
import UIKit

struct StoredColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    init(hex: UInt32) {
        red = Double((hex >> 16) & 255) / 255
        green = Double((hex >> 8) & 255) / 255
        blue = Double(hex & 255) / 255
    }

    @MainActor
    init(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &alpha)
        red = Double(r); green = Double(g); blue = Double(b)
    }

    var color: Color { Color(red: red, green: green, blue: blue) }
}

struct GradeColorRule: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var minimum: Double
    var color: StoredColor

    static let defaults: [GradeColorRule] = [
        .init(minimum: 90, color: .init(hex: 0x248545)),
        .init(minimum: 80, color: .init(hex: 0x2879C9)),
        .init(minimum: 70, color: .init(hex: 0xB77911)),
        .init(minimum: 60, color: .init(hex: 0xBD5A23)),
        .init(minimum: 0, color: .init(hex: 0xBE3844))
    ]
}

struct ClassAlias: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var symbol: String
}

struct CustomizationSettings: Codable, Equatable, Sendable {
    var accent: StoredColor?
    var gradeColorsEnabled = false
    var defaultGradeColor = StoredColor(hex: 0x737373)
    var gradeRules = GradeColorRule.defaults
    var aliases: [ClassAlias] = []
    var classLinks: [String: UUID] = [:]

    func alias(for title: String) -> ClassAlias? {
        guard let id = classLinks[title] else { return nil }
        return aliases.first { $0.id == id }
    }

    func gradeColor(for score: Double?) -> StoredColor? {
        guard gradeColorsEnabled else { return nil }
        guard let score, score.isFinite else { return defaultGradeColor }
        return gradeRules.filter { $0.minimum.isFinite && $0.minimum <= score }
            .max { $0.minimum < $1.minimum }?.color ?? defaultGradeColor
    }

    mutating func removeAlias(_ id: UUID) {
        aliases.removeAll { $0.id == id }
        classLinks = classLinks.filter { $0.value != id }
    }
}

@MainActor
final class CustomizationStore: ObservableObject {
    @Published private(set) var settings: CustomizationSettings
    private let defaults: UserDefaults
    private static let key = "schoolity.customization.v1"

    init(defaults: UserDefaults = .standard) {
        var storage = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"), defaults === UserDefaults.standard,
           let isolated = UserDefaults(suiteName: "com.schoolity.ui-testing.customization") {
            isolated.removePersistentDomain(forName: "com.schoolity.ui-testing.customization")
            storage = isolated
        }
        #endif
        self.defaults = storage
        settings = storage.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(CustomizationSettings.self, from: $0) } ?? CustomizationSettings()
    }

    var accentColor: Color { settings.accent?.color ?? Color("ActionAccent") }
    func gradeColor(_ score: Double?) -> Color { settings.gradeColor(for: score)?.color ?? accentColor }
    func name(for title: String) -> String { settings.alias(for: title)?.name ?? title }
    func symbol(for title: String) -> String { settings.alias(for: title)?.symbol ?? "studentdesk" }

    func update(_ change: (inout CustomizationSettings) -> Void) {
        var next = settings
        change(&next)
        guard next != settings else { return }
        guard let data = try? JSONEncoder().encode(next) else { return }
        defaults.set(data, forKey: Self.key)
        settings = next
    }

    func saveAlias(_ alias: ClassAlias) {
        update { settings in
            if let index = settings.aliases.firstIndex(where: { $0.id == alias.id }) { settings.aliases[index] = alias }
            else { settings.aliases.append(alias) }
        }
    }
}

struct NamedColor: Identifiable, Sendable {
    let name: String
    let hex: UInt32
    var id: String { name }
    var stored: StoredColor { StoredColor(hex: hex) }
    static let accents: [NamedColor] = [
        .init(name: "Red", hex: 0xC53742), .init(name: "Orange", hex: 0xBD5A23),
        .init(name: "Yellow", hex: 0xA77A0D), .init(name: "Green", hex: 0x248545),
        .init(name: "Mint", hex: 0x278679), .init(name: "Teal", hex: 0x08666E),
        .init(name: "Cyan", hex: 0x227EAC), .init(name: "Blue", hex: 0x2879C9),
        .init(name: "Indigo", hex: 0x5953BF), .init(name: "Purple", hex: 0x8C4BA8),
        .init(name: "Pink", hex: 0xB84179), .init(name: "Brown", hex: 0x836048)
    ]
}
