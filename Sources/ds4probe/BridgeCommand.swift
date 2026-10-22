#if os(macOS)
import Foundation
import CoreGraphics
import DS4Mac
import DualSenseCore

/// Maps controller input to keyboard and mouse events with edge detection.
private final class Bridge {
    let injector = EventInjector()
    let sens: Float
    var heldKeys = Set<CGKeyCode>()
    var heldButtons = Set<Int>()  // 0 = left, 1 = right
    var remainderX: Float = 0
    var remainderY: Float = 0

    init(sens: Float) { self.sens = sens }

    func setKey(_ key: CGKeyCode, _ down: Bool) {
        if down && !heldKeys.contains(key) {
            heldKeys.insert(key)
            injector.keyDown(key)
        } else if !down && heldKeys.contains(key) {
            heldKeys.remove(key)
            injector.keyUp(key)
        }
    }

    func setButton(_ id: Int, _ down: Bool) {
        let button: CGMouseButton = id == 0 ? .left : .right
        if down && !heldButtons.contains(id) {
            heldButtons.insert(id)
            injector.mouseButton(button, down: true)
        } else if !down && heldButtons.contains(id) {
            heldButtons.remove(id)
            injector.mouseButton(button, down: false)
        }
    }

    func update(_ r: InputReport) {
        setKey(13, r.leftStick.y > 0.5)
        setKey(1, r.leftStick.y < -0.5)
        setKey(0, r.leftStick.x < -0.5)
        setKey(2, r.leftStick.x > 0.5)
        setKey(14, r.buttons.contains(.cross))
        setKey(15, r.buttons.contains(.triangle))
        setKey(49, r.buttons.contains(.circle))
        setKey(53, r.buttons.contains(.options))
        setKey(56, r.buttons.contains(.l1))
        setKey(9, r.buttons.contains(.r3))
        setButton(0, r.r2 > 0.5)
        setButton(1, r.l2 > 0.5)

        let deadZone: Float = 0.12
        let scale: Float = 10 * sens
        let x = r.rightStick.x
        let y = r.rightStick.y
        remainderX += abs(x) > deadZone ? x * scale : 0
        remainderY += abs(y) > deadZone ? -y * scale : 0
        let dx = Int(remainderX)
        let dy = Int(remainderY)
        remainderX -= Float(dx)
        remainderY -= Float(dy)
        if dx != 0 || dy != 0 {
            injector.mouseMove(dx: dx, dy: dy)
        }
    }

    func releaseAll() {
        for key in heldKeys { injector.keyUp(key) }
        heldKeys.removeAll()
        for id in heldButtons { injector.mouseButton(id == 0 ? .left : .right, down: false) }
        heldButtons.removeAll()
    }
}

func runBridge(_ args: Args) -> Never {
    let sens = Float(args.double("--sens", default: 1.0))
    let trusted = EventInjector.requestAccessibility()
    print("accessibility trusted: \(trusted)")
    let device = openFirstDevice(seize: args.has("--seize"))
    switchBluetoothToFullReports(device)

    let bridge = Bridge(sens: sens)
    device.onInputReport = { _, bytes in
        if let report = InputReport(usbReport: bytes) {
            bridge.update(report)
        }
    }
    onInterrupt {
        bridge.releaseAll()
        device.close()
    }
    print("bridge running (sens \(sens)); Ctrl-C to stop")
    runForever()
}
#endif
