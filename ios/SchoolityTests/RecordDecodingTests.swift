import XCTest
@testable import Schoolity

final class RecordDecodingTests: XCTestCase {
    func testTermAwareScheduleDecodes() throws {
        let json = #"{"terms":[{"id":1,"name":"Quarter 1","beginDate":"08/25/2026","endDate":"10/30/2026","classes":[{"id":"math","title":"Algebra II","teacher":"Sample Teacher","room":"102","period":"1","meetingDays":"M,T,W,Th,F"}]}],"currentTerm":1}"#
        let schedule = try JSONDecoder().decode(ScheduleData.self, from: Data(json.utf8))
        XCTAssertEqual(schedule.currentTerm, 1)
        XCTAssertEqual(schedule.terms.first?.classes.first?.title, "Algebra II")
        XCTAssertEqual(schedule.terms.first?.classes.first?.meetingDays, "M,T,W,Th,F")
    }

    func testStudentInformationDecodesFieldsGroupsAndTables() throws {
        let json = #"{"kind":"student","sections":[{"title":"Student","fields":[{"label":"Name","value":"Sample Student"}],"groups":[{"title":"Emergency contact","fields":[{"label":"Name","value":"Sample Contact"}]}],"table":{"columns":["Label","Value"],"rows":[["Homeroom","101"]]},"note":"Sample note"}],"notice":"Partial data"}"#
        let page = try JSONDecoder().decode(StudentInfoPage.self, from: Data(json.utf8))
        XCTAssertEqual(page.sections.first?.fields.first?.value, "Sample Student")
        XCTAssertEqual(page.sections.first?.groups?.first?.fields.first?.label, "Name")
        XCTAssertEqual(page.sections.first?.table?.rows.first?.last, "101")
        XCTAssertEqual(page.notice, "Partial data")
    }

    func testCourseHistoryDecodesRequirementsAndCredits() throws {
        let json = #"{"kind":"history","courses":[{"id":"1-0-0","title":"Algebra I","code":"MATH101","school":"Sample School","year":"2025","term":"Semester 1","grade":"10","mark":"A","attempted":1,"completed":1}],"requirements":[{"id":"math","subject":"Mathematics","required":3,"completed":2,"inProgress":0.5,"remaining":0.5}],"classOf":"2027"}"#
        let page = try JSONDecoder().decode(CourseHistoryPage.self, from: Data(json.utf8))
        XCTAssertEqual(page.courses.first?.mark, "A")
        XCTAssertEqual(page.requirements.first?.inProgress, 0.5)
        XCTAssertEqual(page.classOf, "2027")
    }

    func testAttendanceDecodesTotalsAndPeriodDetails() throws {
        let json = #"{"kind":"attendance","days":[{"date":"10/01/2026","reason":"Excused","note":"","periods":[{"period":"1","status":"Excused","reason":"Appointment","course":"Algebra II","teacher":"Sample Teacher"}]}],"totals":[{"label":"Excused periods","value":1}]}"#
        let page = try JSONDecoder().decode(AttendancePage.self, from: Data(json.utf8))
        XCTAssertEqual(page.days.first?.periods.first?.course, "Algebra II")
        XCTAssertEqual(page.totals.first?.value, 1)
    }

    func testSubjectDetailsDecodesCompletedAndInProgressRows() throws {
        let json = #"{"columns":["Course","Mark"],"completed":[["Algebra I","A"]],"inProgress":[["Geometry",""]]}"#
        let details = try JSONDecoder().decode(SubjectDetails.self, from: Data(json.utf8))
        XCTAssertEqual(details.completed.first?.first, "Algebra I")
        XCTAssertEqual(details.inProgress.count, 1)
    }
}
