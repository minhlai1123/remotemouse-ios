import Foundation

/// Non-linear Pointer Ballistics & Sensitivity Calculator for iOS Client.
///
/// Architecture Decision (ADR-Phase-3.3):
/// The Mobile Client calculates acceleration and sensitivity curves locally
/// to ensure responsive, zero-latency cursor control without double acceleration.
/// The Desktop Host receives pixel-displacement (dx, dy) directly.
public final class PointerBallistics {

    public static let defaultSensitivity: Double = 1.0
    public static let minSensitivity: Double = 0.5
    public static let maxSensitivity: Double = 3.0

    // Velocity thresholds in pixels per second
    public static let vMin: Double = 100.0   // Below 100 px/s: 1.0x acceleration (precision)
    public static let vMax: Double = 1500.0  // Above 1500 px/s: capped at aMax
    public static let aMax: Double = 2.8     // Maximum non-linear acceleration multiplier
    public static let exponent: Double = 1.35

    public static let defaultDt: Double = 0.016 // ~60Hz frame (16.6ms)

    public var sensitivity: Double {
        didSet {
            sensitivity = PointerBallistics.clampSensitivity(sensitivity)
        }
    }

    public init(sensitivity: Double = defaultSensitivity) {
        self.sensitivity = PointerBallistics.clampSensitivity(sensitivity)
    }

    public static func clampSensitivity(_ value: Double) -> Double {
        if value.isNaN || value.isInfinite {
            return defaultSensitivity
        }
        return max(minSensitivity, min(maxSensitivity, value))
    }

    public func calculateAcceleration(velocityPxS: Double) -> Double {
        if velocityPxS <= PointerBallistics.vMin {
            return 1.0
        }
        if velocityPxS >= PointerBallistics.vMax {
            return PointerBallistics.aMax
        }

        let u = (velocityPxS - PointerBallistics.vMin) / (PointerBallistics.vMax - PointerBallistics.vMin)
        return 1.0 + (PointerBallistics.aMax - 1.0) * pow(u, PointerBallistics.exponent)
    }

    /// Computes accelerated displacement (outDx, outDy) from raw touch displacement and time delta (dt in seconds).
    /// Output is clamped to Int16 boundaries for RMPP CompactFrame serialization.
    public func computeDisplacement(dx: Double, dy: Double, dt: Double = defaultDt) -> (Int16, Int16) {
        if dx == 0 && dy == 0 {
            return (0, 0)
        }
        if dx.isNaN || dy.isNaN || dx.isInfinite || dy.isInfinite {
            return (0, 0)
        }

        let effectiveDt: Double
        if dt <= 0 || dt.isNaN || dt.isInfinite {
            effectiveDt = PointerBallistics.defaultDt
        } else {
            effectiveDt = max(0.004, min(0.200, dt))
        }

        let distance = hypot(dx, dy)
        if distance == 0 {
            return (0, 0)
        }

        let velocity = distance / effectiveDt
        let accel = calculateAcceleration(velocityPxS: velocity)
        let multiplier = accel * sensitivity

        let outDx = Int(round(dx * multiplier))
        let outDy = Int(round(dy * multiplier))

        let clampedDx = Int16(clamping: outDx)
        let clampedDy = Int16(clamping: outDy)

        return (clampedDx, clampedDy)
    }
}
