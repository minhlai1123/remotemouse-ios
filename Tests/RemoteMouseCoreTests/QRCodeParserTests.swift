import XCTest
@testable import RemoteMouseCore

final class QRCodeParserTests: XCTestCase {
    private let sampleFp = "a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0"
    private let samplePin = "482910"

    func testParseValidIpv4QrUri() {
        let uri = "rmpp://192.168.1.100:54321?fp=\(sampleFp)&pin=\(samplePin)&v=2"
        let parsed = QRCodeParser.parse(uri)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.ip, "192.168.1.100")
        XCTAssertEqual(parsed?.port, 54321)
        XCTAssertEqual(parsed?.fingerprint, sampleFp)
        XCTAssertEqual(parsed?.pin, samplePin)
        XCTAssertEqual(parsed?.version, 2)
    }

    func testParseValidIpv6QrUri() {
        let uri = "rmpp://[2001:db8::1]:54321?fp=\(sampleFp)&pin=\(samplePin)&v=2"
        let parsed = QRCodeParser.parse(uri)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.ip, "2001:db8::1")
        XCTAssertEqual(parsed?.port, 54321)
        XCTAssertEqual(parsed?.fingerprint, sampleFp)
        XCTAssertEqual(parsed?.pin, samplePin)
    }

    func testRejectInvalidScheme() {
        let uri = "http://192.168.1.100:54321?fp=\(sampleFp)&pin=\(samplePin)&v=2"
        XCTAssertNil(QRCodeParser.parse(uri))
    }

    func testRejectPortOutOfBounds() {
        let uriLow = "rmpp://192.168.1.100:0?fp=\(sampleFp)&pin=\(samplePin)&v=2"
        let uriHigh = "rmpp://192.168.1.100:65536?fp=\(sampleFp)&pin=\(samplePin)&v=2"
        XCTAssertNil(QRCodeParser.parse(uriLow))
        XCTAssertNil(QRCodeParser.parse(uriHigh))
    }

    func testRejectInvalidFingerprint() {
        let uriShort = "rmpp://192.168.1.100:54321?fp=deadbeef&pin=\(samplePin)&v=2"
        let uriNonHex = "rmpp://192.168.1.100:54321?fp=\(String(repeating: "z", count: 64))&pin=\(samplePin)&v=2"
        XCTAssertNil(QRCodeParser.parse(uriShort))
        XCTAssertNil(QRCodeParser.parse(uriNonHex))
    }

    func testRejectInvalidPin() {
        let uri5Digits = "rmpp://192.168.1.100:54321?fp=\(sampleFp)&pin=12345&v=2"
        let uriLetters = "rmpp://192.168.1.100:54321?fp=\(sampleFp)&pin=abcdef&v=2"
        XCTAssertNil(QRCodeParser.parse(uri5Digits))
        XCTAssertNil(QRCodeParser.parse(uriLetters))
    }

    func testRejectWrongVersion() {
        let uriV1 = "rmpp://192.168.1.100:54321?fp=\(sampleFp)&pin=\(samplePin)&v=1"
        XCTAssertNil(QRCodeParser.parse(uriV1))
    }

    func testSanitizeMasksPinAndTruncatesFp() {
        let uri = "rmpp://192.168.1.100:54321?fp=\(sampleFp)&pin=\(samplePin)&v=2"
        let sanitized = QRCodeParser.sanitize(uri)

        XCTAssertFalse(sanitized.contains(samplePin))
        XCTAssertTrue(sanitized.contains("pin=******"))
        XCTAssertFalse(sanitized.contains(sampleFp))
        XCTAssertTrue(sanitized.contains(String(sampleFp.prefix(8))))
    }

    func testDiscoveredHostDeduplicationKey() {
        let host1 = DiscoveredHost(
            name: "PC-1",
            address: "192.168.1.5",
            port: 54321,
            fingerprint: sampleFp,
            source: .bonjour
        )
        let host2 = DiscoveredHost(
            name: "PC-1",
            address: "192.168.1.5",
            port: 54321,
            fingerprint: sampleFp.uppercased(),
            source: .udpFallback
        )

        XCTAssertEqual(host1.id, host2.id)
    }
}
