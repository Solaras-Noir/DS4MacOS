import XCTest
@testable import DualSenseCore

final class MappingEngineTests: XCTestCase {
    private func engine(_ p: Profile) -> MappingEngine { MappingEngine(profile: p) }
    private func update(_ e: MappingEngine, _ s: ControllerState, _ g: [GestureEvent] = [],
                        at t: TimeInterval) -> MappingOutput {
        e.update(state: s, gestures: g, at: t)
    }

    func testHeldButtonEmitsOneKeyDownThenKeyUp() {
        let e = engine(.fallout4KeyboardMouse)
        let down = MapTest.state(buttons: [.cross])
        XCTAssertEqual(update(e, down, at: 1.0).actions, [.keyDown(14)])
        XCTAssertEqual(update(e, down, at: 1.004).actions, [])
        XCTAssertEqual(update(e, down, at: 1.008).actions, [])
        XCTAssertEqual(update(e, MapTest.state(), at: 1.012).actions, [.keyUp(14)])
    }

    func testSharedKeyReleasedOnlyWhenBothSourcesLetGo() {
        let e = engine(.fallout4KeyboardMouse) // L1 and L3 both Shift
        XCTAssertEqual(update(e, MapTest.state(buttons: [.l1, .l3]), at: 1).actions, [.keyDown(56)])
        XCTAssertEqual(update(e, MapTest.state(buttons: [.l3]), at: 1.01).actions, [])
        XCTAssertEqual(update(e, MapTest.state(), at: 1.02).actions, [.keyUp(56)])
    }

    func testDpadDirections() {
        let e = engine(.fallout4KeyboardMouse)
        XCTAssertEqual(update(e, MapTest.state(dpad: .northEast), at: 1).actions, [.keyDown(18), .keyDown(21)])
        XCTAssertEqual(update(e, MapTest.state(dpad: .south), at: 1.01).actions,
                       [.keyUp(18), .keyUp(21), .keyDown(19)])
    }

    func testWASDHysteresis() {
        let e = engine(.fallout4KeyboardMouse) // threshold 0.5, hysteresis 0.1
        XCTAssertEqual(update(e, MapTest.state(left: (0, 0.45)), at: 1).actions, [])
        XCTAssertEqual(update(e, MapTest.state(left: (0, 0.6)), at: 1.01).actions, [.keyDown(13)])
        // Between release (0.4) and press (0.5) thresholds: stays down.
        XCTAssertEqual(update(e, MapTest.state(left: (0, 0.45)), at: 1.02).actions, [])
        XCTAssertEqual(update(e, MapTest.state(left: (0, 0.35)), at: 1.03).actions, [.keyUp(13)])
        // And does not re-press until past 0.5 again.
        XCTAssertEqual(update(e, MapTest.state(left: (0, 0.45)), at: 1.04).actions, [])
    }

    func testWASDAllDirections() {
        let e = engine(.fallout4KeyboardMouse)
        XCTAssertEqual(update(e, MapTest.state(left: (-1, 0)), at: 1).actions, [.keyDown(0)])
        XCTAssertEqual(update(e, MapTest.state(left: (0, -1)), at: 1.01).actions, [.keyUp(0), .keyDown(1)])
        XCTAssertEqual(update(e, MapTest.state(left: (1, 0)), at: 1.02).actions, [.keyUp(1), .keyDown(2)])
    }

    func testWASDDiagonal() {
        let e = engine(.fallout4KeyboardMouse)
        XCTAssertEqual(update(e, MapTest.state(left: (0.8, 0.8)), at: 1).actions, [.keyDown(2), .keyDown(13)])
    }

    func testMouseDistanceSameAt250And65Hz() {
        let s = MapTest.state(right: (1, 0))
        let a = MapTest.totalMove(engine(.fallout4KeyboardMouse), state: s, rate: 0.004)
        let b = MapTest.totalMove(engine(.fallout4KeyboardMouse), state: s, rate: 1.0 / 65.0)
        XCTAssertEqual(a.0, 900, accuracy: 6)
        XCTAssertEqual(b.0, 900, accuracy: 16)
        XCTAssertEqual(a.0, b.0, accuracy: 20)
        XCTAssertEqual(a.1, 0)
    }

    func testMouseUpIsNegativeScreenY() {
        let s = MapTest.state(right: (0, 1))
        let m = MapTest.totalMove(engine(.fallout4KeyboardMouse), state: s, rate: 0.004)
        XCTAssertLessThan(m.1, -800)
    }

    func testMouseFractionalRemainderCarried() {
        var p = Profile(name: "slow")
        p.rightStick = .mouse(sensitivity: 100, curve: 1, deadZone: 0)
        let e = engine(p)
        let s = MapTest.state(right: (1, 0))
        var total = 0.0
        var t = 1.0
        for _ in 0..<101 { // 101 updates, 2 ms apart (first has dt 0), so 200 ms of movement
            for a in update(e, s, at: t).actions { if case let .mouseMove(dx, _) = a { total += dx } }
            t += 0.002
        }
        // 200 ms at 100 px/s = 20 px even though each step is only 0.2 px.
        XCTAssertEqual(total, 20, accuracy: 1)
    }

    func testRadialDeadZone() {
        let e = engine(.fallout4KeyboardMouse) // dead zone 0.12
        // Radial check: (0.1, 0.1) has each axis under 0.12 but magnitude 0.141, so it moves;
        // (0.08, 0.08) has magnitude 0.113, inside the dead zone.
        XCTAssertEqual(MapTest.totalMove(e, state: MapTest.state(right: (0.08, 0.08)), rate: 0.004).0, 0)
        XCTAssertNotEqual(MapTest.totalMove(engine(.fallout4KeyboardMouse),
                                            state: MapTest.state(right: (0.1, 0.1)), rate: 0.004).0, 0)
        XCTAssertEqual(MapTest.totalMove(engine(.fallout4KeyboardMouse),
                                         state: MapTest.state(right: (0.11, 0)), rate: 0.004).0, 0)
        XCTAssertGreaterThan(MapTest.totalMove(engine(.fallout4KeyboardMouse),
                                               state: MapTest.state(right: (0.3, 0)), rate: 0.004).0, 10)
    }

    func testMouseVelocityCurve() {
        let half = MappingEngine.mouseVelocity(x: 0.56, y: 0, sensitivity: 1000, curve: 2, deadZone: 0.12)
        XCTAssertEqual(half.0, 1000 * pow((0.56 - 0.12) / 0.88, 2), accuracy: 1e-3)
        XCTAssertEqual(MappingEngine.mouseVelocity(x: 1, y: 0, sensitivity: 900, curve: 1.6, deadZone: 0.12).0,
                       900, accuracy: 1e-6)
    }

    func testMouseStallIsClamped() {
        let e = engine(.fallout4KeyboardMouse)
        let s = MapTest.state(right: (1, 0))
        _ = update(e, s, at: 1)
        var moved = 0.0
        for a in update(e, s, at: 100).actions { if case let .mouseMove(dx, _) = a { moved = dx } }
        XCTAssertLessThanOrEqual(moved, 91)
    }

    func testTriggerPressWithHysteresisAndRumble() {
        let e = engine(.fallout4KeyboardMouse) // R2 left mouse, threshold 0.3, pulse on R2
        XCTAssertEqual(update(e, MapTest.state(r2: 0.2), at: 1).actions, [])
        let down = update(e, MapTest.state(r2: 0.4), at: 1.01)
        XCTAssertEqual(down.actions, [.mouseDown(.left)])
        XCTAssertEqual(down.feedback, [.rumble(strong: 160, weak: 80, durationMs: 120)])
        let hold = update(e, MapTest.state(r2: 0.28), at: 1.02) // inside hysteresis band
        XCTAssertEqual(hold.actions, [])
        XCTAssertEqual(hold.feedback, [])
        XCTAssertEqual(update(e, MapTest.state(r2: 0.1), at: 1.03).actions, [.mouseUp(.left)])
    }

    func testL2MapsToRightMouseWithoutRumble() {
        let e = engine(.fallout4KeyboardMouse)
        let out = update(e, MapTest.state(l2: 1), at: 1)
        XCTAssertEqual(out.actions, [.mouseDown(.right)])
        XCTAssertEqual(out.feedback, [])
    }

    func testAugmentEmitsNothingForUnboundInputs() {
        let e = engine(.fallout4Augment)
        let s = MapTest.state(buttons: [.cross, .circle, .l1, .r3, .options], dpad: .north,
                              left: (1, 1), right: (1, 1), l2: 1, r2: 1)
        XCTAssertEqual(update(e, s, at: 1).actions, [])
        XCTAssertEqual(update(e, s, at: 1.5).actions, [])
    }

    func testAugmentStillRumblesOnR2() {
        let e = engine(.fallout4Augment)
        XCTAssertEqual(update(e, MapTest.state(r2: 1), at: 1).feedback,
                       [.rumble(strong: 160, weak: 80, durationMs: 120)])
    }

    func testProxyModeBehavesLikeAugment() {
        var p = Profile.genericAugment
        p.mode = .proxy
        let e = engine(p)
        XCTAssertEqual(update(e, MapTest.state(buttons: [.cross]), at: 1).actions, [])
        XCTAssertEqual(update(e, MapTest.state(), [.tap(0)], at: 1.1).actions, [.keyDown(48)])
    }

    func testExplicitButtonBindingInAugmentIsHonoured() {
        var p = Profile.fallout4Augment
        p.buttons[.square] = .key(code: 15)
        let e = engine(p)
        XCTAssertEqual(update(e, MapTest.state(buttons: [.square, .cross]), at: 1).actions, [.keyDown(15)])
    }

    func testMouseButtonBindingOnFaceButton() {
        var p = Profile(name: "m")
        p.buttons[.r1] = .mouseButton(.middle)
        let e = engine(p)
        XCTAssertEqual(update(e, MapTest.state(buttons: [.r1]), at: 1).actions, [.mouseDown(.middle)])
        XCTAssertEqual(update(e, MapTest.state(), at: 1.01).actions, [.mouseUp(.middle)])
    }

    func testScrollButtonFiresOncePerPress() {
        var p = Profile(name: "s")
        p.buttons[.r1] = .scroll(dy: -2)
        let e = engine(p)
        let down = MapTest.state(buttons: [.r1])
        XCTAssertEqual(update(e, down, at: 1).actions, [.scroll(-2)])
        XCTAssertEqual(update(e, down, at: 1.01).actions, [])
        _ = update(e, MapTest.state(), at: 1.02)
        XCTAssertEqual(update(e, down, at: 1.03).actions, [.scroll(-2)])
    }

    func testInitialFeedback() {
        let fb = engine(.fallout4KeyboardMouse).initialFeedback()
        XCTAssertEqual(fb.count, 3)
        XCTAssertEqual(fb.first, .lightbar(RGB(red: 0, green: 60, blue: 255)))
        XCTAssertTrue(fb.contains { if case .trigger(.right, _) = $0 { return true }; return false })
        var p = Profile(name: "leds"); p.playerLEDs = 0x04
        XCTAssertEqual(engine(p).initialFeedback(), [.playerLEDs(0x04)])
    }

    func testReleaseAllAfterMixedInputs() {
        let e = engine(.fallout4KeyboardMouse)
        _ = update(e, MapTest.state(buttons: [.cross, .l1], left: (1, 0), r2: 1), at: 1)
        _ = update(e, MapTest.state(buttons: [.cross, .l1], left: (1, 0), r2: 1), [.tap(0)], at: 1.01)
        let rel = e.releaseAll()
        XCTAssertEqual(Set(rel), Set([.keyUp(14), .keyUp(56), .keyUp(2), .keyUp(48), .mouseUp(.left)]))
        XCTAssertEqual(rel.count, 5)
        XCTAssertEqual(e.releaseAll(), [])
        // After releaseAll the held inputs press again.
        XCTAssertTrue(update(e, MapTest.state(buttons: [.cross]), at: 2).actions.contains(.keyDown(14)))
    }

    func testReleaseAllWhenNothingHeld() {
        XCTAssertEqual(engine(.passThrough).releaseAll(), [])
    }
}
