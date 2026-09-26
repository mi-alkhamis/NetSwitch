import Foundation

struct AppAlert: Identifiable, Equatable {
    enum Kind: Equatable {
        case success
        case error
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
}
