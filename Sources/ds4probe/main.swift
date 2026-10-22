#if os(macOS)
import Foundation

let usage = """
usage: ds4probe <command> [options]

commands:
  list          list connected DualSense controllers
  dump          capture input reports to a fixture file
  read          print decoded input reports
  lightbar      set the lightbar color
  rumble        run the rumble motors
  trigger       set an adaptive trigger effect
  player        set the player LEDs
  inject-key    post a keyboard event
  inject-mouse  post a mouse move event
  inject-click  post a mouse click event
  bridge        map controller input to events
"""

let args = CommandLine.arguments.dropFirst()
if args.isEmpty || args.first == "help" || args.first == "--help" || args.first == "-h" {
    print(usage)
    exit(0)
}
print("ds4probe: command '\(args.first ?? "")' is not implemented yet")
print(usage)
exit(0)
#endif
