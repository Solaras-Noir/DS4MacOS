/// Which rumble flag variant the controller firmware expects.
///
/// The Linux driver (`hid-playstation.c` L1331-1342, `use_vibration_v2` at L1806; see
/// `docs/protocol/dualsense-hid.md`, section Rumble) always sets valid_flag0 bit 1 (haptics select) and then
/// exactly one of: valid_flag0 bit 0 (old firmware) or valid_flag2 bit 2 (new firmware). It never sets
/// flag0 bit 0 and flag2 bit 2 together. The caller (M2's DeviceManager) should read feature report 0x20
/// and use `.v2` when `update_version` (LE16 at buffer offset 44) is >= 0x0215, else `.v1`.
public enum VibrationMode: Equatable {
    /// Old firmware: valid_flag0 |= 0x03; valid_flag2 bit 2 untouched.
    case v1
    /// Firmware with update_version >= 0x0215 (and the Edge): valid_flag0 |= 0x02, valid_flag2 |= 0x04.
    case v2
}
