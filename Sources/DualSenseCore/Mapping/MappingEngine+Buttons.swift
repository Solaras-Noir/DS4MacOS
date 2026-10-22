import Foundation

extension MappingEngine {
    /// Adds the bindings of all pressed face/shoulder/dpad buttons, in a fixed order.
    func collectButtons(_ state: ControllerState, into active: inout [(Source, Binding)]) {
        for id in ButtonID.allCases where Self.isPressed(id, in: state) {
            guard let binding = profile.buttons[id] else { continue }
            if case .none = binding { continue }
            active.append((.button(id), binding))
        }
    }

    static func isPressed(_ id: ButtonID, in state: ControllerState) -> Bool {
        let b = state.buttons
        switch id {
        case .cross: return b.contains(.cross)
        case .circle: return b.contains(.circle)
        case .square: return b.contains(.square)
        case .triangle: return b.contains(.triangle)
        case .l1: return b.contains(.l1)
        case .r1: return b.contains(.r1)
        case .l3: return b.contains(.l3)
        case .r3: return b.contains(.r3)
        case .options: return b.contains(.options)
        case .create: return b.contains(.create)
        case .ps: return b.contains(.ps)
        case .mute: return b.contains(.mute)
        case .dpadUp: return [.north, .northEast, .northWest].contains(state.dpad)
        case .dpadDown: return [.south, .southEast, .southWest].contains(state.dpad)
        case .dpadLeft: return [.west, .northWest, .southWest].contains(state.dpad)
        case .dpadRight: return [.east, .northEast, .southEast].contains(state.dpad)
        }
    }

    /// Adds trigger button bindings and emits the rumble pulse on a press edge.
    func collectTriggers(_ state: ControllerState, into active: inout [(Source, Binding)],
                         feedback: inout [FeedbackAction]) {
        for (side, binding, value) in [(TriggerSide.left, profile.l2, state.l2),
                                       (TriggerSide.right, profile.r2, state.r2)] {
            var threshold: Float = 0.5
            var mapped: Binding = .none
            if case let .button(b, t) = binding { mapped = b; threshold = t }
            let wasActive = activeTriggers.contains(side)
            let isActive = wasActive ? value >= threshold - Self.triggerHysteresis : value >= threshold
            if isActive {
                activeTriggers.insert(side)
                if case .none = mapped {} else { active.append((.trigger(side), mapped)) }
                if !wasActive, let pulse = profile.rumbleOnTrigger, pulse.trigger == side {
                    feedback.append(.rumble(strong: pulse.strong, weak: pulse.weak,
                                            durationMs: pulse.durationMs))
                }
            } else {
                activeTriggers.remove(side)
            }
        }
    }
}
