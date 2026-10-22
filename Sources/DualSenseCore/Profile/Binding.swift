import Foundation

/// A mouse button the engine can press.
public enum MouseButton: String, Equatable, Hashable, Codable, CaseIterable {
    case left
    case right
    case middle
}

/// What an input produces. `.none` emits nothing (in `augment` mode the game keeps the pad).
public enum Binding: Equatable, Hashable, Codable {
    /// A macOS virtual key code (for example 14 for E).
    case key(code: UInt16)
    case mouseButton(MouseButton)
    /// A scroll step fired once on press. Positive scrolls up.
    case scroll(dy: Int)
    case none
}

/// The DualSense buttons a profile can bind, plus the four dpad directions.
/// The raw value is the key used in profile JSON.
public enum ButtonID: String, Equatable, Hashable, Codable, CaseIterable {
    case cross, circle, square, triangle
    case l1, r1, l3, r3
    case options, create, ps, mute
    case dpadUp, dpadDown, dpadLeft, dpadRight
}

/// Whether a profile lets the game keep the pad, takes it over, or serves a proxy pad.
public enum ProfileMode: String, Equatable, Codable, CaseIterable {
    /// Pad shared with the game; the app adds touchpad keys, feedback and any explicit binding.
    case augment
    /// Pad seized; every input becomes keyboard and mouse events.
    case keyboardMouse
    /// Reserved for M3b; the engine currently treats it like `augment`.
    case proxy
}
