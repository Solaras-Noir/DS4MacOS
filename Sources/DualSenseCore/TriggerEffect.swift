/// An adaptive trigger effect: an 11-byte block (mode byte plus 10 parameters).
///
/// Named effects are built with the static factories, which return nil for out-of-range arguments and
/// `.off` when the arguments mean "no effect". Packing follows `docs/protocol/dualsense-hid.md`, section
/// Trigger effects (derived from Nielk1 TriggerEffectGenerator).
public enum TriggerEffect: Equatable {
    /// No effect (all 11 bytes zero). The doc notes N uses mode 0x05 for off; 0x00 is what we send, so
    /// it is the one to test on hardware.
    case off
    /// A raw mode byte with up to 10 parameter bytes. Shorter lists are padded with zeros, longer ones truncated.
    case raw(mode: UInt8, params: [UInt8])

    /// The mode byte followed by exactly 10 parameter bytes (11 bytes in total).
    public var encoded: [UInt8] {
        switch self {
        case .off:
            return [UInt8](repeating: 0, count: 11)
        case let .raw(mode, params):
            var out: [UInt8] = [mode]
            out.append(contentsOf: params.prefix(10))
            while out.count < 11 { out.append(0) }
            return out
        }
    }

    // MARK: Named effects

    /// Constant resistance from `position` (0...9) to the end of travel. `strength` 0...8 (0 = off).
    public static func feedback(position: Int, strength: Int) -> TriggerEffect? {
        guard (0...9).contains(position), (0...8).contains(strength) else { return nil }
        if strength == 0 { return .off }
        var s = [Int](repeating: 0, count: 10)
        for i in position..<10 { s[i] = strength }
        return zoned(mode: 0x21, strengths: s, frequency: nil)
    }

    /// Resistance wall between `start` (2...7) and `end` (start+1...8), `strength` 0...8 (0 = off).
    public static func weapon(start: Int, end: Int, strength: Int) -> TriggerEffect? {
        guard (2...7).contains(start), end > start, end <= 8, (0...8).contains(strength) else { return nil }
        if strength == 0 { return .off }
        let mask = (1 << start) | (1 << end)
        return .raw(mode: 0x25, params: [UInt8(mask & 0xFF), UInt8(mask >> 8), UInt8(strength - 1)])
    }

    /// Vibration from `position` (0...9) on. `amplitude` 0...8 and `frequency` 0...255 in Hz; 0 for either = off.
    public static func vibration(position: Int, amplitude: Int, frequency: Int) -> TriggerEffect? {
        guard (0...9).contains(position), (0...8).contains(amplitude), (0...255).contains(frequency) else { return nil }
        if amplitude == 0 || frequency == 0 { return .off }
        var s = [Int](repeating: 0, count: 10)
        for i in position..<10 { s[i] = amplitude }
        return zoned(mode: 0x26, strengths: s, frequency: frequency)
    }

    /// Per-zone resistance: exactly 10 strengths, each 0...8 (0 = zone inactive). All zero gives `.off`.
    public static func multiplePositionFeedback(strengths: [Int]) -> TriggerEffect? {
        guard strengths.count == 10, strengths.allSatisfy({ (0...8).contains($0) }) else { return nil }
        if strengths.allSatisfy({ $0 == 0 }) { return .off }
        return zoned(mode: 0x21, strengths: strengths, frequency: nil)
    }

    /// Resistance ramping from `startStrength` at `startPosition` (0...8) to `endStrength` at
    /// `endPosition` (start+1...9); strengths 1...8. Interpolated values round half to even, zones
    /// after `endPosition` keep `endStrength`, zones before `startPosition` are inactive.
    public static func slopeFeedback(startPosition: Int, endPosition: Int,
                                     startStrength: Int, endStrength: Int) -> TriggerEffect? {
        guard (0...8).contains(startPosition), endPosition > startPosition, endPosition <= 9,
              (1...8).contains(startStrength), (1...8).contains(endStrength) else { return nil }
        let slope = Double(endStrength - startStrength) / Double(endPosition - startPosition)
        var s = [Int](repeating: 0, count: 10)
        for i in startPosition..<10 {
            if i >= endPosition {
                s[i] = endStrength
            } else {
                let v = (Double(startStrength) + slope * Double(i - startPosition))
                    .rounded(.toNearestOrEven)
                s[i] = min(8, max(1, Int(v)))
            }
        }
        return zoned(mode: 0x21, strengths: s, frequency: nil)
    }

    /// Per-zone vibration: `frequency` 1...255 Hz and exactly 10 amplitudes, each 0...8. All zero gives `.off`.
    public static func multiplePositionVibration(frequency: Int, amplitudes: [Int]) -> TriggerEffect? {
        guard (1...255).contains(frequency), amplitudes.count == 10,
              amplitudes.allSatisfy({ (0...8).contains($0) }) else { return nil }
        if amplitudes.allSatisfy({ $0 == 0 }) { return .off }
        return zoned(mode: 0x26, strengths: amplitudes, frequency: frequency)
    }

    /// Packs 10 zone strengths (0 = inactive): p1-p2 active-zone mask LE, p3-p6 3-bit `strength-1` per
    /// zone LE, p9 frequency (index 8) when given.
    private static func zoned(mode: UInt8, strengths: [Int], frequency: Int?) -> TriggerEffect {
        var mask: UInt32 = 0
        var packed: UInt32 = 0
        for (i, s) in strengths.prefix(10).enumerated() where s > 0 {
            mask |= 1 << UInt32(i)
            packed |= UInt32((s - 1) & 7) << UInt32(3 * i)
        }
        var p = [UInt8](repeating: 0, count: 10)
        p[0] = UInt8(truncatingIfNeeded: mask)
        p[1] = UInt8(truncatingIfNeeded: mask >> 8)
        for k in 0..<4 { p[2 + k] = UInt8(truncatingIfNeeded: packed >> UInt32(8 * k)) }
        if let f = frequency { p[8] = UInt8(truncatingIfNeeded: f) }
        return .raw(mode: mode, params: p)
    }
}
