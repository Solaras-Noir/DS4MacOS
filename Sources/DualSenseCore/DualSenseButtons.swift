/// The digital buttons of the controller, excluding the D-pad.
public struct DualSenseButtons: OptionSet {
    /// Raw bit set.
    public let rawValue: UInt16
    /// Creates a set from raw bits.
    public init(rawValue: UInt16) { self.rawValue = rawValue }

    public static let square = DualSenseButtons(rawValue: 1 << 0)
    public static let cross = DualSenseButtons(rawValue: 1 << 1)
    public static let circle = DualSenseButtons(rawValue: 1 << 2)
    public static let triangle = DualSenseButtons(rawValue: 1 << 3)
    public static let l1 = DualSenseButtons(rawValue: 1 << 4)
    public static let r1 = DualSenseButtons(rawValue: 1 << 5)
    public static let l2 = DualSenseButtons(rawValue: 1 << 6)
    public static let r2 = DualSenseButtons(rawValue: 1 << 7)
    public static let create = DualSenseButtons(rawValue: 1 << 8)
    public static let options = DualSenseButtons(rawValue: 1 << 9)
    public static let l3 = DualSenseButtons(rawValue: 1 << 10)
    public static let r3 = DualSenseButtons(rawValue: 1 << 11)
    public static let ps = DualSenseButtons(rawValue: 1 << 12)
    public static let touchpad = DualSenseButtons(rawValue: 1 << 13)
    public static let mute = DualSenseButtons(rawValue: 1 << 14)
}
