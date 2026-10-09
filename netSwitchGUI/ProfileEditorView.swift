import SwiftUI
import NetSwitchCore
import UniformTypeIdentifiers
import AppKit

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
    @State private var draggingDNSID: UUID? = nil

    private enum Field: Hashable { case name }
    @FocusState private var focusedField: Field?

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
                HStack(alignment: .center, spacing: 1) {
                    Text("Profile Name")
                        .font(.subheadline.weight(.medium))
                        .frame(width: 110, alignment: .leading)

                    LTRTextField(text: $name, placeholder: "Profile Name")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
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
                        placeholder: "192.168.100.40"
                    )
                    IPFieldRow(
                        title: "Subnet Mask",
                        text: $subnetMask,
                        placeholder: "255.255.255.0"
                    )
                    IPFieldRow(
                        title: "Gateway",
                        text: $gateway,
                        placeholder: "192.168.100.1"
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
                    ForEach(dnsServers, id: \.id) { entry in
                        dnsRow(id: entry.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
                        Image(systemName: "Wi-Fi")
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
        .frame(minWidth: 460, minHeight: 400)
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
            if profile == nil { focusedField = .name }
        }
    }

    // MARK: - DNS Rows

    private struct DNSRowContent: View {
        let id: UUID
        @Binding var value: String
        let ordinalPlaceholder: String
        let isValid: Bool
        @Binding var dnsServers: [DNSEntry]
        @Binding var draggingDNSID: UUID?

        @State private var showSuccessFlash = false

        var body: some View {
            HStack(spacing: 6) {
                // Left: ordinal label
                Text(ordinalPlaceholder)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)

                // Drag handle icon
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                    .accessibilityLabel("Reorder DNS")

                // Text field with placeholder and validation background
                ZStack(alignment: .leading) {
                    if value.isEmpty {
                        Text("DNS Server")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                    }

                    LTRTextField(text: $value, placeholder: "")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .background(
                    showSuccessFlash
                        ? Color.green.opacity(0.15)
                        : (
                            value.isEmpty
                                ? Color(nsColor: .textBackgroundColor)
                                : (isValid ? Color(nsColor: .textBackgroundColor) : Color.red.opacity(0.15))
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            value.isEmpty
                                ? Color(nsColor: .separatorColor)
                                : (isValid ? Color(nsColor: .separatorColor) : Color.red.opacity(0.5)),
                            lineWidth: 1
                        )
                )

                if !value.isEmpty && !isValid {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .help("Invalid IP address")
                }

                Spacer(minLength: 8)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dnsServers.removeAll { $0.id == id }
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red.opacity(0.85))
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .help("Remove DNS server")
            }
            .onDrag {
                draggingDNSID = id
                return NSItemProvider(object: id.uuidString as NSString)
            }
            .onDrop(of: [.text], delegate: DNSReorderDropDelegate(
                current: id,
                items: $dnsServers,
                dragging: $draggingDNSID
            ))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .onChange(of: value) { oldValue, newValue in
                let wasValid = oldValue.isEmpty || validIP(oldValue)
                let isNowValid = newValue.isEmpty || validIP(newValue)
                if !wasValid && isNowValid && !newValue.isEmpty {
                    showSuccessFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if validIP(value) { showSuccessFlash = false } else { showSuccessFlash = false }
                    }
                } else if !isNowValid {
                    showSuccessFlash = false
                }
            }
        }
    }

    private func dnsRow(id: UUID) -> some View {
        let value = dnsServers.first { $0.id == id }?.value ?? ""
        let ordinalPlaceholder: String = {
            if let idx = dnsServers.firstIndex(where: { $0.id == id }) {
                switch idx {
                case 0: return "Primary"
                case 1: return "Secondary"
                case 2: return "Tertiary"
                case 3: return "Quaternary"
                default: return "DNS \(idx + 1)"
                }
            }
            return "DNS"
        }()

        let dnsIsValid = value.isEmpty || validIP(value)

        return DNSRowContent(
            id: id,
            value: binding(for: id),
            ordinalPlaceholder: ordinalPlaceholder,
            isValid: dnsIsValid,
            dnsServers: $dnsServers,
            draggingDNSID: $draggingDNSID
        )
    }

    private func positionLabel(for position: Int) -> String {
        switch position {
        case 0: "Primary"
        case 1: "Secondary"
        default: "\(position + 1)"
        }
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

    // MARK: - Drag & Drop Reordering for DNS
    private struct DNSReorderDropDelegate: DropDelegate {
        let current: UUID
        @Binding var items: [DNSEntry]
        @Binding var dragging: UUID?

        func dropEntered(info: DropInfo) {
            guard let dragging, dragging != current,
                  let fromIndex = items.firstIndex(where: { $0.id == dragging }),
                  let toIndex = items.firstIndex(where: { $0.id == current })
            else { return }

            if items.indices.contains(fromIndex) && items.indices.contains(toIndex) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    let item = items.remove(at: fromIndex)
                    items.insert(item, at: toIndex)
                }
                self.dragging = current
            }
        }

        func performDrop(info: DropInfo) -> Bool {
            dragging = nil
            return true
        }
    }
}

// MARK: - IP Field Row (with live validation feedback)

private struct IPFieldRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    @State private var touched = false
    @State private var showSuccessFlash = false

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(width: 110, alignment: .leading)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                }

                LTRTextField(text: $text, placeholder: "")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
            }
            .background(
                showSuccessFlash
                    ? Color.green.opacity(0.15)
                    : (
                        text.isEmpty
                            ? Color(nsColor: .textBackgroundColor)
                            : (validIP(text) ? Color(nsColor: .textBackgroundColor) : Color.red.opacity(0.15))
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        text.isEmpty
                            ? Color(nsColor: .separatorColor)
                            : (validIP(text) ? Color(nsColor: .separatorColor) : Color.orange.opacity(0.5)),
                        lineWidth: 1
                    )
            )

            if touched, !text.isEmpty, !validIP(text) {
                Text("Enter a valid IPv4 address.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onChange(of: text) { oldValue, newValue in
            let wasValid = validIP(oldValue)
            let isNowValid = validIP(newValue)
            if !wasValid && isNowValid {
                showSuccessFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Only clear if still valid to avoid flicker when user keeps editing
                    if validIP(text) {
                        showSuccessFlash = false
                    } else {
                        showSuccessFlash = false
                    }
                }
            } else if !isNowValid {
                // Ensure we don't show success when invalid
                showSuccessFlash = false
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.15), value: text)
    }
}

// MARK: - Left-to-Right, Left-Aligned Text Field (macOS)

private struct LTRTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        field.focusRingType = .none
        field.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.alignment = .left
        field.baseWritingDirection = .leftToRight
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        nsView.alignment = .left
        nsView.baseWritingDirection = .leftToRight
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LTRTextField
        init(_ parent: LTRTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

