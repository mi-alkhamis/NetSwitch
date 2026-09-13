import Foundation

public enum ProfileStoreError: LocalizedError {
    case duplicateName(String)
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case let .duplicateName(name): "A profile named '\(name)' already exists."
        case let .notFound(name): "No profile named '\(name)' exists."
        }
    }
}

public final class ProfileStore {
    public let fileURL: URL
    /// False for the in-memory fallback, where `load()` and `save()` are no-ops.
    public let isPersistent: Bool
    public private(set) var profiles: [Profile] = []

    public init(directoryName: String) throws {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("profiles.json")
        self.isPersistent = true
        try load()
    }

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        self.isPersistent = true
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try load()
    }

    /// A store that holds profiles in memory only and never throws on creation.
    ///
    /// This is the last-resort fallback when profile storage is unusable: the app still launches
    /// and works for the current session instead of crashing, it just cannot persist anything.
    /// Callers are expected to tell the user that.
    public static func inMemory() -> ProfileStore {
        ProfileStore(unpersisted: FileManager.default.temporaryDirectory.appendingPathComponent("profiles.json"))
    }

    private init(unpersisted fileURL: URL) {
        self.fileURL = fileURL
        self.isPersistent = false
    }

    public func load() throws {
        guard isPersistent else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { profiles = []; return }
        profiles = try JSONDecoder().decode([Profile].self, from: Data(contentsOf: fileURL))
    }

    public func add(_ profile: Profile) throws {
        try ProfileValidator.validate(profile)
        guard find(name: profile.name) == nil else { throw ProfileStoreError.duplicateName(profile.name) }
        profiles.append(profile)
        try save()
    }

    public func update(_ profile: Profile) throws {
        try ProfileValidator.validate(profile)
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { throw ProfileStoreError.notFound(profile.name) }
        guard !profiles.contains(where: { $0.id != profile.id && $0.name.caseInsensitiveCompare(profile.name) == .orderedSame }) else {
            throw ProfileStoreError.duplicateName(profile.name)
        }
        profiles[index] = profile
        try save()
    }

    /// Deletes by identity. Preferred over `delete(name:)` — two profiles can be renamed into
    /// near-identical names, and the GUI always has the exact record in hand.
    public func delete(id: UUID) throws {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw ProfileStoreError.notFound(id.uuidString)
        }
        profiles.remove(at: index)
        try save()
    }

    /// Deletes by name. Kept for the CLI, where the name is all the user typed.
    public func delete(name: String) throws {
        guard let index = profiles.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { throw ProfileStoreError.notFound(name) }
        profiles.remove(at: index)
        try save()
    }

    public func find(name: String) -> Profile? {
        profiles.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func save() throws {
        guard isPersistent else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: fileURL, options: .atomic)
    }
}
