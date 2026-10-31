import Foundation

public final class RMPPStreamParser {
    private var buffer: Data
    private let maxBufferSize: Int

    public init(maxBufferSize: Int = RMPPConstants.maxAccumulatorBufferSize) {
        self.buffer = Data()
        self.maxBufferSize = maxBufferSize
    }

    public func feed(_ chunk: Data) -> [RMPPFrame] {
        if buffer.count + chunk.count > maxBufferSize {
            buffer.removeAll()
            return []
        }

        buffer.append(chunk)
        var frames: [RMPPFrame] = []
        var offset = 0

        while buffer.count - offset >= 4 {
            let b0 = buffer[offset]
            let b1 = buffer[offset + 1]

            // Scan for Magic 0x524D ('R', 'M')
            if b0 != 0x52 || b1 != 0x4D {
                offset += 1
                continue
            }

            let ver = buffer[offset + 2]
            if ver != RMPPConstants.protocolVersion {
                offset += 2
                continue
            }

            let type = buffer[offset + 3]

            if RMPPConstants.compactMsgTypes.contains(type) {
                if buffer.count - offset < RMPPConstants.compactFrameSize {
                    break
                }
                let frameSlice = buffer.subdata(in: offset..<(offset + RMPPConstants.compactFrameSize))
                do {
                    let frame = try CompactFrame.deserialize(from: frameSlice)
                    frames.append(frame)
                    offset += RMPPConstants.compactFrameSize
                } catch {
                    offset += 2
                }
            } else if RMPPConstants.extendedMsgTypes.contains(type) {
                if buffer.count - offset < RMPPConstants.extendedHeaderSize {
                    break
                }

                let payloadLen = Int(buffer.withUnsafeBytes {
                    $0.load(fromByteOffset: offset + 8, as: UInt16.self).bigEndian
                })
                if payloadLen > RMPPConstants.maxPayloadSize {
                    offset += 2
                    continue
                }
                let totalFrameLen = RMPPConstants.extendedHeaderSize + payloadLen + 2

                if buffer.count - offset < totalFrameLen {
                    break
                }

                let frameSlice = buffer.subdata(in: offset..<(offset + totalFrameLen))
                do {
                    let frame = try ExtendedFrame.deserialize(from: frameSlice)
                    frames.append(frame)
                    offset += totalFrameLen
                } catch {
                    offset += 2
                }
            } else {
                // Unknown message type: advance 2 bytes past magic to resynchronize
                offset += 2
            }
        }

        if offset > 0 {
            if offset >= buffer.count {
                buffer.removeAll(keepingCapacity: true)
            } else {
                buffer = buffer.subdata(in: offset..<buffer.count)
            }
        }

        return frames
    }

    public func reset() {
        buffer.removeAll()
    }
}
