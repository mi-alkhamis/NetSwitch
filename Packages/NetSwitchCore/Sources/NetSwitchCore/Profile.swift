import Foundation

public struct Profile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var service: String
    public var useDHCP: Bool
    public var ipAddress: String
    public var subnetMask: String
    public var gateway: String
    public var dnsServers: [String]

    public init(
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

    public var summary: String {
        let mode = useDHCP ? "DHCP" : "\(ipAddress) / \(subnetMask) gw \(gateway)"
        let dns = dnsServers.isEmpty ? "no DNS" : "dns \(dnsServers.joined(separator: ", "))"
        return "\(name) [\(service)] \(mode) \(dns)"
    }
}
