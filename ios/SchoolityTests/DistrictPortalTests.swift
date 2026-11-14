import XCTest
import Foundation
@testable import Schoolity

private final class DistrictProtocol: URLProtocol {
    struct Reply {
        let status: Int
        let text: String
        var headers: [String: String] = [:]
    }
    private static let lock = NSLock()
    private static var replies: [String: Reply] = [:]
    private static var captured: [URLRequest] = []
    static func configure(_ value: [String: Reply]) {
        lock.lock(); defer { lock.unlock() }
        replies = value; captured = []
    }
    static var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }; return captured
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.captured.append(request)
        let reply = Self.replies[request.url!.path]
        Self.lock.unlock()
        guard let reply, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class DistrictPortalTests: XCTestCase {
    @MainActor
    private func portal(webStatus: Int = 200, profileStatus: Int = 200) -> DistrictPortal {
        DistrictProtocol.configure([
            "/api/v1/mobile/PXPWebServices/AttemptLogin": .init(status: 200,
                text: #"{"access_token":"synthetic-token","expires_in":3600}"#,
                headers: ["Set-Cookie": "ASP.NET_SessionId=fixture; Path=/; Secure; HttpOnly"]),
            "/api/v1/mobile/PXPWebServices/GetStudentInfoData": .init(status: profileStatus,
                text: #"{"data":{"studentInfoXML":{"formattedName":"Sample Student","permID":"000123"}}}"#),
            "/PXP2_CourseHistory.aspx": .init(status: webStatus, text: "<script>PXP.CourseHistory=[];</script>")
        ])
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DistrictProtocol.self]
        return DistrictPortal(configuration: config)
    }

    @MainActor
    func testAllTrafficGoesDirectlyToDistrictAndHistoryPreservesQueryAndCookie() async throws {
        let client = portal()
        defer { client.clear() }
        try await client.signIn(username: "sample", password: "synthetic", protectSession: false)
        let connected = try await client.connected()
        XCTAssertTrue(connected)
        let profile: StudentProfile = try await client.read("profile")
        XCTAssertEqual(profile.studentId, "000123")
        let history: CourseHistoryPage = try await client.read("history")
        XCTAssertTrue(history.courses.isEmpty)
        let requests = DistrictProtocol.requests
        XCTAssertTrue(requests.allSatisfy { $0.url?.host == "synergyportal.anoka.k12.mn.us" && $0.url?.scheme == "https" })
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Authorization"), "Basic " + Data("sample:synthetic".utf8).base64EncodedString())
        let historyRequest = try XCTUnwrap(requests.last)
        XCTAssertEqual(historyRequest.url?.query, "AGU=0")
        XCTAssertEqual(historyRequest.value(forHTTPHeaderField: "Cookie"), "ASP.NET_SessionId=fixture")
        XCTAssertNil(historyRequest.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-token")
    }

    @MainActor
    func testWebCookieRejectionDoesNotExpireMobileToken() async throws {
        let client = portal(webStatus: 302)
        defer { client.clear() }
        try await client.signIn(username: "sample", password: "synthetic", protectSession: false)
        do {
            let _: CourseHistoryPage = try await client.read("history")
            XCTFail("The redirected history request should fail")
        } catch PortalFailure.message { }
        let connected = try await client.connected()
        XCTAssertTrue(connected)
    }

    @MainActor
    func testMobileTokenRejectionAndSignOutRemoveAccess() async throws {
        let client = portal(profileStatus: 401)
        defer { client.clear() }
        try await client.signIn(username: "sample", password: "synthetic", protectSession: false)
        do { _ = try await client.connected(); XCTFail("Revoked token should fail") }
        catch PortalFailure.signedOut { }
        try await client.signOut()
        let connected = try await client.connected()
        XCTAssertFalse(connected)
        XCTAssertNil(client.savedSignIn)
    }
}
