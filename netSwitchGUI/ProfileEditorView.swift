import SwiftUI
import NetSwitchCore

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let profile: Profile?
    let onSave: (Profile) -> Void

    @State private var name = ""
    @State private var service = "Wi-Fi"
    @State private var useDHCP = true
    @State private var ipAddress = ""
    @State private var subnetMask = ""
    @State private var gateway = ""
    @State private var dnsServersText = ""

    private var isEditing: Bool {
        profile != nil
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Profile Name", text: $name)

                TextField("Network Service", text: $service)

                Toggle("Use DHCP", isOn: $useDHCP)
            }

            if !useDHCP {
                Section("Static IPv4") {
                    TextField("IP Address", text: $ipAddress)
                    TextField("Subnet Mask", text: $subnetMask)
                    TextField("Gateway", text: $gateway)
                }
            }

            Section("DNS") {
                TextField(
                    "DNS Servers",
                    text: $dnsServersText,
                    prompt: Text("Example: 1.1.1.1, 1.0.0.1")
                )

                Text("Separate multiple DNS servers with commas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .navigationTitle(isEditing ? "Edit Profile" : "New Profile")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save Changes" : "Save Profile") {
                    saveProfile()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            loadProfile()
        }
    }

    private func loadProfile() {
        guard let profile else {
            return
        }

        name = profile.name
        service = profile.service
        useDHCP = profile.useDHCP
        ipAddress = profile.ipAddress
        subnetMask = profile.subnetMask
        gateway = profile.gateway
        dnsServersText = profile.dnsServers.joined(separator: ", ")
    }

    private func saveProfile() {
        let dnsServers = dnsServersText
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        let savedProfile = Profile(
            id: profile?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            service: service.trimmingCharacters(in: .whitespacesAndNewlines),
            useDHCP: useDHCP,
            ipAddress: ipAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            subnetMask: subnetMask.trimmingCharacters(in: .whitespacesAndNewlines),
            gateway: gateway.trimmingCharacters(in: .whitespacesAndNewlines),
            dnsServers: dnsServers
        )

        onSave(savedProfile)
        dismiss()
    }
}
