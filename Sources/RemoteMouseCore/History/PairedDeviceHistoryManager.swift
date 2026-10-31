import Foundation

/// Metadata record for a paired desktop host stored in iOS connection history.
/// 
/// STRICT SECURITY AUDIT:
/// - NEVER contains pairing token, PIN, or private key!
/// - Pairing tokens are stored separately and encrypted inside Keychain Services via KeychainTokenStorage.
public struct PairedDevice: Identifiable, Codable, Equatable {
    public let id: String // Host UUID
    public let name: String
    public let lastAddress: String
    public let port: Int
    public let fingerprint: String
    public let pairedAt: Date
    public let lastConnected: Date

    public init(
        id: String,
        name: String,
        lastAddress: String,
        port: Int,
        fingerprint: String,
        pairedAt: Date = Date(),
        lastConnected: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.lastAddress = lastAddress
        self.port = port
        self.fingerprint = fingerprint.lowercased()
        self.pairedAt = pairedAt
        self.lastConnected = lastConnected
    }
}

/// Manages Paired Devices History for iOS.
/// 
/// ARCHITECTURAL DISTINCTION:
/// - "forgetDevice(id)": Deletes local metadata and deletes local token from iOS Keychain.
///   Does NOT revoke the token on the Host (requires Host Dashboard or active revoke protocol call).
public class PairedDeviceHistoryManager: ObservableObject {
    public static let shared = PairedDeviceHistoryManager()

    private let userDefaultsKey = "com.remotemouse.paired_devices_history"
    private let tokenStorage: KeychainTokenStorage

    @Published public private(set) var devices: [PairedDevice] = []

    public init(tokenStorage: KeychainTokenStorage = KeychainTokenStorage()) {
        self.tokenStorage = tokenStorage
        loadDevices()
    }

    /// Loads paired devices list from UserDefaults.
    public func loadDevices() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let list = try? JSONDecoder().decode([PairedDevice].self, from: data)
        else {
            self.devices = []
            return
        }
        self.devices = list
    }

    /// Adds or updates a paired device record.
    public func saveDevice(_ device: PairedDevice) {
        var current = devices
        if let idx = current.firstIndex(where: { $0.id == device.id }) {
            current[idx] = device
        } else {
            current.insert(device, at: 0)
        }
        persistDevices(current)
    }

    /// Forgets a device locally:
    /// 1. Removes device record from history.
    /// 2. Deletes pairing token from Keychain.
    public func forgetDevice(id: String) {
        var current = devices
        current.removeAll { $0.id == id }
        persistDevices(current)
        tokenStorage.deleteToken(for: id)
    }

    private func persistDevices(_ list: [PairedDevice]) {
        self.devices = list
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
