import Combine
import Foundation
import NetSwitchCore

@MainActor
final class AppState: ObservableObject {
    static let defaultService = "Wi-Fi"

    @Published private(set) var profiles: [Profile] = []
    @Published var selectedProfileID: UUID?
    @Published private(set) var networkInfo = NetworkInfo(service: defaultService)
    @Published private(set) var isRefreshing = false
    @Published private(set) var isApplying = false
    @Published var alert: AppAlert?
    @Published var menuBarAlert: AppAlert?
    

    private let profileStore: ProfileStore

    init() {
        do {
            profileStore = try ProfileStore(directoryName: "NetSwitch")
            profiles = profileStore.profiles
            selectedProfileID = profiles.first?.id
        } catch {
            let originalError = error

            do {
                let profileFileURL = try Self.profileFileURL()
                let backupFileURL = try Self.backupUnreadableProfileFile(
                    at: profileFileURL
                )

                profileStore = try ProfileStore(fileURL: profileFileURL)
                profiles = []
                selectedProfileID = nil

                let backupMessage: String

                if let backupFileURL {
                    backupMessage = """
                    Your previous profile file was backed up as:
                    \(backupFileURL.lastPathComponent)
                    """
                } else {
                    backupMessage = "No previous profile file was found to back up."
                }

                alert = AppAlert(
                    kind: .error,
                    title: "Saved Profiles Could Not Be Loaded",
                    message: """
                    NetSwitch started with an empty profile list because \
                    the saved profile data is incompatible or unreadable.

                    \(backupMessage)

                    Original error: \(originalError.localizedDescription)
                    """
                )
            } catch {
                fatalError(
                    "NetSwitch could not initialize profile storage: "
                        + error.localizedDescription
                )
            }
        }
    }
    func requestWiFiAuthorization() {
        WiFiAuthorization.shared.requestAuthorization { [weak self] in
            self?.refreshNetworkInfo()
        }
    }
    

    var selectedProfile: Profile? {
        profiles.first { $0.id == selectedProfileID }
    }

    var wifiName: String {
        networkInfo.ssid
    }

    func refreshNetworkInfo() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            do {
                let (info, wifi) = try await Task.detached(priority: .userInitiated) {
                    let info = try NetworkClient.info(for: Self.defaultService)
                    let wifi = NetworkClient.wifiStatus()
                    return (info, wifi)
                }.value

                self.networkInfo = info
                self.wifiSignal = wifi.signalStrength
                self.wifiEncryption = wifi.encryption
                self.wifiChannel = wifi.channel
                self.wifiBand = wifi.band
                self.isRefreshing = false
            } catch {
                self.isRefreshing = false
                self.showError(
                    title: "Could Not Refresh Network Status",
                    error: error
                )
            }
        }
    }

    func addProfile(_ profile: Profile) {
        do {
            try profileStore.add(profile)
            reloadProfiles()
            selectedProfileID = profile.id

            alert = AppAlert(
                kind: .success,
                title: "Profile Saved",
                message: "\"\(profile.name)\" is ready to apply."
            )
        } catch {
            showError(
                title: "Could Not Save Profile",
                error: error
            )
        }
    }

    func updateProfile(_ profile: Profile) {
        do {
            try profileStore.update(profile)
            reloadProfiles()
            selectedProfileID = profile.id

            alert = AppAlert(
                kind: .success,
                title: "Profile Updated",
                message: "\"\(profile.name)\" was updated."
            )
        } catch {
            showError(
                title: "Could Not Update Profile",
                error: error
            )
        }
    }

    func deleteSelectedProfile() {
        guard let profile = selectedProfile else {
            return
        }

        do {
            try profileStore.delete(name: profile.name)
            reloadProfiles()
            selectedProfileID = profiles.first?.id

            alert = AppAlert(
                kind: .success,
                title: "Profile Deleted",
                message: "\"\(profile.name)\" was removed."
            )
        } catch {
            showError(
                title: "Could Not Delete Profile",
                error: error
            )
        }
    }
    func delete(_ profile: Profile) {
        do {
            try profileStore.delete(name: profile.name)
            reloadProfiles()
            if selectedProfileID == profile.id {
                selectedProfileID = profiles.first?.id
            }

            alert = AppAlert(
                kind: .success,
                title: "Profile Deleted",
                message: "\"\(profile.name)\" was removed."
            )
        } catch {
            showError(
                title: "Could Not Delete Profile",
                error: error
            )
        }
    }

    func apply(_ profile: Profile) {
        performApply(profile) { [weak self] alert in
            self?.alert = alert
        }
    }

    func applyFromMenuBar(_ profile: Profile) {
        performApply(profile) { [weak self] alert in
            self?.menuBarAlert = alert
        }
    }

    private func performApply(_ profile: Profile, setAlert: @escaping (AppAlert) -> Void) {
        guard !isApplying else { return }
        isApplying = true

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try NetworkClient.apply(profile)
                }.value

                // configd applies changes asynchronously; give it a moment before
                // reading state back, especially for static IP/DNS changes.
                try? await Task.sleep(nanoseconds: 900_000_000) // 0.9s
                self.refreshNetworkInfo()

                // If we expected DNS servers but didn't see them yet, try once more
                // after a slightly longer wait — static config can take a bit longer.
                if !profile.dnsServers.isEmpty {
                    try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s
                    if self.networkInfo.dnsServers.isEmpty {
                        self.refreshNetworkInfo()
                    }
                }

                self.isApplying = false

                setAlert(AppAlert(
                    kind: .success,
                    title: "Profile Applied",
                    message: "\"\(profile.name)\" was applied to \(profile.service)."
                ))

                activeProfile = profile
            } catch {
                self.isApplying = false
                setAlert(AppAlert(
                    kind: .error,
                    title: "Could Not Apply Profile",
                    message: error.localizedDescription
                ))
            }
        }
    }
    private func reloadProfiles() {
        do {
            try profileStore.load()
            profiles = profileStore.profiles
        } catch {
            showError(
                title: "Could Not Load Profiles",
                error: error
            )
        }
    }

    private func showError(title: String, error: Error) {
        alert = AppAlert(
            kind: .error,
            title: title,
            message: error.localizedDescription
        )
    }

    private static func profileFileURL() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directoryURL = baseURL.appendingPathComponent(
            "NetSwitch",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        return directoryURL.appendingPathComponent("profiles.json")
    }

    private static func backupUnreadableProfileFile(
        at profileFileURL: URL
    ) throws -> URL? {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: profileFileURL.path) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"

        let backupFileName = """
        profiles.broken-\(formatter.string(from: Date())).json
        """

        let backupFileURL = profileFileURL
            .deletingLastPathComponent()
            .appendingPathComponent(backupFileName)

        try fileManager.moveItem(
            at: profileFileURL,
            to: backupFileURL
        )

        return backupFileURL
    }

    // WiFi status (StatusView + MenuBar)
    @Published var wifiSignal: Int = 0
    @Published var wifiEncryption: String = ""
    @Published var wifiChannel: Int = 0
    @Published var wifiBand: String = ""

    // Active profile detection
    @Published var activeProfile: Profile? = nil

    // WiFi scanning (WiFiScannerView)
    @Published var wifiNetworks: [WiFiNetwork] = []
    @Published var isScanningWiFi: Bool = false

    func scanWiFi() { /* CoreWLAN scan */ }
    func connect(to network: WiFiNetwork, password: String, save: Bool) { /* connect logic */ }
}
