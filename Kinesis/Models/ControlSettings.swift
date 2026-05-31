import Foundation

struct ControlSettings: Codable, Equatable {
    var cursorEnabled: Bool
    var clickDragEnabled: Bool
    var scrollEnabled: Bool
    var trackingSpeed: Double
    var smoothing: Double
    var scrollSensitivity: Double
    var pinchThreshold: Double
    var confidenceThreshold: Double

    static let defaults = ControlSettings(
        cursorEnabled: true,
        clickDragEnabled: true,
        scrollEnabled: true,
        trackingSpeed: 9.0,
        smoothing: 0.35,
        scrollSensitivity: 1.0,
        pinchThreshold: 0.30,
        confidenceThreshold: 0.62
    )
}
