import Foundation
import CoreGraphics

/// Gesture Manager for iOS Client.
/// Manages 1-finger mouse navigation with Pointer Ballistics,
/// 2-finger vertical and horizontal scrolling with noise deadzone,
/// kinetic scroll inertia with bounded exponential decay,
/// and Left-Handed mode button mapping.
public final class GestureManager {

    private static let keySensitivity = "rmpp_sensitivity"
    private static let keyNaturalScroll = "rmpp_natural_scroll"
    private static let keyLeftHanded = "rmpp_left_handed"

    // Gesture constants
    public static let scrollDeadzonePx: Double = 3.5
    public static let scrollScaleFactor: Double = 8.0

    // Inertia constants
    public static let inertiaMinVelocity: Double = 80.0   // px/s to trigger inertia
    public static let inertiaStopVelocity: Double = 15.0  // px/s to terminate inertia
    public static let inertiaFriction: Double = 0.91      // Decay factor per 16ms frame
    public static let inertiaFrameMs: Double = 16.0       // 60Hz loop interval
    public static let inertiaMaxDurationMs: Double = 1500.0

    public let ballistics: PointerBallistics
    public var isNaturalScroll: Bool = false
    public var isLeftHanded: Bool = false

    private let client: RMPPClient
    private let queue = DispatchQueue(label: "com.remotemouse.gesture", qos: .userInteractive)
    private var inertiaTimer: DispatchSourceTimer?

    // Last touch positions
    private var lastTouchPoint: CGPoint?
    private var lastTouchTime: TimeInterval = 0

    // Scroll tracking
    private var lastScrollTime: TimeInterval = 0
    private var scrollVelocityX: Double = 0
    private var scrollVelocityY: Double = 0

    public init(client: RMPPClient) {
        self.client = client
        self.ballistics = PointerBallistics()
        loadPreferences()
    }

    public func loadPreferences() {
        let defaults = UserDefaults.standard
        let savedSens = defaults.double(forKey: GestureManager.keySensitivity)
        if savedSens >= PointerBallistics.minSensitivity && savedSens <= PointerBallistics.maxSensitivity {
            ballistics.sensitivity = savedSens
        }
        isNaturalScroll = defaults.bool(forKey: GestureManager.keyNaturalScroll)
        isLeftHanded = defaults.bool(forKey: GestureManager.keyLeftHanded)
    }

    public func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(ballistics.sensitivity, forKey: GestureManager.keySensitivity)
        defaults.set(isNaturalScroll, forKey: GestureManager.keyNaturalScroll)
        defaults.set(isLeftHanded, forKey: GestureManager.keyLeftHanded)
    }

    /// Primary button mapping: Left click (1) in right-handed mode, Right click (2) in left-handed mode.
    public var primaryButtonId: UInt16 {
        return isLeftHanded ? RMPPConstants.buttonRight : RMPPConstants.buttonLeft
    }

    /// Secondary button mapping: Right click (2) in right-handed mode, Left click (1) in left-handed mode.
    public var secondaryButtonId: UInt16 {
        return isLeftHanded ? RMPPConstants.buttonLeft : RMPPConstants.buttonRight
    }

    public func onPrimaryClick() {
        client.sendMouseClick(button: primaryButtonId, clickCount: 1)
    }

    public func onSecondaryClick() {
        client.sendMouseClick(button: secondaryButtonId, clickCount: 1)
    }

    public func cancelInertia() {
        queue.async { [weak self] in
            self?.stopInertiaTimer()
        }
    }

    private func stopInertiaTimer() {
        inertiaTimer?.cancel()
        inertiaTimer = nil
    }

    // Single-finger movement with Pointer Ballistics
    public func handleSingleFingerMove(location: CGPoint, translation: CGSize) {
        cancelInertia()

        let now = Date().timeIntervalSince1970
        guard let lastPoint = lastTouchPoint else {
            lastTouchPoint = location
            lastTouchTime = now
            return
        }

        let rawDx = Double(location.x - lastPoint.x)
        let rawDy = Double(location.y - lastPoint.y)
        let dt = max(0.004, now - lastTouchTime)

        lastTouchPoint = location
        lastTouchTime = now

        let (accelDx, accelDy) = ballistics.computeDisplacement(dx: rawDx, dy: rawDy, dt: dt)
        if accelDx != 0 || accelDy != 0 {
            client.sendMouseMove(dx: accelDx, dy: accelDy)
        }
    }

    public func handleSingleFingerEnd() {
        lastTouchPoint = nil
        lastTouchTime = 0
    }

    // Two-finger scroll with noise filter & kinetic inertia
    public func handleTwoFingerScroll(translationX: Double, translationY: Double) {
        cancelInertia()

        let now = Date().timeIntervalSince1970
        let dt = lastScrollTime > 0 ? max(0.004, now - lastScrollTime) : 0.016
        lastScrollTime = now

        // Check deadzone to filter tremor
        if abs(translationX) >= GestureManager.scrollDeadzonePx || abs(translationY) >= GestureManager.scrollDeadzonePx {
            scrollVelocityX = translationX / dt
            scrollVelocityY = translationY / dt

            var vWheel = translationY * GestureManager.scrollScaleFactor
            var hWheel = translationX * GestureManager.scrollScaleFactor

            if isNaturalScroll {
                vWheel = -vWheel
                hWheel = -hWheel
            }

            let clampedV = Int16(clamping: Int(round(vWheel)))
            let clampedH = Int16(clamping: Int(round(hWheel)))

            if clampedV != 0 || clampedH != 0 {
                client.sendMouseScroll(hWheel: clampedH, vWheel: clampedV)
            }
        }
    }

    public func handleTwoFingerScrollEnd() {
        lastScrollTime = 0
        startInertiaDecay(initialVx: scrollVelocityX, initialVy: scrollVelocityY)
        scrollVelocityX = 0
        scrollVelocityY = 0
    }

    private func startInertiaDecay(initialVx: Double, initialVy: Double) {
        let speed = hypot(initialVx, initialVy)
        guard speed >= GestureManager.inertiaMinVelocity else { return }

        queue.async { [weak self] in
            guard let self = self else { return }
            self.stopInertiaTimer()

            var vx = initialVx
            var vy = initialVy
            let startTime = Date().timeIntervalSince1970

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + .milliseconds(16), repeating: .milliseconds(16))

            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                let elapsedMs = (Date().timeIntervalSince1970 - startTime) * 1000.0
                let currentSpeed = hypot(vx, vy)

                if currentSpeed < GestureManager.inertiaStopVelocity || elapsedMs > GestureManager.inertiaMaxDurationMs {
                    self.stopInertiaTimer()
                    return
                }

                // Decay velocity by friction factor
                vx *= GestureManager.inertiaFriction
                vy *= GestureManager.inertiaFriction

                let dt = GestureManager.inertiaFrameMs / 1000.0
                let stepX = vx * dt
                let stepY = vy * dt

                var vWheel = stepY * GestureManager.scrollScaleFactor
                var hWheel = stepX * GestureManager.scrollScaleFactor

                if self.isNaturalScroll {
                    vWheel = -vWheel
                    hWheel = -hWheel
                }

                let clampedV = Int16(clamping: Int(round(vWheel)))
                let clampedH = Int16(clamping: Int(round(hWheel)))

                if clampedV != 0 || clampedH != 0 {
                    self.client.sendMouseScroll(hWheel: clampedH, vWheel: clampedV)
                }
            }

            timer.resume()
            self.inertiaTimer = timer
        }
    }
}
