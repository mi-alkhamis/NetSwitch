import Foundation

public enum ProfileValidationError: LocalizedError, Equatable {
    case emptyName
    case emptyService
    case invalidIPv4(String, field: String)
    case incompleteStaticProfile

    public var errorDescription: String? {
        switch self {
        case .emptyName: "Profile name cannot be empty."
        case .emptyService: "Network service cannot be empty."
        case let .invalidIPv4(value, field): "\(field) '\(value)' is not a valid IPv4 address."
        case .incompleteStaticProfile: "A static profile needs an IP address, subnet mask, and gateway."
        }
    }
}

public enum ProfileValidator {
    public static func isIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { Int($0).map { (0...255).contains($0) } ?? false }
    }

    public static func validate(_ profile: Profile) throws {
        guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProfileValidationError.emptyName
        }
        guard !profile.service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProfileValidationError.emptyService
        }
        if !profile.useDHCP {
            guard !profile.ipAddress.isEmpty, !profile.subnetMask.isEmpty, !profile.gateway.isEmpty else {
                throw ProfileValidationError.incompleteStaticProfile
            }
        }
        for (value, field) in [(profile.ipAddress, "IP address"), (profile.subnetMask, "Subnet mask"), (profile.gateway, "Gateway")] where !value.isEmpty {
            guard isIPv4(value) else { throw ProfileValidationError.invalidIPv4(value, field: field) }
        }
        for server in profile.dnsServers where !isIPv4(server) {
            throw ProfileValidationError.invalidIPv4(server, field: "DNS server")
        }
    }
}
