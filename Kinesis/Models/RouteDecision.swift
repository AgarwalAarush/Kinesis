import Foundation

struct RouteDecision: Equatable {
    enum Action: Equatable {
        case applied
        case ignored
        case released
    }

    var action: Action
    var reason: String
}
