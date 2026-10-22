#if os(macOS)
import Foundation
import DS4Mac
import DualSenseCore

private func buttonNames(_ b: DualSenseButtons) -> String {
    let all: [(DualSenseButtons, String)] = [
        (.square, "square"), (.cross, "cross"), (.circle, "circle"), (.triangle, "triangle"),
        (.l1, "l1"), (.r1, "r1"), (.l2, "l2"), (.r2, "r2"), (.create, "create"),
        (.options, "options"), (.l3, "l3"), (.r3, "r3"), (.ps, "ps"),
        (.touchpad, "touchpad"), (.mute, "mute"),
    ]
    return all.filter { b.contains($0.0) }.map { $0.1 }.joined(separator: ",")
}

private func describe(_ r: InputReport) -> String {
    func f(_ v: Float) -> String { String(format: "%+.2f", v) }
    let touches = r.touch.filter { $0.isTouching }
        .map { "#\($0.id)(\($0.x),\($0.y))" }.joined(separator: " ")
    let left = "L(\(f(r.leftStick.x)),\(f(r.leftStick.y)))"
    let right = "R(\(f(r.rightStick.x)),\(f(r.rightStick.y)))"
    let l2 = "L2 " + String(format: "%.2f", r.l2)
    let r2 = "R2 " + String(format: "%.2f", r.r2)
    let dpad = "dpad \(r.dpad)"
    let btn = "btn[" + buttonNames(r.buttons) + "]"
    let seq = "seq \(r.sequence)"
    let touch = "touch[" + touches + "]"
    let bat = "bat \(r.battery.level)% \(r.battery.state)"
    let parts: [String] = [left, right, l2, r2, dpad, btn, seq, touch, bat]
    return parts.joined(separator: " ")
}

func runRead(_ args: Args) -> Never {
    let device = openFirstDevice(seize: args.has("--seize"))
    switchBluetoothToFullReports(device)

    var latest: InputReport?
    var count = 0
    var failures = 0
    var lastFailure: (id: UInt8, length: Int)?

    device.onInputReport = { id, bytes in
        count += 1
        if let report = InputReport(usbReport: bytes) {
            latest = report
        } else {
            failures += 1
            lastFailure = (id, bytes.count)
        }
    }
    every(0.1) {
        if let report = latest { print(describe(report)) }
    }
    every(1.0) {
        print("rate: \(count) reports/s")
        count = 0
        if failures > 0, let f = lastFailure {
            print(String(format: "undecoded: %d reports, last id=0x%02x length=%d", failures, f.id, f.length))
            failures = 0
        }
    }
    onInterrupt { device.close() }
    runForever()
}
#endif
