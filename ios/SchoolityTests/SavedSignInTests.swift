import XCTest
import LocalAuthentication
@testable import Schoolity

final class SavedSignInTests: XCTestCase {
    @MainActor
    func testCategoryClassesPreloadOnceAndRefreshInvalidatesTheirCache() async throws {
        let portal = TestPortal()
        portal.historyJSON = #"{"kind":"history","courses":[],"requirements":[{"id":"math","subject":"Math"},{"id":"science","subject":"Science"}],"classOf":"2027"}"#
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        await store.preloadWorkspace()
        XCTAssertNotNil(store.cachedHistorySubject(id: "math"))
        XCTAssertNotNil(store.cachedHistorySubject(id: "science"))
        _ = try await store.historySubject(id: "math")
        XCTAssertEqual(portal.subjectReadCounts, ["math": 1, "science": 1])
        await store.loadRecord(.history, refresh: true)
        await store.preloadWorkspace()
        XCTAssertEqual(portal.subjectReadCounts, ["math": 2, "science": 2])
        await store.signOut()
        XCTAssertNil(store.cachedHistorySubject(id: "math"))
        XCTAssertNil(store.cachedHistorySubject(id: "science"))
    }

    @MainActor
    func testSubjectFailureDoesNotBlockOtherPreloadsAndCanRetry() async throws {
        let portal = TestPortal()
        portal.historyJSON = #"{"kind":"history","courses":[],"requirements":[{"id":"math","subject":"Math"},{"id":"science","subject":"Science"}],"classOf":"2027"}"#
        portal.subjectErrors["math"] = PortalFailure.message("Temporary failure")
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        await store.loadRecord(.history)
        _ = try await store.historySubject(id: "science")
        XCTAssertNil(store.cachedHistorySubject(id: "math"))
        XCTAssertNotNil(store.cachedHistorySubject(id: "science"))
        XCTAssertEqual(store.access, .signedIn)
        portal.subjectErrors["math"] = nil
        _ = try await store.historySubject(id: "math")
        XCTAssertNotNil(store.cachedHistorySubject(id: "math"))
        XCTAssertEqual(portal.subjectReadCounts["math"], 2)
    }

    @MainActor
    func testConcurrentSubjectRequestsShareWorkAndSignOutRejectsLateResults() async {
        let portal = TestPortal()
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        let pending = expectation(description: "Category request started")
        portal.delayedSubjects = ["math"]
        portal.onSubject = { _ in pending.fulfill() }
        let first = Task { try await store.historySubject(id: "math") }
        await fulfillment(of: [pending], timeout: 3)
        let second = Task { try await store.historySubject(id: "math") }
        await Task.yield()
        await store.signOut()
        portal.subjectContinuations["math"]?.resume(returning: SubjectDetails(columns: ["Course"], completed: [["Sample"]], inProgress: []))
        for task in [first, second] {
            do { _ = try await task.value; XCTFail("A signed-out request returned student data") }
            catch { XCTAssertTrue(error is CancellationError || error is PortalFailure) }
        }
        XCTAssertEqual(portal.subjectReadCounts["math"], 1)
        XCTAssertNil(store.cachedHistorySubject(id: "math"))
        XCTAssertEqual(store.access, .signedOut)
    }

    @MainActor
    func testPreloadDoesNotFetchBeforeSignInOrAfterSignOut() async {
        let portal = TestPortal()
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.preloadWorkspace()
        XCTAssertTrue(portal.readCounts.isEmpty)
        await store.start()
        await store.signOut()
        let reads = portal.readCounts
        await store.preloadWorkspace()
        XCTAssertEqual(portal.readCounts, reads)
        XCTAssertNil(store.schedule)
        XCTAssertNil(store.studentInfo)
        XCTAssertNil(store.courseHistory)
        XCTAssertNil(store.attendance)
        XCTAssertTrue(store.records.isEmpty)
    }

    @MainActor
    func testWorkspacePreloadsEverySectionWithoutOpeningItsTab() async {
        let portal = TestPortal()
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        async let first: Void = store.preloadWorkspace()
        async let second: Void = store.preloadWorkspace()
        _ = await (first, second)
        XCTAssertNotNil(store.profile)
        XCTAssertNotNil(store.schedule)
        XCTAssertNotNil(store.records[.mail])
        XCTAssertNotNil(store.records[.documents])
        XCTAssertNotNil(store.studentInfo)
        XCTAssertNotNil(store.courseHistory)
        XCTAssertNotNil(store.attendance)
        for resource in ["profile", "schedule-terms", "mail", "documents", "student", "history", "attendance"] {
            XCTAssertEqual(portal.readCounts[resource], 1, "Duplicate preload: \(resource)")
        }
        XCTAssertEqual(store.access, .signedIn)
    }

    @MainActor
    func testOneFailedPreloadDoesNotBlockOtherSectionsAndCanRetry() async {
        let portal = TestPortal()
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        portal.resourceErrors["documents"] = PortalFailure.message("Temporary failure")
        await store.preloadWorkspace()
        XCTAssertNotNil(store.failures[.documents])
        XCTAssertNil(store.records[.documents])
        XCTAssertNotNil(store.schedule)
        XCTAssertNotNil(store.studentInfo)
        XCTAssertNotNil(store.courseHistory)
        XCTAssertNotNil(store.attendance)
        XCTAssertNotNil(store.records[.mail])
        XCTAssertEqual(store.access, .signedIn)
        portal.resourceErrors["documents"] = nil
        await store.load(.documents)
        XCTAssertNotNil(store.records[.documents])
        XCTAssertNil(store.failures[.documents])
    }

    @MainActor
    func testCancelledLoadsDoNotPublishFailuresOrSignOut() async {
        let portal = TestPortal()
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        XCTAssertEqual(store.access, .signedIn)
        let cancellations: [Error] = [CancellationError(), URLError(.cancelled)]
        for error in cancellations {
            portal.readError = error
            await store.refreshGrades()
            await store.loadProfile(refresh: true)
            await store.loadSchedule(refresh: true)
            await store.loadRecord(.student, refresh: true)
            await store.load(.mail, refresh: true)
            XCTAssertEqual(store.access, .signedIn)
            XCTAssertNil(store.gradeError)
            XCTAssertNil(store.profileError)
            XCTAssertNil(store.scheduleError)
            XCTAssertTrue(store.recordErrors.isEmpty)
            XCTAssertTrue(store.failures.isEmpty)
            XCTAssertFalse(store.isLoading)
            XCTAssertFalse(store.isLoadingProfile)
            XCTAssertFalse(store.isLoadingSchedule)
            XCTAssertTrue(store.loadingRecords.isEmpty)
            XCTAssertTrue(store.loadingResources.isEmpty)
        }
    }

    @MainActor
    func testUnknownDiscoveryOnSessionRejectionKeepsCredentialsForAuthenticatedRetry() async {
        let portal = TestPortal()
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        portal.savedSignIn = SavedSessionInfo(expires: .distantFuture, requiresUnlock: true, legacy: true)
        portal.readError = PortalFailure.signedOut
        await store.refreshGrades()
        XCTAssertEqual(store.access, .locked)
        XCTAssertNotNil(portal.savedSignIn)
        XCTAssertNil(store.gradebook)
        portal.readError = nil
        portal.connectionResult = false
        portal.renewalResult = true
        await store.unlockSavedSignIn()
        XCTAssertEqual(portal.renewalCalls, 1)
        XCTAssertEqual(store.access, .signedIn)
    }

    @MainActor
    func testFirstSchoolLoginRequestsLocalAuthenticationAndReadsSavedEntry() async {
        let portal = TestPortal()
        portal.savedSignIn = nil
        let unlock = TestUnlocker()
        let store = AppStore(client: portal, unlocker: unlock)
        await store.start()
        await store.signIn(username: "sample", password: "synthetic-only")
        XCTAssertEqual(unlock.calls, 1)
        XCTAssertEqual(portal.restoreCalls, 1)
        XCTAssertTrue(portal.restoredWithContext)
        XCTAssertEqual(store.access, .signedIn)
        XCTAssertNotNil(store.gradebook)
    }

    @MainActor
    func testCancellingFaceIDOnFirstLoginKeepsSavedCredentialsForRetry() async {
        let portal = TestPortal()
        portal.savedSignIn = nil
        let unlock = TestUnlocker()
        unlock.cancelAuthentication = true
        let store = AppStore(client: portal, unlocker: unlock)
        await store.start()
        await store.signIn(username: "sample", password: "synthetic-only")
        XCTAssertEqual(store.access, .locked)
        XCTAssertEqual(unlock.calls, 1)
        XCTAssertEqual(portal.restoreCalls, 0)
        XCTAssertEqual(portal.savedSignIn?.canRenew, true)
        XCTAssertNil(store.gradebook)
        unlock.cancelAuthentication = false
        await store.unlockSavedSignIn()
        XCTAssertEqual(store.access, .signedIn)
    }

    @MainActor
    func testFirstLoginDoesNotShowRecordsWhenSavedEntryCannotBeRead() async {
        let portal = TestPortal()
        portal.savedSignIn = nil
        portal.restorationError = KeychainStorageFailure(status: -25308)
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        await store.signIn(username: "sample", password: "synthetic-only")
        XCTAssertEqual(store.access, .locked)
        XCTAssertNotNil(store.unlockError)
        XCTAssertNotNil(portal.savedSignIn)
        XCTAssertNil(store.gradebook)
    }

    @MainActor
    func testBackgroundDuringPasscodeFreeStartupRestartsOnReturn() async {
        let portal = TestPortal()
        portal.savedSignIn = SavedSessionInfo(expires: .distantFuture, requiresUnlock: false)
        portal.delayConnection = true
        let pending = expectation(description: "Startup session check pending")
        portal.onConnection = { pending.fulfill() }
        let unlock = TestUnlocker()
        unlock.available = false
        let store = AppStore(client: portal, unlocker: unlock)
        let startup = Task { await store.start() }
        await fulfillment(of: [pending], timeout: 3)
        let oldCheck = portal.connectionContinuation
        store.enterBackground()
        XCTAssertEqual(store.access, .checking)
        XCTAssertNotNil(portal.savedSignIn)
        portal.delayConnection = false
        portal.onConnection = nil
        await store.enterForeground()
        XCTAssertEqual(store.access, .signedIn)
        XCTAssertNotNil(store.gradebook)
        XCTAssertEqual(portal.connectionCalls, 2)
        XCTAssertEqual(unlock.calls, 0)
        // A late failure from before backgrounding must not undo the new login.
        oldCheck?.resume(returning: false)
        await startup.value
        XCTAssertEqual(store.access, .signedIn)
        XCTAssertNotNil(store.gradebook)
        XCTAssertNotNil(portal.savedSignIn)
    }

    @MainActor
    func testCancelledAutomaticSignInWaitsForRetryAndRetainsCredentials() async {
        let portal = TestPortal()
        portal.savedSignIn = SavedSessionInfo(expires: .distantPast, requiresUnlock: true, canRenew: true)
        portal.connectionResult = false
        portal.renewalResult = true
        let unlock = TestUnlocker()
        unlock.cancelAuthentication = true
        let store = AppStore(client: portal, unlocker: unlock)
        await store.start()
        XCTAssertEqual(store.access, .locked)
        XCTAssertEqual(unlock.calls, 1)
        XCTAssertEqual(portal.restoreCalls, 0)
        XCTAssertEqual(portal.renewalCalls, 0)
        XCTAssertNotNil(portal.savedSignIn)
        await store.enterForeground()
        XCTAssertEqual(unlock.calls, 1)
        unlock.cancelAuthentication = false
        await store.unlockSavedSignIn()
        XCTAssertEqual(unlock.calls, 2)
        XCTAssertEqual(portal.renewalCalls, 1)
        XCTAssertEqual(store.access, .signedIn)
    }

    @MainActor
    func testCredentialsCannotBeSavedWithoutLocalAuthenticationProtection() {
        let saved = SavedSession(value: "synthetic", expires: .distantFuture, username: "sample", password: "synthetic-only")
        XCTAssertThrowsError(try SessionVault.save(saved, requiresUnlock: false))
    }

    @MainActor
    func testExpiredSessionWithCredentialsSignsInAgainAfterFaceID() async {
        let portal = TestPortal()
        portal.savedSignIn = SavedSessionInfo(expires: .distantPast, requiresUnlock: true, canRenew: true)
        portal.connectionResult = false
        portal.renewalResult = true
        let unlock = TestUnlocker()
        let store = AppStore(client: portal, unlocker: unlock)
        await store.start()
        XCTAssertEqual(unlock.calls, 1)
        XCTAssertEqual(portal.renewalCalls, 1)
        XCTAssertEqual(store.access, .signedIn)
        XCTAssertNotNil(store.gradebook)
    }

    @MainActor
    func testCancelledFaceIDCannotReadCredentialsOrRenewSession() async {
        let portal = TestPortal()
        portal.savedSignIn = SavedSessionInfo(expires: .distantPast, requiresUnlock: true, canRenew: true)
        let unlock = TestUnlocker()
        unlock.cancelAuthentication = true
        let store = AppStore(client: portal, unlocker: unlock)
        await store.start()
        XCTAssertEqual(store.access, .locked)
        XCTAssertEqual(portal.restoreCalls, 0)
        XCTAssertEqual(portal.renewalCalls, 0)
        XCTAssertEqual(portal.savedSignIn?.canRenew, true)
    }

    @MainActor
    func testChangedPasswordRemovesSavedCredentialsAndShowsSchoolLogin() async {
        let portal = TestPortal()
        portal.savedSignIn = SavedSessionInfo(expires: .distantPast, requiresUnlock: true, canRenew: true)
        portal.connectionResult = false
        portal.renewalError = PortalFailure.credentialsRejected
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        XCTAssertEqual(store.access, .signedOut)
        XCTAssertNil(portal.savedSignIn)
        XCTAssertTrue(store.loginError?.contains("username and password") == true)
    }

    @MainActor
    func testNetworkFailureKeepsSavedCredentialsForRetry() async {
        let portal = TestPortal()
        portal.savedSignIn = SavedSessionInfo(expires: .distantPast, requiresUnlock: true, canRenew: true)
        portal.connectionResult = false
        portal.renewalError = PortalFailure.message("Connection unavailable.")
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        XCTAssertEqual(store.access, .locked)
        XCTAssertNotNil(portal.savedSignIn)
        XCTAssertEqual(store.unlockError, "Connection unavailable.")
        portal.renewalError = nil
        portal.renewalResult = true
        await store.unlockSavedSignIn()
        XCTAssertEqual(store.access, .signedIn)
    }

    @MainActor
    func testBackgroundDuringCredentialRenewalCannotRevealSchoolData() async {
        let portal = TestPortal()
        portal.savedSignIn = SavedSessionInfo(expires: .distantPast, requiresUnlock: true, canRenew: true)
        portal.connectionResult = false
        portal.delayRenewal = true
        let pending = expectation(description: "Credential renewal started")
        portal.onRenewal = { pending.fulfill() }
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        let task = Task { await store.start() }
        await fulfillment(of: [pending], timeout: 3)
        store.enterBackground()
        portal.renewalContinuation?.resume(returning: true)
        await task.value
        XCTAssertEqual(store.access, .locked)
        XCTAssertNil(store.gradebook)
        XCTAssertEqual(portal.savedSignIn?.canRenew, true)
    }

    func testOlderKeychainEntriesDecodeWithoutSavedCredentials() throws {
        let session = try JSONDecoder().decode(SavedSession.self, from: Data(#"{"value":"opaque","expires":9999999999}"#.utf8))
        XCTAssertFalse(session.canRenew)
        XCTAssertNil(session.password)
        let metadata = try JSONDecoder().decode(SavedSessionInfo.self, from: Data(#"{"expires":-9999,"requiresUnlock":true,"legacy":false}"#.utf8))
        XCTAssertFalse(metadata.isValid)
    }

    @MainActor
    func testSavedCookieIsNotReadWhenFaceIDIsCancelled() async {
        let portal = TestPortal()
        let unlock = TestUnlocker()
        unlock.cancelAuthentication = true
        let store = AppStore(client: portal, unlocker: unlock)
        await store.start()
        XCTAssertEqual(store.access, .locked)
        XCTAssertEqual(unlock.calls, 1)
        XCTAssertEqual(portal.restoreCalls, 0)
        XCTAssertEqual(portal.connectionCalls, 0)
        XCTAssertNotNil(portal.savedSignIn)
        XCTAssertNotNil(store.unlockError)
        // Returning from Apple's authentication prompt is not a new app open.
        await store.enterForeground()
        XCTAssertEqual(unlock.calls, 1)
    }

    @MainActor
    func testSuccessfulFaceIDRestoresSessionThenLoadsSchoolData() async {
        let portal = TestPortal()
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        XCTAssertEqual(store.access, .signedIn)
        XCTAssertEqual(portal.restoreCalls, 1)
        XCTAssertTrue(portal.restoredWithContext)
        XCTAssertTrue(portal.protectRestoredSession)
        XCTAssertEqual(portal.connectionCalls, 1)
        XCTAssertNotNil(store.gradebook)
    }

    @MainActor
    func testAppSwitchesKeepWorkspaceAndDoNotRepeatAuthentication() async {
        let portal = TestPortal()
        let unlock = TestUnlocker()
        let store = AppStore(client: portal, unlocker: unlock)
        await store.start()
        XCTAssertNotNil(store.profile)
        let originalUnlocks = unlock.calls
        let originalRestores = portal.restoreCalls
        let originalForgets = portal.forgetCalls
        store.records[.mail] = [SchoolEvent(id: "sample", title: "Sample message", detail: "", date: "")]
        for _ in 0..<3 {
            store.enterBackground()
            XCTAssertEqual(store.access, .signedIn)
            XCTAssertNotNil(store.gradebook)
            XCTAssertNotNil(store.profile)
            XCTAssertEqual(store.records[.mail]?.count, 1)
            XCTAssertNotNil(portal.savedSignIn)
            await store.enterForeground()
            XCTAssertEqual(store.access, .signedIn)
        }
        XCTAssertEqual(unlock.calls, originalUnlocks)
        XCTAssertEqual(portal.restoreCalls, originalRestores)
        XCTAssertEqual(portal.forgetCalls, originalForgets)
    }

    @MainActor
    func testAppSwitchDoesNotRequireReadingKeychainMetadata() async {
        let portal = TestPortal()
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        XCTAssertEqual(store.access, .signedIn)
        let originalForgets = portal.forgetCalls
        portal.savedSignIn = nil // Models temporarily unavailable Keychain metadata.
        store.enterBackground()
        await store.enterForeground()
        XCTAssertEqual(store.access, .signedIn)
        XCTAssertNotNil(store.gradebook)
        XCTAssertNotNil(store.profile)
        XCTAssertEqual(portal.forgetCalls, originalForgets)
    }

    @MainActor
    func testSettingUpPasscodeDoesNotInterruptAnActiveSessionOnReturn() async {
        let portal = TestPortal()
        portal.savedSignIn = SavedSessionInfo(expires: .distantFuture, requiresUnlock: false)
        let unlock = TestUnlocker()
        unlock.available = false
        let store = AppStore(client: portal, unlocker: unlock)
        await store.start()
        store.enterBackground()
        unlock.available = true
        await store.enterForeground()
        XCTAssertEqual(unlock.calls, 0)
        XCTAssertEqual(store.access, .signedIn)
        // A new app process still protects restoration using the new passcode.
        let reopened = AppStore(client: portal, unlocker: unlock)
        await reopened.start()
        XCTAssertEqual(unlock.calls, 1)
        XCTAssertTrue(portal.protectRestoredSession)
    }

    @MainActor
    func testExpiredSavedSessionRequiresSchoolPasswordWithoutFaceID() async {
        let portal = TestPortal()
        portal.savedSignIn = SavedSessionInfo(expires: .distantPast, requiresUnlock: true)
        let unlock = TestUnlocker()
        let store = AppStore(client: portal, unlocker: unlock)
        await store.start()
        XCTAssertEqual(store.access, .signedOut)
        XCTAssertEqual(unlock.calls, 0)
        XCTAssertEqual(portal.restoreCalls, 0)
        XCTAssertNil(portal.savedSignIn)
    }

    @MainActor
    func testDistrictRevocationReturnsToSchoolPasswordAfterUnlock() async {
        let portal = TestPortal()
        portal.connectionResult = false
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        XCTAssertEqual(store.access, .signedOut)
        XCTAssertNil(portal.savedSignIn)
        XCTAssertNil(store.gradebook)
    }

    @MainActor
    func testUnprotectedLegacySessionIsUpgradedAfterLocalAuthentication() async {
        let portal = TestPortal()
        portal.savedSignIn = SavedSessionInfo(expires: .distantFuture, requiresUnlock: false, legacy: true)
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        XCTAssertEqual(store.access, .signedIn)
        XCTAssertTrue(portal.protectRestoredSession)
        XCTAssertTrue(portal.restoredWithContext)
    }

    @MainActor
    func testDeviceWithoutPasscodeRetainsExistingSavedSessionBehavior() async {
        let portal = TestPortal()
        portal.savedSignIn = SavedSessionInfo(expires: .distantFuture, requiresUnlock: false)
        let unlock = TestUnlocker()
        unlock.available = false
        let store = AppStore(client: portal, unlocker: unlock)
        await store.start()
        XCTAssertEqual(store.access, .signedIn)
        XCTAssertEqual(unlock.calls, 0)
        XCTAssertFalse(portal.restoredWithContext)
        XCTAssertFalse(portal.protectRestoredSession)
    }

    @MainActor
    func testProtectedSessionNeverFallsBackToUnprotectedRead() async {
        let portal = TestPortal()
        let unlock = TestUnlocker()
        unlock.available = false
        let store = AppStore(client: portal, unlocker: unlock)
        await store.start()
        XCTAssertEqual(store.access, .locked)
        XCTAssertEqual(portal.restoreCalls, 0)
        store.usePasswordInstead()
        XCTAssertEqual(store.access, .signedOut)
        XCTAssertNil(portal.savedSignIn)
    }

    @MainActor
    func testNewPasswordLoginSavesProtectedSessionAndSignOutRemovesIt() async {
        let portal = TestPortal()
        portal.savedSignIn = nil
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        await store.start()
        await store.signIn(username: "sample", password: "synthetic-test-only")
        XCTAssertEqual(store.access, .signedIn)
        XCTAssertEqual(portal.savedSignIn?.requiresUnlock, true)
        await store.signOut()
        XCTAssertEqual(store.access, .signedOut)
        XCTAssertNil(portal.savedSignIn)
    }

    @MainActor
    func testBackgroundDuringRestoreCannotPublishLateSchoolData() async {
        let portal = TestPortal()
        let pending = expectation(description: "Session check started")
        portal.onConnection = { pending.fulfill() }
        portal.delayConnection = true
        let store = AppStore(client: portal, unlocker: TestUnlocker())
        let task = Task { await store.start() }
        await fulfillment(of: [pending], timeout: 3)
        store.enterBackground()
        portal.connectionContinuation?.resume(returning: false)
        await task.value
        XCTAssertEqual(store.access, .locked)
        XCTAssertNotNil(portal.savedSignIn)
        XCTAssertNil(store.gradebook)
    }
}

@MainActor
private final class TestUnlocker: LocalUnlocking {
    var available = true
    var method = "Face ID"
    var symbol = "faceid"
    var calls = 0
    var cancelAuthentication = false
    func authenticate() async throws -> LAContext {
        calls += 1
        guard available else { throw DeviceUnlockFailure.unavailable }
        if cancelAuthentication { throw DeviceUnlockFailure.cancelled }
        return LAContext()
    }
    func cancel() {}
}

@MainActor
private final class TestPortal: SchoolPortal {
    var historyJSON = #"{"kind":"history","courses":[],"requirements":[],"classOf":""}"#
    var subjectReadCounts: [String: Int] = [:]
    var subjectErrors: [String: Error] = [:]
    var delayedSubjects: Set<String> = []
    var onSubject: ((String) -> Void)?
    var subjectContinuations: [String: CheckedContinuation<SubjectDetails, Error>] = [:]
    var readCounts: [String: Int] = [:]
    var resourceErrors: [String: Error] = [:]
    var savedSignIn: SavedSessionInfo? = SavedSessionInfo(expires: .distantFuture, requiresUnlock: true)
    var restoreCalls = 0
    var connectionCalls = 0
    var forgetCalls = 0
    var restoredWithContext = false
    var protectRestoredSession = false
    var restorationError: Error?
    var readError: Error?
    var connectionResult = true
    var delayConnection = false
    var onConnection: (() -> Void)?
    var connectionContinuation: CheckedContinuation<Bool, Never>?
    var renewalCalls = 0
    var renewalResult = false
    var renewalError: Error?
    var delayRenewal = false
    var onRenewal: (() -> Void)?
    var renewalContinuation: CheckedContinuation<Bool, Never>?
    func renewSession(context: LAContext) async throws -> Bool {
        renewalCalls += 1
        if let renewalError { throw renewalError }
        onRenewal?()
        if delayRenewal { return await withCheckedContinuation { renewalContinuation = $0 } }
        return renewalResult
    }
    func restoreSession(context: LAContext?, requiresUnlock: Bool) throws -> Bool {
        restoreCalls += 1
        if let restorationError { throw restorationError }
        restoredWithContext = context != nil
        protectRestoredSession = requiresUnlock
        return true
    }
    func forgetSession() { forgetCalls += 1 }
    func clear() { savedSignIn = nil }
    func connected() async throws -> Bool {
        connectionCalls += 1
        onConnection?()
        if delayConnection { return await withCheckedContinuation { connectionContinuation = $0 } }
        return connectionResult
    }
    func signIn(username: String, password: String, protectSession: Bool) async throws {
        savedSignIn = SavedSessionInfo(expires: .distantFuture, requiresUnlock: protectSession, canRenew: protectSession)
    }
    func signOut() async throws { clear() }
    func read<T: Decodable>(_ resource: String, term: Int?) async throws -> T {
        readCounts[resource, default: 0] += 1
        if let readError { throw readError }
        if let error = resourceErrors[resource] { throw error }
        let json: String
        switch resource {
        case "grades": json = #"{"courses":[],"terms":[],"currentTerm":0}"#
        case "schedule-terms": json = #"{"terms":[],"currentTerm":0}"#
        case "mail", "documents": json = "[]"
        case "student": json = #"{"kind":"student","sections":[]}"#
        case "history": json = historyJSON
        case "attendance": json = #"{"kind":"attendance","days":[],"totals":[]}"#
        default: json = #"{"name":"Sample Student","school":"Sample School","grade":"11"}"#
        }
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
    func readHistorySubject(_ id: String) async throws -> SubjectDetails {
        subjectReadCounts[id, default: 0] += 1
        if let error = subjectErrors[id] { throw error }
        onSubject?(id)
        if delayedSubjects.contains(id) {
            return try await withCheckedThrowingContinuation { subjectContinuations[id] = $0 }
        }
        return SubjectDetails(columns: ["Term", "Course Title (ID)", "Mark", "Credit Attempted", "Credit Completed"],
                              completed: [["2025 - T1", "Sample course (S101)", "A", "0.50", "0.50"]], inProgress: [])
    }
    func download(id: String, filename: String, messageID: String?) async throws -> URL { throw PortalFailure.signedOut }
}
