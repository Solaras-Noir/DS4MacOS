import Foundation

extension Profile {
    /// macOS virtual key codes used by the built-ins.
    private enum Key {
        static let a: UInt16 = 0, s: UInt16 = 1, d: UInt16 = 2, w: UInt16 = 13
        static let v: UInt16 = 9, q: UInt16 = 12, e: UInt16 = 14, r: UInt16 = 15, m: UInt16 = 46
        static let tab: UInt16 = 48, space: UInt16 = 49, esc: UInt16 = 53
        static let shift: UInt16 = 56, ctrl: UInt16 = 59
        static let n1: UInt16 = 18, n2: UInt16 = 19, n3: UInt16 = 20, n4: UInt16 = 21
        static let f6: UInt16 = 97, f7: UInt16 = 98, f8: UInt16 = 100, f10: UInt16 = 109, f11: UInt16 = 103
    }

    private static let blue = RGB(red: 0, green: 60, blue: 255)
    private static let r2Pulse = RumblePulse(strong: 160, weak: 80, durationMs: 120, trigger: .right)

    private static func tapZones(left: Binding, right: Binding, extra: [GestureKind: Binding]) -> TouchpadBinding {
        var zone0: [GestureKind: Binding] = [.tap: left]
        var zone1: [GestureKind: Binding] = [.tap: right]
        for (kind, binding) in extra {
            zone0[kind] = binding
            if kind != .twoFingerTap { zone1[kind] = binding }
        }
        return TouchpadBinding(layout: .columns2, zones: [0: zone0, 1: zone1])
    }

    /// Fallout 4 with the pad fully replaced by keyboard and mouse.
    public static let fallout4KeyboardMouse = Profile(
        name: "Fallout 4 (keyboard and mouse)", mode: .keyboardMouse,
        buttons: [
            .cross: .key(code: Key.e), .circle: .key(code: Key.ctrl),
            .square: .key(code: Key.r), .triangle: .key(code: Key.space),
            .l1: .key(code: Key.shift), .r1: .key(code: Key.v),
            .l3: .key(code: Key.shift), .r3: .key(code: Key.q),
            .options: .key(code: Key.esc), .create: .key(code: Key.tab),
            .dpadUp: .key(code: Key.n1), .dpadDown: .key(code: Key.n2),
            .dpadLeft: .key(code: Key.n3), .dpadRight: .key(code: Key.n4),
        ],
        leftStick: .wasd(threshold: 0.5, hysteresis: 0.1),
        rightStick: .mouse(sensitivity: 900, curve: 1.6, deadZone: 0.12),
        l2: .button(.mouseButton(.right), threshold: 0.3),
        r2: .button(.mouseButton(.left), threshold: 0.3),
        touchpad: tapZones(left: .key(code: Key.tab), right: .key(code: Key.m),
                           extra: [.swipeUp: .scroll(dy: 3), .swipeDown: .scroll(dy: -3)]),
        lightbar: blue,
        leftTriggerEffect: TriggerEffect.feedback(position: 3, strength: 3),
        rightTriggerEffect: TriggerEffect.weapon(start: 4, end: 7, strength: 6),
        rumbleOnTrigger: r2Pulse)

    /// Fallout 4 with the pad left to the game; touchpad gestures send mod hotkeys.
    public static let fallout4Augment = Profile(
        name: "Fallout 4 (augment)", mode: .augment,
        touchpad: tapZones(left: .key(code: Key.f6), right: .key(code: Key.f7),
                           extra: [.swipeUp: .key(code: Key.f8), .swipeDown: .key(code: Key.f10),
                                   .twoFingerTap: .key(code: Key.f11)]),
        lightbar: blue,
        leftTriggerEffect: TriggerEffect.feedback(position: 3, strength: 3),
        rightTriggerEffect: TriggerEffect.weapon(start: 4, end: 7, strength: 6),
        rumbleOnTrigger: r2Pulse)

    /// Generic augment profile: touchpad extras only.
    public static let genericAugment = Profile(
        name: "Generic (augment)", mode: .augment,
        touchpad: tapZones(left: .key(code: Key.tab), right: .key(code: Key.m),
                           extra: [.swipeUp: .scroll(dy: 3), .swipeDown: .scroll(dy: -3),
                                   .twoFingerTap: .key(code: Key.esc)]),
        lightbar: blue,
        leftTriggerEffect: TriggerEffect.feedback(position: 3, strength: 3),
        rightTriggerEffect: TriggerEffect.weapon(start: 4, end: 7, strength: 6),
        rumbleOnTrigger: r2Pulse)

    /// Nothing bound, no feedback.
    public static let passThrough = Profile(name: "Pass-through", mode: .augment)

    /// All shipped profiles.
    public static var builtIns: [Profile] {
        [fallout4KeyboardMouse, fallout4Augment, genericAugment, passThrough]
    }
}
