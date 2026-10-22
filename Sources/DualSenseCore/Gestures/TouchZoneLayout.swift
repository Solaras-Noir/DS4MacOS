/// A rectangle in touchpad coordinates (half-open: contains x in origin..<origin+size).
public struct TouchRect: Equatable, Codable {
    /// Left edge.
    public var x: Int
    /// Top edge.
    public var y: Int
    /// Width in touchpad units.
    public var width: Int
    /// Height in touchpad units.
    public var height: Int

    /// Creates a rectangle.
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// True when the point lies inside the rectangle.
    public func contains(x px: Int, y py: Int) -> Bool {
        px >= x && px < x + width && py >= y && py < y + height
    }
}

/// How the touchpad is divided into zones.
public enum TouchZoneLayout: Equatable, Codable {
    /// One zone covering the pad.
    case single
    /// Two zones side by side (left = 0, right = 1).
    case columns2
    /// Two zones stacked (top = 0, bottom = 1).
    case rows2
    /// Four zones, row-major (top-left 0, top-right 1, bottom-left 2, bottom-right 3).
    case grid2x2
    /// Custom rectangles; index is array order. A point in none of them is zone 0.
    case custom([TouchRect])

    /// Touchpad width in units.
    public static let padWidth = 1920
    /// Touchpad height in units.
    public static let padHeight = 1080

    /// Zone index for a touchpad position.
    public func zone(x: Int, y: Int) -> ZoneIndex {
        switch self {
        case .single: return 0
        case .columns2: return Self.cell(x, Self.padWidth, 2)
        case .rows2: return Self.cell(y, Self.padHeight, 2)
        case .grid2x2:
            return Self.cell(y, Self.padHeight, 2) * 2 + Self.cell(x, Self.padWidth, 2)
        case .custom(let rects):
            return rects.firstIndex(where: { $0.contains(x: x, y: y) }) ?? 0
        }
    }

    private static func cell(_ v: Int, _ size: Int, _ n: Int) -> Int {
        min(n - 1, max(0, v * n / size))
    }
}
