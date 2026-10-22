import Foundation

extension MappingEngine {
    /// Looks up a gesture binding; unbound gestures return nil.
    func gestureBinding(zone: ZoneIndex, kind: GestureKind) -> Binding? {
        guard let b = profile.touchpad.zones[zone]?[kind] else { return nil }
        if case .none = b { return nil }
        return b
    }

    /// Fires tap-like gestures as short presses (down now, up on a later update after 40 ms),
    /// scroll bindings immediately, and `hold` as press-while-held.
    func handleGestures(_ events: [GestureEvent], at time: TimeInterval, scrolls: inout [Int]) {
        for event in events {
            switch event {
            case .tap(let z): fire(z, .tap, at: time, scrolls: &scrolls)
            case .twoFingerTap: fire(0, .twoFingerTap, at: time, scrolls: &scrolls)
            case .swipe(let dir, let z):
                switch dir {
                case .up: fire(z, .swipeUp, at: time, scrolls: &scrolls)
                case .down: fire(z, .swipeDown, at: time, scrolls: &scrolls)
                case .left: fire(z, .swipeLeft, at: time, scrolls: &scrolls)
                case .right: fire(z, .swipeRight, at: time, scrolls: &scrolls)
                }
            case .padClick(let z): fire(z, .click, at: time, scrolls: &scrolls)
            case .holdBegan(let z):
                if let b = gestureBinding(zone: z, kind: .hold) { holds[z] = b }
            case .holdEnded(let z): holds[z] = nil
            case .drag: break
            }
        }
    }

    private func fire(_ zone: ZoneIndex, _ kind: GestureKind, at time: TimeInterval,
                      scrolls: inout [Int]) {
        guard let binding = gestureBinding(zone: zone, kind: kind) else { return }
        if case let .scroll(dy) = binding {
            scrolls.append(dy)
            return
        }
        pendingTaps.removeAll { $0.binding == binding }
        pendingTaps.append(PendingTap(binding: binding, releaseAt: time + Self.tapDuration))
    }
}
