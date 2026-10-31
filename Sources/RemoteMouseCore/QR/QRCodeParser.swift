import Foundation

/// Validated QR Pairing payload for iOS.
public struct ParsedQRData: Equatable {
    public let ip: String
    public let port: Int
    public let fingerprint: String
    public let pin: String
    public let version: Int

    public init(ip: String, port: Int, fingerprint: String, pin: String, version: Int = 2) {
        self.ip = ip
        self.port = port
        self.fingerprint = fingerprint.lowercased()
        self.pin = pin
        self.version = version
    }
}

/// QR Code URI Parser and Validator for Remote Mouse Pro (iOS).
/// Conforms to ADR 3.4-C, ADR-01, and ADR-03.
public enum QRCodeParser {
    public static let scheme = "rmpp"
    private static let fpRegex = try? NSRegularExpression(pattern: "^[0-9a-f]{64}$", options: .caseInsensitive)
    private static let pinRegex = try? NSRegularExpression(pattern: "^\\d{6}$")

    /// Parses and strictly validates a pairing QR URI string.
    /// Format: rmpp://<ip>:<port>?fp=<sha256_hex_64>&pin=<pin_6_digits>&v=2
    public static func parse(_ uriString: String?) -> ParsedQRData? {
        guard let str = uriString?.trimmingCharacters(in: .whitespacesAndNewlines),
              let components = URLComponents(string: str),
              components.scheme?.lowercased() == scheme,
              let rawHost = components.host,
              let port = components.port,
              (1...65535).contains(port),
              let queryItems = components.queryItems
        else {
            return nil
        }

        let cleanHost = (rawHost.hasPrefix("[") && rawHost.hasSuffix("]"))
            ? String(rawHost.dropFirst().dropLast())
            : rawHost

        guard !cleanHost.isEmpty else { return nil }

        var fp: String?
        var pin: String?
        var version: Int?

        for item in queryItems {
            switch item.name.lowercased() {
            case "fp":
                fp = item.value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            case "pin":
                pin = item.value?.trimmingCharacters(in: .whitespacesAndNewlines)
            case "v":
                if let vStr = item.value, let v = Int(vStr) {
                    version = v
                }
            default:
                break
            }
        }

        guard let validFp = fp, isValidFingerprint(validFp),
              let validPin = pin, isValidPin(validPin),
              let validV = version, validV == 2
        else {
            return nil
        }

        return ParsedQRData(
            ip: cleanHost,
            port: port,
            fingerprint: validFp,
            pin: validPin,
            version: validV
        )
    }

    private static func isValidFingerprint(_ fp: String) -> Bool {
        guard fp.count == 64 else { return false }
        let range = NSRange(location: 0, length: fp.utf16.count)
        return fpRegex?.firstMatch(in: fp, options: [], range: range) != nil
    }

    private static func isValidPin(_ pin: String) -> Bool {
        guard pin.count == 6 else { return false }
        let range = NSRange(location: 0, length: pin.utf16.count)
        return pinRegex?.firstMatch(in: pin, options: [], range: range) != nil
    }

    /// Sanitizes pairing URI for safe logging without exposing the 6-digit PIN.
    public static func sanitize(_ uriString: String?) -> String {
        guard let parsed = parse(uriString) else { return "[INVALID_QR_URI]" }
        let fpPrefix = String(parsed.fingerprint.prefix(8))
        return "\(scheme)://\(parsed.ip):\(parsed.port)?fp=\(fpPrefix)...&pin=******&v=\(parsed.version)"
    }
}
