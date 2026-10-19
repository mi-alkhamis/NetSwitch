import Combine

@MainActor
final class AppAlertCenter: ObservableObject {
    @Published var alert: AppAlert?
    @Published var menuBarAlert: AppAlert?
}
