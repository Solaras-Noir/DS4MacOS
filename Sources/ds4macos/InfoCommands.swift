#if os(macOS)
import Foundation
import ApplicationServices
import DS4Mac

/// `ds4macos devices`.
func devicesCommand() {
    let devices = HIDDevice.all()
    if devices.isEmpty {
        print("no DualSense controller found")
        return
    }
    for d in devices {
        print("\(d.name)  product 0x\(String(d.productID, radix: 16))  transport \(d.transport)")
    }
}

/// `ds4macos permissions`: reports the Accessibility status and shows the system prompt if missing.
func permissionsCommand() {
    if AXIsProcessTrusted() {
        print("Accessibility: granted")
        return
    }
    print("Accessibility: NOT granted; asking now")
    let trusted = EventInjector.requestAccessibility()
    print(trusted ? "Accessibility: granted"
                  : "Grant Accessibility to this terminal in System Settings > Privacy & Security, then rerun.")
    print("Input Monitoring is needed to read the pad; macOS asks for it on first use.")
}
#endif
