import XCTest
@testable import Kinesis

final class GestureIntentTests: XCTestCase {
    func testDecodesHelperIntentShape() throws {
        let json = """
        {
          "timestamp": 12.5,
          "tracking": "active",
          "gesture": "index_move",
          "confidence": 0.91,
          "cursorDelta": { "dx": 2.5, "dy": -1.25 },
          "scrollDelta": { "dx": 0.0, "dy": 0.0 },
          "click": "none",
          "diagnostics": { "handedness": "right", "fps": 29.8 }
        }
        """

        let intent = try JSONDecoder().decode(GestureIntent.self, from: Data(json.utf8))

        XCTAssertEqual(intent.tracking, .active)
        XCTAssertEqual(intent.gesture, .indexMove)
        XCTAssertEqual(intent.cursorDelta, GestureVector(dx: 2.5, dy: -1.25))
        XCTAssertEqual(intent.diagnostics.handedness, .right)
    }

    func testDefaultSettingsKeepV0ControlsEnabled() {
        let settings = ControlSettings.defaults
        XCTAssertTrue(settings.cursorEnabled)
        XCTAssertTrue(settings.clickDragEnabled)
        XCTAssertTrue(settings.scrollEnabled)
        XCTAssertGreaterThan(settings.confidenceThreshold, 0.5)
    }
}
