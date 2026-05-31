import AppKit
import CoreGraphics
import Foundation

protocol MacControlProviding: AnyObject {
    var isMouseDown: Bool { get }
    func apply(intent: GestureIntent, settings: ControlSettings)
    func releaseAll()
}

final class MacControlBridge: MacControlProviding {
    private(set) var isMouseDown = false

    func apply(intent: GestureIntent, settings: ControlSettings) {
        let current = currentMouseLocation()

        if settings.cursorEnabled, (intent.gesture == .indexMove || intent.gesture == .pinchHold) {
            moveCursor(from: current, delta: intent.cursorDelta, settings: settings)
        }

        if settings.scrollEnabled, intent.gesture == .twoFingerScroll {
            postScroll(delta: intent.scrollDelta, settings: settings)
        }

        if settings.clickDragEnabled {
            handleClick(intent.click)
        }
    }

    func releaseAll() {
        guard isMouseDown else { return }
        postMouse(type: .leftMouseUp)
        isMouseDown = false
    }

    private func currentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? CGPoint(x: 0, y: 0)
    }

    private func moveCursor(from current: CGPoint, delta: GestureVector, settings: ControlSettings) {
        guard abs(delta.dx) >= settings.cursorDeadZone || abs(delta.dy) >= settings.cursorDeadZone else { return }

        let bounds = CGDisplayBounds(CGMainDisplayID())
        let next = CGPoint(
            x: min(max(current.x + delta.dx * settings.trackingSpeed, bounds.minX), bounds.maxX),
            y: min(max(current.y + delta.dy * settings.trackingSpeed, bounds.minY), bounds.maxY)
        )
        CGWarpMouseCursorPosition(next)
        postMouse(type: .mouseMoved, at: next)
    }

    private func postScroll(delta: GestureVector, settings: ControlSettings) {
        guard abs(delta.dx) >= settings.scrollDeadZone || abs(delta.dy) >= settings.scrollDeadZone else { return }

        let vertical = Int32(delta.dy * 8.0 * settings.scrollSensitivity)
        let horizontal = Int32(delta.dx * 8.0 * settings.scrollSensitivity)
        guard vertical != 0 || horizontal != 0 else { return }

        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: vertical,
            wheel2: horizontal,
            wheel3: 0
        )
        event?.post(tap: .cghidEventTap)
    }

    private func handleClick(_ click: ClickAction) {
        switch click {
        case .none:
            return
        case .tap:
            postMouse(type: .leftMouseDown)
            postMouse(type: .leftMouseUp)
            isMouseDown = false
        case .down:
            guard !isMouseDown else { return }
            postMouse(type: .leftMouseDown)
            isMouseDown = true
        case .up:
            releaseAll()
        }
    }

    private func postMouse(type: CGEventType, at location: CGPoint? = nil) {
        let point = location ?? currentMouseLocation()
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }
}
