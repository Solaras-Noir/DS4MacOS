/// Direction of the hat switch (D-pad).
public enum Dpad: Equatable {
    case none, north, northEast, east, southEast, south, southWest, west, northWest

    /// Maps the 4-bit hat value (0 N, 1 NE ... 7 NW, anything else released) to a direction.
    public init(hat: UInt8) {
        switch hat {
        case 0: self = .north
        case 1: self = .northEast
        case 2: self = .east
        case 3: self = .southEast
        case 4: self = .south
        case 5: self = .southWest
        case 6: self = .west
        case 7: self = .northWest
        default: self = .none
        }
    }
}
