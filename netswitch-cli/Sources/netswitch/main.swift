import Foundation

// MARK: - Profile spec parsing (shared by `profile add` and `profile edit`)

/// Partial profile spec pulled out of `--service`, `--dhcp/--static`, `--ip`,
/// `--subnet`, `--gateway`, `--dns`, `--dns-empty`. All optional so the same
/// parser serves "create fully" and "edit partially".
struct Spec {
    var service: String?
    var useDHCP: Bool?
    var ip: String?
    var subnet: String?
    var gateway: String?
    var dns: [String]?
}

func parseSpec(_ args: [String]) -> Spec {
    var s = Spec()
    var i = 0
    func val(_ flag: String) -> String {
        i += 1
        guard i < args.count else { fail("Expected a value after \(flag).") }
        return args[i]
    }
    while i < args.count {
        switch args[i] {
        case "--service":   s.service = val("--service")
        case "--dhcp", "--static":
            guard s.useDHCP == nil else { fail("Use only one of --dhcp or --static.") }
            s.useDHCP = args[i] == "--dhcp"
        case "--ip":        s.ip = val("--ip")
        case "--subnet":    s.subnet = val("--subnet")
        case "--gateway":   s.gateway = val("--gateway")
        case "--dns":       s.dns = parseDns(val("--dns"))
        case "--dns-empty": s.dns = []
        default:            fail("Unknown option: \(args[i])")
        }
        i += 1
    }
    return s
}

/// Split a DNS string on commas and/or whitespace: "8.8.8.8, 1.1.1.1" → two entries.
func parseDns(_ raw: String) -> [String] {
    let servers = raw.split { $0 == "," || $0.isWhitespace }.map(String.init)
    guard !servers.isEmpty else { fail("--dns needs at least one server; use --dns-empty to clear DNS.") }
    return servers
}

/// Build a brand-new Profile from a spec. Requires a complete static config when
/// `--static` is given.
func specToProfile(_ spec: Spec, name: String) -> Profile {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        fail("Profile name cannot be empty.")
    }
    if let service = spec.service, service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        fail("Service name cannot be empty.")
    }
    let useDHCP = spec.useDHCP ?? true
    let ip = spec.ip ?? ""
    let subnet = spec.subnet ?? ""
    let gateway = spec.gateway ?? ""
    let dns = spec.dns ?? []

    if !useDHCP {
        guard !ip.isEmpty else { fail("--static requires --ip <address>.") }
        guard !subnet.isEmpty else { fail("--static requires --subnet <mask>.") }
        guard !gateway.isEmpty else { fail("--static requires --gateway <router>.") }
    }
    if useDHCP && (spec.ip != nil || spec.subnet != nil || spec.gateway != nil) {
        fail("--dhcp cannot be combined with --ip, --subnet, or --gateway.")
    }
    if !ip.isEmpty { requireIP(ip, label: "IP address") }
    if !subnet.isEmpty { requireIP(subnet, label: "Subnet mask") }
    if !gateway.isEmpty { requireIP(gateway, label: "Gateway") }
    dns.forEach { requireIP($0, label: "DNS server") }

    return Profile(
        name: name,
        service: spec.service ?? "Wi-Fi",
        useDHCP: useDHCP,
        ipAddress: ip,
        subnetMask: subnet,
        gateway: gateway,
        dnsServers: dns
    )
}

/// Apply only the fields present in `spec` onto an existing profile (for `profile edit`).
func merge(_ base: Profile, with spec: Spec) -> Profile {
    var p = base
    if let v = spec.service { p.service = v }
    if let v = spec.useDHCP { p.useDHCP = v }
    if let v = spec.ip { p.ipAddress = v }
    if let v = spec.subnet { p.subnetMask = v }
    if let v = spec.gateway { p.gateway = v }
    if let v = spec.dns { p.dnsServers = v }

    if p.useDHCP && (spec.ip != nil || spec.subnet != nil || spec.gateway != nil) {
        fail("A DHCP profile cannot include --ip, --subnet, or --gateway.")
    }
    if spec.useDHCP == true {
        p.ipAddress = ""
        p.subnetMask = ""
        p.gateway = ""
    }
    if !p.useDHCP {
        guard !p.ipAddress.isEmpty else { fail("Static profile needs --ip (currently empty).") }
        guard !p.subnetMask.isEmpty else { fail("Static profile needs --subnet.") }
        guard !p.gateway.isEmpty else { fail("Static profile needs --gateway.") }
    }
    if p.service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        fail("Service name cannot be empty.")
    }
    if !p.ipAddress.isEmpty { requireIP(p.ipAddress, label: "IP address") }
    if !p.subnetMask.isEmpty { requireIP(p.subnetMask, label: "Subnet mask") }
    if !p.gateway.isEmpty { requireIP(p.gateway, label: "Gateway") }
    p.dnsServers.forEach { requireIP($0, label: "DNS server") }
    return p
}

// MARK: - Applying a profile to a real service

func applyProfile(_ profile: Profile) {
    let service = profile.service

    // 1) Addressing (DHCP vs manual).
    if profile.useDHCP {
        check(Net.run(["-setdhcp", service]), "set DHCP")
    } else {
        check(
            Net.run(["-setmanual", service, profile.ipAddress, profile.subnetMask, profile.gateway]),
            "set manual IP"
        )
    }

    // 2) DNS. Empty list → "Empty" (clears), per networksetup's convention.
    if profile.dnsServers.isEmpty {
        check(Net.run(["-setdnsservers", service, "Empty"]), "clear DNS")
    } else {
        check(Net.run(["-setdnsservers", service] + profile.dnsServers), "set DNS")
    }

    print("✅ Applied profile '\(profile.name)' → service '\(service)'")
}

// MARK: - CLI dispatch

let args = CommandLine.arguments
let argv = args
var i = 1 // index into argv; argv[0] is the program name

func nextArg(_ msg: String = "missing argument") -> String {
    i += 1
    guard i < argv.count else { fail(msg) }
    return argv[i]
}

func remaining() -> [String] {
    Array(argv.dropFirst(i + 1))
}

func usage() -> Never {
    print("""
    NetSwitch CLI — Phase 1 test harness

    Read-only (no admin needed):
      netswitch services                 list network services (networksetup -listallnetworkservices)
      netswitch hardware                 list hardware ports + device names (find your Wi-Fi device)
      netswitch wifi <device>            preferred Wi-Fi networks, e.g. `netswitch wifi en0`
      netswitch info <service>           current IPv4/subnet/router/DNS for a service

    Set live config (admin — run with `sudo` or let the osascript prompt fire):
      netswitch set network <service> --dhcp
      netswitch set network <service> --ip <ip> --subnet <mask> --gateway <router>
      netswitch set dns <service> <dns1> [dns2 ...]
      netswitch set dns <service> --empty

    Saved profiles (~/Library/Application Support/NetSwitch/profiles.json):
      netswitch profile add <name> [--service Wi-Fi] [--dhcp | --static --ip .. --subnet .. --gateway ..] [--dns a,b] [--dns-empty]
      netswitch profile list
      netswitch profile show <name>
      netswitch profile edit <name> [--dhcp | --static --ip .. --subnet .. --gateway ..] [--dns a,b] [--dns-empty] [--service ..]
      netswitch profile delete <name>    (alias: remove)
      netswitch profile apply <name>    apply a saved profile to its service (admin)

    Examples:
      netswitch profile add home --dhcp --dns 1.1.1.1,1.0.0.1
      netswitch profile add office --service Wi-Fi --static --ip 10.0.1.50 --subnet 255.255.255.0 --gateway 10.0.1.1 --dns 8.8.8.8,8.8.4.4
      sudo netswitch profile apply home
      netswitch info Wi-Fi
    """)
    exit(0)
}

guard i < argv.count else { usage() }

switch argv[i] {
case "--help", "-h", "help": usage()

// MARK: read-only
case "services":
    print(Net.runReadonly(["-listallnetworkservices"]).output)

case "hardware":
    print(Net.runReadonly(["-listallhardwareports"]).output)

case "wifi":
    let device = nextArg("usage: netswitch wifi <device>  (e.g. en0 — see `netswitch hardware`)")
    print(Net.runReadonly(["-listpreferredwirelessnetworks", device]).output)

case "info":
    let service = nextArg("usage: netswitch info <service>  (e.g. Wi-Fi — see `netswitch services`)")
    print(Net.runReadonly(["-getinfo", service]).output)

// MARK: set live config
case "set":
    let what = nextArg("usage: netswitch set <network|dns> ...")
    switch what {
    case "network":
        let service = nextArg("usage: netswitch set network <service> [--dhcp | --ip .. --subnet .. --gateway ..]")
        let spec = parseSpec(remaining())
        guard spec.service == nil, spec.dns == nil else {
            fail("set network accepts only --dhcp or --ip, --subnet, --gateway.")
        }
        guard let useDHCP = spec.useDHCP else {
            fail("Specify --dhcp or a complete manual configuration.")
        }
        if useDHCP {
            guard spec.ip == nil, spec.subnet == nil, spec.gateway == nil else {
                fail("--dhcp cannot be combined with --ip, --subnet, or --gateway.")
            }
            check(Net.run(["-setdhcp", service]), "set DHCP")
        } else {
            guard let ip = spec.ip, !ip.isEmpty else { fail("manual requires --ip") }
            guard let subnet = spec.subnet, !subnet.isEmpty else { fail("manual requires --subnet") }
            guard let gateway = spec.gateway, !gateway.isEmpty else { fail("manual requires --gateway") }
            requireIP(ip, label: "IP address")
            requireIP(subnet, label: "Subnet mask")
            requireIP(gateway, label: "Gateway")
            check(Net.run(["-setmanual", service, ip, subnet, gateway]), "set manual IP")
        }
        print("✅ network for '\(service)' → \(useDHCP ? "DHCP" : "manual \(spec.ip ?? "")")")

    case "dns":
        let service = nextArg("usage: netswitch set dns <service> <dns1> [dns2 ...]  |  --empty")
        let rest = remaining()
        if rest == ["--empty"] || rest == ["empty"] {
            check(Net.run(["-setdnsservers", service, "Empty"]), "clear DNS")
            print("✅ DNS for '\(service)' → cleared")
        } else {
            guard !rest.isEmpty else { fail("no DNS servers given; use --empty to clear.") }
            rest.forEach { requireIP($0, label: "DNS server") }
            check(Net.run(["-setdnsservers", service] + rest), "set DNS")
            print("✅ DNS for '\(service)' → \(rest.joined(separator: ", "))")
        }

    default:
        fail("netswitch set: unknown target '\(what)'. Use 'network' or 'dns'.")
    }

// MARK: saved profiles
case "profile":
    let sub = nextArg("usage: netswitch profile <add|list|show|edit|delete|apply> ...")
    let store = ProfileStore()
    switch sub {
    case "add":
        let name = nextArg("usage: netswitch profile add <name> [options]")
        if store.find(name: name) != nil { fail("A profile named '\(name)' already exists.") }
        let p = specToProfile(parseSpec(remaining()), name: name)
        store.add(p)
        print("✅ added profile '\(p.name)': \(p.summary)")

    case "list":
        if store.profiles.isEmpty {
            print("No profiles yet. Add one: netswitch profile add <name> ...")
        } else {
            print("Profiles (\(store.profiles.count)): file://\(store.fileURL.path)")
            for (n, p) in store.profiles.enumerated() {
                print("  \(n + 1). \(p.summary)")
            }
        }

    case "show":
        let name = nextArg("usage: netswitch profile show <name>")
        guard let p = store.find(name: name) else { fail("No profile named '\(name)'.") }
        print(p.summary)
        print("  id:         \(p.id.uuidString)")
        print("  service:    \(p.service)")
        print("  mode:       \(p.useDHCP ? "DHCP" : "Manual")")
        if !p.useDHCP {
            print("  ip:         \(p.ipAddress)")
            print("  subnet:     \(p.subnetMask)")
            print("  gateway:    \(p.gateway)")
        }
        print("  dns:        \(p.dnsServers.isEmpty ? "(none)" : p.dnsServers.joined(separator: ", "))")

    case "edit":
        let name = nextArg("usage: netswitch profile edit <name> [options]")
        guard let existing = store.find(name: name) else { fail("No profile named '\(name)'.") }
        let spec = parseSpec(remaining())
        guard spec.service != nil || spec.useDHCP != nil || spec.ip != nil || spec.subnet != nil || spec.gateway != nil || spec.dns != nil else {
            fail("profile edit needs at least one option.")
        }
        var updated = existing
        updated.id = existing.id // keep stable id; merge preserves it
        updated = merge(existing, with: spec)
        store.update(updated)
        print("✅ updated profile '\(updated.name)': \(updated.summary)")

    case "delete", "remove":
        let name = nextArg("usage: netswitch profile delete <name>")
        store.remove(name: name)

    case "apply":
        let name = nextArg("usage: netswitch profile apply <name>")
        guard let p = store.find(name: name) else { fail("No profile named '\(name)'.") }
        applyProfile(p)

    default:
        fail("netswitch profile: unknown subcommand '\(sub)'. Use add|list|show|edit|delete|apply.")
    }

default:
    fail("Unknown command '\(argv[i])'. Try `netswitch --help`.")
}
