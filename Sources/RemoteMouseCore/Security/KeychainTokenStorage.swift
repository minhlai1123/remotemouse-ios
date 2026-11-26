import Foundation
import Security

public struct IOSPairingRecord: Codable, Equatable {
    public var val: String? // reserved
    public let host: String
    public let clientUUID: String
    public let pairingToken: String
    public let hostFingerprint: String

    public init(host: String, clientUUID: String, pairingToken: String, hostFingerprint: String, val: String? = nil) {
        self.val = val
        self.host = host
        self.clientUUID = clientUUID
        self.pairingToken = pairingToken
        self.hostFingerprint = hostFingerprint
    }
}

/// Secure Pairing Token Storage for iOS using Apple Keychain Services.
/// Configured with kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly to prevent
/// unencrypted backup leakage and cross-device sync.
public final class KeychainTokenStorage {

    public static let shared = KeychainTokenStorage()
    private let serviceName = "com.remotemouse.pairing"

    public init() {}

    @discardableResult
    public func savePairing(host: String, clientUUID: String, pairingToken: String, hostFingerprint: String) -> Bool {
        let record = IOSPairingRecord(
            host: host,
            clientUUID: clientUUID,
            pairingToken: pairingToken,
            hostFingerprint: hostFingerprint
        )

        guard let encodedData = try? JSONEncoder().encode(record) else {
            return false
        }

        // Delete any existing item for this host
        deletePairing(host: host)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: host,
            kSecValueData as String: encodedData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func getPairing(host: String) -> IOSPairingRecord? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: host,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(IOSPairingRecord.self, from: data)
    }

    @discardableResult
    public func deletePairing(host: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: host
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    @discardableResult
    public func deleteToken(for host: String) -> Bool {
        return deletePairing(host: host)
    }

    @discardableResult
    public func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
