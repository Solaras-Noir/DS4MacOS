import XCTest
@testable import DualSenseCore

final class OutputReportTests: XCTestCase {
    func testEmpty() {
        let b = OutputReport().usbBytes()
        XCTAssertEqual(b.count, 48)
        XCTAssertEqual(b[0], 0x02)
        XCTAssertEqual(Array(b[1...]), [UInt8](repeating: 0, count: 47))
    }

    func testRumble() {
        var r = OutputReport()
        r.rumble(strong: 200, weak: 50)
        let b = r.usbBytes()
        XCTAssertEqual(b[1], 0x01)
        XCTAssertEqual(b[2], 0)
        XCTAssertEqual(b[3], 50)   // motor_right = weak
        XCTAssertEqual(b[4], 200)  // motor_left = strong
        XCTAssertEqual(b[39], 0x04)
    }

    func testLightbar() {
        var r = OutputReport()
        r.lightbar = RGB(red: 1, green: 2, blue: 3)
        let b = r.usbBytes()
        XCTAssertEqual(b[2], 0x04)
        XCTAssertEqual(Array(b[45...47]), [1, 2, 3])
        XCTAssertEqual(b[1], 0)
    }

    func testPlayerLEDs() {
        var r = OutputReport()
        r.playerLEDs = 0x04
        let b = r.usbBytes()
        XCTAssertEqual(b[2], 0x10)
        XCTAssertEqual(b[44], 0x04)
    }

    func testMicLED() {
        var r = OutputReport()
        r.micLED = .pulse
        let b = r.usbBytes()
        XCTAssertEqual(b[2], 0x01)
        XCTAssertEqual(b[9], 2)
    }

    func testRightTrigger() {
        var r = OutputReport()
        r.rightTrigger = .raw(mode: 0x02, params: [1, 2, 3])
        let b = r.usbBytes()
        XCTAssertEqual(b[1], 0x04)
        XCTAssertEqual(Array(b[11...21]), [2, 1, 2, 3, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(Array(b[22...32]), [UInt8](repeating: 0, count: 11))
    }

    func testLeftTriggerTruncates() {
        var r = OutputReport()
        r.leftTrigger = .raw(mode: 0x21, params: Array(1...15))
        let b = r.usbBytes()
        XCTAssertEqual(b[1], 0x08)
        XCTAssertEqual(Array(b[22...32]), [0x21, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        XCTAssertEqual(b.count, 48)
    }

    func testTriggerOffStillSetsFlag() {
        var r = OutputReport()
        r.leftTrigger = .off
        r.rightTrigger = .off
        let b = r.usbBytes()
        XCTAssertEqual(b[1], 0x0C)
        XCTAssertEqual(Array(b[11...32]), [UInt8](repeating: 0, count: 22))
    }

    func testCombinedFlags() {
        var r = OutputReport()
        r.rumble(strong: 1, weak: 2)
        r.lightbar = RGB(red: 9, green: 9, blue: 9)
        r.playerLEDs = 1
        r.micLED = .on
        r.rightTrigger = .off
        r.leftTrigger = .off
        let b = r.usbBytes()
        XCTAssertEqual(b[1], 0x0D)
        XCTAssertEqual(b[2], 0x15)
        XCTAssertEqual(b[39], 0x04)
    }
}
