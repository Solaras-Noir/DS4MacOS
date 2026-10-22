import Foundation
@testable import DualSenseCore

enum MapTest {
    static func stick(_ x: Float, _ y: Float) -> StickState {
        let rx = UInt8(max(0, min(255, (128 + x * 127).rounded())))
        let ry = UInt8(max(0, min(255, (128 - y * 127).rounded())))
        return StickState(rawX: rx, rawY: ry)
    }

    static func state(buttons: DualSenseButtons = [], dpad: Dpad = .none,
                      left: (Float, Float) = (0, 0), right: (Float, Float) = (0, 0),
                      l2: Float = 0, r2: Float = 0) -> ControllerState {
        ControllerState(leftStick: stick(left.0, left.1), rightStick: stick(right.0, right.1),
                        dpad: dpad, buttons: buttons, l2: l2, r2: r2, touches: [],
                        battery: BatteryStatus(statusByte: 0x08), gyro: SIMD3(0, 0, 0),
                        accel: SIMD3(0, 0, 0), sensorTimestamp: 0, transport: .usb, isSimple: false)
    }

    static func totalMove(_ engine: MappingEngine, state: ControllerState, rate dt: TimeInterval,
                          seconds: TimeInterval = 1.0) -> (Double, Double) {
        var x = 0.0, y = 0.0
        var t = 1.0
        let end = t + seconds
        while t <= end + 1e-9 {
            for a in engine.update(state: state, gestures: [], at: t).actions {
                if case let .mouseMove(dx, dy) = a { x += dx; y += dy }
            }
            t += dt
        }
        return (x, y)
    }
}
