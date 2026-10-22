import XCTest
@testable import DualSenseCore

final class FirmwareInfoTests: XCTestCase {
    private func report(version: UInt16, count: Int = 64) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: count)
        b[0] = 0x20
        if count > 45 {
            b[44] = UInt8(version & 0xFF)
            b[45] = UInt8(version >> 8)
        }
        return b
    }

    func testDecodesLittleEndian() {
        XCTAssertEqual(FirmwareInfo.updateVersion(featureReport: report(version: 0x0224)), 0x0224)
        XCTAssertEqual(FirmwareInfo.updateVersion(featureReport: report(version: 0x0102)), 0x0102)
    }

    func testShortBufferIsNil() {
        XCTAssertNil(FirmwareInfo.updateVersion(featureReport: []))
        XCTAssertNil(FirmwareInfo.updateVersion(featureReport: [UInt8](repeating: 0, count: 45)))
        XCTAssertNotNil(FirmwareInfo.updateVersion(featureReport: [UInt8](repeating: 0, count: 46)))
    }

    func testCutoff() {
        XCTAssertEqual(VibrationMode.forUpdateVersion(0x0214), .v1)
        XCTAssertEqual(VibrationMode.forUpdateVersion(0x0215), .v2)
        XCTAssertEqual(VibrationMode.forUpdateVersion(0x0000), .v1)
        XCTAssertEqual(VibrationMode.forUpdateVersion(0xFFFF), .v2)
    }
}
