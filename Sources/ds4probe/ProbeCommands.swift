#if os(macOS)
import Foundation
import DS4Mac
import DualSenseCore

func runList() -> Never {
    let devices = HIDDevice.all()
    if devices.isEmpty {
        print("no DualSense controllers found")
        exit(1)
    }
    for d in devices {
        let pid = String(format: "0x%04X", d.productID)
        print("\(d.name) product=\(pid) transport=\(d.transport) maxInputReportSize=\(d.maxInputReportSize)")
    }
    exit(0)
}

/// Opens the controller without seizing, sends the report, waits briefly and exits.
/// `followUp` runs after `delay` seconds (used by rumble to stop the motors).
func sendOutput(_ report: OutputReport, followUp: (delay: Double, report: OutputReport)? = nil) -> Never {
    let device = openFirstDevice(seize: false)
    if !device.transport.lowercased().contains("usb") {
        print("note: transport is \(device.transport); the USB output report format may be ignored")
    }
    func send(_ r: OutputReport) {
        let bytes = r.usbBytes()
        let result = device.setOutputReport(id: 0x02, bytes: bytes)
        print("sent \(bytes.count) bytes -> \(hex32(result))")
        print(hex(bytes))
    }
    send(report)
    if let next = followUp {
        after(next.delay) { send(next.report) }
        after(next.delay + 0.1) { exit(0) }
    } else {
        after(0.1) { exit(0) }
    }
    runForever()
}

func runLightbar(_ args: Args) -> Never {
    var r = OutputReport()
    r.lightbar = RGB(red: args.positionalByte(0, "R"),
                     green: args.positionalByte(1, "G"),
                     blue: args.positionalByte(2, "B"))
    sendOutput(r)
}

func runRumble(_ args: Args) -> Never {
    let strong = args.positionalByte(0, "STRONG")
    let weak = args.positionalByte(1, "WEAK")
    let ms = max(0, args.int("--ms", default: 500))
    var on = OutputReport()
    on.rumble(strong: strong, weak: weak)
    var off = OutputReport()
    off.rumble(strong: 0, weak: 0)
    sendOutput(on, followUp: (delay: Double(ms) / 1000.0, report: off))
}

func runTrigger(_ args: Args) -> Never {
    guard let side = args.positional.first, side == "left" || side == "right" else {
        badUsage("trigger needs left or right")
    }
    let mode = args.positionalByte(1, "MODE")
    var params: [UInt8] = []
    var index = 2
    while index < args.positional.count {
        params.append(args.positionalByte(index, "P\(index - 1)"))
        index += 1
    }
    guard params.count <= 10 else { badUsage("at most 10 trigger parameters") }
    var r = OutputReport()
    if side == "left" {
        r.leftTrigger = .raw(mode: mode, params: params)
    } else {
        r.rightTrigger = .raw(mode: mode, params: params)
    }
    sendOutput(r)
}

func runPlayer(_ args: Args) -> Never {
    let patterns: [UInt8] = [0x00, 0x04, 0x0A, 0x15, 0x1B, 0x1F]
    let n = args.positionalInt(0, "N")
    guard n >= 0 && n < patterns.count else { badUsage("player N must be 0-5") }
    var r = OutputReport()
    r.playerLEDs = patterns[n]
    sendOutput(r)
}
#endif
