import XCTest
@testable import RemoteMouseCore

final class RMPPProtocolTests: XCTestCase {

    // Helper to decode hex string to Data
    private func dataFromHex(_ hex: String) -> Data {
        var data = Data()
        var temp = ""
        for char in hex {
            temp.append(char)
            if temp.count == 2 {
                if let byte = UInt8(temp, radix: 16) {
                    data.append(byte)
                }
                temp = ""
            }
        }
        return data
    }

    func testCRC16StandardVector() {
        let ascii = "123456789".data(using: .ascii)!
        let crc = CRC16.calculate(ascii)
        XCTAssertEqual(crc, 0x29B1, "CRC16 of 123456789 must match CCITT-FALSE 0x29B1")
    }

    func testCompactFrameMouseMove() throws {
        let expectedHex = "524D010100000001000FFFE70000CB02"
        let expectedData = dataFromHex(expectedHex)

        let frame = CompactFrame(
            msgType: RMPPConstants.msgMouseMove,
            seq: 1,
            data1: 15,
            data2: -25,
            flags: 0
        )
        let serialized = frame.serialize()
        XCTAssertEqual(serialized, expectedData)

        let deserialized = try CompactFrame.deserialize(from: expectedData)
        XCTAssertEqual(deserialized.msgType, RMPPConstants.msgMouseMove)
        XCTAssertEqual(deserialized.seq, 1)
        XCTAssertEqual(deserialized.data1, 15)
        XCTAssertEqual(deserialized.data2, -25)
        XCTAssertEqual(deserialized.checksum, 0xCB02)
    }

    func testCompactFrameMouseDownLeft() throws {
        let expectedHex = "524D010200000002000100000000CAD0"
        let expectedData = dataFromHex(expectedHex)

        let frame = CompactFrame(
            msgType: RMPPConstants.msgMouseDown,
            seq: 2,
            data1: 1,
            data2: 0,
            flags: 0
        )
        XCTAssertEqual(frame.serialize(), expectedData)

        let parsed = try CompactFrame.deserialize(from: expectedData)
        XCTAssertEqual(parsed.checksum, 0xCAD0)
    }

    func testCompactFrameMouseClickRight() throws {
        let expectedHex = "524D01040000000400020001000043E3"
        let expectedData = dataFromHex(expectedHex)

        let frame = CompactFrame(
            msgType: RMPPConstants.msgMouseClick,
            seq: 4,
            data1: 2,
            data2: 1,
            flags: 0
        )
        XCTAssertEqual(frame.serialize(), expectedData)
    }

    func testCompactFrameMouseScroll() throws {
        let expectedHex = "524D01050000000500000078000021D1"
        let expectedData = dataFromHex(expectedHex)

        let frame = CompactFrame(
            msgType: RMPPConstants.msgMouseScroll,
            seq: 5,
            data1: 0,
            data2: 120,
            flags: 0
        )
        XCTAssertEqual(frame.serialize(), expectedData)
    }

    func testCompactFrameSafetyReleaseAll() throws {
        let expectedHex = "524D01FF00000007000000000000009E"
        let expectedData = dataFromHex(expectedHex)

        let frame = CompactFrame(
            msgType: RMPPConstants.msgSafetyReleaseAll,
            seq: 7,
            data1: 0,
            data2: 0,
            flags: 0
        )
        XCTAssertEqual(frame.serialize(), expectedData)
    }

    func testExtendedFrameAuthRequest() throws {
        let expectedHex = "524D01800000000A006400007B22636C69656E745F75756964223A202263306138303130312D313233342D353637382D616263642D303031313232333334343535222C20226465766963655F6E616D65223A20225465737450686F6E65222C202270696E223A2022313233343536227D065B"
        let expectedData = dataFromHex(expectedHex)

        let payloadStr = "{\"client_uuid\": \"c0a80101-1234-5678-abcd-001122334455\", \"device_name\": \"TestPhone\", \"pin\": \"123456\"}"
        let payloadData = payloadStr.data(using: .utf8)!

        let frame = ExtendedFrame(
            msgType: RMPPConstants.msgAuthRequest,
            seq: 10,
            payload: payloadData
        )
        XCTAssertEqual(frame.serialize(), expectedData)

        let deserialized = try ExtendedFrame.deserialize(from: expectedData)
        XCTAssertEqual(deserialized.checksum, 0x065B)
        XCTAssertEqual(deserialized.payload, payloadData)
    }

    func testExtendedFrameVietnameseUnicode() throws {
        let expectedHex = "524D01120000000B0025000058696E206368C3A06F205669E1BB8774204E616D20F09F87BBF09F87B320F09F96B1EFB88F122F"
        let expectedData = dataFromHex(expectedHex)

        let text = "Xin chào Việt Nam 🇻🇳 🖱️"
        let payload = text.data(using: .utf8)!

        let frame = ExtendedFrame(
            msgType: RMPPConstants.msgTextInput,
            seq: 11,
            payload: payload
        )
        XCTAssertEqual(frame.serialize(), expectedData)

        let deserialized = try ExtendedFrame.deserialize(from: expectedData)
        XCTAssertEqual(deserialized.checksum, 0x122F)
        XCTAssertEqual(String(data: deserialized.payload, encoding: .utf8), text)
    }

    func testStreamParserChunking() {
        let parser = RMPPStreamParser()
        let frameHex = "524D010100000001000FFFE70000CB02"
        let frameData = dataFromHex(frameHex)

        let chunk1 = frameData.subdata(in: 0..<6)
        let chunk2 = frameData.subdata(in: 6..<16)

        let frames1 = parser.feed(chunk1)
        XCTAssertEqual(frames1.count, 0)

        let frames2 = parser.feed(chunk2)
        XCTAssertEqual(frames2.count, 1)
        guard let compact = frames2.first as? CompactFrame else {
            XCTFail("Frame should be CompactFrame")
            return
        }
        XCTAssertEqual(compact.seq, 1)
        XCTAssertEqual(compact.data1, 15)
        XCTAssertEqual(compact.data2, -25)
    }

    func testStreamParserConcatenation() {
        let parser = RMPPStreamParser()
        let f1Hex = "524D010100000001000FFFE70000CB02"
        let f2Hex = "524D010200000002000100000000CAD0"
        let combined = dataFromHex(f1Hex + f2Hex)

        let frames = parser.feed(combined)
        XCTAssertEqual(frames.count, 2)
    }

    func testStreamParserResyncGarbage() {
        let parser = RMPPStreamParser()
        let garbage = dataFromHex("DEADBEEFCAFE1234")
        let validHex = "524D010100000001000FFFE70000CB02"
        let combined = garbage + dataFromHex(validHex)

        let frames = parser.feed(combined)
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].seq, 1)
    }

    func testChecksumMismatchRejection() {
        let corruptedHex = "524D010100000001000FFFE700000000"
        let corruptedData = dataFromHex(corruptedHex)

        XCTAssertThrowsError(try CompactFrame.deserialize(from: corruptedData)) { error in
            guard case RMPPError.checksumMismatch = error else {
                XCTFail("Expected checksumMismatch error")
                return
            }
        }
    }

    func testAuthResponseSuccessStringSchema() throws {
        let jsonStr = "{\"status\": \"SUCCESS\", \"session_token\": \"mock-token-256\", \"host_name\": \"Host-1\"}"
        let payload = jsonStr.data(using: .utf8)!
        let frame = ExtendedFrame(msgType: RMPPConstants.msgAuthResponse, seq: 100, payload: payload)

        let parsedJson = try JSONSerialization.jsonObject(with: frame.payload) as? [String: Any]
        XCTAssertNotNil(parsedJson)
        let status = parsedJson?["status"] as? String
        XCTAssertEqual(status, "SUCCESS")
    }

    func testAuthResponseRejectedSchema() throws {
        let jsonStr = "{\"status\": \"REJECTED\", \"reason\": \"INVALID_PIN\"}"
        let payload = jsonStr.data(using: .utf8)!
        let frame = ExtendedFrame(msgType: RMPPConstants.msgAuthResponse, seq: 101, payload: payload)

        let parsedJson = try JSONSerialization.jsonObject(with: frame.payload) as? [String: Any]
        XCTAssertNotNil(parsedJson)
        let status = parsedJson?["status"] as? String
        XCTAssertEqual(status, "REJECTED")
        let reason = parsedJson?["reason"] as? String
        XCTAssertEqual(reason, "INVALID_PIN")
    }

    func testStreamParserUnknownTypeResync() {
        let parser = RMPPStreamParser()
        // Unknown type 0x77 with fake large payload length 0xEA60 (60,000 bytes)
        let fakeUnknown = dataFromHex("524D017700000001EA600000")
        let valid = dataFromHex("524D010100000001000FFFE70000CB02")

        let frames = parser.feed(fakeUnknown + valid)
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].msgType, RMPPConstants.msgMouseMove)
    }

    func testSha256FingerprintCalculation() {
        let input = "RemoteMousePro".data(using: .ascii)!
        let fp = RMPPClient.computeSha256Fingerprint(data: input)
        XCTAssertEqual(fp.count, 64)
    }
}
