import SwiftUI
import NetSwitchCore

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let profile: Profile?
    let onSave: (Profile) -> Void

    /// A DNS row with stable identity.
    ///
    /// The rows used to be driven by `ForEach(dnsServers.indices, id: \.self)` with
    /// `$dnsServers[index]` bindings, which crashes with "Index out of range" when a row is removed
    /// while SwiftUI still holds a binding to the old index.
    private struct DNSEntry: Identifiable, Equatable {
        let id = UUID()
        var value: String
    }

    @State private var name = ""
    @State private var useDHCP = true
    @State private var ipAddress = ""
    @State private var subnetMask = ""
    @State private var gateway = ""
    @State private var dnsServers: [DNSEntry] = []
    @State private var showAdvanced = false

    private var isEditing: Bool {
        profile != nil
    }

    /// The service an edit must preserve. `saveProfile` used to hardcode "Wi-Fi", which silently
    /// converted an Ethernet profile (creatable via the CLI's `--service`) into a Wi-Fi one.
    private var service: String {
        profile?.service ?? AppState.defaultService
    }

    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if !useDHCP {
            guard validIP(ipAddress), validIP(subnetMask), validIP(gateway) else { return false }
        }
        return dnsServers.allSatisfy { $0.value.isEmpty || validIP($0.value) }
    }

    var body: some View {
        Form {
            // MARK: Profile Name
            Section {
                TextField("Profile Name", text: $name)
                    .font(.body)
            } header: {
                Label("Profile", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.subheadline.weight(.semibold))
            }

            // MARK: Configuration Mode
            Section {
                Picker("Mode", selection: $useDHCP) {
                    Text("DHCP (Automatic)")
                        .tag(true)
                    Text("Static IP (Manual)")
                        .tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 2)

                if useDHCP {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Network settings will be configured automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            } header: {
                Label("Configuration", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
            }

            // MARK: Static IP Fields (animated show/hide)
            if !useDHCP {
                Section {
                    IPFieldRow(
                        title: "IP Address",
                        text: $ipAddress,
                        placeholder: "10.0.1.50"
                    )
                    IPFieldRow(
                        title: "Subnet Mask",
                        text: $subnetMask,
                        placeholder: "255.255.255.0"
                    )
                    IPFieldRow(
                        title: "Gateway",
                        text: $gateway,
                        placeholder: "10.0.1.1"
                    )
                } header: {
                    Label("Static IP", systemImage: "network")
                        .font(.subheadline.weight(.semibold))
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }

            // MARK: DNS Servers (reorderable)
            Section {
                VStack(spacing: 6) {
                    ForEach(Array(dnsServers.enumerated()), id: \.element.id) { position, entry in
                        dnsRow(id: entry.id, position: position)
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dnsServers.append(DNSEntry(value: ""))
                    }
                } label: {
                    Label("Add DNS Server", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderless)
            } header: {
                Label("DNS Servers", systemImage: "server.rack")
                    .font(.subheadline.weight(.semibold))
            } footer: {
                Label(
                    "Order matters — the first server is queried first. Leave empty to use system default.",
                    systemImage: "arrow.up.arrow.down"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // MARK: Advanced (hidden by default for v0.1)
            Section {
                DisclosureGroup(isExpanded: $showAdvanced) {
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text("Network Service")
                        Spacer()
                        Text(service)
                            .foregroundStyle(.secondary)
                            .font(.callout.weight(.medium))
                        // TODO: Replace with Picker when multi-service support is added
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label("Advanced", systemImage: "gearshape")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .animation(.easeInOut(duration: 0.25), value: useDHCP)
        .animation(.easeInOut(duration: 0.2), value: showAdvanced)
        .navigationTitle(isEditing ? "Edit Profile" : "New Profile")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveProfile()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text(isEditing ? "Save Changes" : "Save Profile")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .onAppear {
            loadProfile()
        }
    }

    // MARK: - DNS Rows

    private func dnsRow(id: UUID, position: Int) -> some View {
        let value = dnsServers.first { $0.id == id }?.value ?? ""

        return HStack(spacing: 10) {
            // Explicit arrows rather than a drag handle: `.onMove` only fires inside a `List`, so
            // the handle this replaces never did anything.
            VStack(spacing: 1) {
                Button {
                    move(id: id, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(position == 0)
                .help("Move up")

                Button {
                    move(id: id, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(position == dnsServers.count - 1)
                .help("Move down")
            }
            .buttonStyle(.plain)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)

            Image(systemName: "server.rack")
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 16)

            TextField("DNS Server", text: binding(for: id))
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)

            if !value.isEmpty && !validIP(value) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .help("Invalid IP address")
            } else if !value.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            Button {
                removeDNSServer(id: id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red.opacity(0.85))
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .help("Remove DNS server")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    /// Looks the row up by id on every access, so a stale index can never be used to subscript.
    private func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { dnsServers.first { $0.id == id }?.value ?? "" },
            set: { newValue in
                guard let index = dnsServers.firstIndex(where: { $0.id == id }) else { return }
                dnsServers[index].value = newValue
            }
        )
    }

    // MARK: - Data

    private func loadProfile() {
        guard let profile else { return }
        name = profile.name
        useDHCP = profile.useDHCP
        ipAddress = profile.ipAddress
        subnetMask = profile.subnetMask
        gateway = profile.gateway
        dnsServers = profile.dnsServers.map { DNSEntry(value: $0) }
    }

    private func saveProfile() {
        let cleanDNS = dnsServers
            .map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && validIP($0) }

        let savedProfile = Profile(
            id: profile?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            service: service,
            useDHCP: useDHCP,
            ipAddress: useDHCP ? "" : ipAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            subnetMask: useDHCP ? "" : subnetMask.trimmingCharacters(in: .whitespacesAndNewlines),
            gateway: useDHCP ? "" : gateway.trimmingCharacters(in: .whitespacesAndNewlines),
            dnsServers: cleanDNS
        )

        onSave(savedProfile)
        dismiss()
    }

    private func removeDNSServer(id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            dnsServers.removeAll { $0.id == id }
        }
    }

    private func move(id: UUID, by offset: Int) {
        guard let index = dnsServers.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard dnsServers.indices.contains(target) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            dnsServers.swapAt(index, target)
        }
    }
}

// MARK: - IP Field Row (with live validation feedback)

private struct IPFieldRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if !text.isEmpty {
                    Image(systemName: validIP(text) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(validIP(text) ? .green : .orange)
                        .font(.caption)
                        .transition(.opacity)
                }
            }

            TextField(placeholder, text: $text)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            text.isEmpty
                                ? Color(nsColor: .separatorColor)
                                : (validIP(text) ? Color.green.opacity(0.4) : Color.orange.opacity(0.5)),
                            lineWidth: 1
                        )
                )
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.15), value: text)
    }
}
