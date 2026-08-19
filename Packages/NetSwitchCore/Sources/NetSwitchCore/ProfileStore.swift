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
    public private(set) var profiles: [Profile] = []

    public init(directoryName: String) throws {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("profiles.json")
        try load()
    }

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try load()
    }

    public func load() throws {
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

    public func delete(name: String) throws {
        guard let index = profiles.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { throw ProfileStoreError.notFound(name) }
        profiles.remove(at: index)
        try save()
    }

    public func find(name: String) -> Profile? {
        profiles.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: fileURL, options: .atomic)
    }
}
