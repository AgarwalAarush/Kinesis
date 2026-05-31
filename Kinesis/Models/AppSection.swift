import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case tuning
    case permissions
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .tuning:
            "Tuning"
        case .permissions:
            "Permissions"
        case .diagnostics:
            "Diagnostics"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            "cursorarrow.motionlines"
        case .tuning:
            "dial.medium"
        case .permissions:
            "lock.shield"
        case .diagnostics:
            "waveform.path.ecg"
        }
    }
}
