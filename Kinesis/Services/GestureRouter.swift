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

        if output.isMouseDown, settings.dryRunEnabled {
            output.releaseAll()
            return RouteDecision(action: .released, reason: "Released held click before entering Dry Run.")
        }

        if output.isMouseDown, !settings.clickDragEnabled, intent.click != .none || intent.gesture == .pinchHold {
            output.releaseAll()
            return RouteDecision(action: .released, reason: "Released held click because click and drag control is disabled.")
        }

        guard hasEnabledAction(intent: intent, settings: settings) else {
            if output.isMouseDown {
                output.releaseAll()
                return RouteDecision(action: .released, reason: "Released held click because the matching control is disabled.")
            }
            return RouteDecision(action: .ignored, reason: "The matching control is disabled.")
        }

        guard !settings.dryRunEnabled else {
            return RouteDecision(action: .ignored, reason: dryRunReason(for: intent))
        }

        output.apply(intent: intent, settings: settings)
        return RouteDecision(action: .applied, reason: "Applied \(intent.gesture.rawValue).")
    }

    private func hasEnabledAction(intent: GestureIntent, settings: ControlSettings) -> Bool {
        if settings.cursorEnabled, (intent.gesture == .indexMove || intent.gesture == .pinchHold) {
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

    private func dryRunReason(for intent: GestureIntent) -> String {
        if intent.click != .none {
            return "Dry Run: would \(intent.click.rawValue) with \(intent.gesture.rawValue)."
        }
        if intent.gesture == .twoFingerScroll {
            return "Dry Run: would scroll by \(rounded(intent.scrollDelta.dx)), \(rounded(intent.scrollDelta.dy))."
        }
        if intent.gesture == .indexMove {
            return "Dry Run: would move cursor by \(rounded(intent.cursorDelta.dx)), \(rounded(intent.cursorDelta.dy))."
        }
        return "Dry Run: recognized \(intent.gesture.rawValue)."
    }

    private func rounded(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}
