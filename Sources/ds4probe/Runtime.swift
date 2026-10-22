#if os(macOS)
import Foundation
import DS4Mac
import IOKit

/// Objects that must stay alive while the run loop runs (timers, signal sources).
var retainedObjects: [Any] = []

/// Runs `block` every `interval` seconds on the main queue.
func every(_ interval: Double, _ block: @escaping () -> Void) {
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + interval, repeating: interval)
    timer.setEventHandler(handler: block)
    timer.resume()
    retainedObjects.append(timer)
}

/// Runs `block` once after `seconds` on the main queue.
func after(_ seconds: Double, _ block: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: block)
}

/// Handles Ctrl-C: runs `cleanup`, then exits with status 0.
func onInterrupt(_ cleanup: @escaping () -> Void) {
    _ = signal(SIGINT, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    source.setEventHandler {
        cleanup()
        exit(0)
    }
    source.resume()
    retainedObjects.append(source)
}

/// Spins the main run loop until the process exits.
func runForever() -> Never {
    CFRunLoopRun()
    exit(0)
}

func hex(_ bytes: [UInt8]) -> String {
    return bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
}

func hex32(_ value: Int32) -> String {
    return String(format: "0x%08x", UInt32(bitPattern: value))
}

/// Finds the first controller and opens it. Prints the IOReturn in hex and exits 1 on failure.
func openFirstDevice(seize: Bool) -> HIDDevice {
    guard let device = HIDDevice.all().first else {
        printErr("no DualSense controller found")
        exit(1)
    }
    let result = device.open(seize: seize)
    print("open(seize: \(seize)) on \(device.name) [\(device.transport)] -> \(hex32(result))")
    if result != 0 {
        if UInt32(bitPattern: result) == 0xE00002E2 {
            print("kIOReturnNotPermitted: grant Input Monitoring to the terminal, or retry without --seize")
        } else if UInt32(bitPattern: result) == 0xE00002C5 {
            print("kIOReturnExclusiveAccess: another process holds the device; quit it and retry")
        }
        exit(1)
    }
    return device
}

/// Over Bluetooth, reads feature report 0x05 so the controller switches to full reports.
func switchBluetoothToFullReports(_ device: HIDDevice) {
    guard device.transport.lowercased().contains("bluetooth") else { return }
    if let bytes = device.getFeatureReport(id: 0x05, length: 64) {
        print("feature report 0x05 read ok, \(bytes.count) bytes")
    } else {
        print("feature report 0x05 read FAILED")
    }
}
#endif
