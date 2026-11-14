import Foundation
import LocalAuthentication

@MainActor
protocol SchoolPortal: AnyObject {
    var savedSignIn: SavedSessionInfo? { get }
    func restoreSession(context: LAContext?, requiresUnlock: Bool) throws -> Bool
    func renewSession(context: LAContext) async throws -> Bool
    func forgetSession()
    func clear()
    func connected() async throws -> Bool
    func signIn(username: String, password: String, protectSession: Bool) async throws
    func signOut() async throws
    func read<T: Decodable>(_ resource: String, term: Int?) async throws -> T
    func readHistorySubject(_ id: String) async throws -> SubjectDetails
    func download(id: String, filename: String, messageID: String?) async throws -> URL
}

enum PortalFailure: LocalizedError {
    case signedOut
    case credentialsRejected
    case message(String)
    var errorDescription: String? {
        switch self {
        case .signedOut: return "Your session ended. Sign in again."
        case .credentialsRejected: return "Your district didn’t accept these credentials. Check your username and password, then try again."
        case .message(let message): return message
        }
    }

    static func response(status: Int, signingIn: Bool, message: String?) -> PortalFailure {
        if status == 401 {
            return signingIn
                ? .credentialsRejected
                : .signedOut
        }
        return .message(message ?? "Schoolity couldn’t load this request. Try again.")
    }

    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}
