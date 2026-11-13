import SwiftUI
import LocalAuthentication

@MainActor
final class AppStore: ObservableObject {
    enum Access: Equatable { case checking, locked, signedOut, signedIn, unavailable }
    @Published var access: Access = .checking
    @Published var gradebook: Gradebook?
    @Published var profile: StudentProfile?
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
        if info.requiresUnlock || unlocker.available {
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
            if case PortalFailure.signedOut = error { handle(error) }
            else { access = .locked; unlockError = error.localizedDescription }
        }
    }

    private func finishRestoring(context: LAContext?, requiresUnlock: Bool, ticket: UUID) async throws {
        guard try client.restoreSession(context: context, requiresUnlock: requiresUnlock) else {
            reset(); loginError = "Your session ended. Sign in again."
            return
        }
        let connected = try await client.connected()
        guard ticket == generation, !backgrounded else { return }
        if connected { access = .signedIn; await refreshGrades() }
        else { client.clear(); reset(); loginError = "Your session ended. Sign in again." }
    }

    func enterBackground() {
        backgrounded = true
        guard !signingOut, let info = client.savedSignIn, info.requiresUnlock || unlocker.available else { return }
        unlocker.cancel()
        client.forgetSession()
        clearWorkspace()
        isUnlocking = false
        unlockError = nil
        access = .locked
    }

    func enterForeground() async {
        // Local Authentication temporarily makes the app inactive. Only a real
        // background/foreground transition may trigger another automatic scan.
        guard backgrounded else { return }
        backgrounded = false
        if access == .locked { await unlockSavedSignIn() }
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
        do {
            try await client.signIn(username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password, protectSession: unlocker.available)
            generation = UUID()
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
        if profile == nil, access == .signedIn, ticket == generation {
            do {
                let next: StudentProfile = try await client.read("profile", term: nil)
                if ticket == generation { profile = next }
            } catch { if ticket == generation { handle(error) } }
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
        if case PortalFailure.signedOut = error { client.clear(); reset(); loginError = error.localizedDescription }
    }

    private func reset() {
        clearWorkspace()
        isUnlocking = false
        unlockError = nil
        access = .signedOut
    }

    private func clearWorkspace() {
        generation = UUID()
        gradebook = nil
        profile = nil
        records = [:]
        failures = [:]
        loadingResources = []
        gradeError = nil
        isLoading = false
        PortalClient.clearDownloads()
    }
}
