import Foundation

/// Source of discovery for a candidate desktop host.
public enum DiscoverySource: String, Codable {
    case bonjour = "mDNS / Bonjour"
    case udpFallback = "UDP Broadcast"
    case manual = "Manual IP"
}

/// Candidate desktop host discovered on local network.
/// Untrusted locator: Identity MUST be authenticated via TLS 1.3 fingerprint pinning.
public struct DiscoveredHost: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let address: String
    public let port: Int
    public let fingerprint: String
    public let version: Int
    public let source: DiscoverySource
    public let lastSeen: Date

    public init(
        name: String,
        address: String,
        port: Int,
        fingerprint: String,
        version: Int = 2,
        source: DiscoverySource,
        lastSeen: Date = Date()
    ) {
        self.id = "\(fingerprint.lowercased())_\(port)"
        self.name = name
        self.address = address
        self.port = port
        self.fingerprint = fingerprint.lowercased()
        self.version = version
        self.source = source
        self.lastSeen = lastSeen
    }
}
