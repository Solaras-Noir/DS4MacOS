#if os(macOS)
import Foundation
import DualSenseCore

/// Built-in profiles under the names used on the command line.
let builtInProfiles: [(name: String, profile: Profile)] = [
    ("fallout4KeyboardMouse", .fallout4KeyboardMouse),
    ("fallout4Augment", .fallout4Augment),
    ("genericAugment", .genericAugment),
    ("passThrough", .passThrough),
]

/// Resolves a built-in name or a JSON file path. Exits 2 listing the built-ins if neither matches.
func loadProfile(_ spec: String) -> Profile {
    if let found = builtInProfiles.first(where: { $0.name == spec }) { return found.profile }
    guard FileManager.default.fileExists(atPath: spec) else {
        printErr("unknown profile '\(spec)' (not a built-in name or an existing file)")
        printErr("built-in profiles: \(builtInProfiles.map { $0.name }.joined(separator: ", "))")
        exit(2)
    }
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: spec))
        return try JSONDecoder().decode(Profile.self, from: data)
    } catch {
        printErr("cannot read profile \(spec): \(error)")
        exit(2)
    }
}

/// `ds4macos export-profile <name> <path.json>`.
func exportProfileCommand(_ args: CommandArgs) {
    guard args.positional.count == 2 else { badUsage("export-profile needs a profile name and a path") }
    let name = args.positional[0]
    guard let found = builtInProfiles.first(where: { $0.name == name }) else {
        printErr("unknown built-in profile '\(name)'")
        printErr("built-in profiles: \(builtInProfiles.map { $0.name }.joined(separator: ", "))")
        exit(2)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
        let data = try encoder.encode(found.profile)
        try data.write(to: URL(fileURLWithPath: args.positional[1]), options: .atomic)
        print("wrote \(args.positional[1])")
    } catch {
        printErr("export failed: \(error)")
        exit(1)
    }
}
#endif
