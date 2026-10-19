import Combine
import Foundation
import NetSwitchCore

@MainActor
final class AppState: ObservableObject {
    static let defaultService = "Wi-Fi"

    private let profilesController: ProfilesController
    private let networkStatus: NetworkStatusController
    private let profileApply: ProfileApplyController
    private let wifiScanner: WiFiScannerController
    private let alertCenter: AppAlertCenter
    private var childSubscriptions = Set<AnyCancellable>()

    init() {
        let startup = ProfileStoreBootstrapper.bootstrap()
        let alerts = AppAlertCenter()
        let profiles = ProfilesController(store: startup.store, alertCenter: alerts)
        let network = NetworkStatusController(alertCenter: alerts)
        let apply = ProfileApplyController(
            networkStatus: network,
            alertCenter: alerts
        )

        profilesController = profiles
        networkStatus = network
        profileApply = apply
        wifiScanner = WiFiScannerController()
        alertCenter = alerts

        profiles.selectedProfileID = startup.selectedProfileID
        alerts.alert = startup.alert

        observe(profiles)
        observe(network)
        observe(apply)
        observe(wifiScanner)
        observe(alerts)
    }

    private func observe<Child: ObservableObject>(_ child: Child) {
        child.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &childSubscriptions)
    }

    var profiles: [Profile] { profilesController.profiles }
    var selectedProfileID: UUID? {
        get { profilesController.selectedProfileID }
        set { profilesController.selectedProfileID = newValue }
    }
    var selectedProfile: Profile? { profilesController.selectedProfile }

    var networkInfo: NetworkInfo { networkStatus.networkInfo }
    var networkInfoPublisher: AnyPublisher<NetworkInfo, Never> {
        networkStatus.$networkInfo.eraseToAnyPublisher()
    }
    var networkServices: [String] { networkStatus.networkServices }
    var isRefreshing: Bool { networkStatus.isRefreshing }
    var wifiSignal: Int { networkStatus.wifiSignal }
    var wifiEncryption: String { networkStatus.wifiEncryption }
    var wifiChannel: Int { networkStatus.wifiChannel }
    var wifiBand: String { networkStatus.wifiBand }
    var wifiName: String { networkStatus.wifiName }

    var isApplying: Bool { profileApply.isApplying }
    var lastAppliedProfile: Profile? { profileApply.lastAppliedProfile }

    var wifiNetworks: [WiFiNetwork] { wifiScanner.wifiNetworks }
    var isScanningWiFi: Bool { wifiScanner.isScanningWiFi }

    var alert: AppAlert? {
        get { alertCenter.alert }
        set { alertCenter.alert = newValue }
    }
    var menuBarAlert: AppAlert? {
        get { alertCenter.menuBarAlert }
        set { alertCenter.menuBarAlert = newValue }
    }

    func addProfile(_ profile: Profile) { profilesController.add(profile) }
    func updateProfile(_ profile: Profile) { profilesController.update(profile) }
    func deleteSelectedProfile() { profilesController.deleteSelectedProfile() }
    func delete(_ profile: Profile) { profilesController.delete(profile) }

    func requestWiFiAuthorization() {
        networkStatus.refreshNetworkServices()
        WiFiAuthorization.shared.requestAuthorization { [weak self] in
            self?.refreshNetworkInfo()
        }
    }

    func refreshNetworkServices() { networkStatus.refreshNetworkServices() }
    func refreshNetworkInfo() {
        networkStatus.refreshNetworkInfo(
            service: profileApply.lastAppliedProfile?.service ?? Self.defaultService
        )
    }

    func apply(_ profile: Profile) { profileApply.apply(profile) }
    func applyFromMenuBar(_ profile: Profile) { profileApply.applyFromMenuBar(profile) }
    func scanWiFi() { wifiScanner.scanWiFi() }
    func connect(to network: WiFiNetwork, password: String, save: Bool) {
        wifiScanner.connect(to: network, password: password, save: save)
    }
}
