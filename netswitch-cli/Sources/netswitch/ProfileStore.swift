import Foundation

/// JSON-backed profile store. Lives in Application Support/NetSwitch by default so
/// it doesn't collide with the demo app's `AuthDemo` directory, but the path is
/// overridable for tests.
final class ProfileStore {
    let fileURL: URL
    private(set) var profiles: [Profile] = []

    init(directoryName: String = "NetSwitch", fileName: String = "profiles.json") {
        let fm = FileManager.default
        let base: URL
        if let override = ProcessInfo.processInfo.environment["NETSWITCH_PROFILES_DIR"], !override.isEmpty {
            base = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        }
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            fail("Could not create profile directory '\(dir.path)': \(error.localizedDescription)")
        }
        self.fileURL = dir.appendingPathComponent(fileName)
        load()
    }

    // MARK: - Persistence

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([Profile].self, from: data) {
            self.profiles = decoded
        }
    }

    func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(profiles) else { return }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            fail("Could not save profiles to '\(fileURL.path)': \(error.localizedDescription)")
        }
    }

    // MARK: - Lookups

    func find(name: String) -> Profile? {
        profiles.first { $0.name.lowercased() == name.lowercased() }
    }

    func add(_ p: Profile) {
        guard !profiles.contains(where: { $0.name.lowercased() == p.name.lowercased() }) else {
            fail("A profile named '\(p.name)' already exists.")
        }
        profiles.append(p)
        save()
    }

    func update(_ p: Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == p.id }) else {
            fail("Profile '\(p.name)' not found (id mismatch).")
        }
        guard !profiles.contains(where: {
            $0.id != p.id && $0.name.lowercased() == p.name.lowercased()
        }) else {
            fail("Another profile already uses the name '\(p.name)'.")
        }
        profiles[idx] = p
        save()
    }

    func remove(name: String) {
        guard let idx = profiles.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) else {
            fail("No profile named '\(name)'.")
        }
        let removed = profiles.remove(at: idx)
        save()
        print("Removed '\(removed.name)'.")
    }
}
