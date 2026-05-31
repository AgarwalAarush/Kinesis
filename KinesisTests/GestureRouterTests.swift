import XCTest
@testable import Kinesis

final class GestureRouterTests: XCTestCase {
    func testIgnoresIntentWhenTrackingDisabledAndReleasesMouse() {
        let bridge = FakeBridge()
        bridge.mouseDown = true
        let decision = GestureRouter().route(
            intent: .sample(gesture: .indexMove),
            settings: .defaults,
            trackingEnabled: false,
            emergencyPaused: false,
            output: bridge
        )

        XCTAssertEqual(decision.action, .released)
        XCTAssertEqual(bridge.releaseCount, 1)
        XCTAssertEqual(bridge.applyCount, 0)
    }

    func testEmergencyPauseSuppressesOutput() {
        let bridge = FakeBridge()
        let decision = GestureRouter().route(
            intent: .sample(gesture: .indexMove),
            settings: .defaults,
            trackingEnabled: true,
            emergencyPaused: true,
            output: bridge
        )

        XCTAssertEqual(decision.action, .released)
        XCTAssertEqual(bridge.releaseCount, 1)
        XCTAssertEqual(bridge.applyCount, 0)
    }

    func testLowConfidenceReleasesInsteadOfApplying() {
        let bridge = FakeBridge()
        let intent = GestureIntent.sample(gesture: .indexMove, confidence: 0.1)

        let decision = GestureRouter().route(
            intent: intent,
            settings: .defaults,
            trackingEnabled: true,
            emergencyPaused: false,
            output: bridge
        )

        XCTAssertEqual(decision.action, .released)
        XCTAssertEqual(bridge.releaseCount, 1)
        XCTAssertEqual(bridge.applyCount, 0)
    }

    func testClutchGestureReleasesDrag() {
        let bridge = FakeBridge()
        bridge.mouseDown = true

        let decision = GestureRouter().route(
            intent: .sample(tracking: .active, gesture: .fistPause),
            settings: .defaults,
            trackingEnabled: true,
            emergencyPaused: false,
            output: bridge
        )

        XCTAssertEqual(decision.action, .released)
        XCTAssertEqual(bridge.releaseCount, 1)
        XCTAssertFalse(bridge.isMouseDown)
    }

    func testAppliesEnabledCursorGesture() {
        let bridge = FakeBridge()
        var settings = ControlSettings.defaults
        settings.dryRunEnabled = false
        let decision = GestureRouter().route(
            intent: .sample(gesture: .indexMove),
            settings: settings,
            trackingEnabled: true,
            emergencyPaused: false,
            output: bridge
        )

        XCTAssertEqual(decision.action, .applied)
        XCTAssertEqual(bridge.applyCount, 1)
        XCTAssertEqual(bridge.releaseCount, 0)
    }

    func testDisabledCursorGestureIsIgnored() {
        let bridge = FakeBridge()
        var settings = ControlSettings.defaults
        settings.cursorEnabled = false

        let decision = GestureRouter().route(
            intent: .sample(gesture: .indexMove),
            settings: settings,
            trackingEnabled: true,
            emergencyPaused: false,
            output: bridge
        )

        XCTAssertEqual(decision.action, .ignored)
        XCTAssertEqual(bridge.applyCount, 0)
    }

    func testDisabledClickDragReleasesHeldMouse() {
        let bridge = FakeBridge()
        bridge.mouseDown = true
        var settings = ControlSettings.defaults
        settings.clickDragEnabled = false

        let decision = GestureRouter().route(
            intent: .sample(gesture: .pinchHold, click: .down),
            settings: settings,
            trackingEnabled: true,
            emergencyPaused: false,
            output: bridge
        )

        XCTAssertEqual(decision.action, .released)
        XCTAssertEqual(bridge.releaseCount, 1)
        XCTAssertFalse(bridge.isMouseDown)
    }

    func testPinchHoldRoutesAsMovementGesture() {
        let bridge = FakeBridge()
        var settings = ControlSettings.defaults
        settings.dryRunEnabled = false

        let decision = GestureRouter().route(
            intent: .sample(gesture: .pinchHold, click: .none),
            settings: settings,
            trackingEnabled: true,
            emergencyPaused: false,
            output: bridge
        )

        XCTAssertEqual(decision.action, .applied)
        XCTAssertEqual(bridge.applyCount, 1)
    }

    func testDryRunRecognizesWithoutApplyingOutput() {
        let bridge = FakeBridge()
        var settings = ControlSettings.defaults
        settings.dryRunEnabled = true

        let decision = GestureRouter().route(
            intent: .sample(gesture: .indexMove),
            settings: settings,
            trackingEnabled: true,
            emergencyPaused: false,
            output: bridge
        )

        XCTAssertEqual(decision.action, .ignored)
        XCTAssertTrue(decision.reason.contains("Dry Run"))
        XCTAssertEqual(bridge.applyCount, 0)
        XCTAssertEqual(bridge.releaseCount, 0)
    }
}

private final class FakeBridge: MacControlProviding {
    var mouseDown = false
    var applyCount = 0
    var releaseCount = 0

    var isMouseDown: Bool {
        mouseDown
    }

    func apply(intent: GestureIntent, settings: ControlSettings) {
        applyCount += 1
        if intent.click == .down {
            mouseDown = true
        } else if intent.click == .up || intent.click == .tap {
            mouseDown = false
        }
    }

    func releaseAll() {
        releaseCount += 1
        mouseDown = false
    }
}

private extension GestureIntent {
    static func sample(
        tracking: GestureTrackingState = .active,
        gesture: GestureName,
        confidence: Double = 0.9,
        click: ClickAction = .none
    ) -> GestureIntent {
        GestureIntent(
            timestamp: 1,
            tracking: tracking,
            gesture: gesture,
            confidence: confidence,
            cursorDelta: GestureVector(dx: 1, dy: 1),
            scrollDelta: GestureVector(dx: 0, dy: 0),
            click: click,
            diagnostics: GestureDiagnostics(handedness: .right, fps: 30)
        )
    }
}
