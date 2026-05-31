import Foundation

enum GestureTrackingState: String, Codable, CaseIterable {
    case active
    case paused
    case lost
}

enum GestureName: String, Codable, CaseIterable {
    case indexMove = "index_move"
    case pinch
    case pinchHold = "pinch_hold"
    case twoFingerScroll = "two_finger_scroll"
    case fistPause = "fist_pause"
    case openPalmPause = "open_palm_pause"
    case none
}

enum ClickAction: String, Codable, CaseIterable {
    case none
    case down
    case up
    case tap
}

enum Handedness: String, Codable, CaseIterable {
    case left
    case right
    case unknown
}

struct GestureVector: Codable, Equatable {
    var dx: Double
    var dy: Double

    static let zero = GestureVector(dx: 0, dy: 0)
}

struct GestureDiagnostics: Codable, Equatable {
    var handedness: Handedness
    var fps: Double
}

struct GestureIntent: Codable, Equatable, Identifiable {
    var id: Double { timestamp }
    var timestamp: Double
    var tracking: GestureTrackingState
    var gesture: GestureName
    var confidence: Double
    var cursorDelta: GestureVector
    var scrollDelta: GestureVector
    var click: ClickAction
    var diagnostics: GestureDiagnostics

    static let idle = GestureIntent(
        timestamp: 0,
        tracking: .paused,
        gesture: .none,
        confidence: 0,
        cursorDelta: .zero,
        scrollDelta: .zero,
        click: .none,
        diagnostics: GestureDiagnostics(handedness: .unknown, fps: 0)
    )
}
