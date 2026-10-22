import Foundation

extension MappingEngine {
    /// macOS key codes for W, A, S, D.
    private static let keyUp: UInt16 = 13, keyLeft: UInt16 = 0, keyDown: UInt16 = 1, keyRight: UInt16 = 2

    /// Adds WASD key presses for any stick bound to `.wasd`, applying hysteresis per direction.
    func collectSticks(_ state: ControllerState, into active: inout [(Source, Binding)]) {
        for (side, binding, stick) in [(StickSide.left, profile.leftStick, state.leftStick),
                                       (StickSide.right, profile.rightStick, state.rightStick)] {
            guard case let .wasd(threshold, hysteresis) = binding else { continue }
            let values: [(StickDirection, Float, UInt16)] = [
                (.up, stick.y, Self.keyUp), (.down, -stick.y, Self.keyDown),
                (.left, -stick.x, Self.keyLeft), (.right, stick.x, Self.keyRight),
            ]
            for (dir, value, code) in values {
                let source = Source.stick(side, dir)
                let on = activeStickDirections.contains(source)
                let now = on ? value > threshold - hysteresis : value > threshold
                if now {
                    activeStickDirections.insert(source)
                    active.append((source, .key(code: code)))
                } else {
                    activeStickDirections.remove(source)
                }
            }
        }
    }

    /// Mouse movement for any stick bound to `.mouse`: velocity (px/s) times elapsed time, with the
    /// fractional pixels carried to the next update. Returns whole pixels.
    func mouseMovement(_ state: ControllerState, dt: TimeInterval) -> (Double, Double) {
        var vx = 0.0, vy = 0.0
        for (binding, stick) in [(profile.leftStick, state.leftStick), (profile.rightStick, state.rightStick)] {
            guard case let .mouse(sensitivity, curve, deadZone) = binding else { continue }
            let v = Self.mouseVelocity(x: stick.x, y: stick.y, sensitivity: sensitivity,
                                       curve: curve, deadZone: deadZone)
            vx += v.0
            vy += v.1
        }
        mouseRemainderX += vx * dt
        mouseRemainderY += vy * dt
        let wx = mouseRemainderX.rounded(.towardZero)
        let wy = mouseRemainderY.rounded(.towardZero)
        mouseRemainderX -= wx
        mouseRemainderY -= wy
        return (wx, wy)
    }

    /// Radial dead zone, rescaled so the response starts at 0 on the dead-zone edge, then a power
    /// curve. Stick y is up-positive; the result is in screen coordinates (y down).
    static func mouseVelocity(x: Float, y: Float, sensitivity: Double, curve: Double,
                              deadZone: Float) -> (Double, Double) {
        let mag = Double((x * x + y * y).squareRoot())
        let dz = Double(min(max(deadZone, 0), 0.99))
        guard mag > dz, mag > 0 else { return (0, 0) }
        let scaled = min(1, (mag - dz) / (1 - dz))
        let speed = sensitivity * pow(scaled, max(curve, 0.01))
        return (Double(x) / mag * speed, -Double(y) / mag * speed)
    }
}
