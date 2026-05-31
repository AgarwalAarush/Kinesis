import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum PermissionService {
    static func snapshot(promptForAccessibility: Bool = false) -> PermissionSnapshot {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptForAccessibility]
        let accessibility = AXIsProcessTrustedWithOptions(options as CFDictionary)
        let inputMonitoring = CGPreflightListenEventAccess()
        return PermissionSnapshot(accessibilityTrusted: accessibility, inputMonitoringTrusted: inputMonitoring)
    }

    static func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
    }

    static func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        openPrivacyPane("Privacy_ListenEvent")
    }

    private static func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
