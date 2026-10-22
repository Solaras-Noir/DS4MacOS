/// Battery level and charging state.
public struct BatteryStatus: Equatable {
    /// Charge in percent, 0...100. Zero when the state is error or unknown.
    public let level: Int
    /// Charging state.
    public let state: BatteryState

    /// Decodes the status byte (low nibble level 0...10, high nibble state).
    public init(statusByte: UInt8) {
        let raw = Int(statusByte & 0x0F)
        switch statusByte >> 4 {
        case 0:
            state = .discharging
            level = min(raw * 10 + 5, 100)
        case 1:
            state = .charging
            level = min(raw * 10 + 5, 100)
        case 2:
            state = .full
            level = 100
        case 0xA, 0xB:
            state = .error
            level = 0
        default:
            state = .unknown
            level = 0
        }
    }
}
