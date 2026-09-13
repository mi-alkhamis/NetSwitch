import Foundation
import CoreWLAN
import SystemConfiguration
import Security

public struct NetworkInfo: Equatable, Sendable {
    public var service: String
    public var ssid: String
    public var ipAddress: String
    public var subnetMask: String
    public var gateway: String
    public var dnsServers: [String]

    public init(service: String, ssid: String = "", ipAddress: String = "—", subnetMask: String = "—", gateway: String = "—", dnsServers: [String] = []) {
        self.service = service
        self.ssid = ssid
        self.ipAddress = ipAddress
        self.subnetMask = subnetMask
        self.gateway = gateway
        self.dnsServers = dnsServers
    }
}

/// Live Wi-Fi radio details for the currently associated network.
/// All fields default to empty/zero if unavailable (no entitlement, not connected, etc.)
/// — this never throws, since "no data" is a normal, expected state.
public struct WiFiStatus: Equatable, Sendable {
    public var ssid: String
    public var signalStrength: Int // dBm; 0 if unknown
    public var encryption: String  // "WPA2", "WPA3", "Open", "Unknown", etc.
    public var channel: Int        // 0 if unknown
    public var band: String        // "2.4 GHz", "5 GHz", "6 GHz", or "" if unknown

    public init(ssid: String = "", signalStrength: Int = 0, encryption: String = "", channel: Int = 0, band: String = "") {
        self.ssid = ssid
        self.signalStrength = signalStrength
        self.encryption = encryption
        self.channel = channel
        self.band = band
    }
}

public enum NetworkClientError: LocalizedError {
    case authorizationDenied
    case authorizationFailed(OSStatus)
    case preferencesLockFailed
    case preferencesCommitFailed
    case serviceNotFound(String)
    case protocolUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied: "Administrator authorization was denied."
        case let .authorizationFailed(status): "Could not obtain administrator authorization (status \(status))."
        case .preferencesLockFailed: "Could not access system network preferences."
        case .preferencesCommitFailed: "Could not save the network change."
        case let .serviceNotFound(name): "Network service '\(name)' was not found."
        case let .protocolUnavailable(name): "Could not access \(name) settings for this service."
        }
    }
}

public enum NetworkClient {

    // MARK: - Reading (no privilege required)

    public static func services() throws -> [String] {
        guard let prefs = SCPreferencesCreate(nil, "NetSwitch" as CFString, nil),
              let set = SCNetworkSetCopyCurrent(prefs),
              let services = SCNetworkSetCopyServices(set) as? [SCNetworkService] else {
            return []
        }
        return services.compactMap { SCNetworkServiceGetName($0) as String? }
    }

    public static func currentSSID(for service: String) throws -> String {
        CWWiFiClient.shared().interface()?.ssid() ?? ""
    }

    /// Reads signal strength, security type, and channel/band for the current Wi-Fi interface.
    /// Requires the "Access Wi-Fi Information" entitlement (or Location authorization) to return
    /// real values; without it, macOS returns empty/placeholder data rather than an error.
    public static func wifiStatus() -> WiFiStatus {
        guard let interface = CWWiFiClient.shared().interface() else {
            return WiFiStatus()
        }

        let ssid = interface.ssid() ?? ""
        let signal = interface.rssiValue()
        let encryption = encryptionLabel(for: interface.security())
        let channel = interface.wlanChannel()?.channelNumber ?? 0
        let band = bandLabel(for: interface.wlanChannel()?.channelBand)

        return WiFiStatus(ssid: ssid, signalStrength: signal, encryption: encryption, channel: channel, band: band)
    }

    public static func info(for service: String) throws -> NetworkInfo {
        var info = NetworkInfo(service: service)
        info.ssid = (try? currentSSID(for: service)) ?? ""

        guard let store = SCDynamicStoreCreate(nil, "NetSwitch" as CFString, nil, nil),
              let serviceID = serviceID(for: service) else {
            return info
        }

        if let ipv4 = SCDynamicStoreCopyValue(store, "State:/Network/Service/\(serviceID)/IPv4" as CFString) as? [String: Any] {
            if let addrs = ipv4[kSCPropNetIPv4Addresses as String] as? [String], let first = addrs.first {
                info.ipAddress = first
            }
            if let masks = ipv4[kSCPropNetIPv4SubnetMasks as String] as? [String], let first = masks.first {
                info.subnetMask = first
            }
            if let router = ipv4[kSCPropNetIPv4Router as String] as? String {
                info.gateway = router
            }
        }

        if let dns = SCDynamicStoreCopyValue(store, "State:/Network/Service/\(serviceID)/DNS" as CFString) as? [String: Any],
           let servers = dns[kSCPropNetDNSServerAddresses as String] as? [String] {
            info.dnsServers = servers
        }

        return info
    }

    // MARK: - Writing (requires admin authorization)

    public static func apply(_ profile: Profile) throws {
        try ProfileValidator.validate(profile)

        let authRef = try authorize()
        defer { AuthorizationFree(authRef, [.destroyRights]) }

        guard let prefs = SCPreferencesCreateWithAuthorization(nil, "NetSwitch" as CFString, nil, authRef) else {
            throw NetworkClientError.preferencesLockFailed
        }
        guard SCPreferencesLock(prefs, true) else { throw NetworkClientError.preferencesLockFailed }
        defer { SCPreferencesUnlock(prefs) }

        guard let service = networkService(named: profile.service, in: prefs) else {
            throw NetworkClientError.serviceNotFound(profile.service)
        }
        guard let ipv4Protocol = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeIPv4) else {
            throw NetworkClientError.protocolUnavailable("IPv4")
        }

        var config: [String: Any] = [:]
        if profile.useDHCP {
            config[kSCPropNetIPv4ConfigMethod as String] = kSCValNetIPv4ConfigMethodDHCP
        } else {
            config[kSCPropNetIPv4ConfigMethod as String] = kSCValNetIPv4ConfigMethodManual
            config[kSCPropNetIPv4Addresses as String] = [profile.ipAddress]
            config[kSCPropNetIPv4SubnetMasks as String] = [profile.subnetMask]
            config[kSCPropNetIPv4Router as String] = profile.gateway
        }

        guard SCNetworkProtocolSetConfiguration(ipv4Protocol, config as CFDictionary) else {
            throw NetworkClientError.preferencesCommitFailed
        }

        try setDNS(profile.dnsServers, for: profile.service, prefs: prefs)

        guard SCPreferencesCommitChanges(prefs), SCPreferencesApplyChanges(prefs) else {
            throw NetworkClientError.preferencesCommitFailed
        }
    }

    public static func setDNS(_ servers: [String], for service: String) throws {
        for server in servers where !ProfileValidator.isIPv4(server) {
            throw ProfileValidationError.invalidIPv4(server, field: "DNS server")
        }
        let authRef = try authorize()
        defer { AuthorizationFree(authRef, [.destroyRights]) }

        guard let prefs = SCPreferencesCreateWithAuthorization(nil, "NetSwitch" as CFString, nil, authRef) else {
            throw NetworkClientError.preferencesLockFailed
        }
        guard SCPreferencesLock(prefs, true) else { throw NetworkClientError.preferencesLockFailed }
        defer { SCPreferencesUnlock(prefs) }

        try setDNS(servers, for: service, prefs: prefs)

        guard SCPreferencesCommitChanges(prefs), SCPreferencesApplyChanges(prefs) else {
            throw NetworkClientError.preferencesCommitFailed
        }
    }

    private static func setDNS(_ servers: [String], for service: String, prefs: SCPreferences) throws {
        guard let networkService = networkService(named: service, in: prefs) else {
            throw NetworkClientError.serviceNotFound(service)
        }
        guard let dnsProtocol = SCNetworkServiceCopyProtocol(networkService, kSCNetworkProtocolTypeDNS) else {
            throw NetworkClientError.protocolUnavailable("DNS")
        }
        let config: [String: Any] = servers.isEmpty ? [:] : [kSCPropNetDNSServerAddresses as String: servers]
        guard SCNetworkProtocolSetConfiguration(dnsProtocol, config as CFDictionary) else {
            throw NetworkClientError.preferencesCommitFailed
        }
    }

    // MARK: - Helpers

    private static func serviceID(for name: String) -> String? {
        guard let prefs = SCPreferencesCreate(nil, "NetSwitch" as CFString, nil),
              let service = networkService(named: name, in: prefs) else { return nil }
        return SCNetworkServiceGetServiceID(service) as String?
    }

    private static func networkService(named name: String, in prefs: SCPreferences) -> SCNetworkService? {
        guard let set = SCNetworkSetCopyCurrent(prefs),
              let services = SCNetworkSetCopyServices(set) as? [SCNetworkService] else { return nil }
        return services.first { (SCNetworkServiceGetName($0) as String?) == name }
    }

    private static func encryptionLabel(for security: CWSecurity) -> String {
        switch security {
        case .none: return "Open"
        case .WEP: return "WEP"
        case .wpaPersonal, .wpaPersonalMixed: return "WPA"
        case .wpa2Personal: return "WPA2"
        case .wpa3Personal: return "WPA3"
        case .wpa3Transition: return "WPA3 Transition"
        case .wpaEnterprise, .wpaEnterpriseMixed: return "WPA Enterprise"
        case .wpa2Enterprise: return "WPA2 Enterprise"
        case .wpa3Enterprise: return "WPA3 Enterprise"
        case .dynamicWEP: return "Dynamic WEP"
        @unknown default: return "Unknown"
        }
    }

    private static func bandLabel(for band: CWChannelBand?) -> String {
        guard let band else { return "" }
        switch band {
        case .band2GHz: return "2.4 GHz"
        case .band5GHz: return "5 GHz"
        case .bandUnknown: return ""
        @unknown default: return ""
        }
    }

    // NOTE: right name is unverified by me — see earlier caveats.
    private static func authorize() throws -> AuthorizationRef {
        var authRef: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &authRef) == errAuthorizationSuccess, let auth = authRef else {
            throw NetworkClientError.authorizationFailed(-1)
        }

        var status: OSStatus = errAuthorizationSuccess
        "system.preferences.network".withCString { name in
            var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
            withUnsafeMutablePointer(to: &item) { itemPtr in
                var rights = AuthorizationRights(count: 1, items: itemPtr)
                status = AuthorizationCopyRights(auth, &rights, nil, [.interactionAllowed, .extendRights, .preAuthorize], nil)
            }
        }

        guard status == errAuthorizationSuccess else {
            AuthorizationFree(auth, [.destroyRights])
            throw status == errAuthorizationCanceled ? NetworkClientError.authorizationDenied : NetworkClientError.authorizationFailed(status)
        }
        return auth
    }
}
