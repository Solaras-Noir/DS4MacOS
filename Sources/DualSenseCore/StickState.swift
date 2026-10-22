/// One analog stick: raw bytes plus normalised values.
public struct StickState: Equatable {
    /// Raw X, 0...255, 128 is centre.
    public let rawX: UInt8
    /// Raw Y, 0 is up, 255 is down.
    public let rawY: UInt8
    /// Normalised X, -1...1, right positive.
    public let x: Float
    /// Normalised Y, -1...1, up positive.
    public let y: Float

    /// Builds a stick from raw bytes: (raw - 128) / 127 clamped, with Y inverted.
    public init(rawX: UInt8, rawY: UInt8) {
        self.rawX = rawX
        self.rawY = rawY
        self.x = StickState.normalise(rawX)
        self.y = -StickState.normalise(rawY)
    }

    private static func normalise(_ raw: UInt8) -> Float {
        min(1, max(-1, (Float(raw) - 128) / 127))
    }
}
