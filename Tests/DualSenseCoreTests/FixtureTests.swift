import XCTest
@testable import DualSenseCore

final class FixtureTests: XCTestCase {
    /// Test-only parser: "<reportID> <b0> <b1> ..." -> buffer bytes without the first column.
    static func parseHexLine(_ line: String) -> [UInt8]? {
        let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard tokens.count >= 1 else { return nil }
        var out: [UInt8] = []
        for t in tokens.dropFirst() {
            guard let v = UInt8(t, radix: 16) else { return nil }
            out.append(v)
        }
        return out
    }

    func testHexLineParser() {
        XCTAssertEqual(FixtureTests.parseHexLine("01 01 ff 00"), [1, 255, 0])
        XCTAssertNil(FixtureTests.parseHexLine("01 zz"))
    }

    func testAllUSBFixturesParse() throws {
        let dir = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        for file in files where file.lastPathComponent.hasPrefix("usb-") && file.pathExtension == "hex" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (n, raw) in text.split(whereSeparator: \.isNewline).enumerated() {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.hasPrefix("#") { continue }
                let bytes = try XCTUnwrap(FixtureTests.parseHexLine(line), "\(file.lastPathComponent):\(n + 1) bad hex")
                XCTAssertNotNil(InputReport(usbReport: bytes), "\(file.lastPathComponent):\(n + 1) did not parse")
            }
        }
    }
}
