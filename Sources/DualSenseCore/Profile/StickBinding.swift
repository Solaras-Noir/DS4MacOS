import Foundation

/// How a stick is mapped.
public enum StickBinding: Equatable, Codable {
    /// Four keys. A direction presses past `threshold` and releases below `threshold - hysteresis`.
    case wasd(threshold: Float = 0.5, hysteresis: Float = 0.1)
    /// Mouse movement. `sensitivity` is pixels per second at full deflection, `curve` the response
    /// exponent, `deadZone` the radial dead zone (0...1).
    case mouse(sensitivity: Double, curve: Double, deadZone: Float)
    case none
}

/// Which analogue trigger.
public enum TriggerSide: String, Equatable, Hashable, Codable, CaseIterable {
    case left
    case right
}

/// How an analogue trigger is mapped.
public enum TriggerBinding: Equatable, Codable {
    /// Presses `Binding` once the trigger value (0...1) reaches `threshold`.
    case button(Binding, threshold: Float)
    case none
}

/// A rumble pulse fired when a trigger crosses its press threshold.
public struct RumblePulse: Equatable, Codable {
    public var strong: UInt8
    public var weak: UInt8
    public var durationMs: Int
    public var trigger: TriggerSide

    public init(strong: UInt8, weak: UInt8, durationMs: Int, trigger: TriggerSide) {
        self.strong = strong
        self.weak = weak
        self.durationMs = durationMs
        self.trigger = trigger
    }
}
