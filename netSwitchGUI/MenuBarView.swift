import SwiftUI
import NetSwitchCore

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NetSwitch")
                    .font(.headline)

                Label(
                    "Wi-Fi: \(appState.wifiName)",
                    systemImage: "wifi"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Divider()

            if appState.profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles Yet",
                    systemImage: "network.badge.shield.half.filled",
                    description: Text("Open Settings to create one.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                Text("Saved Profiles")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(appState.profiles) { profile in
                    HStack(spacing: 10) {
                        Image(
                            systemName: profile.useDHCP
                                ? "arrow.triangle.2.circlepath"
                                : "network"
                        )
                        .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)

                            Text(
                                profile.useDHCP
                                    ? "\(profile.service) • DHCP"
                                    : "\(profile.service) • Static"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Apply") {
                            appState.apply(profile)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(appState.isApplying)
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider()

            HStack {
                Button {
                    appState.refreshNetworkInfo()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isRefreshing)

                Spacer()

                Button("Open Settings…") {
                    openSettings()
                }
            }

            if appState.isApplying {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Applying profile…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 330)
        .onAppear {
            appState.refreshNetworkInfo()
        }
        .alert(item: $appState.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
