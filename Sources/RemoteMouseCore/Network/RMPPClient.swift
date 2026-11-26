import Foundation
import Network
import CryptoKit
import Security

public enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case tlsHandshake
    case authenticating
    case connectedController
    case connectedPassive
    case reconnectWait
    case pairingRequired
    case failed(String)
}

public protocol RMPPClientDelegate: AnyObject {
    func rmppClient(_ client: RMPPClient, didChangeState state: ConnectionState)
    func rmppClient(_ client: RMPPClient, didReceiveFrame frame: RMPPFrame)
    func rmppClient(_ client: RMPPClient, didEncounterError error: Error)
    func rmppClient(_ client: RMPPClient, didReceivePairingToken token: String, forHost host: String)
}

public extension RMPPClientDelegate {
    func rmppClient(_ client: RMPPClient, didReceivePairingToken token: String, forHost host: String) {}
}

public final class RMPPClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.remotemouse.network", qos: .userInteractive)
    private let parser = RMPPStreamParser()
    private var sequenceNumber: UInt32 = 0
    private var heartbeatTimer: DispatchSourceTimer?
    private var reconnectTimer: DispatchSourceTimer?

    // Session Parameters for Auto-Reconnect
    private var currentHost: String?
    private var currentPort: UInt16 = RMPPConstants.defaultPort
    private var currentFingerprint: String?
    private var currentClientUUID: String = UUID().uuidString
    private var currentPairingToken: String?
    private var reconnectAttempts = 0
    private var isUserInitiatedDisconnect = false

    public static let maxReconnectAttempts = 10
    public static let maxBackoffSeconds = 10.0

    public weak var delegate: RMPPClientDelegate?
    public private(set) var state: ConnectionState = .disconnected {
        didSet {
            delegate?.rmppClient(self, didChangeState: state)
        }
    }

    public var isConnected: Bool {
        return state == .connectedController || state == .connectedPassive
    }

    public init() {}

    public static func computeSha256Fingerprint(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func connect(host: String, port: UInt16 = RMPPConstants.defaultPort, expectedFingerprint: String?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isUserInitiatedDisconnect = false
            self.currentHost = host
            self.currentPort = port
            self.currentFingerprint = expectedFingerprint
            self.stopReconnectTimer()
            self.executeConnect(host: host, port: port, expectedFingerprint: expectedFingerprint)
        }
    }

    private func executeConnect(host: String, port: UInt16, expectedFingerprint: String?) {
        state = .connecting

        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            state = .failed("Invalid port: \(port)")
            return
        }

        // Fingerprint is mandatory for secure pinning
        guard let rawFp = expectedFingerprint?.trimmingCharacters(in: .whitespacesAndNewlines), !rawFp.isEmpty else {
            state = .failed("MISSING_FINGERPRINT: Host certificate fingerprint is mandatory")
            return
        }
        let cleanExpected = rawFp.replacingOccurrences(of: ":", with: "").lowercased()
        guard cleanExpected.count == 64 && cleanExpected.allSatisfy({ $0.isHexDigit }) else {
            state = .failed("INVALID_FINGERPRINT_FORMAT: Host certificate fingerprint must be 64 hex characters")
            return
        }

        state = .tlsHandshake

        // Configure TLS 1.3 with verify block for Fingerprint Pinning
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv13)
        sec_protocol_options_set_max_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv13)

        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
            let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
            guard let cert = SecTrustGetCertificateAtIndex(trust, 0) else {
                sec_protocol_verify_complete(false)
                return
            }
            let certData = SecCertificateCopyData(cert) as Data
            let computedFp = RMPPClient.computeSha256Fingerprint(data: certData)
            if computedFp.caseInsensitiveCompare(cleanExpected) == .orderedSame {
                sec_protocol_verify_complete(true)
            } else {
                sec_protocol_verify_complete(false)
            }
        }, self.queue)

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true

        let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)

        let conn = NWConnection(host: nwHost, port: nwPort, using: params)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] newState in
            self?.handleStateUpdate(newState)
        }

        conn.start(queue: self.queue)
    }

    public func disconnect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isUserInitiatedDisconnect = true
            self.stopHeartbeat()
            self.stopReconnectTimer()
            self.reconnectAttempts = 0
            self.connection?.cancel()
            self.connection = nil
            self.parser.reset()
            self.state = .disconnected
        }
    }

    public func authenticate(pin: String, deviceName: String = "iOS-Device", clientUUID: String = UUID().uuidString) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.currentClientUUID = clientUUID
            self.state = .authenticating

            let payloadDict: [String: String] = [
                "client_uuid": clientUUID,
                "device_name": deviceName,
                "pin": pin
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict, options: [.sortedKeys]) else {
                self.state = .failed("Failed to serialize auth JSON")
                return
            }

            let frame = ExtendedFrame(
                msgType: RMPPConstants.msgAuthRequest,
                seq: self.nextSequence(),
                payload: jsonData
            )

            self.sendFrame(frame)
        }
    }

    public func resume(pairingToken: String, deviceName: String = "iOS-Device", clientUUID: String = UUID().uuidString) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.currentClientUUID = clientUUID
            self.currentPairingToken = pairingToken
            self.state = .authenticating

            // Step 1: Send Challenge Request via msgAuthResume
            let payloadDict: [String: String] = [
                "client_uuid": clientUUID,
                "device_name": deviceName
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict, options: [.sortedKeys]) else {
                self.state = .failed("Failed to serialize challenge request")
                return
            }

            let frame = ExtendedFrame(
                msgType: RMPPConstants.msgAuthResume,
                seq: self.nextSequence(),
                payload: jsonData
            )

            self.sendFrame(frame)
        }
    }

    private func sendResumeChallengeResponse(challenge: String) {
        guard let token = currentPairingToken else {
            state = .pairingRequired
            return
        }

        let payloadDict: [String: String] = [
            "client_uuid": currentClientUUID,
            "challenge": challenge,
            "pairing_token": token,
            "device_name": "iOS-Device"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict, options: [.sortedKeys]) else {
            state = .failed("Failed to serialize resume challenge response")
            return
        }

        let frame = ExtendedFrame(
            msgType: RMPPConstants.msgAuthResume,
            seq: nextSequence(),
            payload: jsonData
        )

        sendFrame(frame)
    }

    // Input Events - Strictly isolated to connectedController
    public func sendMouseMove(dx: Int16, dy: Int16) {
        queue.async { [weak self] in
            guard let self = self, self.state == .connectedController else { return }
            let frame = CompactFrame(
                msgType: RMPPConstants.msgMouseMove,
                seq: self.nextSequence(),
                data1: dx,
                data2: dy
            )
            self.sendFrame(frame)
        }
    }

    public func sendMouseDown(button: UInt16 = RMPPConstants.buttonLeft) {
        queue.async { [weak self] in
            guard let self = self, self.state == .connectedController else { return }
            let frame = CompactFrame(
                msgType: RMPPConstants.msgMouseDown,
                seq: self.nextSequence(),
                data1: Int16(bitPattern: button),
                data2: 0
            )
            self.sendFrame(frame)
        }
    }

    public func sendMouseUp(button: UInt16 = RMPPConstants.buttonLeft) {
        queue.async { [weak self] in
            guard let self = self, self.state == .connectedController else { return }
            let frame = CompactFrame(
                msgType: RMPPConstants.msgMouseUp,
                seq: self.nextSequence(),
                data1: Int16(bitPattern: button),
                data2: 0
            )
            self.sendFrame(frame)
        }
    }

    public func sendMouseClick(button: UInt16 = RMPPConstants.buttonLeft, clickCount: UInt8 = 1) {
        queue.async { [weak self] in
            guard let self = self, self.state == .connectedController else { return }
            let frame = CompactFrame(
                msgType: RMPPConstants.msgMouseClick,
                seq: self.nextSequence(),
                data1: Int16(bitPattern: button),
                data2: Int16(clickCount)
            )
            self.sendFrame(frame)
        }
    }

    public func sendMouseScroll(hWheel: Int16, vWheel: Int16) {
        queue.async { [weak self] in
            guard let self = self, self.state == .connectedController else { return }
            let frame = CompactFrame(
                msgType: RMPPConstants.msgMouseScroll,
                seq: self.nextSequence(),
                data1: hWheel, // Data1: dwHWheel (horizontal scroll)
                data2: vWheel  // Data2: dwWheel (vertical scroll)
            )
            self.sendFrame(frame)
        }
    }

    // MARK: - Keyboard Input Dispatching (Strictly isolated to connectedController)

    public func sendKeyDown(vkCode: UInt16) {
        queue.async { [weak self] in
            guard let self = self, self.state == .connectedController else { return }
            let frame = CompactFrame(
                msgType: RMPPConstants.msgKeyDown,
                seq: self.nextSequence(),
                data1: Int16(bitPattern: vkCode),
                data2: 0
            )
            self.sendFrame(frame)
        }
    }

    public func sendKeyUp(vkCode: UInt16) {
        queue.async { [weak self] in
            guard let self = self, self.state == .connectedController else { return }
            let frame = CompactFrame(
                msgType: RMPPConstants.msgKeyUp,
                seq: self.nextSequence(),
                data1: Int16(bitPattern: vkCode),
                data2: 0
            )
            self.sendFrame(frame)
        }
    }

    public func sendKeyClick(vkCode: UInt16) {
        sendKeyDown(vkCode: vkCode)
        sendKeyUp(vkCode: vkCode)
    }

    public func sendTextInput(_ text: String) {
        queue.async { [weak self] in
            guard let self = self, self.state == .connectedController else { return }
            guard !text.isEmpty else { return }
            // Normalize Unicode NFC canonical composition
            let normalized = text.precomposedStringWithCanonicalMapping
            guard let payload = normalized.data(using: .utf8), !payload.isEmpty, payload.count <= RMPPConstants.maxPayloadSize else { return }
            let frame = ExtendedFrame(
                msgType: RMPPConstants.msgTextInput,
                seq: self.nextSequence(),
                payload: payload
            )
            self.sendFrame(frame)
        }
    }

    public func sendSafetyReleaseAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let frame = CompactFrame(
                msgType: RMPPConstants.msgSafetyReleaseAll,
                seq: self.nextSequence(),
                data1: 0,
                data2: 0
            )
            self.sendFrame(frame)
        }
    }

    private func sendHeartbeat() {
        guard isConnected else { return }
        let now = UInt32(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 65536) * 1000)
        let frame = CompactFrame(
            msgType: RMPPConstants.msgHeartbeatPing,
            seq: nextSequence(),
            data1: Int16(bitPattern: UInt16(now & 0xFFFF)),
            data2: 0
        )
        sendFrame(frame)
    }

    private func sendFrame(_ frame: RMPPFrame) {
        let data = frame.serialize()
        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.delegate?.rmppClient(self!, didEncounterError: error)
            }
        })
    }

    private func nextSequence() -> UInt32 {
        sequenceNumber &+= 1
        return sequenceNumber
    }

    private func handleStateUpdate(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            startReceive()
            // If pairing token exists, initiate resume automatically
            if let token = currentPairingToken {
                resume(pairingToken: token, clientUUID: currentClientUUID)
            }
        case .failed(let error):
            stopHeartbeat()
            handleConnectionDrop(reason: error.localizedDescription)
        case .cancelled:
            stopHeartbeat()
            if !isUserInitiatedDisconnect {
                handleConnectionDrop(reason: "Connection cancelled")
            } else {
                state = .disconnected
            }
        default:
            break
        }
    }

    private func handleConnectionDrop(reason: String) {
        let canReconnect = !isUserInitiatedDisconnect &&
            state != .pairingRequired &&
            currentPairingToken != nil &&
            currentHost != nil &&
            reconnectAttempts < RMPPClient.maxReconnectAttempts

        if canReconnect {
            reconnectAttempts += 1
            // Exponential backoff: 1s, 2s, 4s, 8s, max 10s
            let backoff = min(pow(2.0, Double(reconnectAttempts - 1)), RMPPClient.maxBackoffSeconds)
            state = .reconnectWait

            stopReconnectTimer()
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + backoff)
            timer.setEventHandler { [weak self] in
                guard let self = self, !self.isUserInitiatedDisconnect else { return }
                self.stopReconnectTimer()
                if let host = self.currentHost {
                    self.executeConnect(host: host, port: self.currentPort, expectedFingerprint: self.currentFingerprint)
                }
            }
            timer.resume()
            reconnectTimer = timer
        } else {
            if state != .pairingRequired {
                state = .failed(reason)
            }
        }
    }

    private func startReceive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let data = content, !data.isEmpty {
                let frames = self.parser.feed(data)
                for frame in frames {
                    self.processIncomingFrame(frame)
                }
            }

            if isComplete {
                self.handleConnectionDrop(reason: "Remote host closed connection")
            } else if let error = error {
                self.delegate?.rmppClient(self, didEncounterError: error)
                self.handleConnectionDrop(reason: error.localizedDescription)
            } else {
                self.startReceive()
            }
        }
    }

    private func processIncomingFrame(_ frame: RMPPFrame) {
        delegate?.rmppClient(self, didReceiveFrame: frame)

        if let compact = frame as? CompactFrame {
            if compact.msgType == RMPPConstants.msgHeartbeatPong {
                // Heartbeat response acknowledged
            }
        } else if let extended = frame as? ExtendedFrame {
            if extended.msgType == RMPPConstants.msgAuthResponse {
                guard let json = (try? JSONSerialization.jsonObject(with: extended.payload)) as? [String: Any],
                      let status = json["status"] as? String else {
                    state = .failed("Invalid authentication response format")
                    return
                }

                if status == "CHALLENGE" {
                    if let challenge = json["challenge"] as? String {
                        sendResumeChallengeResponse(challenge: challenge)
                    } else {
                        state = .failed("Challenge missing from server response")
                    }
                } else if status == "SUCCESS" {
                    reconnectAttempts = 0
                    let role = (json["role"] as? String) ?? "ACTIVE_CONTROLLER"
                    state = (role == "PASSIVE_STANDBY") ? .connectedPassive : .connectedController

                    if let pairingToken = json["pairing_token"] as? String, let host = currentHost {
                        currentPairingToken = pairingToken
                        delegate?.rmppClient(self, didReceivePairingToken: pairingToken, forHost: host)
                    }
                    startHeartbeat()
                } else {
                    let reason = (json["reason"] as? String) ?? "Authentication rejected"
                    if reason == "TOKEN_REVOKED" || reason == "DEVICE_NOT_PAIRED" || reason == "TOKEN_INVALID" {
                        state = .pairingRequired
                    } else {
                        state = .failed(reason)
                    }
                }
            }
        }
    }

    private func startHeartbeat() {
        stopHeartbeat()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            self?.sendHeartbeat()
        }
        timer.resume()
        heartbeatTimer = timer
    }

    private func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    private func stopReconnectTimer() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
    }
}
