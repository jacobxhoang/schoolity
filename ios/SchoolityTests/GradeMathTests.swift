import XCTest
@testable import Schoolity

final class GradeMathTests: XCTestCase {
    private func course(categories: [GradeCategory] = []) -> Course {
        Course(id: "test", name: "Test", teacher: "", room: "", period: "", official: nil,
               categories: categories, assignments: [
                Assignment(id: "practice", title: "Practice", category: "Practice", earned: 20, possible: 20, due: "10/1/2026"),
                Assignment(id: "exam", title: "Exam", category: "Tests", earned: 40, possible: 50, due: "10/9/2026")
               ])
    }

    func testPointsAndWeightedGrades() throws {
        XCTAssertEqual(try XCTUnwrap(GradeMath.calculate(course())), 60 / 70 * 100.0, accuracy: 0.0001)
        let weighted = course(categories: [GradeCategory(name: "Practice", weight: 30), GradeCategory(name: "Tests", weight: 70)])
        XCTAssertEqual(try XCTUnwrap(GradeMath.calculate(weighted)), 86, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(GradeMath.target(weighted, category: "Tests", possible: 50, goal: 93)), 50, accuracy: 0.0001)
    }

    func testExcludedAndUngradedScoresDoNotCountButZeroDoes() throws {
        var value = course()
        value.assignments[0].earned = nil
        value.assignments[1].excluded = true
        XCTAssertNil(GradeMath.calculate(value))
        value.assignments[0].earned = 0
        XCTAssertEqual(try XCTUnwrap(GradeMath.calculate(value)), 0)
    }

    func testExtraCreditAndInvalidTarget() throws {
        var value = course()
        value.assignments = [Assignment(id: "one", title: "Score", category: "Tests", earned: 10, possible: 10, due: ""),
                             Assignment(id: "bonus", title: "Bonus", category: "Tests", earned: 1, possible: 0, due: "")]
        XCTAssertEqual(try XCTUnwrap(GradeMath.calculate(value)), 110, accuracy: 0.0001)
        XCTAssertNil(GradeMath.target(value, category: "Tests", possible: 0, goal: 90))
        XCTAssertNil(GradeMath.target(value, category: "Tests", possible: 50, goal: .infinity))
    }

    func testEmptyWeightedCategoriesRedistribute() throws {
        var value = course(categories: [GradeCategory(name: "Practice", weight: 30), GradeCategory(name: "Tests", weight: 70)])
        value.assignments.removeLast()
        XCTAssertEqual(try XCTUnwrap(GradeMath.calculate(value)), 100)
    }

    func testTrendOrdersUSDatesAndNeverClampsExtraCredit() throws {
        var value = course()
        value.assignments = [Assignment(id: "late", title: "Late", category: "", earned: 12, possible: 10, due: "10/9/2026"),
                             Assignment(id: "early", title: "Early", category: "", earned: 10, possible: 10, due: "9/30/2026")]
        XCTAssertEqual(GradeMath.trend(value).map(\.score), [100, 110])
    }

    func testNormalizedPayloadDecodesEntitiesAsPlainText() throws {
        let data = Data(#"{"courses":[{"id":"math","name":"Math & science","teacher":"Teacher","room":"102","period":"1","official":null,"categories":[],"assignments":[{"id":"test","title":"Chapter 4&5","category":"Tests","earned":0,"possible":40,"due":"10/9/2026","excluded":false}]}],"terms":[{"id":1,"name":"Quarter 1"}],"currentTerm":1}"#.utf8)
        let book = try JSONDecoder().decode(Gradebook.self, from: data)
        XCTAssertEqual(book.courses[0].assignments[0].title, "Chapter 4&5")
        XCTAssertEqual(book.courses[0].assignments[0].earned, 0)
        XCTAssertNil(book.courses[0].official)
    }

    func testSessionExpiryAndFilenameSafety() {
        XCTAssertFalse(SavedSession(value: "opaque-test-token", expires: .distantPast).isValid)
        XCTAssertFalse(SavedSession(value: "", expires: .distantFuture).isValid)
        XCTAssertTrue(SavedSession(value: "opaque-test-token", expires: .distantFuture).isValid)
        XCTAssertEqual(PortalClient.safeFilename("../../Report.pdf"), "Document.._.._Report.pdf")
        XCTAssertEqual(PortalClient.safeFilename(""), "Document")
        XCTAssertEqual(PortalClient.safeFilename("Report.pdf"), "Report.pdf")
    }

    func testPersistentServerCookieCanBeRestoredWithoutPassword() throws {
        let cookie = try XCTUnwrap(HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": "schoolity_session=opaque-test-token; Max-Age=1800; Path=/; HttpOnly; Secure; SameSite=Lax"], for: URL(string: "https://schoolity-jet.vercel.app")!).first)
        XCTAssertEqual(cookie.name, "schoolity_session")
        XCTAssertGreaterThan(try XCTUnwrap(cookie.expiresDate), Date())
    }

    func testScoreEditingNeverIntroducesThousandsSeparators() {
        XCTAssertEqual(GradeMath.input(1200.5), "1200.5")
        XCTAssertEqual(GradeMath.input(0), "0")
    }
}
