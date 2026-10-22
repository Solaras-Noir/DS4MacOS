/// How the controller is connected.
public enum Transport: Equatable {
    /// USB cable, report 0x01 with 64 bytes.
    case usb
    /// Bluetooth, report 0x31 (78 bytes) or the simple report 0x01 (10 bytes).
    case bluetooth
}

/// One decoded controller snapshot, independent of transport. Sticks have no dead zone applied.
public struct ControllerState: Equatable {
    /// Left stick, normalised -1...1 (up positive).
    public var leftStick: StickState
    /// Right stick, normalised -1...1 (up positive).
    public var rightStick: StickState
    /// Hat switch direction.
    public var dpad: Dpad
    /// Pressed digital buttons.
    public var buttons: DualSenseButtons
    /// Left trigger, 0...1.
    public var l2: Float
    /// Right trigger, 0...1.
    public var r2: Float
    /// The two touchpad contact slots.
    public var touches: [TouchPoint]
    /// Battery level and charging state.
    public var battery: BatteryStatus
    /// Raw gyro (x, y, z).
    public var gyro: SIMD3<Int16>
    /// Raw accelerometer (x, y, z).
    public var accel: SIMD3<Int16>
    /// Sensor timestamp in 0.33 microsecond units; 0 for simple reports.
    public var sensorTimestamp: UInt32
    /// Connection the report arrived on.
    public var transport: Transport
    /// True for a Bluetooth simple report (no motion, touch or battery data).
    public var isSimple: Bool

    /// Creates a state from its parts.
    public init(leftStick: StickState, rightStick: StickState, dpad: Dpad, buttons: DualSenseButtons,
                l2: Float, r2: Float, touches: [TouchPoint], battery: BatteryStatus,
                gyro: SIMD3<Int16>, accel: SIMD3<Int16>, sensorTimestamp: UInt32,
                transport: Transport, isSimple: Bool) {
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.dpad = dpad
        self.buttons = buttons
        self.l2 = l2
        self.r2 = r2
        self.touches = touches
        self.battery = battery
        self.gyro = gyro
        self.accel = accel
        self.sensorTimestamp = sensorTimestamp
        self.transport = transport
        self.isSimple = isSimple
    }
}
