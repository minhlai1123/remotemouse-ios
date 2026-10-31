import Foundation
import Network

/// Fallback UDP Broadcast Discovery Listener for iOS using Apple Network.framework NWListener.
/// Listens on port 54322 for periodic discovery datagrams when mDNS is blocked by AP Isolation.
/// Conforms to ADR 3.4-B, ADR-01, and ADR-03.
public class UDPDiscoveryListener {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.remotemouse.discovery.udp", qos: .utility)
    public private(set) var isListening: Bool = false

    public static let defaultPort: UInt16 = 54322
    public static let maxDatagramSize = 1024
    public static let discoveryMagic = "RMPP_DISCOVERY"

    public init() {}

    /// Starts listening for UDP broadcast announcements.
    public func start(
        port: UInt16 = defaultPort,
        onHostFound: @escaping (DiscoveredHost) -> Void
    ) {
        guard !isListening else { return }

        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true

            guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
            let nwListener = try NWListener(using: params, on: nwPort)

            nwListener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isListening = true
                case .failed(let error):
                    print("[UDPDiscoveryListener] Listener failed: \(error)")
                    self?.stop()
                case .cancelled:
                    self?.isListening = false
                default:
                    break
                }
            }

            nwListener.newConnectionHandler = { [weak self] connection in
                self?.handleIncomingConnection(connection, onHostFound: onHostFound)
            }

            self.listener = nwListener
            nwListener.start(queue: queue)
        } catch {
            print("[UDPDiscoveryListener] Failed to initialize listener on port \(port): \(error)")
        }
    }

    private func handleIncomingConnection(
        _ connection: NWConnection,
        onHostFound: @escaping (DiscoveredHost) -> Void
    ) {
        connection.start(queue: queue)
        connection.receiveMessage { content, context, isComplete, error in
            defer { connection.cancel() }
            guard let data = content, error == nil, data.count <= Self.maxDatagramSize else { return }

            var senderIp = "unknown"
            if case .hostPort(let host, _) = connection.endpoint {
                senderIp = "\(host)"
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let magic = json["magic"] as? String, magic == Self.discoveryMagic,
                  let version = json["v"] as? Int, version == 2,
                  let name = json["name"] as? String, !name.isEmpty,
                  let targetPort = json["port"] as? Int, (1...65535).contains(targetPort),
                  let fp = json["fp"] as? String, fp.count == 64
            else {
                return
            }

            let discovered = DiscoveredHost(
                name: name,
                address: senderIp,
                port: targetPort,
                fingerprint: fp.lowercased(),
                version: version,
                source: .udpFallback
            )

            DispatchQueue.main.async {
                onHostFound(discovered)
            }
        }
    }

    /// Stops listening and cleans up network socket.
    public func stop() {
        guard isListening || listener != nil else { return }
        listener?.cancel()
        listener = nil
        isListening = false
    }

    deinit {
        stop()
    }
}
