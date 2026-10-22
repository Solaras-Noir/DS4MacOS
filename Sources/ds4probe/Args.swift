#if os(macOS)
import Foundation

/// Writes a line to standard error.
func printErr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

/// Prints a message and the usage text, then exits with status 2.
func badUsage(_ message: String) -> Never {
    printErr(message)
    printErr(usage)
    exit(2)
}

/// Minimal argument parser: positionals, `--flag value` pairs and bare `--switch` flags.
struct Args {
    private static let valueFlags: Set<String> = [
        "--seconds", "--label", "--out", "--ms", "--hold", "--repeat", "--interval", "--sens",
    ]
    var positional: [String] = []
    private var values: [String: String] = [:]
    private var switches: Set<String> = []

    init(_ items: [String]) {
        var i = 0
        while i < items.count {
            let item = items[i]
            if Args.valueFlags.contains(item) {
                guard i + 1 < items.count else { badUsage("missing value for \(item)") }
                values[item] = items[i + 1]
                i += 2
            } else if item.hasPrefix("--") {
                switches.insert(item)
                i += 1
            } else {
                positional.append(item)
                i += 1
            }
        }
    }

    func has(_ flag: String) -> Bool { switches.contains(flag) }

    func string(_ flag: String) -> String? { values[flag] }

    func int(_ flag: String, default fallback: Int) -> Int {
        guard let text = values[flag] else { return fallback }
        guard let n = Int(text) else { badUsage("bad number for \(flag): \(text)") }
        return n
    }

    func double(_ flag: String, default fallback: Double) -> Double {
        guard let text = values[flag] else { return fallback }
        guard let n = Double(text) else { badUsage("bad number for \(flag): \(text)") }
        return n
    }

    /// Positional argument `index` parsed as an integer, or exits with usage.
    func positionalInt(_ index: Int, _ what: String) -> Int {
        guard index < positional.count, let n = Int(positional[index]) else {
            badUsage("missing or bad \(what)")
        }
        return n
    }

    /// Positional argument `index` parsed as a byte (0-255), or exits with usage.
    func positionalByte(_ index: Int, _ what: String) -> UInt8 {
        let n = positionalInt(index, what)
        guard n >= 0 && n <= 255 else { badUsage("\(what) must be 0-255") }
        return UInt8(n)
    }
}
#endif
