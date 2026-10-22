#if os(macOS)
import Foundation
import CoreGraphics
import DS4Mac

/// Requests accessibility, counts down 3 seconds, then runs `action`.
private func afterCountdown(_ action: @escaping () -> Void) -> Never {
    let trusted = EventInjector.requestAccessibility()
    print("accessibility trusted: \(trusted)")
    print("focus the target window; starting in 3 s")
    after(1) { print("2") }
    after(2) { print("1") }
    after(3, action)
    runForever()
}

func runInjectKey(_ args: Args) -> Never {
    let code = args.positionalInt(0, "KEYCODE")
    guard code >= 0 && code <= Int(UInt16.max) else { badUsage("bad keycode") }
    let hold = max(0, args.int("--hold", default: 50))
    let injector = EventInjector()
    afterCountdown {
        injector.keyDown(CGKeyCode(code))
        after(Double(hold) / 1000.0) {
            injector.keyUp(CGKeyCode(code))
            print("key \(code) sent")
            after(0.05) { exit(0) }
        }
    }
}

func runInjectMouse(_ args: Args) -> Never {
    let dx = args.positionalInt(0, "DX")
    let dy = args.positionalInt(1, "DY")
    let repeats = max(1, args.int("--repeat", default: 1))
    let interval = Double(max(0, args.int("--interval", default: 10))) / 1000.0
    let injector = EventInjector()
    afterCountdown {
        var sent = 0
        every(max(interval, 0.001)) {
            guard sent < repeats else { return }
            injector.mouseMove(dx: dx, dy: dy)
            sent += 1
            if sent == repeats {
                print("sent \(sent) mouse moves")
                after(0.05) { exit(0) }
            }
        }
    }
}

func runInjectClick(_ args: Args) -> Never {
    guard let which = args.positional.first, which == "left" || which == "right" else {
        badUsage("inject-click needs left or right")
    }
    let button: CGMouseButton = which == "left" ? .left : .right
    let injector = EventInjector()
    afterCountdown {
        injector.mouseButton(button, down: true)
        after(0.05) {
            injector.mouseButton(button, down: false)
            print("\(which) click sent")
            after(0.05) { exit(0) }
        }
    }
}
#endif
