/// Table-driven CRC-32 (reflected polynomial 0xEDB88320, init and final xor 0xFFFFFFFF).
public enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    /// Standard CRC-32 of `bytes`.
    public static func checksum<S: Sequence>(_ bytes: S) -> UInt32 where S.Element == UInt8 {
        checksum(seed: nil, bytes)
    }

    /// CRC-32 of a single `seed` byte followed by `bytes` (the DualSense Bluetooth scheme).
    public static func checksum<S: Sequence>(seed: UInt8, _ bytes: S) -> UInt32 where S.Element == UInt8 {
        checksum(seed: Optional(seed), bytes)
    }

    private static func checksum<S: Sequence>(seed: UInt8?, _ bytes: S) -> UInt32 where S.Element == UInt8 {
        var crc: UInt32 = 0xFFFF_FFFF
        func step(_ b: UInt8) {
            crc = table[Int((crc ^ UInt32(b)) & 0xFF)] ^ (crc >> 8)
        }
        if let seed = seed { step(seed) }
        for b in bytes { step(b) }
        return ~crc
    }
}
