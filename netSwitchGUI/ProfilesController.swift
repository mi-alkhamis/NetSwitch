import Combine
import NetSwitchCore
import Foundation

@MainActor
final class ProfilesController: ObservableObject {
    @Published private(set) var profiles: [Profile]
    @Published var selectedProfileID: UUID?

    private let store: ProfileStore
    private let alertCenter: AppAlertCenter?

    init(store: ProfileStore, alertCenter: AppAlertCenter? = nil) {
        self.store = store
        self.alertCenter = alertCenter
        profiles = store.profiles
        selectedProfileID = store.profiles.first?.id
    }

    var selectedProfile: Profile? {
        profiles.first { $0.id == selectedProfileID }
    }

    func add(_ profile: Profile) {
        do {
            try store.add(profile)
            reloadProfiles()
            selectedProfileID = profile.id
            alertCenter?.alert = AppAlert(
                kind: .success,
                title: "Profile Saved",
                message: "\"\(profile.name)\" is ready to apply."
            )
        } catch { showError(title: "Could Not Save Profile", error: error) }
    }

    func update(_ profile: Profile) {
        do {
            try store.update(profile)
            reloadProfiles()
            selectedProfileID = profile.id
            alertCenter?.alert = AppAlert(
                kind: .success,
                title: "Profile Updated",
                message: "\"\(profile.name)\" was updated."
            )
        } catch { showError(title: "Could Not Update Profile", error: error) }
    }

    func deleteSelectedProfile() {
        guard let profile = selectedProfile else { return }
        delete(profile)
    }

    func delete(_ profile: Profile) {
        do {
            try store.delete(id: profile.id)
            reloadProfiles()
            if selectedProfileID == profile.id { selectedProfileID = profiles.first?.id }
            alertCenter?.alert = AppAlert(
                kind: .success,
                title: "Profile Deleted",
                message: "\"\(profile.name)\" was removed."
            )
        } catch { showError(title: "Could Not Delete Profile", error: error) }
    }

    func reloadProfiles() {
        do {
            try store.load()
            profiles = store.profiles
        } catch { showError(title: "Could Not Load Profiles", error: error) }
    }

    private func showError(title: String, error: Error) {
        alertCenter?.alert = AppAlert(
            kind: .error,
            title: title,
            message: error.localizedDescription
        )
    }
}
