import XCTest
@testable import Schoolity

final class GradeNotificationTests: XCTestCase {
    private func book(_ scores: [Double?], term: Int = 0) -> Gradebook {
        Gradebook(courses: [Course(id: "math", name: "Math", teacher: "", room: "", period: "", official: nil, categories: [],
            assignments: scores.enumerated().map {
                Assignment(id: "assignment-\($0.offset)", title: "Work \($0.offset)", category: "Work", earned: $0.element, possible: 10, due: "")
            })], terms: [], currentTerm: term)
    }

    func testInitialSnapshotIsSilentAndZeroIsANewGrade() {
        var state = GradingSnapshot()
        XCTAssertTrue(state.observe(book([8, nil]), account: "first").isEmpty)
        let notifications = state.observe(book([8, 0]), account: "first")
        XCTAssertEqual(notifications.count, 1)
        XCTAssertEqual(notifications.first?.earned, 0)
        XCTAssertTrue(state.observe(book([8, 0]), account: "first").isEmpty)
    }

    func testNewAlreadyGradedAssignmentsNotifyButRegradesDoNotRepeat() {
        var state = GradingSnapshot()
        _ = state.observe(book([8]), account: "first")
        XCTAssertEqual(state.observe(book([9, 7]), account: "first").count, 1)
        XCTAssertTrue(state.observe(book([9, nil]), account: "first").isEmpty)
        XCTAssertTrue(state.observe(book([9, 7]), account: "first").isEmpty)
        XCTAssertTrue(state.observe(book([9]), account: "first").isEmpty)
        XCTAssertTrue(state.observe(book([9, 7]), account: "first").isEmpty)
    }

    func testAccountsAndReportingPeriodsHaveSeparateBaselines() {
        var state = GradingSnapshot()
        _ = state.observe(book([nil]), account: "first")
        XCTAssertTrue(state.observe(book([9]), account: "second").isEmpty)
        XCTAssertTrue(state.observe(book([9], term: 1), account: "first").isEmpty)
        XCTAssertEqual(state.observe(book([9]), account: "first").count, 1)
    }

    func testHypotheticalAndExcludedScoresNeverNotify() {
        var state = GradingSnapshot()
        _ = state.observe(book([nil, nil]), account: "first")
        var next = book([10, 9])
        next.courses[0].assignments[0].hypothetical = true
        next.courses[0].assignments[1].excluded = true
        XCTAssertTrue(state.observe(next, account: "first").isEmpty)
    }

    func testPersistenceContainsNoDisplayDetailsAndDoesNotRepeatAfterRelaunch() throws {
        var state = GradingSnapshot()
        _ = state.observe(book([9]), account: "first")
        let data = try JSONEncoder().encode(state)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("Math"))
        XCTAssertFalse(text.contains("assignment-0"))
        XCTAssertFalse(text.contains("first"))
        var restored = try JSONDecoder().decode(GradingSnapshot.self, from: data)
        XCTAssertTrue(restored.observe(book([9]), account: "first").isEmpty)
    }
}
