/// State of the mute-button LED.
public enum MicLED: UInt8, Equatable {
    /// LED off.
    case off = 0
    /// LED solid on.
    case on = 1
    /// LED pulsing.
    case pulse = 2
}
