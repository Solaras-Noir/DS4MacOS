#if os(macOS)
import Foundation
import CoreGraphics
import ApplicationServices

/// Posts keyboard and mouse events to the HID event tap.
public final class EventInjector {
    private var leftDown = false
    private var rightDown = false

    /// Creates an injector.
    public init() {}

    /// Asks for the Accessibility permission, showing the system prompt if missing.
    /// Returns whether the process is currently trusted.
    @discardableResult
    public static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Posts a key-down event.
    public func keyDown(_ key: CGKeyCode) {
        postKey(key, down: true)
    }

    /// Posts a key-up event.
    public func keyUp(_ key: CGKeyCode) {
        postKey(key, down: false)
    }

    /// Moves the cursor by (dx, dy) pixels and sets the delta fields that games read.
    /// Uses drag events while a mouse button is held.
    public func mouseMove(dx: Int, dy: Int) {
        let current = CGEvent(source: nil)?.location ?? CGPoint.zero
        let target = CGPoint(x: current.x + CGFloat(dx), y: current.y + CGFloat(dy))
        let type: CGEventType
        let button: CGMouseButton
        if leftDown {
            type = .leftMouseDragged
            button = .left
        } else if rightDown {
            type = .rightMouseDragged
            button = .right
        } else {
            type = .mouseMoved
            button = .left
        }
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type,
                                  mouseCursorPosition: target, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy))
        event.post(tap: .cghidEventTap)
    }

    /// Presses or releases the left or right mouse button at the current cursor position.
    public func mouseButton(_ button: CGMouseButton, down: Bool) {
        let current = CGEvent(source: nil)?.location ?? CGPoint.zero
        let type: CGEventType
        switch button {
        case .right:
            type = down ? .rightMouseDown : .rightMouseUp
            rightDown = down
        default:
            type = down ? .leftMouseDown : .leftMouseUp
            leftDown = down
        }
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type,
                                  mouseCursorPosition: current, mouseButton: button) else { return }
        event.post(tap: .cghidEventTap)
    }

    private func postKey(_ key: CGKeyCode, down: Bool) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down) else { return }
        event.post(tap: .cghidEventTap)
    }
}
#endif
