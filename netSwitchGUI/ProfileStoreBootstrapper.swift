import Foundation
import NetSwitchCore

struct ProfileStoreStartup {
    let store: ProfileStore
    let selectedProfileID: UUID?
    let alert: AppAlert?
}

enum ProfileStoreBootstrapper {
    static func bootstrap() -> ProfileStoreStartup {
        do {
            let store = try ProfileStore(directoryName: "NetSwitch")
            return ProfileStoreStartup(
                store: store,
                selectedProfileID: store.profiles.first?.id,
                alert: nil
            )
        } catch {
            return recover(from: error)
        }
    }

    private static func recover(from originalError: Error) -> ProfileStoreStartup {
        do {
            let fileURL = try profileFileURL()
            let backupURL = try backupUnreadableProfileFile(at: fileURL)
            let store = try ProfileStore(fileURL: fileURL)
            let backupMessage = backupURL.map {
                "Your previous profile file was backed up as:\n\($0.lastPathComponent)"
            } ?? "No previous profile file was found to back up."

            return ProfileStoreStartup(
                store: store,
                selectedProfileID: nil,
                alert: AppAlert(
                    kind: .error,
                    title: "Saved Profiles Could Not Be Loaded",
                    message: """
                    NetSwitch started with an empty profile list because the saved profile data is incompatible or unreadable.

                    \(backupMessage)

                    Original error: \(originalError.localizedDescription)
                    """
                )
            )
        } catch {
            let fallbackError = error
            return ProfileStoreStartup(
                store: .inMemory(),
                selectedProfileID: nil,
                alert: AppAlert(
                    kind: .error,
                    title: "Profile Storage Is Unavailable",
                    message: """
                    NetSwitch started with temporary in-memory profile storage. Changes cannot be saved between launches.

                    Profile loading error: \(originalError.localizedDescription)
                    Storage recovery error: \(fallbackError.localizedDescription)
                    """
                )
            )
        }
    }

    private static func profileFileURL() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = baseURL.appendingPathComponent("NetSwitch", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        return directoryURL.appendingPathComponent("profiles.json")
    }

    private static func backupUnreadableProfileFile(at fileURL: URL) throws -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let backupURL = fileURL.deletingLastPathComponent().appendingPathComponent(
            "profiles.broken-\(formatter.string(from: Date())).json"
        )
        try fileManager.moveItem(at: fileURL, to: backupURL)
        return backupURL
    }
}
