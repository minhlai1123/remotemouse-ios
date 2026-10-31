import XCTest
@testable import RemoteMouseCore

final class PointerBallisticsTests: XCTestCase {

    var ballistics: PointerBallistics!

    override func setUp() {
        super.setUp()
        ballistics = PointerBallistics(sensitivity: 1.0)
    }

    func testZeroDisplacementProducesZero() {
        let (dx, dy) = ballistics.computeDisplacement(dx: 0, dy: 0)
        XCTAssertEqual(dx, 0)
        XCTAssertEqual(dy, 0)
    }

    func testLowVelocityPixelPerfectPrecision() {
        // 1px in 16ms -> v = 62.5 px/s (< 100 px/s threshold)
        let (dx, dy) = ballistics.computeDisplacement(dx: 1.0, dy: 0.0, dt: 0.016)
        XCTAssertEqual(dx, 1)
        XCTAssertEqual(dy, 0)

        let accel = ballistics.calculateAcceleration(velocityPxS: 62.5)
        XCTAssertEqual(accel, 1.0, accuracy: 0.001)
    }

    func testMediumVelocityMonotonicAcceleration() {
        let accel1 = ballistics.calculateAcceleration(velocityPxS: 500.0)
        let accel2 = ballistics.calculateAcceleration(velocityPxS: 1000.0)

        XCTAssertGreaterThan(accel1, 1.0)
        XCTAssertGreaterThan(accel2, accel1)
        XCTAssertLessThan(accel2, 2.8)

        let (dx1, _) = ballistics.computeDisplacement(dx: 10.0, dy: 0.0, dt: 0.016)
        let (dx2, _) = ballistics.computeDisplacement(dx: 20.0, dy: 0.0, dt: 0.016)
        // Non-linear acceleration: dx2 / dx1 > 2.0
        XCTAssertGreaterThan(Double(dx2) / Double(dx1), 2.0)
    }

    func testHighVelocityCappedAtMax() {
        let accel1500 = ballistics.calculateAcceleration(velocityPxS: 1500.0)
        let accel3000 = ballistics.calculateAcceleration(velocityPxS: 3000.0)

        XCTAssertEqual(accel1500, 2.8, accuracy: 0.001)
        XCTAssertEqual(accel3000, 2.8, accuracy: 0.001)

        // 50px in 16ms -> v = 3125 px/s -> 50 * 2.8 = 140
        let (dx, dy) = ballistics.computeDisplacement(dx: 50.0, dy: 0.0, dt: 0.016)
        XCTAssertEqual(dx, 140)
        XCTAssertEqual(dy, 0)
    }

    func testSensitivitySliderScaling() {
        ballistics.sensitivity = 0.5
        let (dxLow, _) = ballistics.computeDisplacement(dx: 10.0, dy: 0.0, dt: 0.016)

        ballistics.sensitivity = 1.0
        let (dxBase, _) = ballistics.computeDisplacement(dx: 10.0, dy: 0.0, dt: 0.016)

        ballistics.sensitivity = 2.5
        let (dxHigh, _) = ballistics.computeDisplacement(dx: 10.0, dy: 0.0, dt: 0.016)

        XCTAssertGreaterThan(dxBase, dxLow)
        XCTAssertGreaterThan(dxHigh, dxBase)
        XCTAssertEqual(Double(dxHigh) / Double(dxLow), 5.0, accuracy: 1.0)
    }

    func testSensitivityClamping() {
        ballistics.sensitivity = 0.1
        XCTAssertEqual(ballistics.sensitivity, 0.5, accuracy: 0.001)

        ballistics.sensitivity = 10.0
        XCTAssertEqual(ballistics.sensitivity, 3.0, accuracy: 0.001)

        ballistics.sensitivity = Double.nan
        XCTAssertEqual(ballistics.sensitivity, 1.0, accuracy: 0.001)
    }

    func testLargeInputClampingToInt16() {
        let (dx, dy) = ballistics.computeDisplacement(dx: 50000.0, dy: -50000.0, dt: 0.016)
        XCTAssertEqual(dx, Int16.max)
        XCTAssertEqual(dy, Int16.min)
    }

    func testInvalidInputsHandledSafely() {
        let (dx1, dy1) = ballistics.computeDisplacement(dx: Double.nan, dy: 10.0)
        XCTAssertEqual(dx1, 0)
        XCTAssertEqual(dy1, 0)

        let (dx2, dy2) = ballistics.computeDisplacement(dx: 10.0, dy: Double.infinity)
        XCTAssertEqual(dx2, 0)
        XCTAssertEqual(dy2, 0)

        let (dx3, _) = ballistics.computeDisplacement(dx: 10.0, dy: 10.0, dt: -1.0)
        XCTAssertNotEqual(dx3, 0)
    }
}
