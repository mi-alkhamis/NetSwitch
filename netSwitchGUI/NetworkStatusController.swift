import Combine
import Foundation
import NetSwitchCore

@MainActor
final class NetworkStatusController: ObservableObject {
    @Published private(set) var networkInfo = NetworkInfo(service: AppState.defaultService)
    @Published private(set) var networkServices: [String] = [AppState.defaultService]
    @Published private(set) var isRefreshing = false
    @Published private(set) var wifiSignal = 0
    @Published private(set) var wifiEncryption = ""
    @Published private(set) var wifiChannel = 0
    @Published private(set) var wifiBand = ""

    private let alertCenter: AppAlertCenter

    init(alertCenter: AppAlertCenter) {
        self.alertCenter = alertCenter
    }

    var wifiName: String { networkInfo.ssid }

    func refreshNetworkServices() {
        Task {
            let services = await Task.detached(priority: .utility) {
                (try? NetworkClient.services()) ?? []
            }.value
            networkServices = services.isEmpty ? [AppState.defaultService] : services
        }
    }

    func refreshNetworkInfo(service: String) {
        guard !isRefreshing else { return }
        Task { _ = await refreshNetworkInfoAndWait(for: service) }
    }

    @discardableResult
    func refreshNetworkInfoAndWait(for service: String) async -> NetworkInfo? {
        while isRefreshing {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let (info, wifi) = try await Task.detached(priority: .userInitiated) {
                (try NetworkClient.info(for: service), NetworkClient.wifiStatus())
            }.value
            networkInfo = info
            wifiSignal = wifi.signalStrength
            wifiEncryption = wifi.encryption
            wifiChannel = wifi.channel
            wifiBand = wifi.band
            return info
        } catch {
            alertCenter.alert = AppAlert(
                kind: .error,
                title: "Could Not Refresh Network Status",
                message: error.localizedDescription
            )
            return nil
        }
    }
}
