import Foundation

/// A keyboard or mouse event for the app to inject.
public enum OutputAction: Equatable, Hashable {
    case keyDown(UInt16)
    case keyUp(UInt16)
    /// Whole-pixel relative mouse movement (screen coordinates, y grows downward).
    case mouseMove(dx: Double, dy: Double)
    case mouseDown(MouseButton)
    case mouseUp(MouseButton)
    /// Positive scrolls up.
    case scroll(Int)
}

/// An output to send back to the controller.
public enum FeedbackAction: Equatable {
    case rumble(strong: UInt8, weak: UInt8, durationMs: Int)
    case lightbar(RGB)
    case trigger(TriggerSide, TriggerEffect)
    case playerLEDs(UInt8)
}

/// What one engine update produced.
public struct MappingOutput: Equatable {
    public var actions: [OutputAction]
    public var feedback: [FeedbackAction]

    public init(actions: [OutputAction] = [], feedback: [FeedbackAction] = []) {
        self.actions = actions
        self.feedback = feedback
    }
}
