import Foundation
import NetSwitchCore

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    exit(1)
}

/// Runs `work`, exiting with its error message on failure.
///
/// `@discardableResult` because most callers use this purely for the error handling — several wrap
/// functions that return a value the CLI has no use for, such as `NetworkClient.apply`'s read-back
/// of the resulting `NetworkInfo`.
@discardableResult
func attempt<T>(_ work: () throws -> T) -> T {
    do { return try work() } catch { fail(error.localizedDescription) }
}

struct ProfileOptions {
    var service: String?
    var useDHCP: Bool?
    var ip: String?
    var subnet: String?
    var gateway: String?
    var dns: [String]?
}

func parseOptions(_ values: [String]) -> ProfileOptions {
    var result = ProfileOptions(); var index = 0
    func next(_ flag: String) -> String { index += 1; guard index < values.count else { fail("Expected value after \(flag).") }; return values[index] }
    while index < values.count {
        switch values[index] {
        case "--service": result.service = next("--service")
        case "--dhcp", "--static":
            guard result.useDHCP == nil else { fail("Use only one of --dhcp or --static.") }
            result.useDHCP = values[index] == "--dhcp"
        case "--ip": result.ip = next("--ip")
        case "--subnet": result.subnet = next("--subnet")
        case "--gateway": result.gateway = next("--gateway")
        case "--dns":
            let servers = next("--dns").split { $0 == "," || $0.isWhitespace }.map(String.init)
            guard !servers.isEmpty else { fail("--dns needs at least one server; use --dns-empty to clear DNS.") }
            result.dns = (result.dns ?? []) + servers
        case "--dns-empty": result.dns = []
        default: fail("Unknown option: \(values[index])")
        }
        index += 1
    }
    return result
}

func profile(named name: String, options: ProfileOptions, base: Profile? = nil) -> Profile {
    var value = base ?? Profile(name: name)
    value.name = name
    if let service = options.service { value.service = service }
    if let useDHCP = options.useDHCP { value.useDHCP = useDHCP }
    if let ip = options.ip { value.ipAddress = ip }
    if let subnet = options.subnet { value.subnetMask = subnet }
    if let gateway = options.gateway { value.gateway = gateway }
    if let dns = options.dns { value.dnsServers = dns }
    if value.useDHCP {
        guard options.ip == nil, options.subnet == nil, options.gateway == nil else {
            fail("A DHCP profile cannot include --ip, --subnet, or --gateway.")
        }
        value.ipAddress = ""; value.subnetMask = ""; value.gateway = ""
    }
    attempt { try ProfileValidator.validate(value) }
    return value
}

func store() -> ProfileStore {
    attempt {
        if let directory = ProcessInfo.processInfo.environment["NETSWITCH_PROFILES_DIR"], !directory.isEmpty {
            return try ProfileStore(fileURL: URL(fileURLWithPath: directory, isDirectory: true).appendingPathComponent("profiles.json"))
        }
        // Preserve the committed CLI location so existing profiles remain available.
        return try ProfileStore(directoryName: "NetSwitch")
    }
}

func help() -> Never {
    print("""
    NetSwitch CLI — Core test harness

    Read-only (no admin needed):
      netswitch services                 list network services
      netswitch hardware                 list hardware ports and device names
      netswitch wifi <device>            preferred Wi-Fi networks (for example, en0)
      netswitch info <service>           current SSID/IPv4/subnet/router information

    Set live config (admin prompt):
      netswitch set network <service> --dhcp
      netswitch set network <service> --static --ip <ip> --subnet <mask> --gateway <router>
      netswitch set dns <service> <dns1> [dns2 ...]
      netswitch set dns <service> --empty

    Saved profiles (~/Library/Application Support/NetSwitch/profiles.json):
      netswitch profile add <name> [--service Wi-Fi] [--dhcp | --static --ip .. --subnet .. --gateway ..] [--dns a,b]
      netswitch profile list
      netswitch profile show <name>
      netswitch profile edit <name> [options]
      netswitch profile delete <name>    (alias: remove)
      netswitch profile apply <name>
    """)
    exit(0)
}

let args = CommandLine.arguments
guard args.count > 1 else { help() }
func arg(_ index: Int, _ usage: String) -> String { guard args.count > index else { fail(usage) }; return args[index] }
func rest(_ index: Int) -> [String] { Array(args.dropFirst(index)) }

switch args[1] {
case "help", "--help", "-h": help()
case "services": attempt { try NetworkClient.services().forEach { print($0) } }
case "hardware": attempt { print(try NetworkClient.hardwarePorts()) }
case "wifi": attempt { print(try NetworkClient.preferredWirelessNetworks(for: arg(2, "usage: netswitch wifi <device>  (e.g. en0 — see netswitch hardware)"))) }
case "info":
    let value = attempt { try NetworkClient.info(for: arg(2, "usage: netswitch info <service>  (e.g. Wi-Fi — see netswitch services)")) }
    print("SSID:         \(value.ssid.isEmpty ? "(not connected)" : value.ssid)")
    print("IP address:   \(value.ipAddress)")
    print("Subnet mask:  \(value.subnetMask)")
    print("Router:       \(value.gateway)")
    print("DNS servers:  \(value.dnsServers.isEmpty ? "(none)" : value.dnsServers.joined(separator: ", "))")
case "set":
    let kind = arg(2, "usage: netswitch set <network|dns> <service> ...")
    let service = arg(3, "usage: netswitch set \(kind) <service> ...")
    if kind == "network" {
        let options = parseOptions(rest(4)); guard options.useDHCP != nil else { fail("Specify --dhcp or --static.") }
        attempt { try NetworkClient.apply(profile(named: "temporary", options: ProfileOptions(service: service, useDHCP: options.useDHCP, ip: options.ip, subnet: options.subnet, gateway: options.gateway))) }
        print("✅ Updated network configuration for '\(service)'.")
    } else if kind == "dns" {
        let values = rest(4); let dns = values == ["--empty"] ? [] : values
        guard values == ["--empty"] || !dns.isEmpty else { fail("Use DNS servers or --empty.") }
        attempt { try NetworkClient.setDNS(dns, for: service) }
        print("✅ DNS for '\(service)' → \(dns.isEmpty ? "cleared" : dns.joined(separator: ", "))")
    } else { fail("Unknown set target: \(kind)") }
case "profile":
    let action = arg(2, "usage: netswitch profile <add|list|show|edit|delete|apply>"); let profiles = store()
    switch action {
    case "add": let value = profile(named: arg(3, "usage: netswitch profile add <name>"), options: parseOptions(rest(4))); attempt { try profiles.add(value) }; print("✅ added profile '\(value.name)': \(value.summary)")
    case "list":
        if profiles.profiles.isEmpty { print("No profiles yet. Add one: netswitch profile add <name> ...") }
        else { print("Profiles (\(profiles.profiles.count)): file://\(profiles.fileURL.path)"); for (index, value) in profiles.profiles.enumerated() { print("  \(index + 1). \(value.summary)") } }
    case "show":
        let name = arg(3, "usage: netswitch profile show <name>"); guard let value = profiles.find(name: name) else { fail("No profile named '\(name)'.") }
        print("\(value.summary)\n  id:         \(value.id.uuidString)\n  service:    \(value.service)\n  mode:       \(value.useDHCP ? "DHCP" : "Manual")\n  dns:        \(value.dnsServers.isEmpty ? "(none)" : value.dnsServers.joined(separator: ", "))")
    case "edit": let name = arg(3, "usage: netswitch profile edit <name>"); guard let base = profiles.find(name: name) else { fail("No profile named '\(name)'.") }; let value = profile(named: name, options: parseOptions(rest(4)), base: base); attempt { try profiles.update(value) }; print("✅ updated profile '\(value.name)': \(value.summary)")
    case "delete", "remove": let name = arg(3, "usage: netswitch profile delete <name>"); attempt { try profiles.delete(name: name) }; print("Removed '\(name)'.")
    case "apply": let name = arg(3, "usage: netswitch profile apply <name>"); guard let value = profiles.find(name: name) else { fail("No profile named '\(name)'.") }; attempt { try NetworkClient.apply(value) }; print("✅ Applied profile '\(value.name)' → service '\(value.service)'")
    default: fail("Unknown profile action: \(action)")
    }
default: fail("Unknown command. Try netswitch --help.")
}
