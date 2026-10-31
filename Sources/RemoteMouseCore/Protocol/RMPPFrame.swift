import Foundation

public enum RMPPError: Error, Equatable {
    case invalidFrameSize(expected: Int, actual: Int)
    case invalidMagic(UInt16)
    case unsupportedVersion(UInt8)
    case checksumMismatch(expected: UInt16, calculated: UInt16)
    case payloadTooLarge(Int)
    case truncatedData
}

public protocol RMPPFrame {
    var msgType: UInt8 { get }
    var seq: UInt32 { get }
    func serialize() -> Data
}

public struct CompactFrame: RMPPFrame, Equatable {
    public let msgType: UInt8
    public let seq: UInt32
    public let data1: Int16
    public let data2: Int16
    public let flags: UInt16
    public let checksum: UInt16?

    public init(msgType: UInt8, seq: UInt32, data1: Int16, data2: Int16, flags: UInt16 = 0, checksum: UInt16? = nil) {
        self.msgType = msgType
        self.seq = seq
        self.data1 = data1
        self.data2 = data2
        self.flags = flags
        self.checksum = checksum
    }

    public func serialize() -> Data {
        var data = Data(capacity: RMPPConstants.compactFrameSize)
        var magicBE = RMPPConstants.magic.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &magicBE) { Array($0) })
        data.append(RMPPConstants.protocolVersion)
        data.append(msgType)
        var seqBE = seq.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &seqBE) { Array($0) })
        var d1BE = data1.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &d1BE) { Array($0) })
        var d2BE = data2.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &d2BE) { Array($0) })
        var flBE = flags.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &flBE) { Array($0) })

        let csum = CRC16.calculate(data)
        var csumBE = csum.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &csumBE) { Array($0) })
        return data
    }

    public static func deserialize(from data: Data) throws -> CompactFrame {
        guard data.count == RMPPConstants.compactFrameSize else {
            throw RMPPError.invalidFrameSize(expected: RMPPConstants.compactFrameSize, actual: data.count)
        }

        let magic = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self).bigEndian }
        guard magic == RMPPConstants.magic else {
            throw RMPPError.invalidMagic(magic)
        }

        let ver = data[2]
        guard ver == RMPPConstants.protocolVersion else {
            throw RMPPError.unsupportedVersion(ver)
        }

        let type = data[3]
        let seq = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).bigEndian }
        let d1 = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Int16.self).bigEndian }
        let d2 = data.withUnsafeBytes { $0.load(fromByteOffset: 10, as: Int16.self).bigEndian }
        let fl = data.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt16.self).bigEndian }
        let csum = data.withUnsafeBytes { $0.load(fromByteOffset: 14, as: UInt16.self).bigEndian }

        let calculated = CRC16.calculate(data, offset: 0, length: 14)
        guard calculated == csum else {
            throw RMPPError.checksumMismatch(expected: csum, calculated: calculated)
        }

        return CompactFrame(msgType: type, seq: seq, data1: d1, data2: d2, flags: fl, checksum: csum)
    }
}

public struct ExtendedFrame: RMPPFrame, Equatable {
    public let msgType: UInt8
    public let seq: UInt32
    public let payload: Data
    public let flags: UInt16
    public let checksum: UInt16?

    public init(msgType: UInt8, seq: UInt32, payload: Data, flags: UInt16 = 0, checksum: UInt16? = nil) {
        self.msgType = msgType
        self.seq = seq
        self.payload = payload
        self.flags = flags
        self.checksum = checksum
    }

    public func serialize() -> Data {
        let payloadLen = UInt16(min(payload.count, RMPPConstants.maxPayloadSize))
        var data = Data(capacity: RMPPConstants.extendedHeaderSize + Int(payloadLen) + 2)
        var magicBE = RMPPConstants.magic.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &magicBE) { Array($0) })
        data.append(RMPPConstants.protocolVersion)
        data.append(msgType)
        var seqBE = seq.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &seqBE) { Array($0) })
        var lenBE = payloadLen.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &lenBE) { Array($0) })
        var flBE = flags.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &flBE) { Array($0) })
        data.append(payload.prefix(Int(payloadLen)))

        let csum = CRC16.calculate(data)
        var csumBE = csum.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &csumBE) { Array($0) })
        return data
    }

    public static func deserialize(from data: Data) throws -> ExtendedFrame {
        guard data.count >= RMPPConstants.extendedHeaderSize + 2 else {
            throw RMPPError.invalidFrameSize(expected: RMPPConstants.extendedHeaderSize + 2, actual: data.count)
        }

        let magic = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self).bigEndian }
        guard magic == RMPPConstants.magic else {
            throw RMPPError.invalidMagic(magic)
        }

        let ver = data[2]
        guard ver == RMPPConstants.protocolVersion else {
            throw RMPPError.unsupportedVersion(ver)
        }

        let type = data[3]
        let seq = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).bigEndian }
        let payloadLen = Int(data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt16.self).bigEndian })
        let fl = data.withUnsafeBytes { $0.load(fromByteOffset: 10, as: UInt16.self).bigEndian }

        let expectedTotal = RMPPConstants.extendedHeaderSize + payloadLen + 2
        guard data.count == expectedTotal else {
            throw RMPPError.invalidFrameSize(expected: expectedTotal, actual: data.count)
        }

        let csumOffset = RMPPConstants.extendedHeaderSize + payloadLen
        let csum = data.withUnsafeBytes { $0.load(fromByteOffset: csumOffset, as: UInt16.self).bigEndian }

        let calculated = CRC16.calculate(data, offset: 0, length: csumOffset)
        guard calculated == csum else {
            throw RMPPError.checksumMismatch(expected: csum, calculated: calculated)
        }

        let payload = data.subdata(in: RMPPConstants.extendedHeaderSize..<csumOffset)
        return ExtendedFrame(msgType: type, seq: seq, payload: payload, flags: fl, checksum: csum)
    }
}
