import XCTest
@testable import Kinesis

@MainActor
final class KinesisStoreTests: XCTestCase {
    func testEmergencyPauseDisablesTrackingAndReleasesOutput() {
        let bridge = StoreFakeBridge()
        let store = KinesisStore(bridge: bridge)

        store.trackingEnabled = true
        store.emergencyPause()

        XCTAssertFalse(store.trackingEnabled)
        XCTAssertTrue(store.emergencyPaused)
        XCTAssertEqual(bridge.releaseCount, 1)
    }

    func testResetSessionClearsRecentIntentLog() {
        let store = KinesisStore(bridge: StoreFakeBridge())
        store.recentIntents = [.idle, .idle]

        store.resetSession()

        XCTAssertTrue(store.recentIntents.isEmpty)
        XCTAssertEqual(store.latestDecision.reason, "Session reset.")
    }
}

private final class StoreFakeBridge: MacControlProviding {
    var releaseCount = 0
    var isMouseDown: Bool { false }

    func apply(intent: GestureIntent, settings: ControlSettings) {}

    func releaseAll() {
        releaseCount += 1
    }
}
