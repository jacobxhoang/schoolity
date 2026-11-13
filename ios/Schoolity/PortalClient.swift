import Foundation
import LocalAuthentication

@MainActor
protocol SchoolPortal: AnyObject {
    var savedSignIn: SavedSessionInfo? { get }
    func restoreSession(context: LAContext?, requiresUnlock: Bool) throws -> Bool
    func forgetSession()
    func clear()
    func connected() async throws -> Bool
    func signIn(username: String, password: String, protectSession: Bool) async throws
    func signOut() async throws
    func read<T: Decodable>(_ resource: String, term: Int?) async throws -> T
    func download(id: String, filename: String, messageID: String?) async throws -> URL
}

enum PortalFailure: LocalizedError {
    case signedOut
    case message(String)
    var errorDescription: String? {
        switch self {
        case .signedOut: return "Your session ended. Sign in again."
        case .message(let message): return message
        }
    }

    static func response(status: Int, signingIn: Bool, message: String?) -> PortalFailure {
        if status == 401 {
            return signingIn
                ? .message("Your district didn’t accept these credentials. Check your username and password, then try again.")
                : .signedOut
        }
        return .message(message ?? "Schoolity couldn’t load this request. Try again.")
    }
}

private final class PortalRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // Credentials and the session cookie are never forwarded to redirects.
        completionHandler(nil)
    }
}

@MainActor
final class PortalClient: SchoolPortal {
    static let baseURL = URL(string: "https://schoolity-jet.vercel.app")!
    // Never retrieve a saved cookie until local authentication has completed.
    private var token: SavedSession?
    var savedSignIn: SavedSessionInfo? { SessionVault.info() }
    private let session: URLSession
    private let redirects = PortalRedirects()

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 40
        session = URLSession(configuration: config, delegate: redirects, delegateQueue: nil)
    }

    func clear() {
        token = nil
        SessionVault.clear()
    }

    func forgetSession() { token = nil }

    func restoreSession(context: LAContext?, requiresUnlock: Bool) throws -> Bool {
        guard let saved = try SessionVault.load(context: context) else { clear(); return false }
        if let info = SessionVault.info(), info.legacy || (requiresUnlock && !info.requiresUnlock) {
            try SessionVault.save(saved, requiresUnlock: requiresUnlock)
        }
        token = saved
        return true
    }

    private func send(_ body: [String: Any], path: String = "api/portal") async throws -> (Data, HTTPURLResponse) {
        let requestSession = token?.value
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.baseURL.absoluteString, forHTTPHeaderField: "Origin")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let token, token.isValid {
            request.setValue("schoolity_session=\(token.value)", forHTTPHeaderField: "Cookie")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw PortalFailure.message("Schoolity returned an invalid response. Try again.")
        }
        if response.statusCode == 401 {
            // An old in-flight request must not erase a later successful login.
            if body["action"] as? String != "login", token?.value == requestSession { clear() }
        }
        guard (200..<300).contains(response.statusCode) else {
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw PortalFailure.response(status: response.statusCode, signingIn: body["action"] as? String == "login", message: payload?["error"] as? String)
        }
        return (data, response)
    }

    func connected() async throws -> Bool {
        guard token?.isValid == true else { clear(); return false }
        let requestSession = token?.value
        let (data, _) = try await send(["action": "session"])
        struct Status: Decodable { let connected: Bool }
        let connected = try JSONDecoder().decode(Status.self, from: data).connected
        if !connected, token?.value == requestSession { clear() }
        return connected
    }

    func signIn(username: String, password: String, protectSession: Bool) async throws {
        let (_, response) = try await send(["action": "login", "username": username, "password": password])
        let fields = response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            result[String(describing: pair.key)] = String(describing: pair.value)
        }
        guard let cookie = HTTPCookie.cookies(withResponseHeaderFields: fields, for: Self.baseURL)
            .first(where: { $0.name == "schoolity_session" }),
              let expires = cookie.expiresDate, expires > Date() else {
            clear()
            throw PortalFailure.message("Schoolity couldn’t save this session. Try signing in again.")
        }
        let saved = SavedSession(value: cookie.value, expires: expires)
        token = saved
        do { try SessionVault.save(saved, requiresUnlock: protectSession) }
        catch {
            try? await signOut()
            throw error
        }
    }

    func signOut() async throws {
        defer { clear() }
        _ = try await send(["action": "logout"])
    }

    func read<T: Decodable>(_ resource: String, term: Int? = nil) async throws -> T {
        var body: [String: Any] = ["action": "read", "resource": resource, "normalized": true]
        if let term { body["term"] = term }
        let (data, _) = try await send(body)
        return try JSONDecoder().decode(PortalEnvelope<T>.self, from: data).data
    }

    func download(id: String, filename: String, messageID: String? = nil) async throws -> URL {
        var body: [String: Any] = ["id": id]
        if let messageID { body["kind"] = "mail"; body["messageId"] = messageID }
        let (data, _) = try await send(body, path: "api/documents")
        guard !data.isEmpty else { throw PortalFailure.message("This file is empty. Try again.") }
        let folder = Self.downloadDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(Self.safeFilename(filename))
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static var downloadDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("SchoolityDownloads", isDirectory: true)
    }

    static func clearDownloads() { try? FileManager.default.removeItem(at: downloadDirectory) }

    nonisolated static func safeFilename(_ name: String) -> String {
        let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\:"))
        let result = name.components(separatedBy: forbidden).joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty || result == "." || result == ".." { return "Document" }
        let clipped = String(result.suffix(180))
        return clipped.hasPrefix(".") ? "Document\(clipped)" : clipped
    }
}

private struct PortalEnvelope<Value: Decodable>: Decodable { let data: Value }
