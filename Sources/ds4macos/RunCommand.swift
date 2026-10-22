#if os(macOS)
import Foundation
import ApplicationServices
import DualSenseCore

/// Keeps the runner and the event sources alive for the life of the process.
private var runner: Runner?
private var sources: [Any] = []

/// Runs `block` every `interval` seconds on the main queue.
func every(_ interval: Double, _ block: @escaping () -> Void) {
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + interval, repeating: interval)
    timer.setEventHandler(handler: block)
    timer.resume()
    sources.append(timer)
}

/// Releases everything, restores the terminal and exits with status 0.
private func finish() -> Never {
    runner?.shutdown()
    restoreTerminal()
    exit(0)
}

private func installSignalHandlers() {
    for sig in [SIGINT, SIGTERM, SIGHUP, SIGTSTP, SIGQUIT] {
        _ = signal(sig, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
        source.setEventHandler { finish() }
        source.resume()
        sources.append(source)
    }
}

private func installKeyReader() {
    guard enableRawTerminal() else { return }
    let source = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: .main)
    source.setEventHandler {
        var byte: UInt8 = 0
        let count = read(STDIN_FILENO, &byte, 1)
        if count == 1 {
            if byte == UInt8(ascii: "p") || byte == UInt8(ascii: "P") { runner?.togglePassThrough() }
        } else if count == 0 {
            source.cancel()  // stdin closed
        }
    }
    source.resume()
    sources.append(source)
}

/// `ds4macos run [--profile X] [--mode augment|keyboardMouse]`.
func runCommand(_ args: CommandArgs) {
    var profile = loadProfile(args.string("--profile") ?? "fallout4Augment")
    if let text = args.string("--mode") {
        guard let override = ProfileMode(rawValue: text) else {
            badUsage("bad --mode '\(text)' (augment or keyboardMouse)")
        }
        profile.mode = override
    }
    if profile.mode == .proxy {
        printErr("proxy mode arrives in M3b")
        exit(1)
    }
    if !AXIsProcessTrusted() {
        printErr("warning: Accessibility is not granted; keyboard and mouse events will not be delivered."
            + " Run 'ds4macos permissions'.")
    }

    // Handlers first, so a signal during start-up still releases everything.
    installSignalHandlers()
    let r = Runner(profile: profile)
    runner = r
    r.start()
    installKeyReader()
    CFRunLoopRun()
    finish()
}
#endif
