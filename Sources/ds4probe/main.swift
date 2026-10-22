#if os(macOS)
import Foundation

let usage = """
usage: ds4probe <command> [options]

commands:
  list                                     list connected DualSense controllers
  dump --seconds N --label TEXT --out PATH capture input reports to a fixture file
  read [--seize]                           print decoded input reports at 10 Hz
  lightbar R G B                           set the lightbar color
  rumble STRONG WEAK [--ms N] [--vibration v1|v2]  run the rumble motors (default 500 ms, v2)
  firmware                                 read feature report 0x20, print update_version and rumble variant
  trigger left|right MODE P1..P10          set an adaptive trigger effect (decimal)
  player N                                 set the player LEDs (0-5)
  inject-key KEYCODE [--hold MS]           post a keyboard event
  inject-mouse DX DY [--repeat N --interval MS]  post mouse move events
  inject-click left|right                  post a mouse click
  bridge [--seize] [--sens F]              map controller input to events
"""

let rawArgs = Array(CommandLine.arguments.dropFirst())
guard let command = rawArgs.first else {
    printErr(usage)
    exit(2)
}
if command == "help" || command == "--help" || command == "-h" {
    print(usage)
    exit(0)
}
let args = Args(Array(rawArgs.dropFirst()))

switch command {
case "list": runList()
case "dump": runDump(args)
case "read": runRead(args)
case "lightbar": runLightbar(args)
case "rumble": runRumble(args)
case "firmware": runFirmware()
case "trigger": runTrigger(args)
case "player": runPlayer(args)
case "inject-key": runInjectKey(args)
case "inject-mouse": runInjectMouse(args)
case "inject-click": runInjectClick(args)
case "bridge": runBridge(args)
default:
    printErr("unknown command '\(command)'")
    printErr(usage)
    exit(2)
}
#endif
