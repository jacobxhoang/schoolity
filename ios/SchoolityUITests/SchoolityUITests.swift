import XCTest
import Vision

final class SchoolityUITests: XCTestCase {
    private func capture(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
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

    func testGradebookWhatIfAndCollapsedInbox() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Grades"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Grades"].tap()
        XCTAssertTrue(app.staticTexts["Algebra II"].waitForExistence(timeout: 5))
        capture("gradebook")
        app.staticTexts["Algebra II"].tap()
        XCTAssertTrue(app.staticTexts["Grade history"].waitForExistence(timeout: 5))
        capture("course")
        app.buttons["Add what-if score"].tap()
        XCTAssertTrue(app.textFields["Assignment title"].waitForExistence(timeout: 5))
        app.textFields["Assignment title"].tap()
        app.textFields["Assignment title"].typeText("Future quiz")
        app.textFields["Points earned"].tap()
        app.textFields["Points earned"].typeText("9")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["What-if estimate"].waitForExistence(timeout: 5))
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
        let course = app.staticTexts["Algebra II"]
        XCTAssertTrue(course.waitForExistence(timeout: 5))
        capture("accessible-gradebook")
        app.swipeUp()
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
        XCTAssertTrue(app.staticTexts["Period 1"].waitForExistence(timeout: 5))
        capture("schedule")
        app.tabBars.buttons["Documents"].tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Sample report").firstMatch.waitForExistence(timeout: 5))
        capture("documents")
        app.buttons["Account"].tap()
        XCTAssertTrue(app.staticTexts["Sample Student"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign out"].exists)
        capture("account")
    }

    func testSavedSignInCanUnlock() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-locked", "--ui-unlock-success"]
        app.launch()
        XCTAssertTrue(app.buttons["login.unlock"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        capture("saved-sign-in")
        app.buttons["login.unlock"].tap()
        XCTAssertTrue(app.tabBars.buttons["Grades"].waitForExistence(timeout: 5))
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
        let link = app.buttons["account.studentID"]
        if !link.isHittable { app.swipeUp() }
        link.tap()
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
        let link = app.buttons["account.studentID"]
        if !link.isHittable { app.swipeUp() }
        link.tap()
        XCTAssertTrue(app.staticTexts["Student ID unavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["studentID.number"].exists)
        capture("student-id-unavailable")
    }
}
