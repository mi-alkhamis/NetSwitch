import Foundation

public struct NetworkInfo: Equatable, Sendable {
    public var service: String
    public var ipAddress: String
    public var subnetMask: String
    public var gateway: String
    public var dnsServers: [String]

    public init(service: String, ipAddress: String = "—", subnetMask: String = "—", gateway: String = "—", dnsServers: [String] = []) {
        self.service = service
        self.ipAddress = ipAddress
        self.subnetMask = subnetMask
        self.gateway = gateway
        self.dnsServers = dnsServers
    }
}

public enum NetworkClientError: LocalizedError {
    case commandFailed(String, String, Int32)

    public var errorDescription: String? {
        switch self {
        case let .commandFailed(command, output, status): "\(command) failed (exit \(status)): \(output.isEmpty ? "no output" : output)"
        }
    }
}

public enum NetworkClient {
    private static let networksetup = "/usr/sbin/networksetup"

    public static func services() throws -> [String] {
        let output = try run(["-listallnetworkservices"])
        return output.split(separator: "\n").map(String.init).filter { !$0.hasPrefix("An asterisk") }.map { $0.hasPrefix("*") ? String($0.dropFirst()) : $0 }
    }

    public static func hardwarePorts() throws -> String {
        try run(["-listallhardwareports"])
    }

    public static func preferredWirelessNetworks(for device: String) throws -> String {
        try run(["-listpreferredwirelessnetworks", device])
    }

    public static func rawInfo(for service: String) throws -> String {
        try run(["-getinfo", service])
    }

    public static func info(for service: String) throws -> NetworkInfo {
        let output = try rawInfo(for: service)
        var info = NetworkInfo(service: service)
        for line in output.split(separator: "\n").map(String.init) {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "IP address": info.ipAddress = parts[1].isEmpty ? "—" : parts[1]
            case "Subnet mask": info.subnetMask = parts[1].isEmpty ? "—" : parts[1]
            case "Router": info.gateway = parts[1].isEmpty ? "—" : parts[1]
            default: break
            }
        }
        let dns = try? run(["-getdnsservers", service])
        if let dns, !dns.contains("There aren't any") { info.dnsServers = dns.split(separator: "\n").map(String.init) }
        return info
    }

    public static func apply(_ profile: Profile) throws {
        try ProfileValidator.validate(profile)
        if profile.useDHCP {
            _ = try runElevated(["-setdhcp", profile.service])
        } else {
            _ = try runElevated(["-setmanual", profile.service, profile.ipAddress, profile.subnetMask, profile.gateway])
        }
        try setDNS(profile.dnsServers, for: profile.service)
    }

    /// Change DNS without changing the service's DHCP/static addressing mode.
    public static func setDNS(_ servers: [String], for service: String) throws {
        for server in servers where !ProfileValidator.isIPv4(server) {
            throw ProfileValidationError.invalidIPv4(server, field: "DNS server")
        }
        _ = try runElevated(["-setdnsservers", service] + (servers.isEmpty ? ["Empty"] : servers))
    }

    private static func run(_ args: [String]) throws -> String { try launch(networksetup, args) }

    private static func runElevated(_ args: [String]) throws -> String {
        // Keep the command construction consistent with the previously verified CLI.
        // networksetup arguments are validated profile values or service names; quote
        // each as a shell argument before embedding the command in AppleScript.
        let command = ([networksetup] + args).map { "\"" + $0.replacingOccurrences(of: "\"", with: "\\\"") + "\"" }.joined(separator: " ")
        let script = "do shell script \"\(command.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        return try launch("/usr/bin/osascript", ["-e", script])
    }

    private static func launch(_ executable: String, _ args: [String]) throws -> String {
        let task = Process(); task.executableURL = URL(fileURLWithPath: executable); task.arguments = args
        let stdout = Pipe(), stderr = Pipe(); task.standardOutput = stdout; task.standardError = stderr
        do { try task.run() } catch { throw NetworkClientError.commandFailed(executable, error.localizedDescription, -1) }
        task.waitUntilExit()
        let output = [stdout, stderr].compactMap { String(data: $0.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n")
        guard task.terminationStatus == 0 else { throw NetworkClientError.commandFailed("\(executable) \(args.joined(separator: " "))", output, task.terminationStatus) }
        return output
    }
}
