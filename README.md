# Remote Mouse Pro — iOS Client (Swift / SwiftUI)

Native iOS implementation for **Remote Mouse Pro**, converting an iPhone or iPad into an ultra-low latency wireless trackpad, mouse, and multimedia keyboard for Windows and cross-platform desktop hosts.

Conforms to the **RMPP (Remote Mouse Packet Protocol) v1.1 Specification**.

---

## 🌟 Key Features

### 1. Advanced Touchpad & Pointer Ballistics
- **Multi-Touch Gestures**: Single-finger move, primary click (tap), secondary click (two-finger tap), and double-tap drag-and-drop.
- **Dual-Finger Scrolling**: Smooth inertia scrolling with configurable Natural Scroll direction.
- **Pointer Ballistics Engine**: Non-linear velocity acceleration curve, clamped max acceleration ($2.8\times$), and configurable sensitivity ($0.5\times - 3.0\times$).
- **Left-Handed Mode**: Seamless swap of primary and secondary click buttons.

### 2. Virtual Keyboard & Unicode Input
- **Sticky Modifiers**: Latching toggle for `Ctrl`, `Alt`, `Shift`, and `Win` (Super/Command) keys.
- **Specialized Keycodes**: Direct shortcuts for `Esc`, `Tab`, `Enter`, `Backspace`, `Delete`, `F5`, and `F11`.
- **Vietnamese Unicode Support**: Native IME input buffering, streaming full Unicode characters (Telex/VNI) to Desktop Host via `MSG_TEXT_INPUT` (Opcode `0x05`).

### 3. Banking-Grade Security & Pairing
- **Strict TLS 1.3**: Zero plaintext fallback; full session traffic encrypted under TLS 1.3 via Apple `Network.framework` (`NWConnection`).
- **SHA-256 Certificate Fingerprint Pinning (TOFU)**: Instant host identity verification against certificate fingerprint encoded in pairing QR code or discovery payload.
- **Single-Use Challenge-Response PIN**: Time-bound numeric PIN verification preventing replay attacks.
- **Hardware Keychain Storage**: Encrypted storage for pairing tokens and host fingerprints via `KeychainTokenStorage`.

### 4. Zero-Configuration Discovery & QR Scanner
- **mDNS / Bonjour Discovery**: Automatic host resolution using Apple `NWBrowser` for service `_rmpp._tcp.local`.
- **UDP Broadcast Fallback**: Passive listener on port `54322` when multicast DNS is restricted by local network topology.
- **Camera QR Scanner**: Built-in `AVFoundation` camera feed for 1-second instant pairing via QR code.

---

## 🏗 Architecture & Modules

```text
ios_client/
├── Package.swift                             # Swift Package Manager Manifest
├── Sources/
│   ├── RemoteMouseApp/                       # SwiftUI Views & UI Components
│   │   ├── TouchpadView.swift                # Gesture surface, click buttons & sensitivity bar
│   │   ├── KeyboardView.swift                # Virtual keyboard, IME buffer & sticky modifiers
│   │   ├── QRScannerView.swift               # AVFoundation camera scanner for QR pairing
│   │   └── PairedHistoryView.swift           # Paired desktop host history & quick-reconnect
│   └── RemoteMouseCore/                      # Headless Core Business Logic & Protocol
│       ├── Network/                          # NWConnection, TLS 1.3, state machine & watchdog
│       ├── Protocol/                         # RMPP binary frames, CRC16 checksum & stream parser
│       ├── Input/                            # Gesture recognizer, ballistics & keyboard manager
│       ├── Security/                         # Keychain token storage & cryptographic validation
│       ├── Discovery/                        # NWBrowser mDNS & UDP fallback broadcaster
│       └── QR/                               # RMPP URI parser & QR fingerprint validator
└── Tests/
    └── RemoteMouseCoreTests/                 # Unit tests for protocol, ballistics, QR & keyboard
```

---

## 📋 Requirements & Compatibility

- **Language**: Swift 5.9+
- **Platforms**:
  - iOS 15.0+ / iPadOS 15.0+
  - macOS 12.0+ (Universal Swift Package)
- **Frameworks**:
  - `Network.framework` (TLS 1.3 & TCP transport)
  - `SwiftUI` (Declarative interface)
  - `AVFoundation` (QR code scanning)
  - `Security` (iOS Keychain Services)

---

## 🚀 Building & Testing

### Using Swift Package Manager (CLI)
```bash
# Build the core library
swift build

# Run unit tests
swift test
```

### Using Xcode
1. Open Xcode.
2. Select **File > Open...** and choose the `Package.swift` file (or the folder containing it).
3. Select an iOS Simulator or connected physical iOS device.
4. Press `Cmd + B` to build, or `Cmd + U` to execute unit tests.

---

## 📄 License
Internal proprietary project — Remote Mouse Pro. All rights reserved.
