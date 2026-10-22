import Foundation
@testable import DualSenseCore

/// Drives a `TouchGestureEngine` with synthetic frames at a fixed report rate.
struct GestureSim {
    var engine: TouchGestureEngine
    var time: TimeInterval = 1.0
    let dt: TimeInterval
    var events: [GestureEvent] = []

    init(config: TouchGestureConfig = TouchGestureConfig(), dt: TimeInterval = 0.004) {
        engine = TouchGestureEngine(config: config)
        self.dt = dt
    }

    static func pt(_ id: UInt8, _ x: Int, _ y: Int) -> TouchPoint {
        TouchPoint(isTouching: true, id: id, x: x, y: y)
    }

    /// One report, then advance time by dt. Returns events from this report.
    @discardableResult
    mutating func frame(_ touches: [TouchPoint], click: Bool = false) -> [GestureEvent] {
        let e = engine.update(touches: touches, padClicked: click, at: time)
        events += e
        time += dt
        return e
    }

    /// Holds the given touches still for `duration` seconds (frames inclusive of the first).
    mutating func still(_ touches: [TouchPoint], for duration: TimeInterval) {
        let n = Int((duration / dt).rounded())
        for _ in 0..<max(n, 1) { frame(touches) }
    }

    /// Moves one finger linearly from a to b over `duration`, ending exactly at b.
    mutating func move(id: UInt8, from a: (Int, Int), to b: (Int, Int), over duration: TimeInterval) {
        let n = max(Int((duration / dt).rounded()), 1)
        for i in 1...n {
            let f = Double(i) / Double(n)
            let x = a.0 + Int((Double(b.0 - a.0) * f).rounded())
            let y = a.1 + Int((Double(b.1 - a.1) * f).rounded())
            frame([Self.pt(id, x, y)])
        }
    }

    /// Reports with no finger down.
    mutating func release(frames: Int = 1) { for _ in 0..<frames { frame([]) } }
}
