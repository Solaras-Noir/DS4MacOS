#if os(macOS)
import Foundation
import DS4Mac

func runDump(_ args: Args) -> Never {
    let seconds = args.int("--seconds", default: 10)
    guard let label = args.string("--label"), let out = args.string("--out") else {
        badUsage("dump needs --label and --out")
    }
    let device = openFirstDevice(seize: false)
    switchBluetoothToFullReports(device)

    let safeLabel = label.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: "_")
    let date = ISO8601DateFormatter().string(from: Date())
    var lines = ["# transport=\(device.transport) label=\(safeLabel) date=\(date) maxInputReportSize=\(device.maxInputReportSize)"]

    device.onInputReport = { id, bytes in
        lines.append(String(format: "%02x", id) + " " + hex(bytes))
    }
    after(Double(max(0, seconds))) {
        device.close()
        let text = lines.joined(separator: "\n") + "\n"
        do {
            try text.write(toFile: out, atomically: true, encoding: .utf8)
            print("wrote \(lines.count - 1) reports to \(out)")
            exit(0)
        } catch {
            printErr("failed to write \(out): \(error)")
            exit(1)
        }
    }
    print("capturing for \(seconds) s, move the sticks and press buttons")
    runForever()
}
#endif
