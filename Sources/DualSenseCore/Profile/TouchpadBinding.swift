import Foundation

/// The touchpad gestures a profile can bind.
public enum GestureKind: String, Equatable, Hashable, Codable, CaseIterable {
    case tap, twoFingerTap, hold
    case swipeUp, swipeDown, swipeLeft, swipeRight
    case click
}

/// Touchpad layout plus per-zone gesture bindings. `twoFingerTap` has no zone and is looked up
/// in zone 0. Encodes as JSON objects keyed by zone number then gesture name.
public struct TouchpadBinding: Equatable, Codable {
    public var layout: TouchZoneLayout
    public var zones: [ZoneIndex: [GestureKind: Binding]]

    public init(layout: TouchZoneLayout = .single, zones: [ZoneIndex: [GestureKind: Binding]] = [:]) {
        self.layout = layout
        self.zones = zones
    }

    private enum CodingKeys: String, CodingKey { case layout, zones }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(layout, forKey: .layout)
        var flat: [String: [String: Binding]] = [:]
        for (zone, gestures) in zones {
            var inner: [String: Binding] = [:]
            for (kind, binding) in gestures { inner[kind.rawValue] = binding }
            flat[String(zone)] = inner
        }
        try c.encode(flat, forKey: .zones)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        layout = try c.decodeIfPresent(TouchZoneLayout.self, forKey: .layout) ?? .single
        let flat = try c.decodeIfPresent([String: [String: Binding]].self, forKey: .zones) ?? [:]
        var out: [ZoneIndex: [GestureKind: Binding]] = [:]
        for (zoneKey, inner) in flat {
            guard let zone = Int(zoneKey) else {
                throw DecodingError.dataCorruptedError(forKey: .zones, in: c,
                    debugDescription: "Zone key \(zoneKey) is not an integer")
            }
            var gestures: [GestureKind: Binding] = [:]
            for (name, binding) in inner {
                guard let kind = GestureKind(rawValue: name) else {
                    throw DecodingError.dataCorruptedError(forKey: .zones, in: c,
                        debugDescription: "Unknown gesture \(name)")
                }
                gestures[kind] = binding
            }
            out[zone] = gestures
        }
        zones = out
    }
}
