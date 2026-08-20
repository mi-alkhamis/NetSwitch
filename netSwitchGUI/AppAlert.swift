import Foundation

struct AppAlert: Identifiable {
    enum Kind {
        case success
        case error
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
}
