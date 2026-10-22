import XCTest
@testable import DualSenseCore

final class TouchGestureEngineTests: XCTestCase {
    /// Report intervals: 250 Hz (USB) and 65 Hz (Bluetooth-ish).
    private let rates: [TimeInterval] = [0.004, 1.0 / 65.0]

    private func pt(_ id: UInt8, _ x: Int, _ y: Int) -> TouchPoint { GestureSim.pt(id, x, y) }
    private func nonDrag(_ e: [GestureEvent]) -> [GestureEvent] {
        e.filter { if case .drag = $0 { return false }; return true }
    }
    private func forRates(_ config: TouchGestureConfig = TouchGestureConfig(),
                          _ body: (inout GestureSim, TimeInterval) -> Void) {
        for dt in rates {
            var s = GestureSim(config: config, dt: dt)
            body(&s, dt)
        }
    }

    func testTap() {
        forRates { s, dt in
            s.still([pt(1, 500, 500)], for: 0.100)
            s.release()
            XCTAssertEqual(s.events, [.tap(0)], "dt \(dt)")
        }
    }

    func testTooLongIsNotTap() {
        forRates { s, dt in
            s.still([pt(1, 500, 500)], for: 0.300)
            s.release()
            XCTAssertEqual(s.events, [], "dt \(dt)")
        }
    }

    func testTooMuchMovementIsNotTap() {
        forRates { s, dt in
            s.move(id: 1, from: (500, 500), to: (560, 500), over: 0.100)
            s.release()
            XCTAssertEqual(nonDrag(s.events), [], "dt \(dt)")
        }
    }

    func testTapNearBorderUsesStartZone() {
        forRates(TouchGestureConfig(zones: .columns2)) { s, dt in
            s.frame([pt(1, 950, 500)])
            s.move(id: 1, from: (950, 500), to: (975, 500), over: 0.060)
            s.release()
            XCTAssertEqual(nonDrag(s.events), [.tap(0)], "dt \(dt)")
        }
    }

    func testSlowMoveIsNotSwipe() {
        forRates { s, dt in
            s.frame([pt(1, 400, 500)])
            s.move(id: 1, from: (400, 500), to: (800, 500), over: 1.2)
            s.release()
            XCTAssertEqual(nonDrag(s.events), [], "dt \(dt)")
        }
    }

    func testSwipeInAllDirections() {
        let cases: [((Int, Int), SwipeDirection)] = [
            ((1200, 500), .right), ((200, 500), .left), ((700, 1000), .down), ((700, 50), .up)
        ]
        for (end, dir) in cases {
            forRates { s, dt in
                s.frame([pt(1, 700, 500)])
                s.move(id: 1, from: (700, 500), to: end, over: 0.200)
                s.release()
                XCTAssertEqual(nonDrag(s.events), [.swipe(dir, 0)], "\(dir) dt \(dt)")
            }
        }
    }

    func testSwipeAcrossZonesReportsStartZone() {
        forRates(TouchGestureConfig(zones: .columns2)) { s, dt in
            s.frame([pt(1, 600, 500)])
            s.move(id: 1, from: (600, 500), to: (1500, 500), over: 0.250)
            s.release()
            XCTAssertEqual(nonDrag(s.events), [.swipe(.right, 0)], "dt \(dt)")
        }
    }

    func testHoldBeginsAtThresholdAndEnds() {
        forRates { s, dt in
            let p = [pt(1, 300, 300)]
            var beganAt: TimeInterval?
            let start = s.time
            for _ in 0..<Int(0.6 / dt) {
                let t = s.time
                if s.frame(p).contains(.holdBegan(0)), beganAt == nil { beganAt = t }
            }
            XCTAssertNotNil(beganAt)
            XCTAssertEqual(beganAt ?? 0, start + 0.400, accuracy: dt + 0.0001)
            XCTAssertEqual(s.events.filter { $0 == .holdBegan(0) }.count, 1)
            s.release()
            XCTAssertEqual(s.events.last, .holdEnded(0))
            XCTAssertFalse(s.events.contains(.tap(0)))
        }
    }

    func testHoldThenSwipeMotionOnlyEndsHold() {
        forRates { s, dt in
            s.still([pt(1, 300, 300)], for: 0.450)
            s.move(id: 1, from: (300, 300), to: (900, 300), over: 0.100)
            s.release()
            XCTAssertEqual(nonDrag(s.events), [.holdBegan(0), .holdEnded(0)], "dt \(dt)")
            XCTAssertFalse(s.events.contains { if case .drag = $0 { return true }; return false })
        }
    }

    func testHoldSuppressedWhenMovedBeforeThreshold() {
        forRates { s, dt in
            s.frame([pt(1, 300, 300)])
            s.move(id: 1, from: (300, 300), to: (350, 300), over: 0.100)
            s.still([pt(1, 350, 300)], for: 0.500)
            s.release()
            XCTAssertEqual(nonDrag(s.events), [], "dt \(dt)")
        }
    }

    func testTwoFingerTap() {
        forRates { s, dt in
            s.frame([pt(1, 600, 500)])
            let both = [pt(1, 600, 500), pt(2, 900, 500)]
            s.still(both, for: 0.060)
            s.release()
            XCTAssertEqual(s.events, [.twoFingerTap], "dt \(dt)")
        }
    }

    func testTwoFingerTapWithLiftsInSeparateFrames() {
        forRates { s, dt in
            s.frame([pt(1, 600, 500)])
            let both = [pt(1, 600, 500), pt(2, 900, 500)]
            s.still(both, for: 0.060)
            s.frame([pt(1, 600, 500)])
            s.frame([pt(1, 600, 500)])
            s.release()
            XCTAssertEqual(s.events, [.twoFingerTap], "dt \(dt)")
        }
    }

    func testTwoFingerTapRejectedWhenLiftsTooLate() {
        forRates { s, dt in
            s.frame([pt(1, 600, 500)])
            let both = [pt(1, 600, 500), pt(2, 900, 500)]
            s.still(both, for: 0.250)
            s.release()
            XCTAssertEqual(s.events, [], "dt \(dt)")
        }
    }

    func testTwoFingersFarApartAreNotTwoFingerTap() {
        forRates { s, dt in
            s.frame([pt(1, 600, 500)])
            s.still([pt(1, 600, 500)], for: 0.080)
            s.still([pt(1, 600, 500), pt(2, 900, 500)], for: 0.040)
            s.release()
            XCTAssertFalse(s.events.contains(.twoFingerTap), "dt \(dt)")
        }
    }

    func testDragDeltas() {
        forRates { s, dt in
            s.frame([pt(1, 500, 500)])
            XCTAssertEqual(s.frame([pt(1, 503, 498)]), [.drag(dx: 3, dy: -2)])
            XCTAssertEqual(s.frame([pt(1, 503, 498)]), [])
            XCTAssertEqual(s.frame([pt(1, 510, 505)]), [.drag(dx: 7, dy: 7)])
        }
    }

    func testNoDragWithTwoFingers() {
        forRates { s, dt in
            s.frame([pt(1, 500, 500)])
            s.frame([pt(1, 500, 500), pt(2, 900, 500)])
            XCTAssertEqual(s.frame([pt(1, 520, 500), pt(2, 920, 500)]), [])
        }
    }

    func testPadClickRisingEdgeAndZone() {
        forRates(TouchGestureConfig(zones: .grid2x2)) { s, dt in
            XCTAssertEqual(s.frame([], click: true), [.padClick(0)])
            XCTAssertEqual(s.frame([], click: true), [])
            s.frame([], click: false)
            XCTAssertEqual(s.frame([pt(1, 1500, 900)], click: true), [.padClick(3)])
        }
    }

    func testZoneLayouts() {
        XCTAssertEqual(TouchZoneLayout.single.zone(x: 1900, y: 1000), 0)
        XCTAssertEqual(TouchZoneLayout.columns2.zone(x: 100, y: 900), 0)
        XCTAssertEqual(TouchZoneLayout.columns2.zone(x: 1000, y: 100), 1)
        XCTAssertEqual(TouchZoneLayout.rows2.zone(x: 1900, y: 100), 0)
        XCTAssertEqual(TouchZoneLayout.rows2.zone(x: 100, y: 900), 1)
        XCTAssertEqual(TouchZoneLayout.grid2x2.zone(x: 100, y: 100), 0)
        XCTAssertEqual(TouchZoneLayout.grid2x2.zone(x: 1900, y: 100), 1)
        XCTAssertEqual(TouchZoneLayout.grid2x2.zone(x: 100, y: 1000), 2)
        XCTAssertEqual(TouchZoneLayout.grid2x2.zone(x: 1900, y: 1000), 3)
        let custom = TouchZoneLayout.custom([
            TouchRect(x: 0, y: 0, width: 400, height: 400),
            TouchRect(x: 1500, y: 600, width: 420, height: 480)
        ])
        XCTAssertEqual(custom.zone(x: 100, y: 100), 0)
        XCTAssertEqual(custom.zone(x: 1600, y: 700), 1)
        XCTAssertEqual(custom.zone(x: 900, y: 500), 0)
    }

    func testTwoSuccessiveTaps() {
        forRates(TouchGestureConfig(zones: .columns2)) { s, dt in
            s.still([pt(1, 300, 500)], for: 0.080)
            s.release(frames: 10)
            s.still([pt(2, 1500, 500)], for: 0.080)
            s.release()
            XCTAssertEqual(s.events, [.tap(0), .tap(1)], "dt \(dt)")
        }
    }

    func testReLandWithNewId() {
        forRates { s, dt in
            s.still([pt(1, 300, 500)], for: 0.080)
            s.frame([pt(2, 310, 500)])
            s.still([pt(2, 310, 500)], for: 0.080)
            s.release()
            XCTAssertEqual(s.events, [.tap(0), .tap(0)], "dt \(dt)")
        }
    }

    func testIgnoresNonTouchingSlots() {
        var s = GestureSim()
        let up = TouchPoint(isTouching: false, id: 5, x: 0, y: 0)
        s.frame([pt(1, 500, 500), up])
        XCTAssertEqual(s.frame([pt(1, 505, 500), up]), [.drag(dx: 5, dy: 0)])
    }

    // MARK: M0 fixtures

    private func fixtureTouches(_ name: String) throws -> [[TouchPoint]] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "hex"))
        let text = try String(contentsOf: url, encoding: .utf8)
        var frames: [[TouchPoint]] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let bytes = try XCTUnwrap(FixtureTests.parseHexLine(line))
            let report = try XCTUnwrap(InputReport(usbReport: bytes))
            frames.append(report.touch.filter { $0.isTouching })
        }
        return frames
    }

    func testFixtureTopLeftAndBottomRightZones() throws {
        let layout = TouchZoneLayout.grid2x2
        let tl = try fixtureTouches("usb-touch-topleft").flatMap { $0 }
        let br = try fixtureTouches("usb-touch-bottomright").flatMap { $0 }
        XCTAssertFalse(tl.isEmpty)
        XCTAssertFalse(br.isEmpty)
        XCTAssertTrue(tl.allSatisfy { layout.zone(x: $0.x, y: $0.y) == 0 })
        XCTAssertTrue(br.allSatisfy { layout.zone(x: $0.x, y: $0.y) == 3 })

        // Tap built from a real coordinate.
        var s = GestureSim(config: TouchGestureConfig(zones: layout))
        let p = br[0]
        s.still([pt(p.id, p.x, p.y)], for: 0.080)
        s.release()
        XCTAssertEqual(s.events, [.tap(3)])
    }

    func testFixtureTwoFingersFeedEngine() throws {
        let frames = try fixtureTouches("usb-touch-two")
        let twoDown = try XCTUnwrap(frames.first { $0.count == 2 })
        var s = GestureSim()
        s.frame([twoDown[0]])
        s.frame(twoDown)
        s.still(twoDown, for: 0.040)
        s.release()
        XCTAssertEqual(s.events, [.twoFingerTap])
    }
}
