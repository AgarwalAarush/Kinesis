import Foundation

enum HelperStatus: Equatable {
    case stopped
    case starting
    case running
    case failed(String)

    var title: String {
        switch self {
        case .stopped:
            "Stopped"
        case .starting:
            "Starting"
        case .running:
            "Running"
        case .failed:
            "Failed"
        }
    }

    var detail: String {
        switch self {
        case .stopped:
            "The camera helper is not running."
        case .starting:
            "Launching the Python webcam helper."
        case .running:
            "Receiving gesture intents from the helper."
        case .failed(let message):
            message
        }
    }
}
