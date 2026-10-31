import Foundation

/// Fast table-driven CRC-16/CCITT-FALSE (also known as CRC-16/IBM-3740) implementation.
/// Polynomial: 0x1021, Initial value: 0xFFFF, RefIn: false, RefOut: false, XorOut: 0x0000
/// Standard test vector: "123456789" ASCII -> 0x29B1
public struct CRC16 {
    private static let table: [UInt16] = {
        var tbl = [UInt16](repeating: 0, count: 256)
        let poly: UInt16 = 0x1021
        for i in 0..<256 {
            var curr = UInt16(i) << 8
            for _ in 0..<8 {
                if (curr & 0x8000) != 0 {
                    curr = (curr << 1) ^ poly
                } else {
                    curr = curr << 1
                }
            }
            tbl[i] = curr
        }
        return tbl
    }()

    /// Calculates CRC-16/CCITT-FALSE checksum for the given byte collection or slice.
    public static func calculate<T: Sequence>(_ data: T) -> UInt16 where T.Element == UInt8 {
        var crc: UInt16 = 0xFFFF
        for byte in data {
            let index = Int(((crc >> 8) ^ UInt16(byte)) & 0xFF)
            crc = (crc << 8) ^ table[index]
        }
        return crc
    }

    /// Convenience calculation on Data with offset and length.
    public static func calculate(_ data: Data, offset: Int, length: Int) -> UInt16 {
        guard offset >= 0, length >= 0, offset + length <= data.count else {
            return 0
        }
        let subData = data.subdata(in: offset..<(offset + length))
        return calculate(subData)
    }
}
