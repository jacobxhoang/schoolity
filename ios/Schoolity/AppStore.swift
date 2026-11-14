import SwiftUI
import LocalAuthentication

@MainActor
final class AppStore: ObservableObject {
    enum Access: Equatable { case checking, locked, signedOut, signedIn, unavailable }
    @Published var access: Access = .checking
    @Published var gradebook: Gradebook?
    @Published var profile: StudentProfile?
    @Published var isLoadingProfile = false
    @Published var profileError: String?
    @Published var schedule: ScheduleData?
    @Published var isLoadingSchedule = false
    @Published var scheduleError: String?
    @Published var studentInfo: StudentInfoPage?
    @Published var courseHistory: CourseHistoryPage?
    @Published var attendance: AttendancePage?
    @Published var recordErrors: [StudentRecordFeature: String] = [:]
    @Published var loadingRecords: Set<StudentRecordFeature> = []
    @Published var records: [SchoolResource: [SchoolEvent]] = [:]
    @Published var failures: [SchoolResource: String] = [:]
    @Published var loadingResources: Set<SchoolResource> = []
    @Published var isLoading = false
    @Published var gradeError: String?
    @Published var loginError: String?
    @Published var startupError: String?
    @Published var signingOut = false
    @Published var isUnlocking = false
    @Published var unlockError: String?
    private let client: any SchoolPortal
    private let unlocker: any LocalUnlocking
    private var generation = UUID()
    private var started = false
    private var backgrounded = false
    private var savedSessionNeedsUnlock = false
    #if DEBUG
    private var testingSavedSignIn = false
    #endif

    init(client: (any SchoolPortal)? = nil, unlocker: (any LocalUnlocking)? = nil) {
        self.client = client ?? PortalClient()
        self.unlocker = unlocker ?? DeviceUnlocker()
    }

    var unlockMethod: String {
        #if DEBUG
        if testingSavedSignIn { return "Face ID" }
        #endif
        return unlocker.method
    }
    var unlockSymbol: String {
        #if DEBUG
        if testingSavedSignIn { return "faceid" }
        #endif
        return unlocker.symbol
    }

    func start() async {
        guard !started else { return }
        started = true
        PortalClient.clearDownloads()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-locked") {
            testingSavedSignIn = true
            access = .locked
            if ProcessInfo.processInfo.arguments.contains("--ui-auto-unlock") {
                // Model the asynchronous system prompt across a rendered state
                // transition so UI checks also exercise the launch task lifetime.
                do { try await Task.sleep(for: .milliseconds(200)) }
                catch { return }
                await unlockSavedSignIn()
            }
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            loadUITestData()
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-login") { access = .signedOut; return }
        #endif
        await restore()
    }

    func restore() async {
        guard !isUnlocking else { return }
        guard let info = client.savedSignIn, info.isValid else {
            client.clear()
            reset()
            return
        }
        savedSessionNeedsUnlock = info.requiresUnlock || unlocker.available
        if savedSessionNeedsUnlock {
            access = .locked
            await unlockSavedSignIn()
            return
        }
        let ticket = generation
        access = .checking
        do {
            try await finishRestoring(context: nil, requiresUnlock: false, ticket: ticket)
        } catch {
            guard ticket == generation else { return }
            client.forgetSession()
            startupError = error.localizedDescription
            access = .unavailable
        }
    }

    func unlockSavedSignIn() async {
        guard access == .locked, !isUnlocking, !backgrounded else { return }
        unlockError = nil
        #if DEBUG
        if testingSavedSignIn {
            if ProcessInfo.processInfo.arguments.contains("--ui-unlock-success") { loadUITestData() }
            else { unlockError = DeviceUnlockFailure.cancelled.localizedDescription }
            return
        }
        #endif
        guard let info = client.savedSignIn, info.isValid else {
            client.clear(); reset(); loginError = "Your session ended. Sign in again."
            return
        }
        let ticket = generation
        isUnlocking = true
        defer { if ticket == generation { isUnlocking = false } }
        do {
            let context = try await unlocker.authenticate()
            defer { context.invalidate() }
            guard ticket == generation, !backgrounded else { return }
            try await finishRestoring(context: context, requiresUnlock: true, ticket: ticket)
        } catch {
            guard ticket == generation else { return }
            client.forgetSession()
            if case PortalFailure.credentialsRejected = error { client.clear(); reset(); loginError = error.localizedDescription }
            else if case PortalFailure.signedOut = error { handle(error) }
            else { access = .locked; unlockError = error.localizedDescription }
        }
    }

    private func finishRestoring(context: LAContext?, requiresUnlock: Bool, ticket: UUID) async throws {
        guard try client.restoreSession(context: context, requiresUnlock: requiresUnlock) else {
            reset(); loginError = "Your session ended. Sign in again."
            return
        }
        var connected = false
        do { connected = try await client.connected() }
        catch PortalFailure.signedOut { connected = false }
        guard ticket == generation, !backgrounded else { return }
        if !connected, requiresUnlock, let context {
            // Inspect the authenticated entry, not potentially unavailable
            // discovery metadata, to decide whether credentials can renew it.
            connected = try await client.renewSession(context: context)
            guard ticket == generation, !backgrounded else { return }
        }
        if connected { access = .signedIn; await refreshGrades() }
        else { client.clear(); reset(); loginError = "Your session ended. Sign in again." }
    }

    func enterBackground() {
        backgrounded = true
        // A session check can still be pending on a passcode-free device.
        // Discard that attempt; foregrounding restarts it with a fresh ticket.
        if access == .checking {
            client.forgetSession()
            clearWorkspace()
            return
        }
        // Keychain may already be unavailable when the phone locks. Never
        // depend on another Keychain read to decide whether the UI must lock.
        guard !signingOut, savedSessionNeedsUnlock || access == .locked || isUnlocking else { return }
        lockWorkspace()
    }

    private func lockWorkspace() {
        unlocker.cancel()
        client.forgetSession()
        clearWorkspace()
        isUnlocking = false
        unlockError = nil
        access = .locked
    }

    func enterForeground() async {
        // Local Authentication only makes the app inactive. Require a real
        // background transition before starting another automatic attempt.
        guard backgrounded else { return }
        backgrounded = false
        // A passcode may have been configured while Schoolity was backgrounded.
        if access == .signedIn, !savedSessionNeedsUnlock, unlocker.available {
            savedSessionNeedsUnlock = true
            lockWorkspace()
        }
        if access == .locked { await unlockSavedSignIn() }
        else if access == .checking, started { await restore() }
    }

    func usePasswordInstead() {
        unlocker.cancel()
        client.clear()
        #if DEBUG
        testingSavedSignIn = false
        #endif
        reset()
    }

    func signIn(username: String, password: String) async {
        guard !isLoading else { return }
        isLoading = true
        loginError = nil
        let protectSession = unlocker.available
        do {
            try await client.signIn(username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password, protectSession: protectSession)
            generation = UUID()
            savedSessionNeedsUnlock = protectSession
            if protectSession {
                // Request the system permission now, then read the saved entry
                // back under authentication before showing any school records.
                access = .locked
                isLoading = false
                if backgrounded { lockWorkspace(); return }
                await unlockSavedSignIn()
                return
            }
            access = .signedIn
            if backgrounded { enterBackground() }
        } catch { loginError = error.localizedDescription }
        isLoading = false
        if access == .signedIn { await refreshGrades() }
    }

    func refreshGrades(term: Int? = nil) async {
        guard !isLoading, access == .signedIn else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { return }
        #endif
        let ticket = generation
        isLoading = true
        gradeError = nil
        defer { if ticket == generation { isLoading = false } }
        do {
            let next: Gradebook = try await client.read("grades", term: term ?? gradebook?.currentTerm)
            guard ticket == generation else { return }
            gradebook = next
        } catch {
            guard ticket == generation else { return }
            handle(error)
            gradeError = error.localizedDescription
        }
        if profile == nil, access == .signedIn, ticket == generation { await loadProfile() }
    }

    func loadProfile(refresh: Bool = false) async {
        guard access == .signedIn, !isLoadingProfile, refresh || profile == nil else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { return }
        #endif
        let ticket = generation
        isLoadingProfile = true
        profileError = nil
        defer { if ticket == generation { isLoadingProfile = false } }
        do {
            let next: StudentProfile = try await client.read("profile", term: nil)
            if ticket == generation { profile = next }
        } catch {
            guard ticket == generation else { return }
            handle(error)
            profileError = error.localizedDescription
        }
    }

    func loadSchedule(refresh: Bool = false) async {
        guard access == .signedIn, !isLoadingSchedule, refresh || schedule == nil else { return }
        let ticket = generation
        isLoadingSchedule = true
        scheduleError = nil
        defer { if ticket == generation { isLoadingSchedule = false } }
        do {
            let next: ScheduleData = try await client.read("schedule-terms", term: nil)
            guard ticket == generation else { return }
            schedule = next
        } catch {
            guard ticket == generation else { return }
            handle(error)
            scheduleError = error.localizedDescription
        }
    }

    func loadRecord(_ feature: StudentRecordFeature, refresh: Bool = false) async {
        guard access == .signedIn, !loadingRecords.contains(feature) else { return }
        if !refresh {
            switch feature {
            case .student: guard studentInfo == nil else { return }
            case .history: guard courseHistory == nil else { return }
            case .attendance: guard attendance == nil else { return }
            }
        }
        let ticket = generation
        loadingRecords.insert(feature)
        recordErrors[feature] = nil
        defer { if ticket == generation { loadingRecords.remove(feature) } }
        do {
            switch feature {
            case .student:
                let next: StudentInfoPage = try await client.read("student", term: nil)
                guard ticket == generation else { return }
                studentInfo = next
            case .history:
                let next: CourseHistoryPage = try await client.read("history", term: nil)
                guard ticket == generation else { return }
                courseHistory = next
            case .attendance:
                let next: AttendancePage = try await client.read("attendance", term: nil)
                guard ticket == generation else { return }
                attendance = next
            }
        } catch {
            guard ticket == generation else { return }
            handle(error)
            recordErrors[feature] = error.localizedDescription
        }
    }

    func historySubject(id: String) async throws -> SubjectDetails {
        guard access == .signedIn else { throw PortalFailure.signedOut }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            return SubjectDetails(columns: ["Course", "Mark"], completed: [["Sample completed course", "A"]], inProgress: [])
        }
        #endif
        do {
            return try await client.readHistorySubject(id)
        } catch {
            handle(error)
            throw error
        }
    }

    func load(_ resource: SchoolResource, refresh: Bool = false) async {
        guard access == .signedIn, !loadingResources.contains(resource), refresh || records[resource] == nil else { return }
        let ticket = generation
        loadingResources.insert(resource)
        failures[resource] = nil
        defer { if ticket == generation { loadingResources.remove(resource) } }
        do {
            let next: [SchoolEvent] = try await client.read(resource.rawValue, term: nil)
            if ticket == generation { records[resource] = next }
        } catch {
            guard ticket == generation else { return }
            handle(error)
            failures[resource] = error.localizedDescription
        }
    }

    func download(id: String, filename: String, messageID: String? = nil) async throws -> URL {
        let ticket = generation
        do {
            let url = try await client.download(id: id, filename: filename, messageID: messageID)
            guard ticket == generation, access == .signedIn else {
                PortalClient.clearDownloads()
                throw PortalFailure.signedOut
            }
            return url
        } catch {
            if ticket == generation { handle(error) }
            throw error
        }
    }

    func signOut() async {
        guard !signingOut else { return }
        signingOut = true
        // Clear visible records immediately; block a new login until revocation finishes.
        reset()
        try? await client.signOut()
        signingOut = false
    }

    private func handle(_ error: Error) {
        if case PortalFailure.signedOut = error {
            if let info = client.savedSignIn, info.canRenew == true || info.legacy {
                savedSessionNeedsUnlock = true
                lockWorkspace()
                unlockError = "Unlock to sign in again."
            } else { client.clear(); reset(); loginError = error.localizedDescription }
        }
    }

    private func reset() {
        clearWorkspace()
        savedSessionNeedsUnlock = false
        isUnlocking = false
        unlockError = nil
        access = .signedOut
    }

    private func clearWorkspace() {
        generation = UUID()
        gradebook = nil
        profile = nil
        isLoadingProfile = false
        profileError = nil
        schedule = nil
        isLoadingSchedule = false
        scheduleError = nil
        studentInfo = nil
        courseHistory = nil
        attendance = nil
        recordErrors = [:]
        loadingRecords = []
        records = [:]
        failures = [:]
        loadingResources = []
        gradeError = nil
        isLoading = false
        PortalClient.clearDownloads()
    }
}
