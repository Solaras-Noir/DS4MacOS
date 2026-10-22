import XCTest
@testable import DualSenseCore

/// Expected bytes are hand-derived from docs/protocol/dualsense-hid.md, section "Trigger effects" and
/// "Rumble" (zone mask LE in p1-p2, 3-bit strength-1 per zone LE in p3-p6, frequency in p9).
final class OutputReportExtendedTests: XCTestCase {
    private func params(_ e: TriggerEffect?) -> [UInt8] { Array((e?.encoded ?? []).dropFirst()) }

    func testFeedbackBytes() {
        // Zones 3...9 active: mask 0x3F8; each field is 4 (strength 5 - 1) at bit 3i.
        XCTAssertEqual(TriggerEffect.feedback(position: 3, strength: 5)?.encoded,
                       [0x21, 0xF8, 0x03, 0x00, 0x48, 0x92, 0x24, 0, 0, 0, 0])
    }

    func testFeedbackOffAndInvalid() {
        XCTAssertEqual(TriggerEffect.feedback(position: 3, strength: 0), .off)
        XCTAssertNil(TriggerEffect.feedback(position: 10, strength: 1))
        XCTAssertNil(TriggerEffect.feedback(position: -1, strength: 1))
        XCTAssertNil(TriggerEffect.feedback(position: 0, strength: 9))
    }

    func testWeaponBytes() {
        // mask (1<<2)|(1<<5) = 0x24, p3 = strength-1 = 3.
        XCTAssertEqual(TriggerEffect.weapon(start: 2, end: 5, strength: 4)?.encoded,
                       [0x25, 0x24, 0x00, 0x03, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertNil(TriggerEffect.weapon(start: 1, end: 5, strength: 4))
        XCTAssertNil(TriggerEffect.weapon(start: 8, end: 9, strength: 4))
        XCTAssertNil(TriggerEffect.weapon(start: 4, end: 4, strength: 4))
        XCTAssertNil(TriggerEffect.weapon(start: 4, end: 9, strength: 4))
        XCTAssertEqual(TriggerEffect.weapon(start: 4, end: 6, strength: 0), .off)
    }

    func testVibrationBytes() {
        // Zones 8,9: mask 0x300; (3-1)=2 at bits 24 and 27 = 0x12 in p6; frequency 40 in p9.
        XCTAssertEqual(TriggerEffect.vibration(position: 8, amplitude: 3, frequency: 40)?.encoded,
                       [0x26, 0x00, 0x03, 0x00, 0x00, 0x00, 0x12, 0, 0, 40, 0])
        XCTAssertNil(TriggerEffect.vibration(position: 0, amplitude: 9, frequency: 40))
        XCTAssertNil(TriggerEffect.vibration(position: 0, amplitude: 1, frequency: 256))
        XCTAssertEqual(TriggerEffect.vibration(position: 0, amplitude: 0, frequency: 40), .off)
    }

    func testMultiplePositionFeedbackBytes() {
        // Zones 0 (strength 1 -> 0) and 9 (strength 8 -> 7 at bit 27 = 0x38 in p6); mask 0x201.
        let s = [1, 0, 0, 0, 0, 0, 0, 0, 0, 8]
        XCTAssertEqual(TriggerEffect.multiplePositionFeedback(strengths: s)?.encoded,
                       [0x21, 0x01, 0x02, 0, 0, 0, 0x38, 0, 0, 0, 0])
        XCTAssertNil(TriggerEffect.multiplePositionFeedback(strengths: [1, 2, 3]))
        XCTAssertNil(TriggerEffect.multiplePositionFeedback(strengths: [Int](repeating: 9, count: 10)))
        XCTAssertEqual(TriggerEffect.multiplePositionFeedback(strengths: [Int](repeating: 0, count: 10)), .off)
    }

    func testSlopeFeedbackBytes() {
        // start 1, end 4, strengths 2 -> 8, slope 2: zones 1..3 = 2,4,6, zones 4...9 = 8; fields (s-1) =
        // 1,3,5,7,7,7,7,7,7 at bits 3,6,9,12,...,27; mask 0x3FE.
        XCTAssertEqual(TriggerEffect.slopeFeedback(startPosition: 1, endPosition: 4,
                                                   startStrength: 2, endStrength: 8)?.encoded,
                       [0x21, 0xFE, 0x03, 0xC8, 0xFA, 0xFF, 0x3F, 0, 0, 0, 0])
        XCTAssertNil(TriggerEffect.slopeFeedback(startPosition: 4, endPosition: 4, startStrength: 1, endStrength: 1))
        XCTAssertNil(TriggerEffect.slopeFeedback(startPosition: 0, endPosition: 10, startStrength: 1, endStrength: 1))
        XCTAssertNil(TriggerEffect.slopeFeedback(startPosition: 0, endPosition: 5, startStrength: 0, endStrength: 1))
    }

    func testMultiplePositionVibrationBytes() {
        // Zones 2 (amp 2 -> 1 at bit 6 = 0x40) and 8 (amp 1 -> 0); mask 0x104; frequency 10 in p9.
        let a = [0, 0, 2, 0, 0, 0, 0, 0, 1, 0]
        XCTAssertEqual(TriggerEffect.multiplePositionVibration(frequency: 10, amplitudes: a)?.encoded,
                       [0x26, 0x04, 0x01, 0x40, 0, 0, 0, 0, 0, 10, 0])
        XCTAssertNil(TriggerEffect.multiplePositionVibration(frequency: 0, amplitudes: a))
        XCTAssertNil(TriggerEffect.multiplePositionVibration(frequency: 10, amplitudes: [1]))
        XCTAssertEqual(params(.off).count, 10)
    }

    func testRumbleV2IsDefault() {
        XCTAssertEqual(OutputReport().vibrationMode, .v2)
    }

    func testRumbleV1Flags() {
        var r = OutputReport()
        r.vibrationMode = .v1
        r.rumble(strong: 9, weak: 8)
        let c = r.commonBlock()
        XCTAssertEqual(c[0], 0x03)
        XCTAssertEqual(c[38] & 0x04, 0)
        XCTAssertEqual(c[2], 8)
        XCTAssertEqual(c[3], 9)
    }

    func testRumbleV2Flags() {
        var r = OutputReport()
        r.rumble(strong: 9, weak: 8)
        let c = r.commonBlock()
        XCTAssertEqual(c[0], 0x02)
        XCTAssertNotEqual(c[38] & 0x04, 0)
        XCTAssertEqual(c[0] & 0x01, 0)
    }

    func testNoRumbleLeavesFlagsClear() {
        let c = OutputReport().commonBlock()
        XCTAssertEqual(c[0], 0)
        XCTAssertEqual(c[38], 0)
    }

    func testNeverBothVibrationBits() {
        let effects: [TriggerEffect?] = [nil, .off, TriggerEffect.feedback(position: 1, strength: 2)]
        for mode in [VibrationMode.v1, .v2] {
            for rumble in [false, true] {
                for fade in [false, true] {
                    for eff in effects {
                        var r = OutputReport()
                        r.vibrationMode = mode
                        r.lightbarFadeOut = fade
                        r.rightTrigger = eff
                        r.leftTrigger = eff
                        r.micLED = eff == nil ? nil : .on
                        r.lightbar = fade ? RGB(red: 1, green: 2, blue: 3) : nil
                        if rumble { r.rumble(strong: 1, weak: 1) }
                        let c = r.commonBlock()
                        XCTAssertFalse(c[0] & 0x01 != 0 && c[38] & 0x04 != 0)
                        if eff != nil { XCTAssertEqual(c[0] & 0x0C, 0x0C) }
                    }
                }
            }
        }
    }

    func testRumbleAndTriggerFlagsOr() {
        var r = OutputReport()
        r.vibrationMode = .v1
        r.rumble(strong: 1, weak: 1)
        r.rightTrigger = .off
        XCTAssertEqual(r.commonBlock()[0], 0x07)
        r.leftTrigger = .off
        XCTAssertEqual(r.commonBlock()[0], 0x0F)
    }

    func testLightbarFadeOut() {
        var r = OutputReport()
        r.lightbarFadeOut = true
        let b = r.usbBytes()
        XCTAssertEqual(b[39], 0x02)
        XCTAssertEqual(b[42], 0x02)
        XCTAssertEqual(OutputReport.lightbarSetup().usbBytes(), b)
    }

    func testPlayerLEDMasks() {
        XCTAssertEqual([1, 2, 3, 4, 5].compactMap { PlayerLEDs.mask(player: $0) }, [0x04, 0x0A, 0x15, 0x1B, 0x1F])
        XCTAssertEqual(PlayerLEDs.mask(player: 0), 0)
        XCTAssertNil(PlayerLEDs.mask(player: 6))
    }

    func testMicLEDValues() {
        for (m, v) in [(MicLED.off, UInt8(0)), (.on, 1), (.pulse, 2)] {
            var r = OutputReport()
            r.micLED = m
            XCTAssertEqual(r.usbBytes()[9], v)
        }
    }

    func testBluetoothCommonMatchesUSB() {
        var r = OutputReport()
        r.rumble(strong: 7, weak: 6)
        r.lightbar = RGB(red: 1, green: 2, blue: 3)
        r.playerLEDs = PlayerLEDs.player3
        r.micLED = .on
        r.rightTrigger = TriggerEffect.weapon(start: 2, end: 5, strength: 4)
        r.leftTrigger = TriggerEffect.feedback(position: 3, strength: 5)
        let usb = r.usbBytes(), bt = r.bluetoothBytes(sequence: 5)
        XCTAssertEqual(bt.count, 78)
        XCTAssertEqual(bt[0], 0x31)
        XCTAssertEqual(bt[1], 0x50)
        XCTAssertEqual(bt[2], 0x10)
        XCTAssertEqual(Array(bt[3..<50]), Array(usb[1..<48]))
        XCTAssertEqual(Array(bt[50..<74]), [UInt8](repeating: 0, count: 24))
        XCTAssertEqual(Array(bt[13..<24]), r.rightTrigger?.encoded)
    }

    func testBluetoothCRCValid() {
        var r = OutputReport()
        r.lightbar = RGB(red: 10, green: 20, blue: 30)
        let bt = r.bluetoothBytes(sequence: 0x1F)
        XCTAssertEqual(bt[1] >> 4, 0x0F)
        let stored = UInt32(bt[74]) | UInt32(bt[75]) << 8 | UInt32(bt[76]) << 16 | UInt32(bt[77]) << 24
        XCTAssertEqual(CRC32.checksum(seed: BluetoothFraming.outputSeed, bt[0..<74]), stored)
    }
}
