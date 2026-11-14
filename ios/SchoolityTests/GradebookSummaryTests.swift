import XCTest
@testable import Schoolity

final class GradebookSummaryTests: XCTestCase {
    func testCourseAverageUsesCalculatedEstimatesAndIgnoresDistrictGrades() throws {
        let book = Gradebook(courses: [
            course(id: "a", official: 99, assignments: [assignment(id: "one", earned: 8, possible: 10)]),
            course(id: "b", official: nil, assignments: [assignment(id: "two", earned: 10, possible: 10)])
        ], terms: [], currentTerm: 1)
        XCTAssertEqual(try XCTUnwrap(book.calculatedAverage), 90, accuracy: 0.0001)
        XCTAssertNil(Gradebook(courses: [], terms: [], currentTerm: 1).calculatedAverage)
        XCTAssertNil(Gradebook(courses: [
            course(id: "c", official: 88, assignments: [assignment(id: "three", earned: nil, possible: 10)])
        ], terms: [], currentTerm: 1).calculatedAverage)
    }

    func testRecentAssignmentsSortByDueDateAcrossCoursesAndKeepTiesStable() {
        let first = course(id: "first", official: nil, assignments: [
            Assignment(id: "old", title: "Old", category: "", earned: 1, possible: 2, due: "9/1/2026"),
            Assignment(id: "new", title: "New", category: "", earned: 1, possible: 2, due: "10/20/2026")
        ])
        let second = course(id: "second", official: nil, assignments: [
            Assignment(id: "tie", title: "Tie", category: "", earned: nil, possible: 5, due: "10/20/2026"),
            Assignment(id: "none", title: "No date", category: "", earned: nil, possible: 5, due: "")
        ])
        let recent = Gradebook(courses: [first, second], terms: [], currentTerm: 1).recentAssignments
        XCTAssertEqual(recent.map(\.assignment.id), ["new", "tie", "old", "none"])
        XCTAssertEqual(recent.first?.course.id, "first")
        XCTAssertEqual(recent.last?.course.id, "second")
    }

    func testRecentAssignmentsStopAtEight() {
        let assignments = (0..<10).map { index in
            Assignment(id: "\(index)", title: "Assignment \(index)", category: "",
                       earned: 1, possible: 2, due: "9/\(index + 1)/2026")
        }
        let book = Gradebook(courses: [course(id: "many", official: nil, assignments: assignments)],
                             terms: [], currentTerm: 1)
        XCTAssertEqual(book.recentAssignments.count, 8)
        XCTAssertEqual(book.recentAssignments.first?.assignment.id, "9")
    }

    func testAppearanceDefaultsToSystemAndOlderSettingsStillDecode() throws {
        var settings = CustomizationSettings()
        XCTAssertNil(settings.appearance)
        settings.appearance = .dark
        let encoded = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(CustomizationSettings.self, from: encoded).appearance, .dark)

        let legacy = Data(#"{"gradeColorsEnabled":false,"defaultGradeColor":{"red":0.45,"green":0.45,"blue":0.45},"gradeRules":[],"aliases":[],"classLinks":{}}"#.utf8)
        let restored = try JSONDecoder().decode(CustomizationSettings.self, from: legacy)
        XCTAssertNil(restored.appearance)
    }

    @MainActor
    func testAppearancePreferenceMapsToAColorScheme() throws {
        let suite = "schoolity-appearance-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CustomizationStore(defaults: defaults)
        XCTAssertNil(store.colorScheme)
        store.update { $0.appearance = .light }
        XCTAssertEqual(store.colorScheme, .light)
        store.update { $0.appearance = .dark }
        XCTAssertEqual(store.colorScheme, .dark)
        store.update { $0.appearance = .system }
        XCTAssertNil(store.colorScheme)
        XCTAssertEqual(CustomizationStore(defaults: defaults).colorScheme, nil)
    }

    private func course(id: String, official: Double?, assignments: [Assignment]) -> Course {
        Course(id: id, name: "Course \(id)", teacher: "", room: "", period: "",
               official: official, categories: [], assignments: assignments)
    }

    private func assignment(id: String, earned: Double?, possible: Double) -> Assignment {
        Assignment(id: id, title: "Assignment \(id)", category: "", earned: earned, possible: possible, due: "")
    }
}
