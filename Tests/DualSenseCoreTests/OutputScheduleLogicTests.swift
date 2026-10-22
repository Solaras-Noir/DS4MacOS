import XCTest
@testable import DualSenseCore

final class OutputScheduleLogicTests: XCTestCase {
    func testNothingToSendInitially() {
        var l = OutputScheduleLogic(reassert: true)
        XCTAssertNil(l.poll(now: 0))
        XCTAssertNil(l.poll(now: 10))
    }

    func testChangeSendsOnceThenQuiet() {
        var l = OutputScheduleLogic(reassert: false)
        l.setLightbar(RGB(red: 1, green: 2, blue: 3))
        let r = l.poll(now: 1)
        XCTAssertEqual(r?.lightbar, RGB(red: 1, green: 2, blue: 3))
        XCTAssertNil(l.poll(now: 1.5))
        XCTAssertNil(l.poll(now: 100))
    }

    func testSameValueIsNoChange() {
        var l = OutputScheduleLogic(reassert: false)
        l.setPlayerLEDs(0x04)
        XCTAssertNotNil(l.poll(now: 1))
        l.setPlayerLEDs(0x04)
        XCTAssertNil(l.poll(now: 2))
    }

    func testMinimumGapDefersChange() {
        var l = OutputScheduleLogic(reassert: false)
        l.setLightbar(RGB(red: 1, green: 0, blue: 0))
        XCTAssertNotNil(l.poll(now: 1))
        l.setLightbar(RGB(red: 2, green: 0, blue: 0))
        XCTAssertNil(l.poll(now: 1.005))
        XCTAssertEqual(l.poll(now: 1.011)?.lightbar, RGB(red: 2, green: 0, blue: 0))
    }

    func testRumbleExpires() {
        var l = OutputScheduleLogic(reassert: false)
        l.setRumble(strong: 200, weak: 100, duration: 0.1, now: 0)
        let first = l.poll(now: 0)
        XCTAssertEqual(first?.rumbleValues?.strong, 200)
        XCTAssertNil(l.poll(now: 0.05))
        let off = l.poll(now: 0.1)
        XCTAssertEqual(off?.rumbleValues?.strong, 0)
        XCTAssertEqual(off?.rumbleValues?.weak, 0)
        XCTAssertNil(l.poll(now: 0.5))
    }

    func testRumbleWithoutDurationPersists() {
        var l = OutputScheduleLogic(reassert: false)
        l.setRumble(strong: 10, weak: 20, duration: nil, now: 0)
        XCTAssertNotNil(l.poll(now: 0))
        XCTAssertNil(l.poll(now: 1000))
        XCTAssertEqual(l.rumble?.weak, 20)
    }

    func testZeroRumbleHasNoExpiry() {
        var l = OutputScheduleLogic(reassert: false)
        l.setRumble(strong: 0, weak: 0, duration: 0.1, now: 0)
        XCTAssertNotNil(l.poll(now: 0))
        XCTAssertNil(l.poll(now: 1))
    }

    func testStopRumble() {
        var l = OutputScheduleLogic(reassert: false)
        l.setRumble(strong: 255, weak: 255, duration: nil, now: 0)
        _ = l.poll(now: 0)
        l.stopRumble()
        XCTAssertEqual(l.poll(now: 1)?.rumbleValues?.strong, 0)
    }

    func testAugmentReassertsEveryTwoSeconds() {
        var l = OutputScheduleLogic(reassert: true)
        l.setLightbar(RGB(red: 9, green: 9, blue: 9))
        XCTAssertNotNil(l.poll(now: 0))
        XCTAssertNil(l.poll(now: 1.9))
        let again = l.poll(now: 2.0)
        XCTAssertEqual(again?.lightbar, RGB(red: 9, green: 9, blue: 9))
        XCTAssertNil(l.poll(now: 3.9))
        XCTAssertNotNil(l.poll(now: 4.0))
    }

    func testNoReassertOutsideAugment() {
        var l = OutputScheduleLogic(reassert: false)
        l.setLightbar(RGB(red: 9, green: 9, blue: 9))
        _ = l.poll(now: 0)
        XCTAssertNil(l.poll(now: 10))
    }

    func testReconnectResends() {
        var l = OutputScheduleLogic(reassert: false)
        l.setLeftTrigger(.off)
        _ = l.poll(now: 5)
        l.markReconnected()
        XCTAssertEqual(l.poll(now: 5.001)?.leftTrigger, .off)
    }

    func testReportCarriesVibrationModeAndTriggers() {
        var l = OutputScheduleLogic(reassert: false)
        l.vibrationMode = .v1
        l.setRightTrigger(.raw(mode: 0x21, params: [1]))
        l.setRumble(strong: 1, weak: 2, duration: nil, now: 0)
        let r = l.poll(now: 0)
        XCTAssertEqual(r?.vibrationMode, .v1)
        XCTAssertEqual(r?.rightTrigger, .raw(mode: 0x21, params: [1]))
        XCTAssertEqual(r?.usbBytes()[1], 0x07)
    }

    func testNextDeadline() {
        var l = OutputScheduleLogic(reassert: true)
        XCTAssertNil(l.nextDeadline(now: 0))
        l.setLightbar(nil)
        l.setPlayerLEDs(1)
        XCTAssertEqual(l.nextDeadline(now: 3), 3)
        _ = l.poll(now: 3)
        XCTAssertEqual(l.nextDeadline(now: 3.5), 5)
    }
}
