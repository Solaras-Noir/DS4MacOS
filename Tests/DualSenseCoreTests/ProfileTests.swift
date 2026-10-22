import XCTest
@testable import DualSenseCore

final class ProfileTests: XCTestCase {
    private func roundTrip(_ p: Profile) throws -> Profile {
        let data = try JSONEncoder().encode(p)
        return try JSONDecoder().decode(Profile.self, from: data)
    }

    func testBuiltInsRoundTrip() throws {
        for p in Profile.builtIns {
            XCTAssertEqual(try roundTrip(p), p, p.name)
        }
    }

    func testBuiltInNamesUniqueAndCount() {
        XCTAssertEqual(Profile.builtIns.count, 4)
        XCTAssertEqual(Set(Profile.builtIns.map { $0.name }).count, 4)
    }

    func testButtonsEncodeAsJSONObject() throws {
        let data = try JSONEncoder().encode(Profile.fallout4KeyboardMouse)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let buttons = try XCTUnwrap(obj["buttons"] as? [String: Any])
        XCTAssertNotNil(buttons["cross"])
        XCTAssertNotNil(buttons["dpadUp"])
    }

    func testTouchpadZonesEncodeAsJSONObjects() throws {
        let data = try JSONEncoder().encode(Profile.fallout4Augment)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let pad = try XCTUnwrap(obj["touchpad"] as? [String: Any])
        let zones = try XCTUnwrap(pad["zones"] as? [String: Any])
        let zone0 = try XCTUnwrap(zones["0"] as? [String: Any])
        XCTAssertNotNil(zone0["tap"])
        XCTAssertNotNil(zone0["twoFingerTap"])
    }

    func testHandEditedMinimalJSONDecodes() throws {
        let json = #"{"name":"Mine","buttons":{"cross":{"key":{"code":14}}}}"#
        let p = try JSONDecoder().decode(Profile.self, from: Data(json.utf8))
        XCTAssertEqual(p.name, "Mine")
        XCTAssertEqual(p.mode, .augment)
        XCTAssertEqual(p.formatVersion, 1)
        XCTAssertEqual(p.buttons[.cross], .key(code: 14))
        XCTAssertEqual(p.leftStick, .none)
    }

    func testUnknownButtonKeyFails() {
        let json = #"{"name":"x","buttons":{"banana":{"none":{}}}}"#
        XCTAssertThrowsError(try JSONDecoder().decode(Profile.self, from: Data(json.utf8)))
    }

    func testUnknownGestureKeyFails() {
        let json = #"{"name":"x","touchpad":{"layout":{"single":{}},"zones":{"0":{"wiggle":{"none":{}}}}}}"#
        XCTAssertThrowsError(try JSONDecoder().decode(Profile.self, from: Data(json.utf8)))
    }

    func testNonIntegerZoneKeyFails() {
        let json = #"{"name":"x","touchpad":{"zones":{"left":{"tap":{"none":{}}}}}}"#
        XCTAssertThrowsError(try JSONDecoder().decode(Profile.self, from: Data(json.utf8)))
    }

    func testCustomLayoutAndEffectsRoundTrip() throws {
        var p = Profile(name: "c", mode: .proxy)
        p.touchpad = TouchpadBinding(layout: .custom([TouchRect(x: 0, y: 0, width: 100, height: 100)]),
                                     zones: [0: [.hold: .mouseButton(.middle), .click: .scroll(dy: -2)]])
        p.leftTriggerEffect = .raw(mode: 0x25, params: [1, 2, 3])
        p.rightTriggerEffect = TriggerEffect.off
        p.lightbar = RGB(red: 1, green: 2, blue: 3)
        p.playerLEDs = 0x15
        p.l2 = .button(.key(code: 3), threshold: 0.25)
        p.rumbleOnTrigger = RumblePulse(strong: 1, weak: 2, durationMs: 50, trigger: .left)
        XCTAssertEqual(try roundTrip(p), p)
    }

    func testFallout4KeyboardMouseContents() {
        let p = Profile.fallout4KeyboardMouse
        XCTAssertEqual(p.mode, .keyboardMouse)
        XCTAssertEqual(p.buttons[.cross], .key(code: 14))
        XCTAssertEqual(p.buttons[.dpadRight], .key(code: 21))
        XCTAssertEqual(p.rightStick, .mouse(sensitivity: 900, curve: 1.6, deadZone: 0.12))
        XCTAssertEqual(p.touchpad.zones[1]?[.tap], .key(code: 46))
        XCTAssertNotNil(p.rightTriggerEffect)
        XCTAssertNotNil(p.leftTriggerEffect)
        XCTAssertEqual(p.rumbleOnTrigger?.durationMs, 120)
    }

    func testFallout4AugmentBindsOnlyTouchpad() {
        let p = Profile.fallout4Augment
        XCTAssertEqual(p.mode, .augment)
        XCTAssertTrue(p.buttons.isEmpty)
        XCTAssertEqual(p.leftStick, .none)
        XCTAssertEqual(p.touchpad.zones[0]?[.tap], .key(code: 97))
        XCTAssertEqual(p.touchpad.zones[1]?[.tap], .key(code: 98))
        XCTAssertEqual(p.touchpad.zones[0]?[.swipeUp], .key(code: 100))
        XCTAssertEqual(p.touchpad.zones[0]?[.swipeDown], .key(code: 109))
        XCTAssertEqual(p.touchpad.zones[0]?[.twoFingerTap], .key(code: 103))
    }

    func testPassThroughIsEmpty() {
        let p = Profile.passThrough
        XCTAssertTrue(p.buttons.isEmpty)
        XCTAssertNil(p.lightbar)
        XCTAssertTrue(MappingEngine(profile: p).initialFeedback().isEmpty)
    }
}
