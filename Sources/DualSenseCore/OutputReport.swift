/// Builder for output reports (USB ID 0x02, 48 bytes; Bluetooth ID 0x31, 78 bytes). Both share one
/// 47-byte common block. Valid flags are set only for assigned fields.
public struct OutputReport {
    /// Lightbar colour, if assigned.
    public var lightbar: RGB?
    /// When true, sets the lightbar fade-out/setup bit (valid_flag2 b1, lightbar_setup b1). Over Bluetooth
    /// the kernel sends this once to reconfigure the lightbar (K L1685-1696); see `lightbarSetup()`.
    public var lightbarFadeOut = false
    /// Player LED bit mask (bits 0...4), if assigned. See `PlayerLEDs`.
    public var playerLEDs: UInt8?
    /// Mute-button LED state, if assigned.
    public var micLED: MicLED?
    /// Right trigger effect, if assigned.
    public var rightTrigger: TriggerEffect?
    /// Left trigger effect, if assigned.
    public var leftTrigger: TriggerEffect?
    /// Which rumble flag variant to use; default `.v2`. See `VibrationMode`.
    public var vibrationMode: VibrationMode = .v2
    /// Rumble motors (strong = left/low frequency, weak = right/high frequency), if assigned.
    public private(set) var rumbleValues: (strong: UInt8, weak: UInt8)?

    /// Creates an empty report that changes nothing.
    public init() {}

    /// A report that only performs the Bluetooth lightbar setup (fade-out/reconfigure flag).
    public static func lightbarSetup() -> OutputReport {
        var r = OutputReport()
        r.lightbarFadeOut = true
        return r
    }

    /// Assigns rumble intensities.
    ///
    /// Flags follow the Linux driver (see `VibrationMode`): `.v1` sets valid_flag0 |= 0x03 and leaves
    /// valid_flag2 bit 2 alone; `.v2` sets valid_flag0 |= 0x02 and valid_flag2 |= 0x04. Flag0 bit 0 and
    /// flag2 bit 2 are never both set. M0 failed because it omitted flag0 bit 1.
    public mutating func rumble(strong: UInt8, weak: UInt8) {
        rumbleValues = (strong, weak)
    }

    /// The 47-byte common block shared by USB (at buffer offset 1) and Bluetooth (at offset 3).
    public func commonBlock() -> [UInt8] {
        var c = [UInt8](repeating: 0, count: BluetoothFraming.commonLength)
        var flag0: UInt8 = 0, flag1: UInt8 = 0, flag2: UInt8 = 0

        if let r = rumbleValues {
            switch vibrationMode {
            case .v1: flag0 |= 0x03
            case .v2:
                flag0 |= 0x02
                flag2 |= 0x04
            }
            c[2] = r.weak    // motor_right
            c[3] = r.strong  // motor_left
        }
        if let m = micLED {
            flag1 |= 0x01
            c[8] = m.rawValue
        }
        if let t = rightTrigger {
            flag0 |= 0x04
            c.replaceSubrange(10..<21, with: t.encoded)
        }
        if let t = leftTrigger {
            flag0 |= 0x08
            c.replaceSubrange(21..<32, with: t.encoded)
        }
        if lightbarFadeOut {
            flag2 |= 0x02
            c[41] = 0x02
        }
        if let col = lightbar {
            flag1 |= 0x04
            c[44] = col.red
            c[45] = col.green
            c[46] = col.blue
        }
        if let p = playerLEDs {
            flag1 |= 0x10
            c[43] = p & 0x1F
        }
        c[0] = flag0
        c[1] = flag1
        c[38] = flag2
        return c
    }

    /// Serialises to 48 bytes: byte 0 is 0x02, the common block starts at offset 1.
    public func usbBytes() -> [UInt8] {
        [0x02] + commonBlock()
    }

    /// Serialises to the 78-byte Bluetooth 0x31 report (sequence masked to 4 bits, CRC seed 0xA2).
    public func bluetoothBytes(sequence: UInt8) -> [UInt8] {
        BluetoothFraming.frame(outputCommon: commonBlock(), sequence: sequence)
    }
}
