import XCTest
@testable import DualSenseCore

final class DualSenseCoreTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(DualSenseCore.version.isEmpty)
    }
}
