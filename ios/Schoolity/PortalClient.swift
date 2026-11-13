import Foundation

enum PortalFailure: LocalizedError {
    case signedOut
    case message(String)
    var errorDescription: String? {
        switch self {
        case .signedOut: return "Your session ended. Sign in again."
        case .message(let message): return message
        }
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
final class PortalClient {
    static let baseURL = URL(string: "https://schoolity-jet.vercel.app")!
    private var token: SavedSession? = SessionVault.load()
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

    private func send(_ body: [String: Any], path: String = "api/portal") async throws -> (Data, HTTPURLResponse) {
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
        if response.statusCode == 401 { clear(); throw PortalFailure.signedOut }
        guard (200..<300).contains(response.statusCode) else {
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw PortalFailure.message(payload?["error"] as? String ?? "Schoolity couldn’t load this request. Try again.")
        }
        return (data, response)
    }

    func connected() async throws -> Bool {
        guard token?.isValid == true else { clear(); return false }
        let (data, _) = try await send(["action": "session"])
        struct Status: Decodable { let connected: Bool }
        let connected = try JSONDecoder().decode(Status.self, from: data).connected
        if !connected { clear() }
        return connected
    }

    func signIn(username: String, password: String) async throws {
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
        do { try SessionVault.save(saved) }
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
