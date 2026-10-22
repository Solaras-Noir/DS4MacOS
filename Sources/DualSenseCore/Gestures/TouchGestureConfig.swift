import Foundation

/// Thresholds and zone layout for `TouchGestureEngine`.
public struct TouchGestureConfig: Equatable {
    /// Zone layout.
    public var zones: TouchZoneLayout
    /// Longest contact (seconds) that still counts as a tap.
    public var tapMaxDuration: TimeInterval
    /// Largest distance from the start point (touchpad units) for a tap, two-finger tap or hold.
    public var tapMaxMovement: Int
    /// Time (seconds) a finger must rest to begin a hold.
    public var holdMinDuration: TimeInterval
    /// Minimum straight-line distance for a swipe.
    public var swipeMinDistance: Int
    /// Longest contact (seconds) that still counts as a swipe.
    public var swipeMaxDuration: TimeInterval
    /// Maximum gap (seconds) between two touch-downs for a two-finger tap.
    public var twoFingerTapWindow: TimeInterval

    /// Creates a configuration; defaults suit the 1920x1080 DualSense pad.
    public init(zones: TouchZoneLayout = .single,
                tapMaxDuration: TimeInterval = 0.180,
                tapMaxMovement: Int = 40,
                holdMinDuration: TimeInterval = 0.400,
                swipeMinDistance: Int = 300,
                swipeMaxDuration: TimeInterval = 0.500,
                twoFingerTapWindow: TimeInterval = 0.050) {
        self.zones = zones
        self.tapMaxDuration = tapMaxDuration
        self.tapMaxMovement = tapMaxMovement
        self.holdMinDuration = holdMinDuration
        self.swipeMinDistance = swipeMinDistance
        self.swipeMaxDuration = swipeMaxDuration
        self.twoFingerTapWindow = twoFingerTapWindow
    }
}
