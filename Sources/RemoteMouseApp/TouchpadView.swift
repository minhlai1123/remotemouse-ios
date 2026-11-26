import SwiftUI
import RemoteMouseCore

public struct TouchpadView: View {
    @ObservedObject var viewModel: TouchpadViewModel
    @State private var showSettings: Bool = false
    @State private var showKeyboard: Bool = false
    @State private var showQRScanner: Bool = false
    @State private var showHistory: Bool = false
    @State private var inputPin: String = ""

    public init(viewModel: TouchpadViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar: Status & Quick Controls (Optimized for iPhone 8 4.7" display)
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.statusColor)
                    .frame(width: 10, height: 10)
                Text(viewModel.statusText)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .foregroundColor(.secondary)

                Spacer()

                // QR Scanner Button
                Button(action: { showQRScanner = true }) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(6)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }

                // Paired History Button
                Button(action: { showHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(6)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }

                // Keyboard Toggle Button
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showKeyboard.toggle() } }) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(6)
                        .background(showKeyboard ? Color.accentColor : Color(.tertiarySystemBackground))
                        .foregroundColor(showKeyboard ? .white : .primary)
                        .cornerRadius(8)
                }

                // Settings Toggle Button
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showSettings.toggle() } }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(6)
                        .background(showSettings ? Color.accentColor : Color(.tertiarySystemBackground))
                        .foregroundColor(showSettings ? .white : .primary)
                        .cornerRadius(8)
                }

                // Connect / Disconnect Button
                if viewModel.state == .disconnected || viewModel.state == .failed("") {
                    Button("Connect") {
                        viewModel.connect()
                    }
                    .font(.caption2.bold())
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Disconnect") {
                        viewModel.disconnect()
                    }
                    .font(.caption2.bold())
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))

            // Manual IP Input Bar (shown when disconnected)
            if viewModel.state == .disconnected || viewModel.state == .failed("") {
                HStack(spacing: 8) {
                    Image(systemName: "desktopcomputer")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("PC IP (e.g. 192.168.1.5)", text: $viewModel.host)
                        .font(.caption)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemBackground))
            }

            // PIN Entry Bar (shown when pairing is required)
            if viewModel.state == .pairingRequired {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.orange)
                        .font(.caption)
                    TextField("Enter 6-digit PIN", text: $inputPin)
                        .font(.caption)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    Button("Pair") {
                        viewModel.authenticate(pin: inputPin)
                    }
                    .font(.caption2.bold())
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
            }

            // Collapsible Settings Bar (Sensitivity, Natural Scroll, Left-Handed)
            if showSettings {
                VStack(spacing: 8) {
                    HStack {
                        Text(String(format: "Sensitivity: %.1fx", viewModel.gestureManager.ballistics.sensitivity))
                            .font(.caption2)
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
                        .font(.caption2)

                        Toggle("Left-Handed", isOn: Binding(
                            get: { viewModel.gestureManager.isLeftHanded },
                            set: {
                                viewModel.gestureManager.isLeftHanded = $0
                                viewModel.gestureManager.savePreferences()
                                viewModel.objectWillChange.send()
                            }
                        ))
                        .font(.caption2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Collapsible Keyboard Section
            if showKeyboard {
                KeyboardView(keyboardManager: viewModel.keyboardManager)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Main Touchpad Area (Maximized space for iPhone 8)
            GeometryReader { _ in
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(.separator), lineWidth: 1)
                        )

                    VStack(spacing: 4) {
                        Image(systemName: "hand.tap")
                            .font(.title3)
                            .foregroundColor(Color(.tertiaryLabel))
                        Text("Touchpad Area\nDrag to move • Tap to click\n2-finger scroll with inertia")
                            .multilineTextAlignment(.center)
                            .font(.caption2)
                            .foregroundColor(Color(.tertiaryLabel))
                    }
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
            .padding([.horizontal, .top], 8)

            // Scroll Bar & Physical Button Simulation (Compact 50pt for iPhone 8)
            HStack(spacing: 8) {
                Button(action: {
                    if viewModel.gestureManager.isLeftHanded {
                        viewModel.gestureManager.onSecondaryClick()
                    } else {
                        viewModel.gestureManager.onPrimaryClick()
                    }
                }) {
                    Text(viewModel.gestureManager.isLeftHanded ? "Right Click" : "Left Click")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, maxHeight: 50)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(10)
                }

                // Middle / 2-finger scroll simulator area
                VStack(spacing: 2) {
                    Image(systemName: "chevron.up")
                        .font(.caption2)
                    Image(systemName: "line.3.horizontal")
                        .font(.caption2)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .frame(width: 44, height: 50)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(10)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            viewModel.handleScroll(translationX: Double(value.translation.width), translationY: Double(value.translation.height))
                        }
                        .onEnded { _ in
                            viewModel.handleScrollEnd()
                        }
                )

                Button(action: {
                    if viewModel.gestureManager.isLeftHanded {
                        viewModel.gestureManager.onPrimaryClick()
                    } else {
                        viewModel.gestureManager.onSecondaryClick()
                    }
                }) {
                    Text(viewModel.gestureManager.isLeftHanded ? "Left Click" : "Right Click")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, maxHeight: 50)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView(
                onScanned: { qr in
                    showQRScanner = false
                    viewModel.connectWithQR(qr)
                },
                onCancel: {
                    showQRScanner = false
                }
            )
        }
        .sheet(isPresented: $showHistory) {
            PairedHistoryView(
                onSelectDevice: { device in
                    showHistory = false
                    viewModel.connectWithDevice(device)
                },
                onScanQR: {
                    showHistory = false
                    showQRScanner = true
                }
            )
        }
    }
}

public final class TouchpadViewModel: ObservableObject, RMPPClientDelegate {
    @Published public var state: ConnectionState = .disconnected
    @Published public var statusText: String = "Disconnected"
    @Published public var host: String = "192.168.1.100"
    @Published public var pin: String = ""
    @Published public var expectedFingerprint: String = ""

    private let client = RMPPClient()
    public let gestureManager: GestureManager
    public let keyboardManager: KeyboardManager

    public init() {
        self.gestureManager = GestureManager(client: client)
        self.keyboardManager = KeyboardManager(client: client)
        if let savedHost = UserDefaults.standard.string(forKey: "last_host"), !savedHost.isEmpty {
            self.host = savedHost
        }
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

    public func connect(host: String? = nil, port: UInt16? = nil, fingerprint: String? = nil) {
        if let h = host { self.host = h }
        if let fp = fingerprint { self.expectedFingerprint = fp }

        let targetHost = self.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetHost.isEmpty else { return }
        UserDefaults.standard.set(targetHost, forKey: "last_host")

        let fp = expectedFingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
        client.connect(host: targetHost, port: port ?? RMPPConstants.defaultPort, expectedFingerprint: fp.isEmpty ? nil : fp)
    }

    public func connectWithQR(_ qr: ParsedQRData) {
        self.host = qr.ip
        self.pin = qr.pin
        self.expectedFingerprint = qr.fingerprint
        connect(host: qr.ip, port: UInt16(qr.port), fingerprint: qr.fingerprint)
    }

    public func connectWithDevice(_ device: PairedDevice) {
        self.host = device.lastAddress
        self.expectedFingerprint = device.fingerprint
        connect(host: device.lastAddress, port: UInt16(device.port), fingerprint: device.fingerprint)
    }

    public func authenticate(pin: String) {
        self.pin = pin
        client.authenticate(pin: pin, deviceName: "iPhone 8")
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
            case .connectedController: self.statusText = "Connected"
            case .connectedPassive: self.statusText = "Connected (Standby)"
            case .reconnectWait: self.statusText = "Reconnecting..."
            case .pairingRequired:
                self.statusText = "Pairing Required"
                if !self.pin.isEmpty {
                    client.authenticate(pin: self.pin, deviceName: "iPhone 8")
                }
            case .failed(let err): self.statusText = "Error: \(err)"
            }
        }
    }

    public func rmppClient(_ client: RMPPClient, didReceiveFrame frame: RMPPFrame) {}
    public func rmppClient(_ client: RMPPClient, didEncounterError error: Error) {}
    public func rmppClient(_ client: RMPPClient, didReceivePairingToken token: String, forHost host: String) {
        let device = PairedDevice(
            id: UUID().uuidString,
            name: "Desktop PC",
            lastAddress: host,
            port: Int(RMPPConstants.defaultPort),
            fingerprint: expectedFingerprint,
            pairedAt: Date(),
            lastConnected: Date()
        )
        PairedDeviceHistoryManager.shared.saveDevice(device)
    }
}
