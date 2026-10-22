import XCTest
@testable import DualSenseCore

final class BluetoothFramingTests: XCTestCase {
    static func fixtureLines(_ name: String) throws -> [[UInt8]] {
        let dir = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
        var out: [[UInt8]] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            out.append(try XCTUnwrap(FixtureTests.parseHexLine(line)))
        }
        return out
    }

    func testStandardCRCVector() {
        XCTAssertEqual(CRC32.checksum(Array("123456789".utf8)), 0xCBF4_3926)
        XCTAssertEqual(CRC32.checksum([UInt8]()), 0)
    }

    func testSeededCRCMatchesIndependentValues() {
        // Computed with python3 zlib.crc32(bytes([seed]) + data).
        XCTAssertEqual(CRC32.checksum(seed: 0xA2, Array("123456789".utf8)), 0x63DA_9F12)
        XCTAssertEqual(CRC32.checksum(seed: 0xA1, Array(0..<10)), 0xFD92_6B54)
    }

    func testBluetoothFixturesVerifyAndDecode() throws {
        for name in ["bt-idle.hex", "bt-cross.hex"] {
            let lines = try BluetoothFramingTests.fixtureLines(name)
            XCTAssertFalse(lines.isEmpty)
            for (n, bytes) in lines.enumerated() {
                XCTAssertEqual(bytes.count, 78, "\(name):\(n)")
                XCTAssertTrue(BluetoothFraming.verify(inputReport: bytes), "\(name):\(n)")
                let r = try XCTUnwrap(InputReport(bluetoothReport: bytes), "\(name):\(n)")
                XCTAssertFalse(r.isSimple)
            }
        }
    }

    func testBTCrossHeldAndIdleEmpty() throws {
        for bytes in try BluetoothFramingTests.fixtureLines("bt-cross.hex") {
            let r = try XCTUnwrap(InputReport(bluetoothReport: bytes))
            XCTAssertTrue(r.buttons.contains(.cross))
        }
        for bytes in try BluetoothFramingTests.fixtureLines("bt-idle.hex") {
            let r = try XCTUnwrap(InputReport(bluetoothReport: bytes))
            XCTAssertTrue(r.buttons.isEmpty)
            XCTAssertEqual(r.dpad, .none)
        }
    }

    func testFlippedBytesRejected() throws {
        let good = try XCTUnwrap(BluetoothFramingTests.fixtureLines("bt-cross.hex").first)
        XCTAssertNotNil(InputReport(bluetoothReport: good))
        for pos in [2, 9, 30, 54, 73, 74, 77] {
            var bad = good
            bad[pos] ^= 0x01
            XCTAssertFalse(BluetoothFraming.verify(inputReport: bad), "pos \(pos)")
            XCTAssertNil(InputReport(bluetoothReport: bad), "pos \(pos)")
        }
    }

    func testFrameLayoutAndRoundTrip() {
        let common = (0..<47).map { UInt8($0 + 1) }
        let f = BluetoothFraming.frame(outputCommon: common, sequence: 5)
        XCTAssertEqual(f.count, 78)
        XCTAssertEqual(f[0], 0x31)
        XCTAssertEqual(f[1], 0x50)
        XCTAssertEqual(f[2], 0x10)
        XCTAssertEqual(Array(f[3..<50]), common)
        XCTAssertTrue(f[50..<74].allSatisfy { $0 == 0 })
        let stored = UInt32(f[74]) | UInt32(f[75]) << 8 | UInt32(f[76]) << 16 | UInt32(f[77]) << 24
        XCTAssertEqual(CRC32.checksum(seed: 0xA2, f[0..<74]), stored)
    }

    func testFrameSequenceWrapsAtSixteen() {
        let a = BluetoothFraming.frame(outputCommon: [], sequence: 3)
        let b = BluetoothFraming.frame(outputCommon: [], sequence: 19)
        XCTAssertEqual(a, b)
        XCTAssertEqual(BluetoothFraming.frame(outputCommon: [], sequence: 16)[1], 0)
        XCTAssertEqual(BluetoothFraming.frame(outputCommon: [], sequence: 15)[1], 0xF0)
    }

    func testFrameTruncatesLongCommon() {
        let f = BluetoothFraming.frame(outputCommon: [UInt8](repeating: 0xFF, count: 60), sequence: 0)
        XCTAssertEqual(f.count, 78)
        XCTAssertEqual(f[49], 0xFF)
        XCTAssertEqual(f[50], 0)
    }

    func testSimpleReportDecode() throws {
        // ID, LX, LY, RX, RY, hat+face, shoulder/stick buttons, PS+touchpad, L2, R2
        let b: [UInt8] = [0x01, 0x00, 0xFF, 0x80, 0x40, 0x22, 0x01, 0x03, 0xFF, 0x80]
        let r = try XCTUnwrap(InputReport(bluetoothReport: b))
        XCTAssertTrue(r.isSimple)
        XCTAssertEqual(r.leftStick.rawX, 0)
        XCTAssertEqual(r.leftStick.rawY, 255)
        XCTAssertEqual(r.rightStick.rawX, 0x80)
        XCTAssertEqual(r.rightStick.rawY, 0x40)
        XCTAssertEqual(r.dpad, Dpad(hat: 2))
        XCTAssertEqual(r.buttons, [.cross, .l1, .ps, .touchpad])
        XCTAssertEqual(r.l2Raw, 255)
        XCTAssertEqual(r.r2Raw, 0x80)
        XCTAssertEqual(r.gyro, SIMD3<Int16>(0, 0, 0))
        XCTAssertFalse(r.touch[0].isTouching)
    }

    func testWrongIDsAndLengthsReturnNil() throws {
        XCTAssertNil(InputReport(bluetoothReport: []))
        XCTAssertNil(InputReport(bluetoothReport: [UInt8](repeating: 0, count: 9)))
        XCTAssertNil(InputReport(bluetoothReport: [UInt8](repeating: 0, count: 11)))
        XCTAssertNil(InputReport(bluetoothReport: [UInt8](repeating: 0, count: 77)))
        XCTAssertNil(InputReport(bluetoothReport: [0x02] + [UInt8](repeating: 0, count: 9)))
        var good = try XCTUnwrap(BluetoothFramingTests.fixtureLines("bt-idle.hex").first)
        good[0] = 0x01
        XCTAssertNil(InputReport(bluetoothReport: good))
        XCTAssertFalse(BluetoothFraming.verify(inputReport: good))
        XCTAssertFalse(BluetoothFraming.verify(inputReport: []))
    }

    func testUSBAndBTCrossAgree() throws {
        let usb = try XCTUnwrap(BluetoothFramingTests.fixtureLines("usb-cross.hex").first)
        let bt = try XCTUnwrap(BluetoothFramingTests.fixtureLines("bt-cross.hex").first)
        let u = try XCTUnwrap(InputReport(usbReport: usb))
        let b = try XCTUnwrap(InputReport(bluetoothReport: bt))
        XCTAssertEqual(u.buttons, b.buttons)
        XCTAssertTrue(u.buttons.contains(.cross))
        XCTAssertEqual(u.l2Raw, b.l2Raw)
        XCTAssertEqual(u.r2Raw, b.r2Raw)
        XCTAssertEqual(u.dpad, b.dpad)
        XCTAssertLessThan(abs(u.leftStick.x - b.leftStick.x), 0.1)
        XCTAssertLessThan(abs(u.rightStick.y - b.rightStick.y), 0.1)
    }
}
