import XCTest
@testable import Schoolity

final class CustomizationTests: XCTestCase {
    func testGradeRulesUseHighestMatchingThresholdAndFallback() {
        var settings = CustomizationSettings()
        XCTAssertNil(settings.gradeColor(for: 95))
        settings.gradeColorsEnabled = true
        let low = StoredColor(hex: 0x123456)
        let high = StoredColor(hex: 0xABCDEF)
        settings.gradeRules = [.init(minimum: 90, color: high), .init(minimum: 60, color: low)]
        XCTAssertEqual(settings.gradeColor(for: 90), high)
        XCTAssertEqual(settings.gradeColor(for: 120), high)
        XCTAssertEqual(settings.gradeColor(for: 89.9), low)
        XCTAssertEqual(settings.gradeColor(for: 60), low)
        XCTAssertEqual(settings.gradeColor(for: 59), settings.defaultGradeColor)
        XCTAssertEqual(settings.gradeColor(for: nil), settings.defaultGradeColor)
        XCTAssertEqual(settings.gradeColor(for: .nan), settings.defaultGradeColor)
    }

    func testDeletingAnAliasRemovesAllItsClassLinksOnly() {
        var settings = CustomizationSettings()
        let math = ClassAlias(name: "Math", symbol: "function")
        let art = ClassAlias(name: "Art", symbol: "paintpalette.fill")
        settings.aliases = [math, art]
        settings.classLinks = ["Algebra II": math.id, "Geometry": math.id, "Studio": art.id]
        XCTAssertEqual(settings.alias(for: "Algebra II"), math)
        XCTAssertNil(settings.alias(for: "Unknown"))
        settings.removeAlias(math.id)
        XCTAssertNil(settings.alias(for: "Algebra II"))
        XCTAssertNil(settings.classLinks["Geometry"])
        XCTAssertEqual(settings.alias(for: "Studio"), art)
    }

    @MainActor
    func testPreferencesPersistAndAliasEditsUpdateEveryLinkedClass() throws {
        let suite = "schoolity-customization-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CustomizationStore(defaults: defaults)
        var alias = ClassAlias(name: "Math", symbol: "function")
        store.saveAlias(alias)
        store.update {
            $0.accent = StoredColor(hex: 0x123456)
            $0.gradeColorsEnabled = true
            $0.classLinks["Algebra II"] = alias.id
            $0.classLinks["Geometry"] = alias.id
        }
        alias.name = "Mathematics"
        alias.symbol = "number"
        store.saveAlias(alias)
        let restored = CustomizationStore(defaults: defaults)
        XCTAssertEqual(restored.settings, store.settings)
        XCTAssertEqual(restored.name(for: "Algebra II"), "Mathematics")
        XCTAssertEqual(restored.symbol(for: "Geometry"), "number")
        XCTAssertEqual(restored.name(for: "Unknown"), "Unknown")
        XCTAssertEqual(restored.symbol(for: "Unknown"), "studentdesk")
        XCTAssertEqual(restored.settings.aliases.count, 1)
    }

    @MainActor
    func testInvalidStoredPreferencesFallBackToDefaults() throws {
        let suite = "schoolity-customization-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not-json".utf8), forKey: "schoolity.customization.v1")
        XCTAssertEqual(CustomizationStore(defaults: defaults).settings, CustomizationSettings())
    }
}
