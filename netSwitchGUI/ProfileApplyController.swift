import Combine
import Foundation
import NetSwitchCore

@MainActor
final class ProfileApplyController: ObservableObject {
    @Published private(set) var isApplying = false
    @Published private(set) var lastAppliedProfile: Profile?

    private let networkStatus: NetworkStatusController
    private let alertCenter: AppAlertCenter

    init(networkStatus: NetworkStatusController, alertCenter: AppAlertCenter) {
        self.networkStatus = networkStatus
        self.alertCenter = alertCenter
    }

    func apply(_ profile: Profile) { performApply(profile, menuBar: false) }
    func applyFromMenuBar(_ profile: Profile) { performApply(profile, menuBar: true) }

    private func performApply(_ profile: Profile, menuBar: Bool) {
        guard !isApplying else { return }
        isApplying = true

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try NetworkClient.apply(profile)
                }.value

                try? await Task.sleep(nanoseconds: 500_000_000)
                for attempt in 0..<8 {
                    let info = await networkStatus.refreshNetworkInfoAndWait(for: profile.service)
                    if let info, networkInfoMatches(info, profile: profile) { break }
                    if attempt < 7 { try? await Task.sleep(nanoseconds: 500_000_000) }
                }

                isApplying = false
                setAlert(AppAlert(
                    kind: .success,
                    title: "Profile Applied",
                    message: "\"\(profile.name)\" was applied to \(profile.service)."
                ), menuBar: menuBar)
                lastAppliedProfile = profile
            } catch {
                isApplying = false
                setAlert(AppAlert(
                    kind: .error,
                    title: "Could Not Apply Profile",
                    message: error.localizedDescription
                ), menuBar: menuBar)
            }
        }
    }

    private func setAlert(_ alert: AppAlert, menuBar: Bool) {
        if menuBar { alertCenter.menuBarAlert = alert }
        else { alertCenter.alert = alert }
    }

    private func networkInfoMatches(_ info: NetworkInfo, profile: Profile) -> Bool {
        if profile.useDHCP {
            guard info.ipAddress != "—", info.subnetMask != "—" else { return false }
        } else if info.ipAddress != profile.ipAddress
                    || info.subnetMask != profile.subnetMask
                    || info.gateway != profile.gateway {
            return false
        }
        if !profile.dnsServers.isEmpty && info.dnsServers != profile.dnsServers { return false }
        return true
    }
}
