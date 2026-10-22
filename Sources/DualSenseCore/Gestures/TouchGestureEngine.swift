import Foundation

/// Turns per-report touch samples into gestures. Value type, no timers: time arrives with each update.
///
/// Events from one `update` are ordered: lifts (tap / swipe / twoFingerTap / holdEnded, in order of
/// touch-down), then holdBegan, then drag, then padClick.
public struct TouchGestureEngine {
    /// Active configuration.
    public var config: TouchGestureConfig

    private struct Contact {
        var id: UInt8
        var startTime: TimeInterval
        var startX: Int
        var startY: Int
        var startZone: ZoneIndex
        var lastX: Int
        var lastY: Int
        var maxMove: Double = 0
        var holding = false
        var inPair = false
    }

    private struct Pair {
        var ids: [UInt8]
        var startTime: TimeInterval
        var failed = false
        var lifted = 0
    }

    private static let epsilon = 1e-9
    private var contacts: [Contact] = []
    private var pair: Pair?
    private var wasClicked = false

    /// Creates an engine with the given configuration.
    public init(config: TouchGestureConfig = TouchGestureConfig()) {
        self.config = config
    }

    /// Feeds one input report. `time` is in seconds and must not go backwards.
    public mutating func update(touches: [TouchPoint], padClicked: Bool = false,
                                at time: TimeInterval) -> [GestureEvent] {
        var events: [GestureEvent] = []
        var active: [TouchPoint] = []
        for t in touches where t.isTouching && !active.contains(where: { $0.id == t.id }) {
            active.append(t)
        }

        // Lifts.
        for c in contacts where !active.contains(where: { $0.id == c.id }) {
            lift(c, at: time, into: &events)
        }
        contacts.removeAll { c in !active.contains(where: { $0.id == c.id }) }
        if contacts.isEmpty { pair = nil }

        // Landings and moves.
        var drags: [(Int, Int)] = []
        for t in active {
            if let i = contacts.firstIndex(where: { $0.id == t.id }) {
                let dx = t.x - contacts[i].lastX
                let dy = t.y - contacts[i].lastY
                contacts[i].lastX = t.x
                contacts[i].lastY = t.y
                let m = distance(t.x - contacts[i].startX, t.y - contacts[i].startY)
                contacts[i].maxMove = max(contacts[i].maxMove, m)
                if (dx != 0 || dy != 0) && !contacts[i].holding && !contacts[i].inPair {
                    drags.append((dx, dy))
                }
            } else {
                var c = Contact(id: t.id, startTime: time, startX: t.x, startY: t.y,
                                startZone: config.zones.zone(x: t.x, y: t.y),
                                lastX: t.x, lastY: t.y)
                if contacts.count == 1, pair == nil, !contacts[0].holding, !contacts[0].inPair,
                   time - contacts[0].startTime <= config.twoFingerTapWindow + Self.epsilon {
                    contacts[0].inPair = true
                    c.inPair = true
                    pair = Pair(ids: [contacts[0].id, c.id], startTime: contacts[0].startTime)
                }
                contacts.append(c)
            }
        }

        // Holds.
        for i in contacts.indices {
            let c = contacts[i]
            if !c.holding, !c.inPair, c.maxMove <= Double(config.tapMaxMovement) + Self.epsilon,
               time - c.startTime >= config.holdMinDuration - Self.epsilon {
                contacts[i].holding = true
                events.append(.holdBegan(c.startZone))
            }
        }

        // Drag: exactly one finger down, and it moved.
        if contacts.count == 1, drags.count == 1, let d = drags.first {
            events.append(.drag(dx: d.0, dy: d.1))
        }

        // Pad click on rising edge.
        if padClicked && !wasClicked {
            let zone = contacts.first.map { config.zones.zone(x: $0.lastX, y: $0.lastY) } ?? 0
            events.append(.padClick(zone))
        }
        wasClicked = padClicked
        return events
    }

    private mutating func lift(_ c: Contact, at time: TimeInterval, into events: inout [GestureEvent]) {
        if c.holding {
            events.append(.holdEnded(c.startZone))
            if var p = pair, p.ids.contains(c.id) { p.failed = true; p.lifted += 1; pair = p }
            return
        }
        if c.inPair, var p = pair {
            if time - p.startTime > config.tapMaxDuration + Self.epsilon
                || c.maxMove > Double(config.tapMaxMovement) + Self.epsilon {
                p.failed = true
            }
            p.lifted += 1
            if p.lifted == 2 && !p.failed { events.append(.twoFingerTap) }
            pair = p
            return
        }
        let duration = time - c.startTime
        if duration <= config.tapMaxDuration + Self.epsilon,
           c.maxMove <= Double(config.tapMaxMovement) + Self.epsilon {
            events.append(.tap(c.startZone))
            return
        }
        let dx = c.lastX - c.startX
        let dy = c.lastY - c.startY
        if duration <= config.swipeMaxDuration + Self.epsilon,
           distance(dx, dy) >= Double(config.swipeMinDistance) {
            let dir: SwipeDirection = abs(dx) >= abs(dy) ? (dx > 0 ? .right : .left)
                                                         : (dy > 0 ? .down : .up)
            events.append(.swipe(dir, c.startZone))
        }
    }

    private func distance(_ dx: Int, _ dy: Int) -> Double {
        (Double(dx) * Double(dx) + Double(dy) * Double(dy)).squareRoot()
    }
}
