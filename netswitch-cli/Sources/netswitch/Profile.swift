import Foundation

/// Mirrors the GUI app's `Profile` model so a profiles.json written by the CLI
/// is shape-compatible (and vice-versa) if you later point both at the same file.
struct Profile: Codable, Equatable {
    var id: UUID
    var name: String
    var service: String
    var useDHCP: Bool
    var ipAddress: String
    var subnetMask: String
    var gateway: String
    var dnsServers: [String]

    init(
        id: UUID = UUID(),
        name: String,
        service: String = "Wi-Fi",
        useDHCP: Bool = true,
        ipAddress: String = "",
        subnetMask: String = "",
        gateway: String = "",
        dnsServers: [String] = []
    ) {
        self.id = id
        self.name = name
        self.service = service
        self.useDHCP = useDHCP
        self.ipAddress = ipAddress
        self.subnetMask = subnetMask
        self.gateway = gateway
        self.dnsServers = dnsServers
    }
}

extension Profile {
    /// Human-readable one-liner for `profile list` / `profile show`.
    var summary: String {
        let mode = useDHCP ? "DHCP" : "\(ipAddress) / \(subnetMask) gw \(gateway)"
        let dns = dnsServers.isEmpty ? "no DNS" : "dns \(dnsServers.joined(separator: ","))"
        return "\(name)  [\(service)]  \(mode)  \(dns)"
    }
}
