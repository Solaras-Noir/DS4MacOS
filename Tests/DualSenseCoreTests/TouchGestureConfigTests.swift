import XCTest
@testable import DualSenseCore

final class TouchGestureConfigTests: XCTestCase {
    func testDefaults() {
        let c = TouchGestureConfig()
        XCTAssertEqual(c.tapMaxDuration, 0.180, accuracy: 1e-9)
        XCTAssertEqual(c.tapMaxMovement, 40)
        XCTAssertEqual(c.holdMinDuration, 0.400, accuracy: 1e-9)
        XCTAssertEqual(c.swipeMinDistance, 300)
        XCTAssertEqual(c.swipeMaxDuration, 0.500, accuracy: 1e-9)
        XCTAssertEqual(c.twoFingerTapWindow, 0.050, accuracy: 1e-9)
    }
}
