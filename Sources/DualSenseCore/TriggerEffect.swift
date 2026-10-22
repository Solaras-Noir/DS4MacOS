/// An adaptive trigger effect. Named effects arrive in M1; M0 only offers off and raw bytes.
public enum TriggerEffect: Equatable {
    /// No effect (mode 0, all parameters zero).
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
}
