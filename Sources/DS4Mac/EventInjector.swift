#if os(macOS)
import Foundation
import CoreGraphics
import ApplicationServices
import DualSenseCore

/// Posts keyboard, mouse and scroll events to the HID event tap.
///
/// Threading: not thread-safe. Call every method from the main run loop, the same one the
/// device input callbacks run on, so key and button state stays consistent.
///
/// Modifier keys (Shift 56, Ctrl 59, Option 58, Command 55) are tracked while held and their
/// `CGEventFlags` are set on every event posted meanwhile (key, mouse and scroll).
/// No key repeat is synthesised; the system repeats a held key by itself.
public final class EventInjector {
    private var heldKeys = Set<CGKeyCode>()
    private var heldButtons = Set<MouseButton>()
    private var remainderX = 0.0
    private var remainderY = 0.0

    /// Creates an injector.
    public init() {}

    /// Asks for the Accessibility permission, showing the system prompt if missing.
    /// Returns whether the process is currently trusted.
    @discardableResult
    public static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Number of keys and mouse buttons currently held down by this injector.
    public var heldCount: Int { heldKeys.count + heldButtons.count }

    /// Performs one action from the mapping engine.
    public func perform(_ action: OutputAction) {
        switch action {
        case .keyDown(let code):
            keyDown(CGKeyCode(code))
        case .keyUp(let code):
            keyUp(CGKeyCode(code))
        case .mouseMove(let dx, let dy):
            moveMouse(dx: dx, dy: dy)
        case .mouseDown(let button):
            setButton(button, down: true)
        case .mouseUp(let button):
            setButton(button, down: false)
        case .scroll(let amount):
            scroll(amount)
        }
    }

    /// Releases every held key (including modifiers) and mouse button.
    public func releaseAll() {
        for key in heldKeys.sorted() {
            heldKeys.remove(key)
            postKey(key, down: false)
        }
        for button in heldButtons.sorted(by: { $0.rawValue < $1.rawValue }) {
            setButton(button, down: false)
        }
        remainderX = 0
        remainderY = 0
    }

    /// Posts a key-down event. Repeated downs for a held key are ignored.
    public func keyDown(_ key: CGKeyCode) {
        guard heldKeys.insert(key).inserted else { return }
        postKey(key, down: true)
    }

    /// Posts a key-up event. Ignored when the key is not held.
    public func keyUp(_ key: CGKeyCode) {
        guard heldKeys.remove(key) != nil else { return }
        postKey(key, down: false)
    }

    /// Moves the cursor by (dx, dy) pixels and sets the delta fields that games read.
    public func mouseMove(dx: Int, dy: Int) {
        moveMouse(dx: Double(dx), dy: Double(dy))
    }

    /// Presses or releases the left or right mouse button at the current cursor position.
    public func mouseButton(_ button: CGMouseButton, down: Bool) {
        setButton(button == .right ? .right : .left, down: down)
    }

    // MARK: - Internals

    private var currentFlags: CGEventFlags {
        var flags = CGEventFlags()
        if heldKeys.contains(56) { flags.insert(.maskShift) }
        if heldKeys.contains(59) { flags.insert(.maskControl) }
        if heldKeys.contains(58) { flags.insert(.maskAlternate) }
        if heldKeys.contains(55) { flags.insert(.maskCommand) }
        return flags
    }

    private func postKey(_ key: CGKeyCode, down: Bool) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down) else { return }
        event.flags = currentFlags
        event.post(tap: .cghidEventTap)
    }

    private func cursorLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? CGPoint.zero
    }

    private func moveMouse(dx: Double, dy: Double) {
        guard dx.isFinite, dy.isFinite else { return }
        let sumX = dx + remainderX
        let sumY = dy + remainderY
        let stepX = sumX.rounded()
        let stepY = sumY.rounded()
        remainderX = sumX - stepX
        remainderY = sumY - stepY
        guard stepX != 0 || stepY != 0 else { return }
        guard abs(stepX) < 1_000_000, abs(stepY) < 1_000_000 else { return }

        let current = cursorLocation()
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let x = min(max(current.x + CGFloat(stepX), bounds.minX), bounds.maxX - 1)
        let y = min(max(current.y + CGFloat(stepY), bounds.minY), bounds.maxY - 1)

        let type: CGEventType
        let button: CGMouseButton
        if heldButtons.contains(.left) {
            type = .leftMouseDragged
            button = .left
        } else if heldButtons.contains(.right) {
            type = .rightMouseDragged
            button = .right
        } else if heldButtons.contains(.middle) {
            type = .otherMouseDragged
            button = .center
        } else {
            type = .mouseMoved
            button = .left
        }
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type,
                                  mouseCursorPosition: CGPoint(x: x, y: y),
                                  mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(stepX))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(stepY))
        event.flags = currentFlags
        event.post(tap: .cghidEventTap)
    }

    private func setButton(_ button: MouseButton, down: Bool) {
        if down {
            guard heldButtons.insert(button).inserted else { return }
        } else {
            guard heldButtons.remove(button) != nil else { return }
        }
        let type: CGEventType
        let cgButton: CGMouseButton
        switch button {
        case .left:
            type = down ? .leftMouseDown : .leftMouseUp
            cgButton = .left
        case .right:
            type = down ? .rightMouseDown : .rightMouseUp
            cgButton = .right
        case .middle:
            type = down ? .otherMouseDown : .otherMouseUp
            cgButton = .center
        }
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type,
                                  mouseCursorPosition: cursorLocation(),
                                  mouseButton: cgButton) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.flags = currentFlags
        event.post(tap: .cghidEventTap)
    }

    /// Scrolls by whole lines; positive scrolls up.
    private func scroll(_ amount: Int) {
        guard amount != 0 else { return }
        let lines = Int32(clamping: amount)
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1,
                                  wheel1: lines, wheel2: 0, wheel3: 0) else { return }
        event.flags = currentFlags
        event.post(tap: .cghidEventTap)
    }
}
#endif
