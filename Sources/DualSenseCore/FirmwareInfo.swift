import Foundation

/// Decoding of feature report 0x20 (firmware info) and the rumble variant it selects.
public enum FirmwareInfo {
    /// First `update_version` that uses the v2 rumble flags (`DS_FEATURE_VERSION(2,21)` in hid-playstation.c).
    public static let vibrationV2Cutoff: UInt16 = 0x0215
    /// Offset of `update_version` (LE16) in the 64-byte buffer, which includes the report ID at byte 0.
    public static let updateVersionOffset = 44

    /// Reads `update_version` from a feature report 0x20 buffer (report ID at byte 0). Nil if too short.
    public static func updateVersion(featureReport bytes: [UInt8]) -> UInt16? {
        guard bytes.count >= updateVersionOffset + 2 else { return nil }
        return UInt16(bytes[updateVersionOffset]) | (UInt16(bytes[updateVersionOffset + 1]) << 8)
    }
}

extension VibrationMode {
    /// `.v2` when `updateVersion >= 0x0215`, else `.v1`.
    public static func forUpdateVersion(_ updateVersion: UInt16) -> VibrationMode {
        updateVersion >= FirmwareInfo.vibrationV2Cutoff ? .v2 : .v1
    }
}
