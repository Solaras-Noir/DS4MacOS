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

/// Minimal argument parser: positionals and `--flag value` pairs.
struct CommandArgs {
    private static let valueFlags: Set<String> = ["--profile", "--mode"]
    var positional: [String] = []
    private var values: [String: String] = [:]

    init(_ items: [String]) {
        var i = 0
        while i < items.count {
            let item = items[i]
            if CommandArgs.valueFlags.contains(item) {
                guard i + 1 < items.count else { badUsage("missing value for \(item)") }
                values[item] = items[i + 1]
                i += 2
            } else if item.hasPrefix("--") {
                badUsage("unknown option \(item)")
            } else {
                positional.append(item)
                i += 1
            }
        }
    }

    func string(_ flag: String) -> String? { values[flag] }
}
#endif
