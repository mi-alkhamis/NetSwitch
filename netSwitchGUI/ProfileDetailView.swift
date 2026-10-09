import SwiftUI
import NetSwitchCore


struct ProfileDetailView: View {
    @EnvironmentObject private var appState: AppState

    let profile: Profile

    @State private var showingEditor = false

    private var isLastApplied: Bool {
        appState.lastAppliedProfile?.id == profile.id
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: profile.useDHCP ? "checkmark.seal.fill" : "network.badge.shield.half.filled")
                        .font(.title2)
                        .foregroundStyle(profile.useDHCP ? .green : .blue)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.headline)
                            .textSelection(.enabled)

                        Text(profile.useDHCP ? "DHCP (Automatic IP)" : "Static IP Configuration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if appState.lastAppliedProfile?.id == profile.id {
                        ChipLabel(text: "Last Applied", systemImage: "checkmark.circle.fill", tint: .green, bold: true)
                    }
                }
            }

            if profile.useDHCP {
                Section {
                    EmptyNetworkConfigRow(systemImage: "arrow.triangle.2.circlepath", desc: "IP address is assigned automatically by your router")
                } header: {
                    Text("IP Configuration")
                }
            } else {
                Section {
                    IPConfigRow(title: "IP Address", value: profile.ipAddress)
                    IPConfigRow(title: "Subnet Mask", value: profile.subnetMask)
                    IPConfigRow(title: "Router / Gateway", value: profile.gateway)
                } header: {
                    Text("Static IP Configuration")
                }
            }

            Section(header: Text("DNS Configuration")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("DNS Servers")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(profile.dnsServers.isEmpty ? "System default" : "\(profile.dnsServers.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if profile.dnsServers.isEmpty {
                        Text("No custom DNS servers configured — using system default resolvers.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(profile.dnsServers, id: \.self) { server in
                            DNSServerRow(server: server)
                        }
                    }
                }
            }
        }
        .navigationTitle(profile.name)
        .toolbar {
            ToolbarItem {
                Button {
                    showingEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Apply") {
                    if appState.lastAppliedProfile?.id != profile.id {
                        appState.apply(profile)
                    }
                }
                .disabled(appState.lastAppliedProfile?.id == profile.id)
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                ProfileEditorView(profile: profile) { updatedProfile in
                    appState.updateProfile(updatedProfile)
                }
            }
        }
    }
}
