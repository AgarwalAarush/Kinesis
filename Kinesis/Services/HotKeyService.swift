import AppKit
import Foundation

final class HotKeyService {
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func start(onEmergencyPause: @escaping @MainActor () -> Void) {
        stop()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Self.isCommandEscape(event) {
                Task { @MainActor in onEmergencyPause() }
                return nil
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if Self.isCommandEscape(event) {
                Task { @MainActor in onEmergencyPause() }
            }
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        localMonitor = nil
        globalMonitor = nil
    }

    private static func isCommandEscape(_ event: NSEvent) -> Bool {
        event.keyCode == 53 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
    }
}
