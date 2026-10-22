#if os(macOS)
import Foundation

let usage = """
usage: ds4macos <command> [options]

commands:
  run [--profile NAME|PATH.json] [--mode augment|keyboardMouse]
                                run a profile (default fallout4Augment); press p for pass-through
  devices                       list connected DualSense controllers
  permissions                   show the Accessibility status and ask for it if missing
  export-profile NAME PATH.json write a built-in profile as JSON

built-in profiles: \(builtInProfiles.map { $0.name }.joined(separator: ", "))
"""

let rawArgs = Array(CommandLine.arguments.dropFirst())
guard let command = rawArgs.first else {
    printErr(usage)
    exit(2)
}
let args = CommandArgs(Array(rawArgs.dropFirst()))

switch command {
case "help", "--help", "-h": print(usage)
case "run": runCommand(args)
case "devices": devicesCommand()
case "permissions": permissionsCommand()
case "export-profile": exportProfileCommand(args)
default:
    badUsage("unknown command '\(command)'")
}
#endif
