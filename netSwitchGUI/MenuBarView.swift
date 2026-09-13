import SwiftUI
import NetSwitchCore

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Header
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NetSwitch")
                        .font(.headline)
                    Text("Network Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ConnectionBadge(isConnected: !appState.wifiName.isEmpty)
            }

            // MARK: - Metrics Grid
            metricsGrid

            // MARK: - Active/Other Profiles
            if let active = appState.activeProfile {
                Divider().padding(.vertical, 4)
                activeProfileSection(active)
            }

            if !appState.profiles.isEmpty {
                Divider().padding(.vertical, 4)
                otherProfilesSection
            }

            Divider().padding(.vertical, 4)

            // MARK: - Footer Actions
            footerActions

            if appState.isApplying {
                applyingIndicator
            }
        }
        .padding(14)
        .frame(width: 360)
        .onAppear { appState.refreshNetworkInfo() }
        .alert(item: $appState.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Wi-Fi Status Header

    private struct ConnectionBadge: View {
        let isConnected: Bool
        var body: some View {
            HStack(spacing: 6) {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((isConnected ? Color.green.opacity(0.12) : Color.red.opacity(0.12)))
            .foregroundStyle(isConnected ? .green : .red)
            .clipShape(Capsule())
        }
    }

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: Wi‑Fi name and signal/IP
            HStack(alignment: .center, spacing: 10) {
                metricCard(title: "Wi‑Fi", value: appState.wifiName.isEmpty ? "No Wi‑Fi connection" : appState.wifiName)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    SignalStrengthView(dbm: appState.wifiSignal)
                    Text(appState.networkInfo.ipAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }
            }

            // Grid of network details
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    metricCard(title: "IP Address", value: appState.networkInfo.ipAddress)
                    metricCard(title: "Subnet Mask", value: appState.networkInfo.subnetMask)
                }
                GridRow {
                    metricCard(title: "Gateway", value: appState.networkInfo.gateway)
                    metricCard(title: "DNS Servers", value: appState.networkInfo.dnsServers.joined(separator: "  "))
                }
            }
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Active Profile

    private func activeProfileSection(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Active Profile")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                    Text("Applied")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            }

            HStack(spacing: 10) {
                Image(
                    systemName: profile.useDHCP
                        ? "arrow.triangle.2.circlepath"
                        : "network"
                )
                .foregroundStyle(.blue)
                .font(.body)

                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.name)
                        .font(.body.weight(.medium))

                    Text(
                        profile.useDHCP
                            ? "DHCP • \(profile.service)"
                            : "Static • \(profile.ipAddress)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()
            }
            .padding(8)
            .background(.green.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.green.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Other Profiles

    private var otherProfilesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if appState.profiles.count > 1 || appState.activeProfile == nil {
                Text(appState.activeProfile == nil ? "Profiles" : "Other Profiles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            if appState.profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles",
                    systemImage: "network.badge.shield.half.filled",
                    description: Text("Open NetSwitch to create one.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                let others = appState.profiles.filter { $0.id != appState.activeProfile?.id }

                ForEach(others) { profile in
                    HStack(spacing: 10) {
                        Image(
                            systemName: profile.useDHCP
                                ? "arrow.triangle.2.circlepath"
                                : "network"
                        )
                        .foregroundStyle(.secondary)
                        .font(.body)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(profile.name)
                                .font(.body.weight(.medium))

                            Text(
                                profile.useDHCP
                                    ? "DHCP • \(profile.service)"
                                    : "Static • \(profile.ipAddress)"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }

                        Spacer()

                        Button("Apply") {
                            appState.apply(profile)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(appState.isApplying)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Footer

    private var footerActions: some View {
        HStack(spacing: 10) {
            Button {
                appState.refreshNetworkInfo()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(appState.isRefreshing)
            .buttonStyle(.borderless)

            Spacer()

            Button("Open NetSwitch...") {
                openSettings()
            }
            .buttonStyle(.borderless)
        }
    }

    private var applyingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("Applying profile...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
}
