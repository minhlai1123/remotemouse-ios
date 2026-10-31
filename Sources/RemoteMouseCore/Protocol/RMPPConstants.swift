import Foundation

/// RMPP v1.0 Protocol Constants
public enum RMPPConstants {
    public static let magic: UInt16 = 0x524D  // ASCII 'R', 'M'
    public static let protocolVersion: UInt8 = 0x01

    // Compact Frame Message Types (Fixed 16 bytes)
    public static let msgMouseMove: UInt8 = 0x01
    public static let msgMouseDown: UInt8 = 0x02
    public static let msgMouseUp: UInt8 = 0x03
    public static let msgMouseClick: UInt8 = 0x04
    public static let msgMouseScroll: UInt8 = 0x05
    public static let msgKeyDown: UInt8 = 0x10
    public static let msgKeyUp: UInt8 = 0x11
    public static let msgMediaControl: UInt8 = 0x20
    public static let msgSystemPower: UInt8 = 0x30
    public static let msgHeartbeatPing: UInt8 = 0x90
    public static let msgHeartbeatPong: UInt8 = 0x91
    public static let msgSafetyReleaseAll: UInt8 = 0xFF

    // Extended Frame Message Types (Variable length)
    public static let msgTextInput: UInt8 = 0x12
    public static let msgAuthRequest: UInt8 = 0x80
    public static let msgAuthResponse: UInt8 = 0x81
    public static let msgClipboardData: UInt8 = 0x82
    public static let msgAuthResume: UInt8 = 0x83
    public static let msgSessionError: UInt8 = 0xFE

    // Layout constants
    public static let compactFrameSize: Int = 16
    public static let extendedHeaderSize: Int = 12
    public static let maxPayloadSize: Int = 65535
    public static let maxAccumulatorBufferSize: Int = 262144

    public static let compactMsgTypes: Set<UInt8> = [
        msgMouseMove,
        msgMouseDown,
        msgMouseUp,
        msgMouseClick,
        msgMouseScroll,
        msgKeyDown,
        msgKeyUp,
        msgMediaControl,
        msgSystemPower,
        msgHeartbeatPing,
        msgHeartbeatPong,
        msgSafetyReleaseAll
    ]

    public static let extendedMsgTypes: Set<UInt8> = [
        msgTextInput,
        msgAuthRequest,
        msgAuthResponse,
        msgClipboardData,
        msgAuthResume,
        msgSessionError
    ]

    // Network defaults
    public static let defaultPort: UInt16 = 54321
    public static let defaultHeartbeatIntervalMs: UInt32 = 1000
    public static let defaultWatchdogTimeoutMs: UInt32 = 3000

    // Mouse Buttons
    public static let buttonLeft: UInt16 = 1
    public static let buttonRight: UInt16 = 2
    public static let buttonMiddle: UInt16 = 4

    // Auth Status
    public static let authSuccess: UInt16 = 0
    public static let authBadCredentials: UInt16 = 1
    public static let authRateLimited: UInt16 = 2
    public static let authProtocolMismatch: UInt16 = 3
    public static let authInternalError: UInt16 = 255
}
