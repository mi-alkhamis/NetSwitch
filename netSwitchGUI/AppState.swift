import Combine
import Foundation
import NetSwitchCore

@MainActor
final class AppState: ObservableObject {
    static let placeholderWiFiName = "WIF-NAME"
    static let defaultService = "Wi-Fi"

    @Published private(set) var profiles: [Profile] = []
    @Published var selectedProfileID: UUID?
    @Published private(set) var networkInfo = NetworkInfo(service: defaultService)
    @Published private(set) var isRefreshing = false
    @Published private(set) var isApplying = false
    @Published var alert: AppAlert?

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

    var selectedProfile: Profile? {
        profiles.first { $0.id == selectedProfileID }
    }

    var wifiName: String {
        Self.placeholderWiFiName
    }

    func refreshNetworkInfo() {
        isRefreshing = true

        defer {
            isRefreshing = false
        }

        do {
            networkInfo = try NetworkClient.info(for: Self.defaultService)
        } catch {
            showError(
                title: "Could Not Refresh Network Status",
                error: error
            )
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

    func apply(_ profile: Profile) {
        isApplying = true

        defer {
            isApplying = false
        }

        do {
            try NetworkClient.apply(profile)
            refreshNetworkInfo()

            alert = AppAlert(
                kind: .success,
                title: "Profile Applied",
                message: "\"\(profile.name)\" was applied to \(profile.service)."
            )
        } catch {
            showError(
                title: "Could Not Apply Profile",
                error: error
            )
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
}
