#if os(macOS)
// Threading: the scheduler timer is added to the main run loop in common modes (CFRunLoopGetMain via
// RunLoop.main), so it fires on the main thread together with the HID callbacks. Not thread safe;
// call it from the main thread only.
import Foundation
import DualSenseCore

/// Owns the desired output state and writes it to the active controller.
///
/// The decision of when to send lives in `OutputScheduleLogic` (tested on Linux). This class adds a clock,
/// a 10 ms timer, transport framing (USB 0x02, Bluetooth 0x31 with a running sequence counter) and the
/// one-time Bluetooth lightbar setup on attach. The API uses core primitives only.
public final class OutputScheduler {
    private var logic: OutputScheduleLogic
    private weak var device: HIDDevice?
    private var bluetooth = false
    private var sequence: UInt8 = 0
    private var timer: Timer?
    private var setupSentFor: ObjectIdentifier?

    /// Number of failed `IOHIDDeviceSetReport` calls since creation.
    public private(set) var failedWrites = 0

    /// Creates a scheduler. `reassert` is true in augment mode (re-send every 2 s).
    public init(reassert: Bool) {
        logic = OutputScheduleLogic(reassert: reassert)
    }

    deinit {
        timer?.invalidate()
    }

    private static func now() -> Double {
        return ProcessInfo.processInfo.systemUptime
    }

    /// Switches the augment-mode re-assert on or off (profile mode change).
    public func setReassert(_ on: Bool) {
        logic.reassert = on
    }

    /// Sets the lightbar colour.
    public func setLightbar(_ color: RGB?) { logic.setLightbar(color) }
    /// Sets the left trigger effect.
    public func setLeftTrigger(_ effect: TriggerEffect?) { logic.setLeftTrigger(effect) }
    /// Sets the right trigger effect.
    public func setRightTrigger(_ effect: TriggerEffect?) { logic.setRightTrigger(effect) }
    /// Sets the player LED mask (bits 0...4).
    public func setPlayerLEDs(_ mask: UInt8?) { logic.setPlayerLEDs(mask) }

    /// Sets rumble; the motors go to zero after `duration` seconds (nil keeps them until changed).
    public func setRumble(strong: UInt8, weak: UInt8, duration: Double?) {
        logic.setRumble(strong: strong, weak: weak, duration: duration, now: OutputScheduler.now())
    }

    /// Stops rumble.
    public func stopRumble() { logic.stopRumble() }

    /// Points the scheduler at a (new) active device and re-applies the whole desired state.
    /// Over Bluetooth this first sends `OutputReport.lightbarSetup()` once. Pass nil on disconnect.
    public func attach(device: HIDDevice?, vibrationMode: VibrationMode) {
        self.device = device
        logic.vibrationMode = vibrationMode
        sequence = 0
        guard let device = device else {
            timer?.invalidate()
            timer = nil
            setupSentFor = nil
            return
        }
        bluetooth = device.isBluetooth
        var sentSetup = false
        if bluetooth, setupSentFor != ObjectIdentifier(device) {
            write(OutputReport.lightbarSetup())
            setupSentFor = ObjectIdentifier(device)
            sentSetup = true
        }
        logic.markReconnected()
        startTimer()
        // After the setup report the full state waits for the next timer tick (10 ms gap).
        if !sentSetup { tick() }
    }

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: OutputScheduleLogic.minimumGap, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard device != nil else { return }
        if let report = logic.poll(now: OutputScheduler.now()) {
            write(report)
        }
    }

    private func write(_ report: OutputReport) {
        guard let device = device else { return }
        let result: Int32
        if bluetooth {
            let bytes = report.bluetoothBytes(sequence: sequence)
            sequence = (sequence &+ 1) & 0x0F
            result = device.setOutputReport(id: 0x31, bytes: bytes)
        } else {
            result = device.setOutputReport(id: 0x02, bytes: report.usbBytes())
        }
        if result != 0 { failedWrites += 1 }
    }
}
#endif
