import Foundation

final class GestureRouter {
    func route(
        intent: GestureIntent,
        settings: ControlSettings,
        trackingEnabled: Bool,
        emergencyPaused: Bool,
        output: MacControlProviding
    ) -> RouteDecision {
        guard trackingEnabled else {
            output.releaseAll()
            return RouteDecision(action: .released, reason: "Tracking is disabled.")
        }

        guard !emergencyPaused else {
            output.releaseAll()
            return RouteDecision(action: .released, reason: "Emergency pause is active.")
        }

        guard intent.tracking == .active else {
            output.releaseAll()
            return RouteDecision(action: .released, reason: "Hand tracking is \(intent.tracking.rawValue).")
        }

        if intent.gesture == .fistPause || intent.gesture == .openPalmPause {
            output.releaseAll()
            return RouteDecision(action: .released, reason: "Clutch gesture paused input.")
        }

        guard intent.confidence >= settings.confidenceThreshold else {
            output.releaseAll()
            return RouteDecision(action: .released, reason: "Gesture confidence is below threshold.")
        }

        guard hasEnabledAction(intent: intent, settings: settings) else {
            return RouteDecision(action: .ignored, reason: "The matching control is disabled.")
        }

        output.apply(intent: intent, settings: settings)
        return RouteDecision(action: .applied, reason: "Applied \(intent.gesture.rawValue).")
    }

    private func hasEnabledAction(intent: GestureIntent, settings: ControlSettings) -> Bool {
        if settings.cursorEnabled, intent.gesture == .indexMove {
            return true
        }
        if settings.scrollEnabled, intent.gesture == .twoFingerScroll {
            return true
        }
        if settings.clickDragEnabled, intent.click != .none {
            return true
        }
        return false
    }
}
