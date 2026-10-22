/// A parsed USB input report (ID 0x01).
public struct InputReport {
    /// Left stick.
    public let leftStick: StickState
    /// Right stick.
    public let rightStick: StickState
    /// Left trigger analog value, 0...1.
    public let l2: Float
    /// Right trigger analog value, 0...1.
    public let r2: Float
    /// Raw left trigger byte.
    public let l2Raw: UInt8
    /// Raw right trigger byte.
    public let r2Raw: UInt8
    /// Hat switch direction.
    public let dpad: Dpad
    /// Pressed digital buttons.
    public let buttons: DualSenseButtons
    /// Report sequence number.
    public let sequence: UInt8
    /// Raw gyro (x, y, z).
    public let gyro: SIMD3<Int16>
    /// Raw accelerometer (x, y, z).
    public let accel: SIMD3<Int16>
    /// The two touchpad contact slots.
    public let touch: [TouchPoint]
    /// Battery state.
    public let battery: BatteryStatus
    /// True for a Bluetooth simple report (0x01): sticks, buttons and triggers only. Motion, touch and
    /// battery hold neutral values.
    public let isSimple: Bool

    /// Parses a USB report: 64 bytes starting with ID 0x01, or the 63-byte payload alone.
    /// Returns nil for any other length or a wrong ID.
    public init?(usbReport bytes: [UInt8]) {
        let p: ArraySlice<UInt8>
        if bytes.count == 64 {
            guard bytes[0] == 0x01 else { return nil }
            p = bytes[1..<64]
        } else if bytes.count == 63 {
            p = bytes[0..<63]
        } else {
            return nil
        }
        self.init(payload: Array(p))
    }

    /// Parses a Bluetooth report: full 0x31 (78 bytes incl. ID, CRC checked) or simple 0x01 (10 bytes incl. ID).
    /// Returns nil for a wrong ID, wrong length or a failing CRC.
    public init?(bluetoothReport bytes: [UInt8]) {
        if bytes.count == 78 {
            guard bytes[0] == 0x31, BluetoothFraming.verify(inputReport: bytes) else { return nil }
            self.init(payload: Array(bytes[2..<65]))
        } else if bytes.count == 10 {
            guard bytes[0] == 0x01 else { return nil }
            self.init(simple: bytes)
        } else {
            return nil
        }
    }

    private init?(simple b: [UInt8]) {
        guard b.count == 10 else { return nil }
        leftStick = StickState(rawX: b[1], rawY: b[2])
        rightStick = StickState(rawX: b[3], rawY: b[4])
        l2Raw = b[8]
        r2Raw = b[9]
        l2 = Float(b[8]) / 255
        r2 = Float(b[9]) / 255
        sequence = 0
        dpad = Dpad(hat: b[5] & 0x0F)
        buttons = InputReport.buttonSet(b0: b[5], b1: b[6], b2: b[7] & 0x03)
        gyro = SIMD3<Int16>(0, 0, 0)
        accel = SIMD3<Int16>(0, 0, 0)
        touch = [TouchPoint(isTouching: false, id: 0, x: 0, y: 0),
                 TouchPoint(isTouching: false, id: 0, x: 0, y: 0)]
        battery = BatteryStatus(statusByte: 0)
        isSimple = true
    }

    private static func buttonSet(b0: UInt8, b1: UInt8, b2: UInt8) -> DualSenseButtons {
        var set: DualSenseButtons = []
        if b0 & 0x10 != 0 { set.insert(.square) }
        if b0 & 0x20 != 0 { set.insert(.cross) }
        if b0 & 0x40 != 0 { set.insert(.circle) }
        if b0 & 0x80 != 0 { set.insert(.triangle) }
        if b1 & 0x01 != 0 { set.insert(.l1) }
        if b1 & 0x02 != 0 { set.insert(.r1) }
        if b1 & 0x04 != 0 { set.insert(.l2) }
        if b1 & 0x08 != 0 { set.insert(.r2) }
        if b1 & 0x10 != 0 { set.insert(.create) }
        if b1 & 0x20 != 0 { set.insert(.options) }
        if b1 & 0x40 != 0 { set.insert(.l3) }
        if b1 & 0x80 != 0 { set.insert(.r3) }
        if b2 & 0x01 != 0 { set.insert(.ps) }
        if b2 & 0x02 != 0 { set.insert(.touchpad) }
        if b2 & 0x04 != 0 { set.insert(.mute) }
        return set
    }

    /// Shared 63-byte payload parser (USB and Bluetooth 0x31).
    private init?(payload: [UInt8]) {
        guard payload.count == 63,
              let t0 = TouchPoint(bytes: payload[32..<36]),
              let t1 = TouchPoint(bytes: payload[36..<40]) else { return nil }

        func i16(_ o: Int) -> Int16 {
            Int16(bitPattern: UInt16(payload[o]) | (UInt16(payload[o + 1]) << 8))
        }

        leftStick = StickState(rawX: payload[0], rawY: payload[1])
        rightStick = StickState(rawX: payload[2], rawY: payload[3])
        l2Raw = payload[4]
        r2Raw = payload[5]
        l2 = Float(payload[4]) / 255
        r2 = Float(payload[5]) / 255
        sequence = payload[6]

        let b0 = payload[7]
        dpad = Dpad(hat: b0 & 0x0F)
        buttons = InputReport.buttonSet(b0: b0, b1: payload[8], b2: payload[9])

        gyro = SIMD3<Int16>(i16(15), i16(17), i16(19))
        accel = SIMD3<Int16>(i16(21), i16(23), i16(25))
        touch = [t0, t1]
        battery = BatteryStatus(statusByte: payload[52])
        isSimple = false
    }
}
