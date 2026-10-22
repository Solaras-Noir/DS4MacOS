import XCTest
@testable import DualSenseCore

final class InputReportTests: XCTestCase {
    /// 64-byte report with ID, idle state.
    func idle() -> [UInt8] {
        var b = [UInt8](repeating: 0, count: 64)
        b[0] = 0x01
        for i in 1...4 { b[i] = 128 }
        b[8] = 0x08  // hat released
        b[33] = 0x80; b[37] = 0x80  // no touches
        return b
    }

    func testIdle() throws {
        let r = try XCTUnwrap(InputReport(usbReport: idle()))
        XCTAssertEqual(r.leftStick.x, 0)
        XCTAssertEqual(r.leftStick.y, 0)
        XCTAssertEqual(r.dpad, .none)
        XCTAssertTrue(r.buttons.isEmpty)
        XCTAssertFalse(r.touch[0].isTouching)
        XCTAssertEqual(r.l2, 0)
    }

    func testPayloadOnly63() throws {
        let r = try XCTUnwrap(InputReport(usbReport: Array(idle().dropFirst())))
        XCTAssertEqual(r.dpad, .none)
    }

    func testMalformed() {
        XCTAssertNil(InputReport(usbReport: []))
        XCTAssertNil(InputReport(usbReport: Array(idle().prefix(10))))
        XCTAssertNil(InputReport(usbReport: Array(idle().prefix(62))))
        var wrong = idle(); wrong[0] = 0x31
        XCTAssertNil(InputReport(usbReport: wrong))
        XCTAssertNil(InputReport(usbReport: idle() + [0]))
    }

    func testSticksAndTriggers() throws {
        var b = idle()
        b[1] = 0; b[2] = 0; b[3] = 255; b[4] = 255; b[5] = 255; b[6] = 255
        b[8] = 9
        let r = try XCTUnwrap(InputReport(usbReport: b))
        XCTAssertEqual(r.leftStick.x, -1)
        XCTAssertEqual(r.leftStick.y, 1)  // raw 0 is up
        XCTAssertEqual(r.rightStick.x, 1)
        XCTAssertEqual(r.rightStick.y, -1) // clamped from -(127/127)
        XCTAssertEqual(r.rightStick.rawX, 255)
        XCTAssertEqual(r.l2, 1)
        XCTAssertEqual(r.r2Raw, 255)
        XCTAssertEqual(try XCTUnwrap(InputReport(usbReport: idle())).rightStick.rawY, 128)
        XCTAssertEqual(r.sequence, 0)
    }

    func testStickClampsLowEnd() {
        XCTAssertEqual(StickState(rawX: 0, rawY: 255).x, -1)
        XCTAssertEqual(StickState(rawX: 0, rawY: 255).y, -1)
    }

    func testHatDirections() throws {
        let expected: [Dpad] = [.north, .northEast, .east, .southEast, .south, .southWest, .west, .northWest, .none]
        for (hat, dir) in expected.enumerated() {
            var b = idle()
            b[8] = UInt8(hat)
            XCTAssertEqual(try XCTUnwrap(InputReport(usbReport: b)).dpad, dir)
        }
    }

    func testEachButton() throws {
        let map: [(Int, UInt8, DualSenseButtons)] = [
            (8, 0x10, .square), (8, 0x20, .cross), (8, 0x40, .circle), (8, 0x80, .triangle),
            (9, 0x01, .l1), (9, 0x02, .r1), (9, 0x04, .l2), (9, 0x08, .r2),
            (9, 0x10, .create), (9, 0x20, .options), (9, 0x40, .l3), (9, 0x80, .r3),
            (10, 0x01, .ps), (10, 0x02, .touchpad), (10, 0x04, .mute),
        ]
        for (index, mask, button) in map {
            var b = idle()
            b[index] |= mask
            let r = try XCTUnwrap(InputReport(usbReport: b))
            XCTAssertEqual(r.buttons, button, "byte \(index) mask \(mask)")
        }
    }

    func testButtonDoesNotDisturbHat() throws {
        var b = idle()
        b[8] = 0x20 | 0x02
        let r = try XCTUnwrap(InputReport(usbReport: b))
        XCTAssertEqual(r.dpad, .east)
        XCTAssertEqual(r.buttons, .cross)
    }

    func testTouchPoint() throws {
        var b = idle()
        // x = 0x4B5 = 1205, y = 0x2A3 = 675 -> y low nibble 3, high byte 0x2A
        b[33] = 0x05  // touching, id 5
        b[34] = 0xB5
        b[35] = 0x04 | (0x3 << 4)
        b[36] = 0x2A
        let r = try XCTUnwrap(InputReport(usbReport: b))
        XCTAssertTrue(r.touch[0].isTouching)
        XCTAssertEqual(r.touch[0].id, 5)
        XCTAssertEqual(r.touch[0].x, 0x4B5)
        XCTAssertEqual(r.touch[0].y, 0x2A3)
        XCTAssertFalse(r.touch[1].isTouching)
    }

    func testSecondTouchPoint() throws {
        var b = idle()
        b[37] = 0x41; b[38] = 0xFF; b[39] = 0x0F; b[40] = 0
        let r = try XCTUnwrap(InputReport(usbReport: b))
        XCTAssertTrue(r.touch[1].isTouching)
        XCTAssertEqual(r.touch[1].id, 0x41)
        XCTAssertEqual(r.touch[1].x, 0xFFF)
    }

    func testBattery() throws {
        var b = idle()
        b[53] = 0x15
        var r = try XCTUnwrap(InputReport(usbReport: b))
        XCTAssertEqual(r.battery.state, .charging)
        XCTAssertEqual(r.battery.level, 55)
        b[53] = 0x0A
        r = try XCTUnwrap(InputReport(usbReport: b))
        XCTAssertEqual(r.battery.state, .discharging)
        XCTAssertEqual(r.battery.level, 100)
        b[53] = 0x2A
        XCTAssertEqual(try XCTUnwrap(InputReport(usbReport: b)).battery, BatteryStatus(statusByte: 0x2A))
        XCTAssertEqual(BatteryStatus(statusByte: 0x20).level, 100)
        XCTAssertEqual(BatteryStatus(statusByte: 0x20).state, .full)
        XCTAssertEqual(BatteryStatus(statusByte: 0xA3).state, .error)
        XCTAssertEqual(BatteryStatus(statusByte: 0xF0).state, .unknown)
    }

    func testMotionAndSequence() throws {
        var b = idle()
        b[7] = 42
        b[16] = 0xFF; b[17] = 0xFF   // gyro x = -1
        b[22] = 0x34; b[23] = 0x12   // accel x = 0x1234
        let r = try XCTUnwrap(InputReport(usbReport: b))
        XCTAssertEqual(r.sequence, 42)
        XCTAssertEqual(r.gyro.x, -1)
        XCTAssertEqual(r.accel.x, 0x1234)
    }
}
