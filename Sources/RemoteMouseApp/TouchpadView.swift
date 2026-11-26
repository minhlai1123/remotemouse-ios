import SwiftUI
import RemoteMouseCore

public struct TouchpadView: View {
    @ObservedObject var viewModel: TouchpadViewModel

    public init(viewModel: TouchpadViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header: Connection Info & Status
            HStack {
                Circle()
                    .fill(viewModel.statusColor)
                    .frame(width: 12, height: 12)
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if viewModel.state == .disconnected || viewModel.state == .failed("") {
                    Button("Connect") {
                        viewModel.connect()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Disconnect") {
                        viewModel.disconnect()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(.systemBackground))

            // Settings Bar (Phase 3.3 Controls: Sensitivity, Natural Scroll, Left-Handed)
            VStack(spacing: 8) {
                HStack {
                    Text(String(format: "Sensitivity: %.1fx", viewModel.gestureManager.ballistics.sensitivity))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { viewModel.gestureManager.ballistics.sensitivity },
                            set: {
                                viewModel.gestureManager.ballistics.sensitivity = $0
                                viewModel.gestureManager.savePreferences()
                                viewModel.objectWillChange.send()
                            }
                        ),
                        in: 0.5...3.0,
                        step: 0.1
                    )
                }

                HStack(spacing: 16) {
                    Toggle("Natural Scroll", isOn: Binding(
                        get: { viewModel.gestureManager.isNaturalScroll },
                        set: {
                            viewModel.gestureManager.isNaturalScroll = $0
                            viewModel.gestureManager.savePreferences()
                            viewModel.objectWillChange.send()
                        }
                    ))
                    .font(.caption)

                    Toggle("Left-Handed", isOn: Binding(
                        get: { viewModel.gestureManager.isLeftHanded },
                        set: {
                            viewModel.gestureManager.isLeftHanded = $0
                            viewModel.gestureManager.savePreferences()
                            viewModel.objectWillChange.send()
                        }
                    ))
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))

            // Phase 3.5 Keyboard, Sticky Modifiers & Function Keys
            KeyboardView(keyboardManager: viewModel.keyboardManager)

            // Main Touchpad Area
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    
                    Text("Touchpad Area\nDrag to move • Tap to click\n2-finger scroll with inertia")
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            viewModel.handleDrag(value: value)
                        }
                        .onEnded { value in
                            viewModel.handleDragEnd(value: value)
                        }
                )
            }
            .padding([.horizontal, .top])

            // Scroll Bar & Physical Button Simulation with Left-Handed Swap
            HStack(spacing: 12) {
                // Left-most button (Primary in right-handed mode, Secondary in left-handed mode)
                Button(action: {
                    if viewModel.gestureManager.isLeftHanded {
                        viewModel.gestureManager.onSecondaryClick()
                    } else {
                        viewModel.gestureManager.onPrimaryClick()
                    }
                }) {
                    Text(viewModel.gestureManager.isLeftHanded ? "Right Click" : "Left Click")
                        .frame(maxWidth: .infinity, maxHeight: 60)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(12)
                }

                // Middle / 2-finger scroll simulator area
                VStack {
                    Image(systemName: "chevron.up")
                    Image(systemName: "line.3.horizontal")
                    Image(systemName: "chevron.down")
                }
                .frame(width: 50, height: 60)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            viewModel.handleScroll(translationX: Double(value.translation.width), translationY: Double(value.translation.height))
                        }
                        .onEnded { _ in
                            viewModel.handleScrollEnd()
                        }
                )

                // Right-most button (Secondary in right-handed mode, Primary in left-handed mode)
                Button(action: {
                    if viewModel.gestureManager.isLeftHanded {
                        viewModel.gestureManager.onPrimaryClick()
                    } else {
                        viewModel.gestureManager.onSecondaryClick()
                    }
                }) {
                    Text(viewModel.gestureManager.isLeftHanded ? "Left Click" : "Right Click")
                        .frame(maxWidth: .infinity, maxHeight: 60)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

public final class TouchpadViewModel: ObservableObject, RMPPClientDelegate {
    @Published public var state: ConnectionState = .disconnected
    @Published public var statusText: String = "Disconnected"
    @Published public var host: String = "192.168.1.100"
    @Published public var pin: String = "123456"
    @Published public var expectedFingerprint: String = ""

    private let client = RMPPClient()
    public let gestureManager: GestureManager
    public let keyboardManager: KeyboardManager

    public init() {
        self.gestureManager = GestureManager(client: client)
        self.keyboardManager = KeyboardManager(client: client)
        client.delegate = self
    }

    public var statusColor: Color {
        switch state {
        case .disconnected: return .gray
        case .connecting, .authenticating: return .orange
        case .connectedController, .connectedPassive: return .green
        case .reconnectWait, .pairingRequired: return .yellow
        case .tlsHandshake: return .blue
        case .failed: return .red
        }
    }

    public func connect() {
        let fp = expectedFingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
        client.connect(host: host, expectedFingerprint: fp.isEmpty ? nil : fp)
    }

    public func disconnect() {
        gestureManager.cancelInertia()
        keyboardManager.releaseAllModifiers()
        client.disconnect()
    }

    public func handleDrag(value: DragGesture.Value) {
        gestureManager.handleSingleFingerMove(location: value.location, translation: value.translation)
    }

    public func handleDragEnd(value: DragGesture.Value) {
        let translation = value.translation
        let dist = sqrt(translation.width * translation.width + translation.height * translation.height)
        if dist < 5.0 {
            gestureManager.onPrimaryClick()
        }
        gestureManager.handleSingleFingerEnd()
    }

    public func handleScroll(translationX: Double, translationY: Double) {
        gestureManager.handleTwoFingerScroll(translationX: translationX, translationY: translationY)
    }

    public func handleScrollEnd() {
        gestureManager.handleTwoFingerScrollEnd()
    }

    // MARK: - RMPPClientDelegate
    public func rmppClient(_ client: RMPPClient, didChangeState state: ConnectionState) {
        DispatchQueue.main.async {
            self.state = state
            if state != .connectedController {
                self.gestureManager.cancelInertia()
                self.keyboardManager.releaseAllModifiers()
            }
            switch state {
            case .disconnected: self.statusText = "Disconnected"
            case .connecting: self.statusText = "Connecting TCP..."
            case .tlsHandshake: self.statusText = "TLS 1.3 & Fingerprint..."
            case .authenticating: self.statusText = "Authenticating..."
            case .connectedController: self.statusText = "Connected (Active Controller)"
            case .connectedPassive: self.statusText = "Connected (Passive Standby)"
            case .reconnectWait: self.statusText = "Reconnecting..."
            case .pairingRequired: self.statusText = "Pairing Required (Enter PIN)"
            case .failed(let err): self.statusText = "Error: \(err)"
            }
        }
    }

    public func rmppClient(_ client: RMPPClient, didReceiveFrame frame: RMPPFrame) {}
    public func rmppClient(_ client: RMPPClient, didEncounterError error: Error) {}
    public func rmppClient(_ client: RMPPClient, didReceivePairingToken token: String, forHost host: String) {}
}
