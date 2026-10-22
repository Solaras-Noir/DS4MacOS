/// Why a raw report could not be decoded.
public enum DecodeError: Error, Equatable {
    /// The buffer has no bytes.
    case empty
    /// Byte 0 is not a known report ID (0x01 or 0x31).
    case unknownReportID(UInt8)
    /// The length does not match the report ID (USB 64, Bluetooth 78 or simple 10).
    case badLength(Int)
    /// The Bluetooth CRC32 did not match.
    case badCRC
}

/// Decodes raw input buffers, report ID in byte 0, as delivered by the Mac HID callback.
/// Tracks report sequence gaps between calls.
public struct InputDecoder {
    /// Number of reports inferred missing from sequence jumps since creation.
    public private(set) var droppedReports = 0
    private var lastSequence: [Transport: UInt8] = [:]

    /// Creates a decoder with no history.
    public init() {}

    /// Decodes one buffer. 0x01 with 64 bytes is USB, 0x31 with 78 bytes is Bluetooth (CRC checked),
    /// 0x01 with 10 bytes is the Bluetooth simple report. Never traps.
    ///
    /// Sequence: USB uses payload byte 6 (mod 256). Bluetooth full reports use the upper nibble of
    /// buffer byte 1 (mod 16) because the payload seq byte is constant there. Simple reports carry
    /// no counter and are ignored for gap counting.
    public mutating func decode(_ bytes: [UInt8]) -> Result<ControllerState, DecodeError> {
        guard let id = bytes.first else { return .failure(.empty) }
        let transport: Transport
        switch (id, bytes.count) {
        case (0x01, 64): transport = .usb
        case (0x01, 10): transport = .bluetooth
        case (0x31, 78): transport = .bluetooth
        case (0x01, _), (0x31, _): return .failure(.badLength(bytes.count))
        default: return .failure(.unknownReportID(id))
        }
        if id == 0x31, !BluetoothFraming.verify(inputReport: bytes) { return .failure(.badCRC) }
        let parsed = transport == .usb ? InputReport(usbReport: bytes) : InputReport(bluetoothReport: bytes)
        guard let r = parsed else { return .failure(.badLength(bytes.count)) }

        var timestamp: UInt32 = 0
        if !r.isSimple {
            let o = transport == .usb ? 1 + 27 : 2 + 27
            timestamp = UInt32(bytes[o]) | (UInt32(bytes[o + 1]) << 8)
                | (UInt32(bytes[o + 2]) << 16) | (UInt32(bytes[o + 3]) << 24)
            if transport == .usb {
                countGap(transport, current: r.sequence, modulus: 256)
            } else {
                countGap(transport, current: bytes[1] >> 4, modulus: 16)
            }
        }
        return .success(ControllerState(
            leftStick: r.leftStick, rightStick: r.rightStick, dpad: r.dpad, buttons: r.buttons,
            l2: r.l2, r2: r.r2, touches: r.touch, battery: r.battery, gyro: r.gyro, accel: r.accel,
            sensorTimestamp: timestamp, transport: transport, isSimple: r.isSimple))
    }

    private mutating func countGap(_ t: Transport, current: UInt8, modulus: Int) {
        if let last = lastSequence[t] {
            let step = (Int(current) - Int(last) + modulus) % modulus
            if step > 1 { droppedReports += step - 1 }
        }
        lastSequence[t] = current
    }
}
