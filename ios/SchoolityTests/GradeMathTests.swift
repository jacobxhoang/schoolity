import XCTest
@testable import Schoolity

final class GradeMathTests: XCTestCase {
    func testIncrementalTrendMatchesPrefixCalculation() throws {
        for categories in [[], [GradeCategory(name: "Practice", weight: 30), GradeCategory(name: "Tests", weight: 70)]] {
            var value = course(categories: categories)
            value.assignments += [
                Assignment(id: "bonus", title: "Bonus", category: "Tests", earned: 2, possible: 0, due: "10/10/2026"),
                Assignment(id: "zero", title: "Zero", category: "Practice", earned: 0, possible: 10, due: "10/11/2026"),
                Assignment(id: "invalid", title: "Invalid", category: "Tests", earned: 4, possible: -1, due: "10/12/2026"),
                Assignment(id: "unknown", title: "Unknown", category: "Other", earned: 3, possible: 5, due: "10/13/2026")
            ]
            let actual = GradeMath.trend(value)
            var prefix = value
            prefix.assignments = []
            var expected: [Double] = []
            for assignment in value.assignments {
                prefix.assignments.append(assignment)
                if let score = GradeMath.calculate(prefix) { expected.append(score) }
            }
            XCTAssertEqual(actual.count, expected.count)
            for (point, score) in zip(actual, expected) {
                XCTAssertEqual(point.score, score, accuracy: 0.000001)
            }
        }
    }

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
    }

    func testExcludedAndUngradedScoresDoNotCountButZeroDoes() throws {
        var value = course()
        value.assignments[0].earned = nil
        value.assignments[1].excluded = true
        XCTAssertNil(GradeMath.calculate(value))
        value.assignments[0].earned = 0
        XCTAssertEqual(try XCTUnwrap(GradeMath.calculate(value)), 0)
    }

    func testExtraCredit() throws {
        var value = course()
        value.assignments = [Assignment(id: "one", title: "Score", category: "Tests", earned: 10, possible: 10, due: ""),
                             Assignment(id: "bonus", title: "Bonus", category: "Tests", earned: 1, possible: 0, due: "")]
        XCTAssertEqual(try XCTUnwrap(GradeMath.calculate(value)), 110, accuracy: 0.0001)
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
        let points = GradeMath.trend(value)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(try XCTUnwrap(points.first).score, 100, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(points.last).score, 110, accuracy: 0.0001)
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

    func testRejectedCredentialsAndExpiredSessionsHaveDifferentRecovery() {
        let login = PortalFailure.response(status: 401, signingIn: true, message: nil)
        XCTAssertTrue(login.localizedDescription.contains("username and password"))
        let expired = PortalFailure.response(status: 401, signingIn: false, message: nil)
        if case .signedOut = expired {} else { XCTFail("An expired school-data session must return to sign-in") }
        let retry = PortalFailure.response(status: 502, signingIn: false, message: "Try again shortly.")
        XCTAssertEqual(retry.localizedDescription, "Try again shortly.")
    }
}
