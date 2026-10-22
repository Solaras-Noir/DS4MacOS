#if os(macOS)
import Foundation
import IOKit
import IOKit.hid

/// A DualSense controller found through IOHIDManager. Wraps open, input report
/// delivery, output reports and feature reports. All callbacks run on the main run loop.
public final class HIDDevice {
    /// Sony vendor ID.
    public static let vendorID = 0x054C
    /// DualSense and DualSense Edge product IDs.
    public static let productIDs = [0x0CE6, 0x0DF2]

    private static var sharedManager: IOHIDManager?

    /// Underlying IOKit device.
    public let device: IOHIDDevice
    /// Product name as reported by the device.
    public let name: String
    /// USB product ID.
    public let productID: Int
    /// Raw `kIOHIDTransportKey` string, for example "USB" or "Bluetooth".
    public let transport: String
    /// `kIOHIDMaxInputReportSizeKey` value.
    public let maxInputReportSize: Int
    /// Called for every input report with the report ID and the buffer as delivered by IOKit.
    public var onInputReport: ((UInt8, [UInt8]) -> Void)?

    private var buffer: UnsafeMutablePointer<UInt8>?
    private var bufferSize = 0
    private var isOpen = false

    init(device: IOHIDDevice) {
        self.device = device
        self.name = HIDDevice.stringProperty(device, kIOHIDProductKey) ?? "unknown"
        self.productID = HIDDevice.intProperty(device, kIOHIDProductIDKey) ?? 0
        self.transport = HIDDevice.stringProperty(device, kIOHIDTransportKey) ?? "unknown"
        self.maxInputReportSize = HIDDevice.intProperty(device, kIOHIDMaxInputReportSizeKey) ?? 0
    }

    deinit {
        close()
    }

    /// Returns all connected DualSense controllers.
    public static func all() -> [HIDDevice] {
        if sharedManager == nil {
            let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            let matches: [[String: Any]] = productIDs.map {
                [kIOHIDVendorIDKey: vendorID, kIOHIDProductIDKey: $0]
            }
            IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
            sharedManager = manager
        }
        guard let manager = sharedManager,
              let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return set.map { HIDDevice(device: $0) }
    }

    /// Opens the device, optionally seizing it (exclusive access), and starts input report delivery.
    /// Returns the raw IOReturn; 0 is success.
    public func open(seize: Bool) -> IOReturn {
        if isOpen { return 0 }
        let options: IOOptionBits = seize ? IOOptionBits(kIOHIDOptionsTypeSeizeDevice)
                                          : IOOptionBits(kIOHIDOptionsTypeNone)
        let result = IOHIDDeviceOpen(device, options)
        guard result == 0 else { return result }
        isOpen = true

        let size = max(maxInputReportSize, 64)
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        buf.initialize(repeating: 0, count: size)
        buffer = buf
        bufferSize = size

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buf, size, { context, _, _, _, reportID, report, length in
            guard let context = context else { return }
            let me = Unmanaged<HIDDevice>.fromOpaque(context).takeUnretainedValue()
            let count = max(0, Int(length))
            let bytes = Array(UnsafeBufferPointer(start: report, count: count))
            me.onInputReport?(UInt8(truncatingIfNeeded: reportID), bytes)
        }, context)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        return result
    }

    /// Closes the device and frees the report buffer.
    public func close() {
        guard isOpen else { return }
        isOpen = false
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        _ = IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        buffer?.deallocate()
        buffer = nil
    }

    /// Sends an output report. `bytes` must include the report ID in byte 0.
    public func setOutputReport(id: UInt8, bytes: [UInt8]) -> IOReturn {
        return bytes.withUnsafeBufferPointer { ptr -> IOReturn in
            guard let base = ptr.baseAddress else { return IOReturn(bitPattern: 0xE00002C2) }
            return IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(id), base, ptr.count)
        }
    }

    /// Reads a feature report. Returns the bytes read (including the report ID), or nil on failure.
    public func getFeatureReport(id: UInt8, length: Int) -> [UInt8]? {
        guard length > 0 else { return nil }
        var out = [UInt8](repeating: 0, count: length)
        var got = CFIndex(length)
        let result = out.withUnsafeMutableBufferPointer { ptr -> IOReturn in
            guard let base = ptr.baseAddress else { return IOReturn(bitPattern: 0xE00002C2) }
            return IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(id), base, &got)
        }
        guard result == 0 else { return nil }
        return Array(out.prefix(max(0, min(Int(got), length))))
    }

    private static func property(_ device: IOHIDDevice, _ key: String) -> Any? {
        let raw: Any? = IOHIDDeviceGetProperty(device, key as CFString)
        // Some SDK versions return Unmanaged, others a plain object.
        if let unmanaged = raw as? Unmanaged<AnyObject> {
            return unmanaged.takeUnretainedValue()
        }
        return raw
    }

    private static func stringProperty(_ device: IOHIDDevice, _ key: String) -> String? {
        return property(device, key) as? String
    }

    private static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
        return property(device, key) as? Int
    }
}
#endif
