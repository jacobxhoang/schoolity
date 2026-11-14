import XCTest
import Vision

final class SchoolityUITests: XCTestCase {
    private func capture(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func backToRecords(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons["Records"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.staticTexts["Student Info"].waitForExistence(timeout: 5))
    }

    func testLoginHasNoAnonymousEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-login"]
        app.launch()
        XCTAssertTrue(app.textFields["login.username"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["login.submit"].isEnabled)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        capture("login")
    }

    func testLoginFieldsRemainUsableWithKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-login"]
        app.launch()
        let username = app.textFields["login.username"]
        XCTAssertTrue(username.waitForExistence(timeout: 10))
        username.tap()
        username.typeText("sample")
        let password = app.secureTextFields["login.password"]
        password.tap()
        password.typeText("synthetic-only")
        XCTAssertTrue(app.buttons["login.submit"].isEnabled)
        capture("login-keyboard")
    }

    func testGradebookWhatIfAndCollapsedInbox() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Grades"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Grades"].tap()
        let course = app.descendants(matching: .any)["course-sample-math"]
        XCTAssertTrue(course.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Unweighted average of current course grades."].exists)
        XCTAssertFalse(app.tabBars.buttons["Home"].exists)
        XCTAssertEqual(app.tabBars.buttons.count, 5)
        capture("gradebook")
        course.tap()
        XCTAssertTrue(app.staticTexts["Grade history"].waitForExistence(timeout: 5))
        capture("course")
        app.buttons["Add hypothetical score"].tap()
        XCTAssertTrue(app.textFields["Assignment title"].waitForExistence(timeout: 5))
        app.textFields["Assignment title"].tap()
        app.textFields["Assignment title"].typeText("Future quiz")
        app.textFields["Points earned"].tap()
        app.textFields["Points earned"].typeText("9")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Hypothetical estimate"].waitForExistence(timeout: 5))
        app.buttons["Find a target score"].tap()
        XCTAssertTrue(app.navigationBars["Target score"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Add hypothetical score"].waitForExistence(timeout: 5))
        app.buttons["Add hypothetical score"].tap()
        XCTAssertTrue(app.textFields["Assignment title"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Hypothetical estimate"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Inbox"].tap()
        XCTAssertTrue(app.staticTexts["Next week’s review"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sample Teacher"].exists)
        XCTAssertFalse(app.staticTexts["Bring your practice problems on Monday. We’ll review chapters 4 & 5 together."].exists)
        capture("inbox-collapsed")
        app.staticTexts["Next week’s review"].tap()
        XCTAssertTrue(app.staticTexts["Bring your practice problems on Monday. We’ll review chapters 4 & 5 together."].waitForExistence(timeout: 5))
        capture("inbox-expanded")
    }

    func testAccessibilityGradebookAndCourse() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Grades"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Grades"].tap()
        let course = app.descendants(matching: .any)["course-sample-math"]
        capture("accessible-gradebook")
        for _ in 0..<4 where !course.exists {
            app.swipeUp()
        }
        XCTAssertTrue(course.waitForExistence(timeout: 5))
        capture("accessible-gradebook-row")
        if !course.isHittable { app.swipeUp() }
        course.tap()
        XCTAssertTrue(app.staticTexts["District grade"].waitForExistence(timeout: 5))
        capture("accessible-course")
    }

    func testScheduleDocumentsAndAccount() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Schedule"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["schedule-period-sample-math"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["M,T,W,Th,F"].exists)
        capture("schedule")
        app.tabBars.buttons["Documents"].tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Sample report").firstMatch.waitForExistence(timeout: 5))
        capture("documents")
        app.buttons["Account"].tap()
        XCTAssertTrue(app.staticTexts["Sample Student"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["studentID.number"].isHittable)
        capture("account")
        if !app.buttons["Sign out"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["Sign out"].isHittable)
    }

    func testRecordsExposeStudentInformation() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Records"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Records"].tap()
        XCTAssertTrue(app.staticTexts["Student Info"].waitForExistence(timeout: 5))
        app.staticTexts["Student Info"].tap()
        XCTAssertTrue(app.staticTexts["Sample Student"].waitForExistence(timeout: 5))
        capture("student-info")
    }

    func testScheduleAndRecordsScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Schedule"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["schedule-period-sample-math"].waitForExistence(timeout: 5))
        capture("parity-schedule")

        app.tabBars.buttons["Records"].tap()
        XCTAssertTrue(app.staticTexts["Student Info"].waitForExistence(timeout: 5))
        capture("parity-records")

        app.staticTexts["Student Info"].tap()
        XCTAssertTrue(app.staticTexts["Sample Student"].waitForExistence(timeout: 5))
        capture("parity-student-info")
        backToRecords(app)

        app.staticTexts["Attendance"].tap()
        XCTAssertTrue(app.staticTexts["Excused periods"].waitForExistence(timeout: 5))
        capture("parity-attendance")
        backToRecords(app)

        app.staticTexts["Course History"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["graduation-legend"].waitForExistence(timeout: 5))
        capture("parity-course-history")

        let courseRecords = app.descendants(matching: .any)["history-course-records"]
        for _ in 0..<6 where !courseRecords.isHittable { app.swipeUp() }
        XCTAssertTrue(courseRecords.waitForExistence(timeout: 5))
        XCTAssertTrue(courseRecords.isHittable)
        courseRecords.tap()
        let courseRow = app.staticTexts["Algebra I"]
        for _ in 0..<6 where !courseRow.isHittable { app.swipeUp() }
        XCTAssertTrue(courseRow.waitForExistence(timeout: 5))
        capture("parity-course-records")
    }

    func testSavedSignInCanUnlock() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-locked", "--ui-unlock-success"]
        app.launch()
        XCTAssertTrue(app.buttons["login.unlock"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertEqual(app.buttons["login.unlock"].label, "Sign in")
        capture("saved-sign-in")
        app.buttons["login.unlock"].tap()
        XCTAssertTrue(app.tabBars.buttons["Grades"].waitForExistence(timeout: 5))
    }

    func testSavedSignInOpensGradesAutomatically() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-locked", "--ui-unlock-success", "--ui-auto-unlock"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Algebra II"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["login.unlock"].exists)
        XCTAssertEqual(app.tabBars.buttons.count, 5)
        capture("automatic-sign-in")
    }

    func testCancelledUnlockKeepsRetryAndPasswordAvailable() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-locked"]
        app.launch()
        XCTAssertTrue(app.buttons["login.unlock"].waitForExistence(timeout: 10))
        app.buttons["login.unlock"].tap()
        XCTAssertTrue(app.staticTexts["Unlock cancelled. You can try again."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["login.unlock"].isEnabled)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        capture("saved-sign-in-cancelled")
        app.buttons["login.usePassword"].tap()
        XCTAssertTrue(app.textFields["login.username"].waitForExistence(timeout: 5))
    }

    func testStudentIDShowsBarcodeAndDistrictNumber() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Account"].waitForExistence(timeout: 10))
        app.buttons["Account"].tap()
        XCTAssertTrue(app.staticTexts["Sample Student"].waitForExistence(timeout: 5))
        for _ in 0..<3 where !app.staticTexts["studentID.number"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["studentID.number"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["studentID.number"].label, "Student ID, 00012345")
        if !app.staticTexts["studentID.number"].isHittable { app.swipeUp() }
        let image = try XCTUnwrap(XCUIScreen.main.screenshot().image.cgImage)
        let request = VNDetectBarcodesRequest()
        request.revision = VNDetectBarcodesRequestRevision1
        request.usesCPUOnly = true
        request.symbologies = [.code128]
        try VNImageRequestHandler(cgImage: image).perform([request])
        XCTAssertTrue(request.results?.contains(where: { $0.payloadStringValue == "00012345" }) == true)
        capture("student-id")
    }

    func testMissingStudentIDDoesNotCreateAFakeCard() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-no-student-id"]
        app.launch()
        XCTAssertTrue(app.buttons["Account"].waitForExistence(timeout: 10))
        app.buttons["Account"].tap()
        XCTAssertTrue(app.staticTexts["Student ID unavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["studentID.number"].exists)
        capture("student-id-unavailable")
    }
}
