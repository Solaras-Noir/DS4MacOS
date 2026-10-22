/// One touchpad contact slot.
public struct TouchPoint: Equatable {
    /// True when a finger is in contact (bit 7 of the first byte is clear).
    public let isTouching: Bool
    /// Contact id (low 7 bits), increments per new touch.
    public let id: UInt8
    /// X position, 0...1919.
    public let x: Int
    /// Y position, 0...1079.
    public let y: Int

    /// Creates a touch point from explicit values.
    public init(isTouching: Bool, id: UInt8, x: Int, y: Int) {
        self.isTouching = isTouching
        self.id = id
        self.x = x
        self.y = y
    }

    /// Decodes four bytes; returns nil unless exactly four bytes are given.
    public init?(bytes: ArraySlice<UInt8>) {
        guard bytes.count == 4 else { return nil }
        let b = Array(bytes)
        self.isTouching = (b[0] & 0x80) == 0
        self.id = b[0] & 0x7F
        self.x = Int(b[1]) | (Int(b[2] & 0x0F) << 8)
        self.y = Int(b[2] >> 4) | (Int(b[3]) << 4)
    }
}
