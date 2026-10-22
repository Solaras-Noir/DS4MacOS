/// An 8-bit-per-channel colour, used for the lightbar.
public struct RGB: Equatable, Codable {
    /// Red channel, 0...255.
    public var red: UInt8
    /// Green channel, 0...255.
    public var green: UInt8
    /// Blue channel, 0...255.
    public var blue: UInt8

    /// Creates a colour from its three channels.
    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}
