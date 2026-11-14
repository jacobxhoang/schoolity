import Foundation
import LocalAuthentication

private final class DistrictRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class DistrictPortal: SchoolPortal {
    static let baseURL = URL(string: "https://synergyportal.anoka.k12.mn.us")!
    private var token: SavedSession?
    private var identity = UUID()
    private var memoryEpoch = UUID()
    var savedSignIn: SavedSessionInfo? { SessionVault.info() }
    private let session: URLSession
    private let redirects = DistrictRedirects()

    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 40
        session = URLSession(configuration: configuration, delegate: redirects, delegateQueue: nil)
    }

    func clear() { identity = UUID(); forgetSession(); SessionVault.clear() }
    func forgetSession() { token = nil; memoryEpoch = UUID() }
    private func expireSession() {
        token = nil
        if let info = savedSignIn, !info.legacy, info.canRenew == false { SessionVault.clear() }
    }

    func restoreSession(context: LAContext?, requiresUnlock: Bool) throws -> Bool {
        guard let saved = try SessionVault.load(context: context) else { clear(); return false }
        if let info = savedSignIn, info.legacy || (requiresUnlock && !info.requiresUnlock) {
            try SessionVault.save(saved, requiresUnlock: requiresUnlock)
        }
        // An old Vercel cookie must never be sent to the district as a token.
        token = saved.district == true && saved.isValid ? saved.withoutCredentials : nil
        return saved.district == true || saved.canRenew
    }

    func renewSession(context: LAContext) async throws -> Bool {
        let ticket = identity
        guard let saved = try SessionVault.load(context: context), saved.canRenew,
              let username = saved.username, let password = saved.password else { return false }
        do {
            try await signIn(username: username, password: password, protectSession: true)
            return true
        } catch PortalFailure.credentialsRejected {
            if ticket == identity { clear() }
            throw PortalFailure.credentialsRejected
        }
    }

    private func request(path: String, body: [String: Any]? = nil,
                         authorization: String? = nil, web: Bool = false,
                         login: Bool = false) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        let account = identity, epoch = memoryEpoch, activeToken = token?.value
        guard let url = URL(string: path, relativeTo: Self.baseURL)?.absoluteURL,
              url.scheme == "https", url.host == Self.baseURL.host else {
            throw PortalFailure.message("Unsupported district address.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue(body == nil ? "text/html" : "application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        if let authorization { request.setValue(authorization, forHTTPHeaderField: "Authorization") }
        if web {
            guard let cookie = token?.webCookie, !cookie.isEmpty else {
                throw PortalFailure.message("This page needs to reconnect to StudentVUE. Your other pages are still available.")
            }
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
            request.setValue(Self.baseURL.absoluteString, forHTTPHeaderField: "Origin")
            request.setValue("0", forHTTPHeaderField: "AGU")
        }
        let (data, raw) = try await session.data(for: request)
        try Task.checkCancellation()
        guard account == identity, epoch == memoryEpoch,
              login || activeToken == token?.value else { throw CancellationError() }
        guard let response = raw as? HTTPURLResponse else { throw PortalFailure.message("The district returned an invalid response.") }
        guard data.count <= 12_000_000 else { throw PortalFailure.message("The district response exceeded the size limit.") }
        if [401, 403, 302, 301, 303, 307, 308].contains(response.statusCode) {
            if web { throw PortalFailure.message("This page needs to reconnect to StudentVUE. Your other pages are still available.") }
            if !login { expireSession() }
            throw login ? PortalFailure.credentialsRejected : PortalFailure.signedOut
        }
        guard response.statusCode == 200 else {
            throw PortalFailure.message("The district returned HTTP \(response.statusCode). Try again.")
        }
        return (data, response)
    }

    private func exchange(_ method: String, parameters: [String: Any] = [:], basic: String? = nil) async throws -> (Data, HTTPURLResponse) {
        if basic == nil, token?.isValid != true { throw PortalFailure.signedOut }
        let encoded = try JSONSerialization.data(withJSONObject: parameters)
        return try await request(path: "api/v1/mobile/PXPWebServices/\(method)", body: [
            "arguments": ["request": String(decoding: encoded, as: UTF8.self)]
        ], authorization: basic.map { "Basic \($0)" } ?? "Bearer \(token?.value ?? "")", login: basic != nil)
    }

    func connected() async throws -> Bool {
        guard token?.isValid == true else { expireSession(); return false }
        // Confirm district validity; no Schoolity session service is involved.
        _ = try await rawResource("profile", term: nil)
        return true
    }

    func signIn(username: String, password: String, protectSession: Bool) async throws {
        let account = identity, epoch = memoryEpoch
        let auth = Data("\(username):\(password)".utf8).base64EncodedString()
        let (data, response) = try await exchange("AttemptLogin", parameters: [
            "userID": NSNull(), "password": NSNull(), "userType": "Student", "DeviceModel": "Schoolity iOS",
            "LoginClientData": "POST:/api/v1/mobile/PXPWebServices/AttemptLogin:\(Int(Date().timeIntervalSince1970 * 1000)):\(UUID().uuidString)"
        ], basic: auth)
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let value = payload?["access_token"] as? String, !value.isEmpty else { throw PortalFailure.credentialsRejected }
        let seconds = Double(String(describing: payload?["expires_in"] ?? "")) ?? 1800
        let lifetime = seconds.isFinite && seconds >= 1 ? min(seconds.rounded(.down), 30 * 86400) : 1800
        let fields = response.allHeaderFields.reduce(into: [String: String]()) { $0[String(describing: $1.key)] = String(describing: $1.value) }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: Self.baseURL)
            .filter { Self.baseURL.host == $0.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")) || Self.baseURL.host?.hasSuffix("." + $0.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))) == true }
            .map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        let saved = SavedSession(value: value, expires: Date().addingTimeInterval(lifetime),
                                 username: protectSession ? username : nil, password: protectSession ? password : nil,
                                 district: true, webCookie: cookies.isEmpty ? nil : cookies)
        guard account == identity, epoch == memoryEpoch else { throw CancellationError() }
        try SessionVault.save(saved, requiresUnlock: protectSession)
        token = saved.withoutCredentials
    }

    func signOut() async throws {
        // Discard all local district secrets. No Schoolity session to revoke.
        clear()
    }

    private func parse(_ operation: String, _ arguments: [String: Any]) async throws -> Data {
        let account = identity, epoch = memoryEpoch
        let result = try await DistrictParser.parse(operation, arguments: JSONSerialization.data(withJSONObject: arguments))
        try Task.checkCancellation()
        guard account == identity, epoch == memoryEpoch else { throw CancellationError() }
        return result
    }

    private func rawResource(_ resource: String, term: Int?) async throws -> Any {
        var parameters: [String: Any] = ["childIntID": 0, "languageCode": "1"]
        let method: String
        switch resource {
        case "grades":
            method = "Gradebook"; parameters["concurrentSchOrgYearGU"] = ""
            if let term {
                guard (0...100).contains(term) else { throw PortalFailure.message("Invalid reporting period.") }
                parameters["ReportPeriod"] = term; parameters["reportPeriod"] = term
            }
        case "profile", "student": method = "GetStudentInfoData"
        case "attendance": method = "Attendance"
        case "schedule-terms":
            method = "StudentClassList"
            parameters.merge(["loadAllTerms": true, "conSchOrgYearGU": "", "conSchTermIndex": "-1", "termIndex": "-1"]) { _, new in new }
        case "documents": method = "GetStudentDocuments"
        case "mail":
            method = "GetSynergyMailMessage"
            parameters.merge(["folderGU": "Inbox", "loadMessageBody": "true", "skip": "0", "take": "50"]) { _, new in new }
        default: throw PortalFailure.message("That resource is unavailable.")
        }
        let (response, _) = try await exchange(method, parameters: parameters)
        let payload = try await parse("payload", ["resource": resource, "response": JSONSerialization.jsonObject(with: response)])
        return try JSONSerialization.jsonObject(with: payload, options: .fragmentsAllowed)
    }

    private func historyOverview() async throws -> Any {
        let (data, _) = try await request(path: "PXP2_CourseHistory.aspx?AGU=0", web: true)
        let parsed = try await parse("history", ["html": String(decoding: data, as: UTF8.self)])
        return try JSONSerialization.jsonObject(with: parsed)
    }

    func read<T: Decodable>(_ resource: String, term: Int? = nil) async throws -> T {
        var payload: Any
        if resource == "history" { payload = try await historyOverview() }
        else { payload = try await rawResource(resource, term: term) }
        if resource == "student" {
            let profile = payload
            do {
                let (data, _) = try await request(path: "PXP2_Student.aspx?AGU=0", web: true)
                let parsed = try await parse("student", ["profile": profile, "html": String(decoding: data, as: UTF8.self)])
                payload = try JSONSerialization.jsonObject(with: parsed)
            } catch {
                if PortalFailure.isCancellation(error) { throw error }
                payload = ["studentInfo": profile, "studentInfoNotice": "Additional StudentVUE information could not be loaded. Refresh to try again."]
            }
        }
        let normalized = try await parse("normalize", ["resource": resource, "payload": payload])
        return try JSONDecoder().decode(T.self, from: normalized)
    }

    func readHistorySubject(_ id: String) async throws -> SubjectDetails {
        let history: CourseHistoryPage = try await read("history")
        guard history.requirements.contains(where: { $0.id == id && !id.isEmpty }) else {
            throw PortalFailure.message("This subject is unavailable for your account. Refresh course history.")
        }
        let (data, _) = try await request(path: "service/PXP2Communication.asmx/GetCourseHistoryDetails", body: ["agu": "0", "itemGU": id], web: true)
        let parsed = try await parse("subject", ["text": String(decoding: data, as: UTF8.self)])
        return try JSONDecoder().decode(SubjectDetails.self, from: parsed)
    }

    func download(id: String, filename: String, messageID: String? = nil) async throws -> URL {
        let epoch = memoryEpoch
        let listing: [SchoolEvent] = try await read(messageID == nil ? "documents" : "mail")
        let own: Bool
        var parameters: [String: Any] = ["childIntID": 0, "languageCode": "1"]
        let method: String
        if let messageID {
            own = listing.contains { $0.id?.lowercased() == messageID.lowercased() && $0.attachments?.contains(where: { $0.id.lowercased() == id.lowercased() }) == true }
            method = "GetSynergyMailGetAttachment"
            parameters.merge(["smMessageGU": messageID, "smAttachmentGU": id, "attachmentGU": id]) { _, new in new }
        } else {
            own = listing.contains { $0.id?.lowercased() == id.lowercased() }
            method = "GetStudentDocumentContent"; parameters["documentGU"] = id
        }
        guard !id.isEmpty, own else { throw PortalFailure.message("This file is no longer available for your account. Refresh the list.") }
        let (response, _) = try await exchange(method, parameters: parameters)
        let parsed = try await parse("download", ["response": JSONSerialization.jsonObject(with: response), "mail": messageID != nil])
        let base64 = try JSONDecoder().decode(String.self, from: parsed)
        guard epoch == memoryEpoch else { throw CancellationError() }
        guard let bytes = Data(base64Encoded: base64), !bytes.isEmpty else { throw PortalFailure.message("The district returned an empty file.") }
        let folder = Self.downloadDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(Self.safeFilename(filename))
        try bytes.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static var downloadDirectory: URL { FileManager.default.temporaryDirectory.appendingPathComponent("SchoolityDownloads", isDirectory: true) }
    static func clearDownloads() { try? FileManager.default.removeItem(at: downloadDirectory) }
    nonisolated static func safeFilename(_ name: String) -> String {
        let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\:"))
        let result = name.components(separatedBy: forbidden).joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty || result == "." || result == ".." { return "Document" }
        let clipped = String(result.suffix(180))
        return clipped.hasPrefix(".") ? "Document\(clipped)" : clipped
    }
}

typealias PortalClient = DistrictPortal
