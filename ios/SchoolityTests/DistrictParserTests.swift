import XCTest
@testable import Schoolity

final class DistrictParserTests: XCTestCase {
    private func parse(_ operation: String, _ arguments: [String: Any]) throws -> Data {
        try DistrictParser.parseSynchronously(operation, arguments: JSONSerialization.data(withJSONObject: arguments))
    }

    func testBundledJavaScriptRunsInJavaScriptCoreAndDecodesGrades() throws {
        let data = try parse("normalize", ["resource": "grades", "payload": [
            "reportingPeriod": ["index": 0], "courses": [["courseID": "math", "courseName": "Math &amp; Science", "marks": []]]
        ]])
        let grades = try JSONDecoder().decode(Gradebook.self, from: data)
        XCTAssertEqual(grades.currentTerm, 0)
        XCTAssertEqual(grades.courses.first?.name, "Math & Science")
    }

    func testHTMLIsParsedWithoutExecutingDistrictScripts() throws {
        let data = try parse("history", ["html": "<script>throw new Error('must not run'); PXP.CourseHistory = [];</script>"])
        let normalized = try parse("normalize", ["resource": "history", "payload": JSONSerialization.jsonObject(with: data)])
        XCTAssertTrue(try JSONDecoder().decode(CourseHistoryPage.self, from: normalized).courses.isEmpty)
        XCTAssertThrowsError(try parse("history", ["html": "<input type='password'>"]))
    }

    func testDirectSessionMetadataIsOptionalForExistingKeychainEntries() throws {
        let old = try JSONDecoder().decode(SavedSession.self, from: Data(#"{"value":"old-server-cookie","expires":9999999999,"username":"sample","password":"synthetic"}"#.utf8))
        XCTAssertNil(old.district)
        XCTAssertTrue(old.canRenew)
        let direct = SavedSession(value: "district-token", expires: .distantFuture, username: "sample", password: "synthetic", district: true, webCookie: "ASP.NET_SessionId=fixture")
        let active = direct.withoutCredentials
        XCTAssertNil(active.username)
        XCTAssertNil(active.password)
        XCTAssertEqual(active.district, true)
        XCTAssertEqual(active.webCookie, direct.webCookie)
    }

    func testDownloadDecoderRejectsEntityExpansionAndInvalidBase64() throws {
        XCTAssertThrowsError(try parse("download", ["mail": true, "response": ["data": ["attachmentXML": "<!ENTITY x SYSTEM 'file:///private'>"]]]))
        let encoded = try parse("download", ["mail": false, "response": ["data": ["studentAttachedDocumentData": ["documentDatas": [["base64Code": "aGVsbG8="]]]]]])
        XCTAssertEqual(try JSONDecoder().decode(String.self, from: encoded), "aGVsbG8=")
    }
}
