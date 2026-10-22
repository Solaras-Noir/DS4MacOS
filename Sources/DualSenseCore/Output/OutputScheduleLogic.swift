/// Pure decision logic for when an output report must be sent. No IOKit, no real clock: the caller passes
/// `now` (seconds, any monotonic origin) into every call, so behaviour is deterministic in tests.
///
/// Holds the desired output state (lightbar, triggers, player LEDs, rumble with expiry). `poll(now:)`
/// returns a report when something changed, a rumble expired, or (with `reassert`) `reassertInterval`
/// seconds passed since the last send, and never more often than `minimumGap`.
public struct OutputScheduleLogic {
    /// Minimum time between two reports, in seconds.
    public static let minimumGap: Double = 0.010
    /// Re-send interval in augment mode, in seconds (CrossOver's driver overwrites outputs).
    public static let reassertInterval: Double = 2.0

    /// When true (augment mode) the full state is re-sent every `reassertInterval` seconds.
    public var reassert: Bool
    /// Rumble flag variant used for the built reports.
    public var vibrationMode: VibrationMode = .v2

    /// Desired lightbar colour; nil leaves it unassigned.
    public private(set) var lightbar: RGB?
    /// Desired left trigger effect; nil leaves it unassigned.
    public private(set) var leftTrigger: TriggerEffect?
    /// Desired right trigger effect; nil leaves it unassigned.
    public private(set) var rightTrigger: TriggerEffect?
    /// Desired player LED mask (bits 0...4); nil leaves it unassigned.
    public private(set) var playerLEDs: UInt8?
    /// Current rumble intensities; nil until rumble was first set.
    public private(set) var rumble: (strong: UInt8, weak: UInt8)?

    private var rumbleExpiry: Double?
    private var dirty = false
    private var lastSend: Double?

    /// Creates logic with nothing assigned. `reassert` is true for augment mode.
    public init(reassert: Bool) {
        self.reassert = reassert
    }

    /// Sets the lightbar colour.
    public mutating func setLightbar(_ color: RGB?) {
        if color != lightbar { lightbar = color; dirty = true }
    }

    /// Sets the left trigger effect.
    public mutating func setLeftTrigger(_ effect: TriggerEffect?) {
        if effect != leftTrigger { leftTrigger = effect; dirty = true }
    }

    /// Sets the right trigger effect.
    public mutating func setRightTrigger(_ effect: TriggerEffect?) {
        if effect != rightTrigger { rightTrigger = effect; dirty = true }
    }

    /// Sets the player LED mask.
    public mutating func setPlayerLEDs(_ mask: UInt8?) {
        let masked = mask.map { $0 & 0x1F }
        if masked != playerLEDs { playerLEDs = masked; dirty = true }
    }

    /// Sets rumble. With `duration` the motors are set to zero once `now + duration` has passed; nil
    /// keeps the values until changed. Always counts as a change (restarts the expiry).
    public mutating func setRumble(strong: UInt8, weak: UInt8, duration: Double?, now: Double) {
        rumble = (strong, weak)
        if let d = duration, (strong > 0 || weak > 0) {
            rumbleExpiry = now + max(0, d)
        } else {
            rumbleExpiry = nil
        }
        dirty = true
    }

    /// Stops rumble immediately (sends zero values on the next poll).
    public mutating func stopRumble() {
        rumble = (0, 0)
        rumbleExpiry = nil
        dirty = true
    }

    /// Marks the whole state as needing a send, for a new or reconnected device. Also forgets the last
    /// send time so the report goes out on the next poll.
    public mutating func markReconnected() {
        dirty = true
        lastSend = nil
    }

    /// Seconds until the next poll could produce a report, or nil when nothing is scheduled.
    /// Lets a caller sleep instead of ticking; optional.
    public func nextDeadline(now: Double) -> Double? {
        var candidates: [Double] = []
        if dirty { candidates.append(lastSend.map { $0 + Self.minimumGap } ?? now) }
        if let e = rumbleExpiry { candidates.append(e) }
        if reassert, let l = lastSend { candidates.append(l + Self.reassertInterval) }
        return candidates.min()
    }

    /// Returns the report to send now, or nil. Call regularly (a 10 ms timer is enough).
    /// A pending change inside the minimum gap stays pending and is returned by a later poll.
    public mutating func poll(now: Double) -> OutputReport? {
        if let e = rumbleExpiry, now >= e {
            rumble = (0, 0)
            rumbleExpiry = nil
            dirty = true
        }
        let reassertDue = reassert && lastSend.map { now - $0 >= Self.reassertInterval } ?? false
        guard dirty || reassertDue else { return nil }
        if let l = lastSend, now - l < Self.minimumGap { return nil }
        dirty = false
        lastSend = now
        return buildReport()
    }

    /// The report carrying the full desired state.
    public func buildReport() -> OutputReport {
        var r = OutputReport()
        r.vibrationMode = vibrationMode
        r.lightbar = lightbar
        r.leftTrigger = leftTrigger
        r.rightTrigger = rightTrigger
        r.playerLEDs = playerLEDs
        if let m = rumble { r.rumble(strong: m.strong, weak: m.weak) }
        return r
    }
}
