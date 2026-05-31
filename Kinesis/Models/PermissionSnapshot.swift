import Foundation

struct PermissionSnapshot: Equatable {
    var accessibilityTrusted: Bool
    var inputMonitoringTrusted: Bool

    static let unknown = PermissionSnapshot(accessibilityTrusted: false, inputMonitoringTrusted: false)
}
