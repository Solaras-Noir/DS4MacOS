/// Index of a touchpad zone (row-major for grids, array order for custom rects).
public typealias ZoneIndex = Int

/// Direction of a swipe. The dominant axis decides; y grows downward.
public enum SwipeDirection: Equatable {
    /// Finger moved toward the top of the pad.
    case up
    /// Finger moved toward the bottom of the pad.
    case down
    /// Finger moved toward the left.
    case left
    /// Finger moved toward the right.
    case right
}

/// A gesture recognized by `TouchGestureEngine`.
public enum GestureEvent: Equatable {
    /// A quick single-finger tap that started in the zone.
    case tap(ZoneIndex)
    /// A quick tap with two fingers.
    case twoFingerTap
    /// A finger has rested in the zone for the hold duration.
    case holdBegan(ZoneIndex)
    /// A held finger lifted.
    case holdEnded(ZoneIndex)
    /// A fast single-finger stroke, reported with the zone where it started.
    case swipe(SwipeDirection, ZoneIndex)
    /// Per-report movement of a lone finger, in touchpad units.
    case drag(dx: Int, dy: Int)
    /// The touchpad button went down (rising edge). The zone is that of the first touching
    /// finger's current position, or zone 0 if no finger is down.
    case padClick(ZoneIndex)
}
