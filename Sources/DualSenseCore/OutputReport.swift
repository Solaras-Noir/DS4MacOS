/// Builder for the 48-byte USB output report (ID 0x02). Valid flags are set only for assigned fields.
public struct OutputReport {
    /// Lightbar colour, if assigned.
    public var lightbar: RGB?
    /// Player LED bit mask (bits 0...4), if assigned.
    public var playerLEDs: UInt8?
    /// Mute-button LED state, if assigned.
    public var micLED: MicLED?
    /// Right trigger effect, if assigned.
    public var rightTrigger: TriggerEffect?
    /// Left trigger effect, if assigned.
    public var leftTrigger: TriggerEffect?
    /// Rumble motors (strong = left/low frequency, weak = right/high frequency), if assigned.
    public private(set) var rumbleValues: (strong: UInt8, weak: UInt8)?

    /// Creates an empty report that changes nothing.
    public init() {}

    /// Assigns rumble intensities.
    public mutating func rumble(strong: UInt8, weak: UInt8) {
        rumbleValues = (strong, weak)
    }

    /// Serialises to 48 bytes: byte 0 is 0x02, the common block starts at offset 1.
    public func usbBytes() -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 48)
        out[0] = 0x02
        // Common block offset c maps to out[1 + c].
        var flag0: UInt8 = 0, flag1: UInt8 = 0, flag2: UInt8 = 0

        if let r = rumbleValues {
            flag0 |= 0x01
            flag2 |= 0x04
            out[3] = r.weak    // motor_right
            out[4] = r.strong  // motor_left
        }
        if let m = micLED {
            flag1 |= 0x01
            out[9] = m.rawValue
        }
        if let t = rightTrigger {
            flag0 |= 0x04
            out.replaceSubrange(11..<22, with: t.encoded)
        }
        if let t = leftTrigger {
            flag0 |= 0x08
            out.replaceSubrange(22..<33, with: t.encoded)
        }
        if let c = lightbar {
            flag1 |= 0x04
            out[45] = c.red
            out[46] = c.green
            out[47] = c.blue
        }
        if let p = playerLEDs {
            flag1 |= 0x10
            out[44] = p & 0x1F
        }
        out[1] = flag0
        out[2] = flag1
        out[39] = flag2
        return out
    }
}
