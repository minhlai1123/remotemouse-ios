import Foundation

/// KeyboardManager handles virtual key mapping, sticky modifiers state,
/// and Unicode NFC text input normalization for the iOS client.
public final class KeyboardManager {

    public struct ModifierState: Equatable {
        public var isCtrlActive: Bool = false
        public var isAltActive: Bool = false
        public var isShiftActive: Bool = false
        public var isWinActive: Bool = false

        public init(isCtrlActive: Bool = false, isAltActive: Bool = false, isShiftActive: Bool = false, isWinActive: Bool = false) {
            self.isCtrlActive = isCtrlActive
            self.isAltActive = isAltActive
            self.isShiftActive = isShiftActive
            self.isWinActive = isWinActive
        }
    }

    public enum TargetOS {
        case windows
        case macOS
    }

    public var targetOS: TargetOS = .windows {
        didSet {
            notifyModifierChanged()
        }
    }

    private let client: RMPPClient
    private var modifierState = ModifierState()
    public var onModifierStateChanged: ((ModifierState) -> Void)?

    public var currentModifierState: ModifierState {
        return modifierState
    }

    // Standard Win32 Virtual-Key Codes
    public static let vkBack: UInt16 = 0x08
    public static let vkTab: UInt16 = 0x09
    public static let vkReturn: UInt16 = 0x0D
    public static let vkShift: UInt16 = 0x10
    public static let vkControl: UInt16 = 0x11
    public static let vkMenu: UInt16 = 0x12       // Alt key
    public static let vkPause: UInt16 = 0x13
    public static let vkCapital: UInt16 = 0x14
    public static let vkEscape: UInt16 = 0x1B
    public static let vkSpace: UInt16 = 0x20
    public static let vkPrior: UInt16 = 0x21      // Page Up
    public static let vkNext: UInt16 = 0x22       // Page Down
    public static let vkEnd: UInt16 = 0x23
    public static let vkHome: UInt16 = 0x24
    public static let vkLeft: UInt16 = 0x25
    public static let vkUp: UInt16 = 0x26
    public static let vkRight: UInt16 = 0x27
    public static let vkDown: UInt16 = 0x28
    public static let vkSnapshot: UInt16 = 0x2C   // Print Screen
    public static let vkInsert: UInt16 = 0x2D
    public static let vkDelete: UInt16 = 0x2E

    // Windows / Command Key
    public static let vkLWin: UInt16 = 0x5B
    public static let vkRWin: UInt16 = 0x5C

    // Function Keys F1 - F12
    public static let vkF1: UInt16 = 0x70
    public static let vkF2: UInt16 = 0x71
    public static let vkF3: UInt16 = 0x72
    public static let vkF4: UInt16 = 0x73
    public static let vkF5: UInt16 = 0x74
    public static let vkF6: UInt16 = 0x75
    public static let vkF7: UInt16 = 0x76
    public static let vkF8: UInt16 = 0x77
    public static let vkF9: UInt16 = 0x78
    public static let vkF10: UInt16 = 0x79
    public static let vkF11: UInt16 = 0x7A
    public static let vkF12: UInt16 = 0x7B

    public init(client: RMPPClient, onModifierStateChanged: ((ModifierState) -> Void)? = nil) {
        self.client = client
        self.onModifierStateChanged = onModifierStateChanged
    }

    /// Normalizes text to Unicode NFC (precomposed canonical mapping).
    public static func normalizeToNFC(_ text: String) -> String {
        return text.precomposedStringWithCanonicalMapping
    }

    /// Sends a text string to the host with canonical NFC composition.
    /// Safe logging: Never logs keystroke text.
    public func sendText(_ text: String) {
        guard !text.isEmpty else { return }
        let normalized = Self.normalizeToNFC(text)
        client.sendTextInput(normalized)
    }

    /// Sends a single Virtual Key tap (down followed by up).
    public func sendKey(_ vkCode: UInt16) {
        client.sendKeyClick(vkCode: vkCode)
    }

    /// Toggles the Ctrl modifier.
    @discardableResult
    public func toggleCtrl() -> Bool {
        let newState = !modifierState.isCtrlActive
        modifierState.isCtrlActive = newState
        if newState {
            client.sendKeyDown(vkCode: Self.vkControl)
        } else {
            client.sendKeyUp(vkCode: Self.vkControl)
        }
        notifyModifierChanged()
        return newState
    }

    /// Toggles the Alt modifier (Option on macOS).
    @discardableResult
    public func toggleAlt() -> Bool {
        let newState = !modifierState.isAltActive
        modifierState.isAltActive = newState
        if newState {
            client.sendKeyDown(vkCode: Self.vkMenu)
        } else {
            client.sendKeyUp(vkCode: Self.vkMenu)
        }
        notifyModifierChanged()
        return newState
    }

    /// Toggles the Shift modifier.
    @discardableResult
    public func toggleShift() -> Bool {
        let newState = !modifierState.isShiftActive
        modifierState.isShiftActive = newState
        if newState {
            client.sendKeyDown(vkCode: Self.vkShift)
        } else {
            client.sendKeyUp(vkCode: Self.vkShift)
        }
        notifyModifierChanged()
        return newState
    }

    /// Toggles the Windows / Command modifier.
    @discardableResult
    public func toggleWin() -> Bool {
        let newState = !modifierState.isWinActive
        modifierState.isWinActive = newState
        if newState {
            client.sendKeyDown(vkCode: Self.vkLWin)
        } else {
            client.sendKeyUp(vkCode: Self.vkLWin)
        }
        notifyModifierChanged()
        return newState
    }

    /// Releases all currently held sticky modifiers.
    public func releaseAllModifiers() {
        if modifierState.isCtrlActive {
            client.sendKeyUp(vkCode: Self.vkControl)
        }
        if modifierState.isAltActive {
            client.sendKeyUp(vkCode: Self.vkMenu)
        }
        if modifierState.isShiftActive {
            client.sendKeyUp(vkCode: Self.vkShift)
        }
        if modifierState.isWinActive {
            client.sendKeyUp(vkCode: Self.vkLWin)
        }
        modifierState = ModifierState()
        notifyModifierChanged()
    }

    // Adaptive UI labels
    public var ctrlLabel: String { targetOS == .macOS ? "Control" : "Ctrl" }
    public var altLabel: String { targetOS == .macOS ? "Option" : "Alt" }
    public var shiftLabel: String { "Shift" }
    public var winLabel: String { targetOS == .macOS ? "Cmd" : "Win" }

    private func notifyModifierChanged() {
        onModifierStateChanged?(modifierState)
    }
}
