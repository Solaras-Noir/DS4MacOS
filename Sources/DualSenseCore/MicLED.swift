/// State of the mute-button LED (common offset 8, valid_flag1 bit 0).
public enum MicLED: UInt8, Equatable {
    /// LED off.
    case off = 0
    /// LED solid on.
    case on = 1
    /// LED pulsing. UNVERIFIED: the kernel writes only 0/1; value 2 for pulse has no source in
    /// `docs/protocol/dualsense-hid.md` and is untested on hardware.
    case pulse = 2
}
