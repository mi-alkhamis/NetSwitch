import SwiftUI
import NetSwitchCore

struct ProfileDetailView: View {
    @EnvironmentObject private var appState: AppState

    let profile: Profile

    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 16
                ) {
                    ProfileValueCard(
                        title: "Network Service",
                        value: profile.service,
                        systemImage: "wifi"
                    )

                    ProfileValueCard(
                        title: "Configuration",
                        value: profile.useDHCP ? "DHCP" : "Static IP",
                        systemImage: profile.useDHCP
                            ? "arrow.triangle.2.circlepath"
                            : "network"
                    )

                    if !profile.useDHCP {
                        ProfileValueCard(
                            title: "IP Address",
                            value: profile.ipAddress,
                            systemImage: "network"
                        )

                        ProfileValueCard(
                            title: "Subnet Mask",
                            value: profile.subnetMask,
                            systemImage: "rectangle.3.group"
                        )

                        ProfileValueCard(
                            title: "Gateway",
                            value: profile.gateway,
                            systemImage: "point.3.connected.trianglepath.dotted"
                        )
                    }

                    ProfileValueCard(
                        title: "DNS",
                        value: profile.dnsServers.isEmpty
                            ? "System default"
                            : profile.dnsServers.joined(separator: ", "),
                        systemImage: "server.rack"
                    )
                }

                HStack {
                    Button {
                        appState.apply(profile)
                    } label: {
                        Label(
                            appState.isApplying ? "Applying…" : "Apply Profile",
                            systemImage: "checkmark.circle"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.isApplying)

                    Button("Edit") {
                        showingEditor = true
                    }

                    Spacer()

                    Button("Delete", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .padding(28)
        }
        .navigationTitle(profile.name)
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                ProfileEditorView(profile: profile) { updatedProfile in
                    appState.updateProfile(updatedProfile)
                }
            }
        }
        .confirmationDialog(
            "Delete \(profile.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Profile", role: .destructive) {
                appState.deleteSelectedProfile()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved profile. It does not change your current network settings.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name)
                    .font(.largeTitle.bold())

                Text("\(profile.service) • \(profile.useDHCP ? "DHCP" : "Static IP")")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(
                systemName: profile.useDHCP
                    ? "arrow.triangle.2.circlepath.circle.fill"
                    : "network"
            )
            .font(.system(size: 38))
            .foregroundStyle(.blue)
        }
    }
}

private struct ProfileValueCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .textSelection(.enabled)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
