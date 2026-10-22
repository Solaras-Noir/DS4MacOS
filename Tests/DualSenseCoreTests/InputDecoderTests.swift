import XCTest
@testable import DualSenseCore

final class InputDecoderTests: XCTestCase {
    static func fixture(_ name: String) throws -> [[UInt8]] {
        let dir = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
        return text.split(whereSeparator: \.isNewline).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { return nil }
            return FixtureTests.parseHexLine(line)
        }
    }

    static func usbReport(seq: UInt8) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: 64)
        b[0] = 0x01
        b[1] = 128; b[2] = 128; b[3] = 128; b[4] = 128
        b[8] = 0x08
        b[7] = seq
        return b
    }

    func testAllFixturesDecode() throws {
        let dir = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        var count = 0
        for f in files where f.pathExtension == "hex" {
            var d = InputDecoder()
            for (i, buf) in try InputDecoderTests.fixture(f.lastPathComponent).enumerated() {
                if case .failure(let e) = d.decode(buf) { XCTFail("\(f.lastPathComponent):\(i) \(e)") }
                count += 1
            }
        }
        XCTAssertGreaterThan(count, 0)
    }

    func testCrossSameOnUSBAndBluetooth() throws {
        var d = InputDecoder()
        let usb = try XCTUnwrap(InputDecoderTests.fixture("usb-cross.hex").last)
        let bt = try XCTUnwrap(InputDecoderTests.fixture("bt-cross.hex").last)
        let u = try d.decode(usb).get()
        let b = try d.decode(bt).get()
        XCTAssertTrue(u.buttons.contains(.cross))
        XCTAssertEqual(u.buttons, b.buttons)
        XCTAssertEqual(u.transport, .usb)
        XCTAssertEqual(b.transport, .bluetooth)
        XCTAssertFalse(b.isSimple)
    }

    func testErrors() throws {
        var d = InputDecoder()
        XCTAssertEqual(d.decode([]), .failure(.empty))
        XCTAssertEqual(d.decode([0x77, 0, 0]), .failure(.unknownReportID(0x77)))
        XCTAssertEqual(d.decode([0x01, 0, 0, 0]), .failure(.badLength(4)))
        XCTAssertEqual(d.decode([0x31, 0, 0]), .failure(.badLength(3)))
        var bt = try XCTUnwrap(InputDecoderTests.fixture("bt-idle.hex").first)
        XCTAssertEqual(bt.count, 78)
        bt[10] ^= 0xFF
        XCTAssertEqual(d.decode(bt), .failure(.badCRC))
    }

    func testUSBSequenceGapsIncludingWrap() throws {
        var d = InputDecoder()
        for s: UInt8 in [10, 11, 13, 14] { _ = try d.decode(InputDecoderTests.usbReport(seq: s)).get() }
        XCTAssertEqual(d.droppedReports, 1)
        for s: UInt8 in [254, 255, 0, 1] { _ = try d.decode(InputDecoderTests.usbReport(seq: s)).get() }
        // 14 -> 254 is a jump of 240 (239 missing); then no further gaps across the wrap.
        XCTAssertEqual(d.droppedReports, 1 + 239)
        _ = try d.decode(InputDecoderTests.usbReport(seq: 4)).get()
        XCTAssertEqual(d.droppedReports, 1 + 239 + 2)
    }

    func testWrapWithoutGap() throws {
        var d = InputDecoder()
        for s: UInt8 in [254, 255, 0, 1] { _ = try d.decode(InputDecoderTests.usbReport(seq: s)).get() }
        XCTAssertEqual(d.droppedReports, 0)
    }

    func testBluetoothTagCounterNoGapsInFixture() throws {
        var d = InputDecoder()
        for buf in try InputDecoderTests.fixture("bt-idle.hex") { _ = try d.decode(buf).get() }
        XCTAssertEqual(d.droppedReports, 0)
    }

    func testBatteryCharging() throws {
        var d = InputDecoder()
        let s = try d.decode(try XCTUnwrap(InputDecoderTests.fixture("usb-charging.hex").last)).get()
        XCTAssertEqual(s.battery.state, .charging)
    }

    func testSimpleReport() throws {
        var d = InputDecoder()
        let b: [UInt8] = [0x01, 128, 128, 128, 128, 0x28, 0, 0, 255, 0]
        let s = try d.decode(b).get()
        XCTAssertTrue(s.isSimple)
        XCTAssertEqual(s.transport, .bluetooth)
        XCTAssertEqual(s.sensorTimestamp, 0)
        XCTAssertEqual(s.l2, 1, accuracy: 0.001)
        XCTAssertTrue(s.buttons.contains(.cross))
        XCTAssertEqual(d.droppedReports, 0)
    }

    func testTouchTwo() throws {
        var d = InputDecoder()
        let s = try d.decode(try XCTUnwrap(InputDecoderTests.fixture("usb-touch-two.hex").last)).get()
        XCTAssertEqual(s.touches.count, 2)
        XCTAssertTrue(s.touches[0].isTouching)
        XCTAssertTrue(s.touches[1].isTouching)
    }

    func testTimestampRead() throws {
        var d = InputDecoder()
        var b = InputDecoderTests.usbReport(seq: 0)
        b[28] = 0x78; b[29] = 0x56; b[30] = 0x34; b[31] = 0x12
        XCTAssertEqual(try d.decode(b).get().sensorTimestamp, 0x12345678)
        let bt = try XCTUnwrap(InputDecoderTests.fixture("bt-cross.hex").first)
        let t = try d.decode(bt).get().sensorTimestamp
        XCTAssertEqual(t, UInt32(bt[29]) | UInt32(bt[30]) << 8 | UInt32(bt[31]) << 16 | UInt32(bt[32]) << 24)
        XCTAssertNotEqual(t, 0)
    }
}
