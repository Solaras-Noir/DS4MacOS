/// Charging state reported in the status byte.
public enum BatteryState: Equatable {
    case discharging, charging, full, error, unknown
}
