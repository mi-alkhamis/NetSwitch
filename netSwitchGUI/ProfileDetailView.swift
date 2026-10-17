import SwiftUI
import NetSwitchCore
import UniformTypeIdentifiers

struct ProfileDetailView: View {
    @EnvironmentObject private var appState: AppState

    let profile: Profile

    @State private var isEditing = false
    @State private var profileName = ""
    @State private var selectedService = AppState.defaultService
    @State private var useDHCP = true
    @State private var ipAddress = ""
    @State private var subnetMask = ""
    @State private var gateway = ""
    @State private var dnsServers: [DNSDraft] = []
    @State private var draggingDNSID: UUID?

    private struct DNSDraft: Identifiable {
        let id = UUID()
        var value: String
    }

    private var isLastApplied: Bool {
        appState.lastAppliedProfile == profile
    }

    private var displayedUseDHCP: Bool {
        isEditing ? useDHCP : profile.useDHCP
    }

    private var isValid: Bool {
        guard !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !selectedService.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if !useDHCP && (!validIP(ipAddress) || !validIP(subnetMask) || !validIP(gateway)) {
            return false
        }
        return dnsServers.allSatisfy { $0.value.isEmpty || validIP($0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                profileHeader
                ipSection
                dnsSection
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.975, green: 0.981, blue: 0.991))
        .navigationTitle("")
        .onChange(of: profile.id) { _, _ in
            isEditing = false
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isEditing {
                    Button("Cancel", action: cancelEditing)
                    Button("Save Changes", action: saveChanges)
                        .disabled(!isValid)
                } else {
                    Button {
                        beginEditing()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .help("Edit Profile")

                    Button("Apply") {
                        if !isLastApplied {
                            appState.apply(profile)
                        }
                    }
                    .disabled(isLastApplied || appState.isApplying)
                }
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: displayedUseDHCP ? "arrow.triangle.2.circlepath" : "network")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 54, height: 54)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                if isEditing {
                    LTRTextField(text: $profileName, placeholder: "Profile Name")
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.horizontal, 10)
                        .frame(width: 320, height: 36)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(
                                    profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color.orange.opacity(0.5)
                                        : Color(nsColor: .separatorColor),
                                    lineWidth: 1
                                )
                        }
                } else {
                    Text(profile.name)
                        .font(.system(size: 26, weight: .bold))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }

                Text(displayedUseDHCP ? "DHCP · Automatic configuration" : "Static IP configuration")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isEditing && isLastApplied {
                ChipLabel(text: "Last Applied", systemImage: "checkmark.circle.fill", tint: .green, bold: true)
            }
        }
        .padding(.bottom, 2)
    }

    private var ipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(displayedUseDHCP ? "IP CONFIGURATION" : "STATIC IP CONFIGURATION")

            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    Text("Configuration")
                        .font(.system(size: 15))
                    Spacer()
                    if isEditing {
                        Picker("Configuration", selection: $useDHCP) {
                            Text("DHCP").tag(true)
                            Text("Static").tag(false)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 320)
                    } else {
                        Text(profile.useDHCP ? "DHCP" : "Static")
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 320, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .frame(height: 52)

                rowDivider
                HStack(spacing: 16) {
                    Image(systemName: "network")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    Text("Network Adapter")
                        .font(.system(size: 15))
                    Spacer()
                    if isEditing {
                        Picker("Network Adapter", selection: $selectedService) {
                            ForEach(serviceOptions, id: \.self) { service in
                                Text(service).tag(service)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 320, alignment: .leading)
                    } else {
                        Text(profile.service)
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 320, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .frame(height: 52)

                if displayedUseDHCP {
                    rowDivider
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        Text("Address assignment")
                            .font(.system(size: 15))
                        Spacer()
                        Text("Assigned automatically by your router")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                } else {
                    rowDivider
                    if isEditing {
                        editableIPRow(title: "IP Address", image: "desktopcomputer", text: $ipAddress, placeholder: "192.168.100.40")
                        rowDivider
                        editableIPRow(title: "Subnet Mask", image: "point.3.connected.trianglepath.dotted", text: $subnetMask, placeholder: "255.255.255.0")
                        rowDivider
                        editableIPRow(title: "Gateway", image: "wifi.router", text: $gateway, placeholder: "192.168.100.1")
                    } else {
                        detailRow(title: "IP Address", value: profile.ipAddress, image: "desktopcomputer", copyable: true)
                        rowDivider
                        detailRow(title: "Subnet Mask", value: profile.subnetMask, image: "point.3.connected.trianglepath.dotted", copyable: true)
                        rowDivider
                        detailRow(title: "Gateway", value: profile.gateway, image: "wifi.router", copyable: true)
                    }
                }
            }
            .padding(.horizontal, 6)
            .background(cardBackground)
            .animation(.easeInOut(duration: 0.2), value: displayedUseDHCP)
        }
    }

    private var dnsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("DNS SERVERS")
                Spacer()
                let count = isEditing ? dnsServers.count : profile.dnsServers.count
                Text(count == 0 ? "System default" : "\(count) servers")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                if isEditing {
                    if dnsServers.isEmpty {
                        HStack(spacing: 14) {
                            Image(systemName: "network")
                                .foregroundStyle(.secondary)
                                .frame(width: 32)
                            Text("No custom DNS servers")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 52)
                    } else {
                        ForEach(dnsServers) { entry in
                            editableDNSRow(id: entry.id)
                            if entry.id != dnsServers.last?.id { rowDivider }
                        }
                    }

                    rowDivider
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dnsServers.append(DNSDraft(value: ""))
                            }
                        } label: {
                            Label("Add DNS Server", systemImage: "plus.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                } else if profile.dnsServers.isEmpty {
                    HStack(spacing: 14) {
                        Image(systemName: "network")
                            .foregroundStyle(.secondary)
                            .frame(width: 32)
                        Text("Uses DNS servers provided by the network")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                } else {
                    ForEach(Array(profile.dnsServers.enumerated()), id: \.offset) { index, server in
                        dnsRow(index: index + 1, server: server)
                        if index < profile.dnsServers.count - 1 { rowDivider }
                    }
                }
            }
            .padding(.horizontal, 6)
            .background(cardBackground)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func detailRow(
        title: String,
        value: String,
        image: String,
        copyable: Bool = false
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: image)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 15))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium, design: copyable ? .monospaced : .default))
                .textSelection(.enabled)
                .lineLimit(1)
                .frame(width: 320, alignment: .leading)
            if copyable {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Copy \(title)")
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    private func editableIPRow(
        title: String,
        image: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: image)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 15))
            Spacer()
            InlineValidatedTextField(text: text, placeholder: placeholder)
                .frame(width: 320)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    private func editableDNSRow(id: UUID) -> some View {
        let index = dnsServers.firstIndex { $0.id == id } ?? 0
        let value = Binding(
            get: { dnsServers.first { $0.id == id }?.value ?? "" },
            set: { newValue in
                guard let currentIndex = dnsServers.firstIndex(where: { $0.id == id }) else { return }
                dnsServers[currentIndex].value = newValue
            }
        )

        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 14)
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1), in: Circle())

            InlineValidatedTextField(text: value, placeholder: "DNS Server")

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
        .padding(.horizontal, 20)
        .frame(height: 56)
        .opacity(draggingDNSID == id ? 0.55 : 1)
        .onDrag {
            draggingDNSID = id
            return NSItemProvider(object: id.uuidString as NSString)
        }
        .onDrop(of: [UTType.text], delegate: DNSReorderDropDelegate(
            current: id,
            items: $dnsServers,
            draggingID: $draggingDNSID
        ))
    }

    private func dnsRow(index: Int, server: String) -> some View {
        HStack(spacing: 16) {
            Text(String(format: "%02d", index))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1), in: Circle())
            Text(server)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(server, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Copy DNS server")
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
    }

    private func beginEditing() {
        profileName = profile.name
        selectedService = profile.service
        appState.refreshNetworkServices()
        useDHCP = profile.useDHCP
        ipAddress = profile.ipAddress
        subnetMask = profile.subnetMask
        gateway = profile.gateway
        dnsServers = profile.dnsServers.map { DNSDraft(value: $0) }
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
    }

    private func saveChanges() {
        let updated = Profile(
            id: profile.id,
            name: profileName.trimmingCharacters(in: .whitespacesAndNewlines),
            service: selectedService,
            useDHCP: useDHCP,
            ipAddress: useDHCP ? "" : ipAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            subnetMask: useDHCP ? "" : subnetMask.trimmingCharacters(in: .whitespacesAndNewlines),
            gateway: useDHCP ? "" : gateway.trimmingCharacters(in: .whitespacesAndNewlines),
            dnsServers: dnsServers
                .map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        appState.updateProfile(updated)
        isEditing = false
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.accentColor.opacity(0.12))
            .frame(height: 1)
            .padding(.leading, 20)
    }

    private var serviceOptions: [String] {
        var services = appState.networkServices
        if !services.contains(selectedService) {
            services.insert(selectedService, at: 0)
        }
        return services
    }

    private struct DNSReorderDropDelegate: DropDelegate {
        let current: UUID
        @Binding var items: [DNSDraft]
        @Binding var draggingID: UUID?

        func dropEntered(info: DropInfo) {
            guard let draggingID,
                  draggingID != current,
                  let from = items.firstIndex(where: { $0.id == draggingID }),
                  let to = items.firstIndex(where: { $0.id == current }) else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }

        func performDrop(info: DropInfo) -> Bool {
            draggingID = nil
            return true
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(nsColor: .textBackgroundColor).opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
            }
    }
}

private struct InlineValidatedTextField: View {
    @Binding var text: String
    let placeholder: String

    @State private var showSuccessFlash = false

    private var isValid: Bool {
        text.isEmpty || validIP(text)
    }

    var body: some View {
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
                : (text.isEmpty || isValid
                    ? Color(nsColor: .textBackgroundColor)
                    : Color.red.opacity(0.15))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    !isValid ? Color.orange.opacity(0.5) : Color(nsColor: .separatorColor),
                    lineWidth: 1
                )
        }
        .onChange(of: text) { oldValue, newValue in
            let wasValid = oldValue.isEmpty || validIP(oldValue)
            let isNowValid = newValue.isEmpty || validIP(newValue)
            if !wasValid && isNowValid && !newValue.isEmpty {
                showSuccessFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showSuccessFlash = false
                }
            } else if !isNowValid {
                showSuccessFlash = false
            }
        }
        .animation(.easeInOut(duration: 0.15), value: text)
    }
}
