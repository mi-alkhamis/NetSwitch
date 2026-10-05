//
//  MenuBarView 2.swift
//  netSwitch
//
//  Created by Milad Alkhamis on 9/22/26.
//


import SwiftUI
import NetSwitchCore
import Combine

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var localBanner: AppAlert?

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

            // MARK: - Network Details
            networkSection

            // MARK: - Last Applied / Other Profiles
            if let lastApplied = appState.lastAppliedProfile {
                Divider().padding(.vertical, 4)
                lastAppliedProfileSection(lastApplied)
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
        .onChange(of: appState.menuBarAlert?.id) { _, _ in
            guard let newValue = appState.menuBarAlert else { return }
            localBanner = newValue
            appState.menuBarAlert = nil

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if localBanner?.id == newValue.id {
                    localBanner = nil
                }
            }
        }
        .overlay(alignment: .top) {
            if let localBanner {
                HStack(spacing: 6) {
                    Image(systemName: localBanner.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(localBanner.kind == .success ? .green : .red)
                    Text(localBanner.message)
                        .font(.caption)
                        .lineLimit(2)
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: localBanner.id)
            }
        }
    }

    // MARK: - Connection Badge

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

    
    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Signal indicator before SSID — no IP here anymore, shown below instead
            HStack(spacing: 10) {
                SignalStrengthView(dbm: appState.wifiSignal)

                Text(appState.wifiName.isEmpty ? "No Wi‑Fi connection" : appState.wifiName)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 2)

            // IP+CIDR and Gateway side by side — denser, less empty space
            HStack(spacing: 10) {
                metricCard(
                    title: "IP Address",
                    value: ipAddressWithCIDR
                )
                metricCard(
                    title: "Gateway",
                    value: appState.networkInfo.gateway
                )
            }

            dnsCard
        }
    }

    private var ipAddressWithCIDR: String {
        let ip = appState.networkInfo.ipAddress
        guard !ip.isEmpty, ip != "—" else { return ip }
        let suffix = NetworkClient.cidrSuffix(forSubnetMask: appState.networkInfo.subnetMask)
        return suffix.isEmpty ? ip : "\(ip)\(suffix)"
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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

    // MARK: - DNS Card (full-width, one line per server)

    private var dnsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DNS SERVERS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if appState.networkInfo.dnsServers.isEmpty {
                Text("System default")
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Text(appState.networkInfo.dnsServers.joined(separator: ", "))
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .lineLimit(1)
            }
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

    // MARK: - Last Applied Profile

    private func lastAppliedProfileSection(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)

                Text("Last Applied Profile")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text("Applied")
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
                    .stroke(.green.opacity(0.25), lineWidth: 1)
                    .padding(-1)
            )
        }
    }

    // MARK: - Other Profiles

    private var otherProfilesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if appState.profiles.count > 1 || appState.lastAppliedProfile == nil {
                Text(appState.lastAppliedProfile == nil ? "Profiles" : "Other Profiles")
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
                let others = appState.profiles.filter { $0.id != appState.lastAppliedProfile?.id }

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
                            appState.applyFromMenuBar(profile)
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

            Button("Open NetSwitch") {
                openWindow(id: "management")
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
