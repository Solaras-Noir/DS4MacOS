import Foundation

/// A per-game controller profile. JSON uses real objects for `buttons` ({"cross": ...}).
public struct Profile: Equatable, Codable {
    public var formatVersion: Int = 1
    public var name: String
    public var mode: ProfileMode
    public var appBundleIDs: [String]
    public var buttons: [ButtonID: Binding]
    public var leftStick: StickBinding
    public var rightStick: StickBinding
    public var l2: TriggerBinding
    public var r2: TriggerBinding
    public var touchpad: TouchpadBinding
    public var lightbar: RGB?
    public var leftTriggerEffect: TriggerEffect?
    public var rightTriggerEffect: TriggerEffect?
    public var rumbleOnTrigger: RumblePulse?
    public var playerLEDs: UInt8?

    public init(name: String, mode: ProfileMode = .augment, appBundleIDs: [String] = [],
                buttons: [ButtonID: Binding] = [:],
                leftStick: StickBinding = .none, rightStick: StickBinding = .none,
                l2: TriggerBinding = .none, r2: TriggerBinding = .none,
                touchpad: TouchpadBinding = TouchpadBinding(),
                lightbar: RGB? = nil,
                leftTriggerEffect: TriggerEffect? = nil, rightTriggerEffect: TriggerEffect? = nil,
                rumbleOnTrigger: RumblePulse? = nil, playerLEDs: UInt8? = nil) {
        self.name = name
        self.mode = mode
        self.appBundleIDs = appBundleIDs
        self.buttons = buttons
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.l2 = l2
        self.r2 = r2
        self.touchpad = touchpad
        self.lightbar = lightbar
        self.leftTriggerEffect = leftTriggerEffect
        self.rightTriggerEffect = rightTriggerEffect
        self.rumbleOnTrigger = rumbleOnTrigger
        self.playerLEDs = playerLEDs
    }

    private enum CodingKeys: String, CodingKey {
        case formatVersion, name, mode, appBundleIDs, buttons, leftStick, rightStick, l2, r2
        case touchpad, lightbar, leftTriggerEffect, rightTriggerEffect, rumbleOnTrigger, playerLEDs
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(formatVersion, forKey: .formatVersion)
        try c.encode(name, forKey: .name)
        try c.encode(mode, forKey: .mode)
        try c.encode(appBundleIDs, forKey: .appBundleIDs)
        var flat: [String: Binding] = [:]
        for (id, binding) in buttons { flat[id.rawValue] = binding }
        try c.encode(flat, forKey: .buttons)
        try c.encode(leftStick, forKey: .leftStick)
        try c.encode(rightStick, forKey: .rightStick)
        try c.encode(l2, forKey: .l2)
        try c.encode(r2, forKey: .r2)
        try c.encode(touchpad, forKey: .touchpad)
        try c.encodeIfPresent(lightbar, forKey: .lightbar)
        try c.encodeIfPresent(leftTriggerEffect, forKey: .leftTriggerEffect)
        try c.encodeIfPresent(rightTriggerEffect, forKey: .rightTriggerEffect)
        try c.encodeIfPresent(rumbleOnTrigger, forKey: .rumbleOnTrigger)
        try c.encodeIfPresent(playerLEDs, forKey: .playerLEDs)
    }

    /// Missing optional fields fall back to defaults so hand-edited files can be short.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try c.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        name = try c.decode(String.self, forKey: .name)
        mode = try c.decodeIfPresent(ProfileMode.self, forKey: .mode) ?? .augment
        appBundleIDs = try c.decodeIfPresent([String].self, forKey: .appBundleIDs) ?? []
        let flat = try c.decodeIfPresent([String: Binding].self, forKey: .buttons) ?? [:]
        var out: [ButtonID: Binding] = [:]
        for (key, binding) in flat {
            guard let id = ButtonID(rawValue: key) else {
                throw DecodingError.dataCorruptedError(forKey: .buttons, in: c,
                    debugDescription: "Unknown button \(key)")
            }
            out[id] = binding
        }
        buttons = out
        leftStick = try c.decodeIfPresent(StickBinding.self, forKey: .leftStick) ?? .none
        rightStick = try c.decodeIfPresent(StickBinding.self, forKey: .rightStick) ?? .none
        l2 = try c.decodeIfPresent(TriggerBinding.self, forKey: .l2) ?? .none
        r2 = try c.decodeIfPresent(TriggerBinding.self, forKey: .r2) ?? .none
        touchpad = try c.decodeIfPresent(TouchpadBinding.self, forKey: .touchpad) ?? TouchpadBinding()
        lightbar = try c.decodeIfPresent(RGB.self, forKey: .lightbar)
        leftTriggerEffect = try c.decodeIfPresent(TriggerEffect.self, forKey: .leftTriggerEffect)
        rightTriggerEffect = try c.decodeIfPresent(TriggerEffect.self, forKey: .rightTriggerEffect)
        rumbleOnTrigger = try c.decodeIfPresent(RumblePulse.self, forKey: .rumbleOnTrigger)
        playerLEDs = try c.decodeIfPresent(UInt8.self, forKey: .playerLEDs)
    }
}
