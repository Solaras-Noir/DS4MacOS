import XCTest
@testable import DualSenseCore

final class MappingGestureTests: XCTestCase {
    private let idle = MapTest.state()

    func testTapIsKeyDownThenKeyUpAfter40ms() {
        let e = MappingEngine(profile: .fallout4Augment)
        XCTAssertEqual(e.update(state: idle, gestures: [.tap(0)], at: 1.0).actions, [.keyDown(97)])
        XCTAssertEqual(e.update(state: idle, gestures: [], at: 1.02).actions, [])
        XCTAssertEqual(e.update(state: idle, gestures: [], at: 1.04).actions, [.keyUp(97)])
        XCTAssertEqual(e.update(state: idle, gestures: [], at: 1.05).actions, [])
    }

    func testTapTimingAt250And65Hz() {
        for dt in [0.004, 1.0 / 65.0] {
            let e = MappingEngine(profile: .fallout4Augment)
            var t = 1.0
            XCTAssertEqual(e.update(state: idle, gestures: [.tap(1)], at: t).actions, [.keyDown(98)])
            var upAt: TimeInterval?
            for _ in 0..<40 {
                t += dt
                if e.update(state: idle, gestures: [], at: t).actions == [.keyUp(98)] { upAt = t; break }
            }
            let held = (upAt ?? 0) - 1.0
            XCTAssertGreaterThanOrEqual(held, 0.04 - 1e-9, "dt \(dt)")
            XCTAssertLessThan(held, 0.04 + dt + 1e-9, "dt \(dt)")
        }
    }

    func testZonesSelectDifferentKeys() {
        let e = MappingEngine(profile: .fallout4Augment)
        XCTAssertEqual(e.update(state: idle, gestures: [.tap(1)], at: 1).actions, [.keyDown(98)])
    }

    func testSwipesAndTwoFingerTap() {
        let e = MappingEngine(profile: .fallout4Augment)
        XCTAssertEqual(e.update(state: idle, gestures: [.swipe(.up, 0)], at: 1).actions, [.keyDown(100)])
        XCTAssertEqual(e.update(state: idle, gestures: [.swipe(.down, 1)], at: 1.1).actions,
                       [.keyUp(100), .keyDown(109)])
        XCTAssertEqual(e.update(state: idle, gestures: [.twoFingerTap], at: 1.2).actions,
                       [.keyUp(109), .keyDown(103)])
    }

    func testSwipeScrollFiresImmediatelyWithNoKey() {
        let e = MappingEngine(profile: .genericAugment)
        XCTAssertEqual(e.update(state: idle, gestures: [.swipe(.up, 0)], at: 1).actions, [.scroll(3)])
        XCTAssertEqual(e.update(state: idle, gestures: [.swipe(.down, 1)], at: 1.1).actions, [.scroll(-3)])
        XCTAssertEqual(e.update(state: idle, gestures: [], at: 1.2).actions, [])
    }

    func testUnboundGestureEmitsNothing() {
        let e = MappingEngine(profile: .fallout4Augment)
        XCTAssertEqual(e.update(state: idle, gestures: [.swipe(.left, 0), .padClick(0), .holdBegan(0),
                                                        .drag(dx: 5, dy: 5)], at: 1).actions, [])
    }

    func testHoldPressesWhileHeld() {
        var p = Profile(name: "h")
        p.touchpad = TouchpadBinding(layout: .single, zones: [0: [.hold: .key(code: 7)]])
        let e = MappingEngine(profile: p)
        XCTAssertEqual(e.update(state: idle, gestures: [.holdBegan(0)], at: 1).actions, [.keyDown(7)])
        XCTAssertEqual(e.update(state: idle, gestures: [], at: 2).actions, [])
        XCTAssertEqual(e.update(state: idle, gestures: [.holdEnded(0)], at: 3).actions, [.keyUp(7)])
    }

    func testPadClickBinding() {
        var p = Profile(name: "c")
        p.touchpad = TouchpadBinding(layout: .columns2, zones: [1: [.click: .mouseButton(.left)]])
        let e = MappingEngine(profile: p)
        XCTAssertEqual(e.update(state: idle, gestures: [.padClick(1)], at: 1).actions, [.mouseDown(.left)])
        XCTAssertEqual(e.update(state: idle, gestures: [], at: 1.05).actions, [.mouseUp(.left)])
    }

    func testRepeatedTapExtendsPress() {
        let e = MappingEngine(profile: .fallout4Augment)
        XCTAssertEqual(e.update(state: idle, gestures: [.tap(0)], at: 1.0).actions, [.keyDown(97)])
        XCTAssertEqual(e.update(state: idle, gestures: [.tap(0)], at: 1.03).actions, [])
        XCTAssertEqual(e.update(state: idle, gestures: [], at: 1.05).actions, [])
        XCTAssertEqual(e.update(state: idle, gestures: [], at: 1.08).actions, [.keyUp(97)])
    }

    func testReleaseAllCancelsPendingTap() {
        let e = MappingEngine(profile: .fallout4Augment)
        _ = e.update(state: idle, gestures: [.tap(0)], at: 1)
        XCTAssertEqual(e.releaseAll(), [.keyUp(97)])
        XCTAssertEqual(e.update(state: idle, gestures: [], at: 1.1).actions, [])
    }

    func testTapWhileButtonHoldsSameKeyKeepsKeyDown() {
        var p = Profile.fallout4Augment
        p.buttons[.cross] = .key(code: 97)
        let e = MappingEngine(profile: p)
        XCTAssertEqual(e.update(state: MapTest.state(buttons: [.cross]), gestures: [.tap(0)], at: 1).actions,
                       [.keyDown(97)])
        XCTAssertEqual(e.update(state: MapTest.state(buttons: [.cross]), gestures: [], at: 1.1).actions, [])
    }
}
