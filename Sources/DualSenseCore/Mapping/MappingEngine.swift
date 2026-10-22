import Foundation

/// Turns controller state and gesture events into keyboard/mouse actions and controller feedback.
///
/// The engine is stateful: it remembers what is held and emits transitions only. It does no I/O
/// and takes time as an argument, so it is deterministic under test. `proxy` mode currently
/// behaves like `augment`; `.none` bindings always emit nothing.
public final class MappingEngine {
    public let profile: Profile

    /// Which physical thing is producing a held binding.
    enum Source: Hashable {
        case button(ButtonID)
        case stick(StickSide, StickDirection)
        case trigger(TriggerSide)
        case hold(ZoneIndex)
    }

    enum StickSide: Hashable { case left, right }
    enum StickDirection: Hashable, CaseIterable { case up, down, left, right }

    /// A gesture binding that is pressed now and released after `tapDuration`.
    struct PendingTap {
        var binding: Binding
        var releaseAt: TimeInterval
    }

    /// How long a gesture binding stays down (seconds).
    public static let tapDuration: TimeInterval = 0.040
    /// Hysteresis for analogue trigger presses.
    static let triggerHysteresis: Float = 0.05
    /// Longest time step integrated for mouse movement, so a stall does not fling the cursor.
    static let maxStep: TimeInterval = 0.1

    var heldKeys: Set<UInt16> = []
    var heldMouse: Set<MouseButton> = []
    var previousSources: Set<Source> = []
    var activeStickDirections: Set<Source> = []
    var activeTriggers: Set<TriggerSide> = []
    var holds: [ZoneIndex: Binding] = [:]
    var pendingTaps: [PendingTap] = []
    var lastTime: TimeInterval?
    var mouseRemainderX = 0.0
    var mouseRemainderY = 0.0

    /// Creates an engine for a profile.
    public init(profile: Profile) {
        self.profile = profile
    }

    /// The profile's static outputs (lightbar, trigger effects, player LEDs).
    public func initialFeedback() -> [FeedbackAction] {
        var out: [FeedbackAction] = []
        if let rgb = profile.lightbar { out.append(.lightbar(rgb)) }
        if let e = profile.leftTriggerEffect { out.append(.trigger(.left, e)) }
        if let e = profile.rightTriggerEffect { out.append(.trigger(.right, e)) }
        if let leds = profile.playerLEDs { out.append(.playerLEDs(leds)) }
        return out
    }

    /// Releases everything currently held and forgets pending taps and holds.
    public func releaseAll() -> [OutputAction] {
        var out: [OutputAction] = heldKeys.sorted().map { .keyUp($0) }
        out += heldMouse.sorted { $0.rawValue < $1.rawValue }.map { .mouseUp($0) }
        heldKeys = []
        heldMouse = []
        previousSources = []
        activeStickDirections = []
        activeTriggers = []
        holds = [:]
        pendingTaps = []
        mouseRemainderX = 0
        mouseRemainderY = 0
        return out
    }

    /// Advances the engine by one controller report.
    public func update(state: ControllerState, gestures: [GestureEvent],
                       at time: TimeInterval) -> MappingOutput {
        let dt = min(Self.maxStep, max(0, time - (lastTime ?? time)))
        lastTime = time

        var output = MappingOutput()
        pendingTaps.removeAll { $0.releaseAt <= time }

        var scrolls: [Int] = []
        handleGestures(gestures, at: time, scrolls: &scrolls)

        var active: [(Source, Binding)] = []
        collectButtons(state, into: &active)
        collectSticks(state, into: &active)
        collectTriggers(state, into: &active, feedback: &output.feedback)
        for zone in holds.keys.sorted() {
            if let b = holds[zone] { active.append((.hold(zone), b)) }
        }

        // Edge-triggered scroll bindings fire once when their source becomes active.
        let sources = Set(active.map { $0.0 })
        for (source, binding) in active where !previousSources.contains(source) {
            if case let .scroll(dy) = binding { scrolls.append(dy) }
        }
        previousSources = sources

        output.actions = diffHeld(active: active.map { $0.1 }) + scrolls.map { .scroll($0) }
        let move = mouseMovement(state, dt: dt)
        if move.0 != 0 || move.1 != 0 { output.actions.append(.mouseMove(dx: move.0, dy: move.1)) }
        return output
    }

    /// Compares the keys and mouse buttons wanted now with those held and returns transitions.
    private func diffHeld(active: [Binding]) -> [OutputAction] {
        var keys = Set<UInt16>()
        var mouse = Set<MouseButton>()
        for binding in active + pendingTaps.map({ $0.binding }) {
            switch binding {
            case .key(let code): keys.insert(code)
            case .mouseButton(let b): mouse.insert(b)
            case .scroll, .none: break
            }
        }
        var out: [OutputAction] = []
        out += heldKeys.subtracting(keys).sorted().map { .keyUp($0) }
        out += heldMouse.subtracting(mouse).sorted { $0.rawValue < $1.rawValue }.map { .mouseUp($0) }
        out += keys.subtracting(heldKeys).sorted().map { .keyDown($0) }
        out += mouse.subtracting(heldMouse).sorted { $0.rawValue < $1.rawValue }.map { .mouseDown($0) }
        heldKeys = keys
        heldMouse = mouse
        return out
    }
}
