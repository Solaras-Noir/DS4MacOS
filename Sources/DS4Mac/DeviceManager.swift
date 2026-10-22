#if os(macOS)
// Threading: the IOHIDManager and every device are scheduled on the main run loop (CFRunLoopGetMain,
// common modes). All callbacks (matching, removal, input reports) and the closures below therefore run
// on the main thread. Not thread safe; call it from the main thread only.
import Foundation
import IOKit
import IOKit.hid
import DualSenseCore

/// What the manager knows about the active controller when it connects.
public struct ConnectionInfo {
    /// Product name reported by the device.
    public let name: String
    /// USB product ID (0x0CE6 DualSense, 0x0DF2 Edge).
    public let productID: Int
    /// Transport of the device used for input and output.
    public let transport: Transport
    /// Firmware `update_version` from feature report 0x20, nil if the read failed.
    public let updateVersion: UInt16?
    /// Rumble flag variant derived from `updateVersion` (`.v2` if unknown).
    public let vibrationMode: VibrationMode
}

/// Finds DualSense controllers, opens them, decodes input and owns the `OutputScheduler`.
///
/// One pad is "active" at a time. If a USB and a Bluetooth device are both present, both are opened the
/// same way, USB is used for input and output, and the choice is logged.
public final class DeviceManager {
    /// Called with every decoded input state of the active device.
    public var onState: ((ControllerState) -> Void)?
    /// Called when a device becomes the active one (after its feature reports were read).
    public var onConnect: ((ConnectionInfo) -> Void)?
    /// Called when the active device goes away or is replaced, so held keys can be released.
    public var onDisconnect: (() -> Void)?
    /// Called when opening a device fails: product name and the raw IOReturn.
    public var onOpenError: ((String, IOReturn) -> Void)?
    /// Log sink; defaults to `print`.
    public var log: (String) -> Void = { print($0) }

    /// Output scheduler bound to the active device.
    public let scheduler: OutputScheduler
    /// Reports that `InputDecoder` rejected (wrong length, bad CRC, unknown ID).
    public private(set) var undecodableReports = 0
    /// Reports inferred missing from sequence gaps, for the active (or last active) device.
    public var droppedReports: Int { active?.decoder.droppedReports ?? lastDropped }
    /// Currently active connection info, nil when no pad is connected.
    public private(set) var currentInfo: ConnectionInfo?

    private final class Entry {
        let hid: HIDDevice
        var decoder = InputDecoder()
        var updateVersion: UInt16?
        var vibrationMode: VibrationMode = .v2
        init(hid: HIDDevice) { self.hid = hid }
    }

    private let manager: IOHIDManager
    private var entries: [Entry] = []
    private var active: Entry?
    private var lastDropped = 0
    private var seize: Bool
    private var started = false

    /// Creates a manager. Nothing is opened until `start()`.
    public init(seize: Bool, reassert: Bool) {
        self.seize = seize
        self.scheduler = OutputScheduler(reassert: reassert)
        self.manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matches: [[String: Any]] = HIDDevice.productIDs.map {
            [kIOHIDVendorIDKey: HIDDevice.vendorID, kIOHIDProductIDKey: $0]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
    }

    deinit {
        stop()
    }

    /// Registers the callbacks and schedules the manager on the main run loop. Devices already connected
    /// are reported through the matching callback; a `CopyDevices` pass afterwards catches any the
    /// callback did not deliver. The manager itself is not opened, so each device is opened (and
    /// seized or not) only by `HIDDevice.open`.
    public func start() {
        guard !started else { return }
        started = true
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context = context else { return }
            Unmanaged<DeviceManager>.fromOpaque(context).takeUnretainedValue().deviceAdded(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context = context else { return }
            Unmanaged<DeviceManager>.fromOpaque(context).takeUnretainedValue().deviceRemoved(device)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        if let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            for device in set { deviceAdded(device) }
        }
    }

    /// Stops callbacks, closes all devices and detaches the scheduler.
    public func stop() {
        if started {
            started = false
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        }
        let hadActive = active != nil
        for entry in entries { entry.hid.close() }
        entries.removeAll()
        if let a = active { lastDropped = a.decoder.droppedReports }
        active = nil
        currentInfo = nil
        scheduler.attach(device: nil, vibrationMode: .v2)
        if hadActive { onDisconnect?() }
    }

    /// Closes and reopens every device with the new seize setting, so a profile change at runtime
    /// switches modes without restarting. Also sets the scheduler's re-assert flag (on when not seized, i.e. augment). The active device stays active; no connect or disconnect
    /// callbacks fire unless a reopen fails.
    public func reopen(seize newSeize: Bool) {
        seize = newSeize
        let current = entries
        scheduler.setReassert(!newSeize)
        for entry in current {
            entry.hid.close()
            entry.decoder = InputDecoder()
            if !prepare(entry) {
                removeEntry(entry)
            }
        }
        chooseActive()
        if let a = active {
            scheduler.attach(device: a.hid, vibrationMode: a.vibrationMode)
        }
    }

    // MARK: Device lifecycle

    private func deviceAdded(_ device: IOHIDDevice) {
        if entries.contains(where: { CFEqual($0.hid.device, device) }) { return }
        let entry = Entry(hid: HIDDevice(device: device))
        guard prepare(entry) else { return }
        entries.append(entry)
        log("device added: \(entry.hid.name) [\(entry.hid.transport)]")
        chooseActive()
    }

    private func deviceRemoved(_ device: IOHIDDevice) {
        guard let entry = entries.first(where: { CFEqual($0.hid.device, device) }) else { return }
        log("device removed: \(entry.hid.name) [\(entry.hid.transport)]")
        removeEntry(entry)
        chooseActive()
    }

    /// Opens the device and reads its feature reports, then starts input delivery. Returns false on failure.
    private func prepare(_ entry: Entry) -> Bool {
        let hid = entry.hid
        hid.onInputReport = nil
        let result = hid.open(seize: seize)
        guard result == 0 else {
            log("open(seize: \(seize)) failed for \(hid.name): \(String(format: "0x%08x", UInt32(bitPattern: result)))")
            onOpenError?(hid.name, result)
            return false
        }
        if let fw = hid.getFeatureReport(id: 0x20, length: 64),
           let version = FirmwareInfo.updateVersion(featureReport: fw) {
            entry.updateVersion = version
            entry.vibrationMode = VibrationMode.forUpdateVersion(version)
        } else {
            log("feature report 0x20 unreadable on \(hid.name); assuming rumble v2")
        }
        if hid.isBluetooth, hid.getFeatureReport(id: 0x05, length: 41) == nil {
            log("feature report 0x05 unreadable on \(hid.name); full reports may not start")
        }
        hid.onInputReport = { [weak self, weak entry] _, bytes in
            guard let self = self, let entry = entry else { return }
            self.handleInput(entry, bytes)
        }
        return true
    }

    private func removeEntry(_ entry: Entry) {
        entry.hid.onInputReport = nil
        entry.hid.close()
        entries.removeAll { $0 === entry }
        if active === entry {
            lastDropped = entry.decoder.droppedReports
            active = nil
            currentInfo = nil
            scheduler.attach(device: nil, vibrationMode: entry.vibrationMode)
            onDisconnect?()
        }
    }

    /// Picks USB over Bluetooth; announces a change of active device.
    private func chooseActive() {
        let best = entries.first(where: { $0.hid.isUSB }) ?? entries.first
        guard let chosen = best, chosen !== active else { return }
        if active != nil {
            lastDropped = active?.decoder.droppedReports ?? 0
            active = nil
            currentInfo = nil
            onDisconnect?()
        }
        if entries.count > 1 {
            log("multiple devices present; using \(chosen.hid.transport) for input and output")
        }
        active = chosen
        let info = ConnectionInfo(
            name: chosen.hid.name,
            productID: chosen.hid.productID,
            transport: chosen.hid.isBluetooth ? .bluetooth : .usb,
            updateVersion: chosen.updateVersion,
            vibrationMode: chosen.vibrationMode)
        currentInfo = info
        scheduler.attach(device: chosen.hid, vibrationMode: chosen.vibrationMode)
        onConnect?(info)
    }

    private func handleInput(_ entry: Entry, _ bytes: [UInt8]) {
        guard entry === active else { return }
        switch entry.decoder.decode(bytes) {
        case .success(let state): onState?(state)
        case .failure: undecodableReports += 1
        }
    }
}
#endif
