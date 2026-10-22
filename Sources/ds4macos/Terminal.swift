#if os(macOS)
import Foundation

/// Original terminal settings, set once raw mode is on.
private var savedTermios: termios?

/// Puts stdin in non-canonical, no-echo mode (signals stay enabled). Does nothing if stdin is not a TTY.
/// Returns whether raw mode is active. Registers an atexit hook that restores the terminal.
@discardableResult
func enableRawTerminal() -> Bool {
    guard isatty(STDIN_FILENO) != 0, savedTermios == nil else { return savedTermios != nil }
    var original = termios()
    guard tcgetattr(STDIN_FILENO, &original) == 0 else { return false }
    var raw = original
    raw.c_lflag &= ~tcflag_t(ICANON | ECHO)
    withUnsafeMutableBytes(of: &raw.c_cc) { bytes in
        bytes[Int(VMIN)] = 1
        bytes[Int(VTIME)] = 0
    }
    guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else { return false }
    savedTermios = original
    atexit { restoreTerminal() }
    return true
}

/// Restores the terminal settings saved by `enableRawTerminal`. Safe to call any number of times.
func restoreTerminal() {
    guard var original = savedTermios else { return }
    savedTermios = nil
    _ = tcsetattr(STDIN_FILENO, TCSANOW, &original)
}
#endif
