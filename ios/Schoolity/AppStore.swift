import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    enum Access: Equatable { case checking, signedOut, signedIn, unavailable }
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
    private let client = PortalClient()
    private var generation = UUID()
    private var started = false

    func start() async {
        guard !started else { return }
        started = true
        PortalClient.clearDownloads()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            loadUITestData()
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-login") { access = .signedOut; return }
        #endif
        await restore()
    }

    func restore() async {
        access = .checking
        do {
            if try await client.connected() { access = .signedIn; await refreshGrades() }
            else { access = .signedOut }
        } catch {
            startupError = error.localizedDescription
            access = .unavailable
        }
    }

    func signIn(username: String, password: String) async {
        guard !isLoading else { return }
        isLoading = true
        loginError = nil
        do {
            try await client.signIn(username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            generation = UUID()
            access = .signedIn
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
                let next: StudentProfile = try await client.read("profile")
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
            let next: [SchoolEvent] = try await client.read(resource.rawValue)
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
        generation = UUID()
        gradebook = nil
        profile = nil
        records = [:]
        failures = [:]
        loadingResources = []
        gradeError = nil
        isLoading = false
        access = .signedOut
        PortalClient.clearDownloads()
    }
}
