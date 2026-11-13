import LocalAuthentication

@MainActor
protocol LocalUnlocking: AnyObject {
    var available: Bool { get }
    var method: String { get }
    var symbol: String { get }
    func authenticate() async throws -> LAContext
    func cancel()
}

enum DeviceUnlockFailure: LocalizedError {
    case unavailable, cancelled, failed
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Set up a device passcode, or sign in again."
        case .cancelled: return "Unlock cancelled. You can try again."
        case .failed: return "Couldn’t verify your identity. Try again or sign in again."
        }
    }
}

@MainActor
final class DeviceUnlocker: LocalUnlocking {
    private var activeContext: LAContext?
    var available: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }
    private var biometry: LABiometryType {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return .none }
        return context.biometryType
    }
    var method: String {
        switch biometry {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "passcode"
        }
    }
    var symbol: String {
        switch biometry {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock"
        }
    }

    func authenticate() async throws -> LAContext {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { throw DeviceUnlockFailure.unavailable }
        context.localizedCancelTitle = "Cancel"
        activeContext = context
        defer { if activeContext === context { activeContext = nil } }
        do {
            guard try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your saved Schoolity sign-in.") else {
                throw DeviceUnlockFailure.failed
            }
            return context
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel: throw DeviceUnlockFailure.cancelled
            default: throw DeviceUnlockFailure.failed
            }
        }
    }

    func cancel() { activeContext?.invalidate(); activeContext = nil }
}
