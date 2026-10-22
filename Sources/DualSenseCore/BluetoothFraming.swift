/// Bluetooth report framing: CRC checks for input `0x31` and framing of output `0x31`.
public enum BluetoothFraming {
    /// Length of a full Bluetooth input or output report including the report ID.
    public static let reportLength = 78
    /// Length of the common output block.
    public static let commonLength = 47
    /// CRC seed byte for input reports.
    public static let inputSeed: UInt8 = 0xA1
    /// CRC seed byte for output reports.
    public static let outputSeed: UInt8 = 0xA2

    /// Returns true when `bytes` is a 78-byte `0x31` input report whose CRC (seed 0xA1 over bytes 0..<74,
    /// little-endian at 74..<78) matches.
    public static func verify(inputReport bytes: [UInt8]) -> Bool {
        guard bytes.count == reportLength, bytes[0] == 0x31 else { return false }
        let stored = UInt32(bytes[74]) | (UInt32(bytes[75]) << 8)
            | (UInt32(bytes[76]) << 16) | (UInt32(bytes[77]) << 24)
        return CRC32.checksum(seed: inputSeed, bytes[0..<74]) == stored
    }

    /// Builds the 78-byte `0x31` output report: ID, sequence nibble (upper 4 bits of byte 1),
    /// tag 0x10, the 47-byte common block at offset 3, zero fill, CRC (seed 0xA2) little-endian.
    /// The common block is truncated or zero-padded to 47 bytes; `sequence` is masked to 4 bits.
    public static func frame(outputCommon common: [UInt8], sequence: UInt8) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: reportLength)
        out[0] = 0x31
        out[1] = (sequence & 0x0F) << 4
        out[2] = 0x10
        for (i, b) in common.prefix(commonLength).enumerated() { out[3 + i] = b }
        let crc = CRC32.checksum(seed: outputSeed, out[0..<74])
        out[74] = UInt8(truncatingIfNeeded: crc)
        out[75] = UInt8(truncatingIfNeeded: crc >> 8)
        out[76] = UInt8(truncatingIfNeeded: crc >> 16)
        out[77] = UInt8(truncatingIfNeeded: crc >> 24)
        return out
    }
}
