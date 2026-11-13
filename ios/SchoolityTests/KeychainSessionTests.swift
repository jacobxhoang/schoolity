import XCTest
import Security
@testable import Schoolity

final class KeychainSessionTests: XCTestCase {
    func testSavedSessionAndDiscoverySurviveStoreRecreation() throws {
        let service = "com.schoolity.tests.\(UUID().uuidString)"
        let store = KeychainSessionStore(service: service)
        defer { store.clear() }
        let saved = SavedSession(value: "synthetic-cookie", expires: .distantFuture)
        try store.save(saved, requiresUnlock: false)

        // Use the actual Security framework and a new store, not an AppStore fake.
        let reopened = KeychainSessionStore(service: service)
        let info = try XCTUnwrap(reopened.info())
        XCTAssertEqual(info.expires, saved.expires)
        XCTAssertFalse(info.requiresUnlock)
        XCTAssertEqual(info.canRenew, false)
        XCTAssertEqual(try reopened.load(context: nil)?.value, saved.value)
    }

    func testReplacingAndRemovingEntryAlsoUpdatesDiscovery() throws {
        let store = KeychainSessionStore(service: "com.schoolity.tests.\(UUID().uuidString)")
        defer { store.clear() }
        try store.save(SavedSession(value: "old-fixture", expires: .distantFuture), requiresUnlock: false)
        let newExpiry = Date(timeIntervalSinceNow: 3600)
        try store.save(SavedSession(value: "new-fixture", expires: newExpiry), requiresUnlock: false)
        XCTAssertEqual(try store.load(context: nil)?.value, "new-fixture")
        XCTAssertEqual(try XCTUnwrap(store.info()).expires.timeIntervalSince1970, newExpiry.timeIntervalSince1970, accuracy: 0.001)
        store.clear()
        XCTAssertNil(store.info())
        XCTAssertNil(try store.load(context: nil))
    }

    func testOlderEntryWithoutSeparateDiscoveryStillRestores() throws {
        let service = "com.schoolity.tests.\(UUID().uuidString)"
        let store = KeychainSessionStore(service: service)
        defer { store.clear() }
        let saved = SavedSession(value: "legacy-fixture", expires: .distantFuture)
        let info = SavedSessionInfo(expires: saved.expires, requiresUnlock: false)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "schoolity_session",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: try JSONEncoder().encode(saved),
            kSecAttrGeneric as String: try JSONEncoder().encode(info)
        ]
        XCTAssertEqual(SecItemAdd(query as CFDictionary, nil), errSecSuccess)
        XCTAssertEqual(store.info()?.expires, saved.expires)
        XCTAssertEqual(try store.load(context: nil)?.value, saved.value)
        try store.save(saved, requiresUnlock: false)
        XCTAssertEqual(KeychainSessionStore(service: service).info()?.canRenew, false)
    }

    func testAuthenticationAndTemporaryErrorsAreNotMissingAccounts() throws {
        for status in [errSecInteractionNotAllowed, errSecAuthFailed, errSecNotAvailable, errSecMissingEntitlement] {
            let info = try XCTUnwrap(KeychainSessionStore.discoveryFallback(itemStatus: status, metadataStatus: errSecItemNotFound))
            XCTAssertTrue(info.requiresUnlock)
            XCTAssertTrue(info.isValid)
        }
        XCTAssertNotNil(KeychainSessionStore.discoveryFallback(itemStatus: errSecItemNotFound, metadataStatus: errSecInteractionNotAllowed))
        XCTAssertNil(KeychainSessionStore.discoveryFallback(itemStatus: errSecItemNotFound, metadataStatus: errSecItemNotFound))
    }
}
