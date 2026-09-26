import SwiftUI
import NetSwitchCore

struct StatusView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        WiFiScannerView()
                    } label: {
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundStyle(.blue)
                            Text("Wi-Fi Networks")
                            Spacer()
                            if appState.isScanningWiFi || !appState.wifiNetworks.isEmpty {
                                Image(systemName: appState.wifiNetworks.isEmpty && !appState.isScanningWiFi ? "ellipsis" : "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            if appState.isScanningWiFi {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                }

                Section("Current Wi-Fi") {
                    if appState.wifiName.isEmpty {
                        NetworkStatusLabelRow(
                            title: "Status",
                            value: "Not Connected"
                        )
                    } else {
                        NetworkStatusLabelRow(
                            title: "Network Name",
                            value: appState.wifiName
                        )

                        if !appState.wifiEncryption.isEmpty {
                            NetworkStatusLabelRow(
                                title: "Security",
                                value: appState.wifiEncryption
                            )
                        }

                        if !appState.wifiBand.isEmpty {
                            NetworkStatusLabelRow(
                                title: "Band",
                                value: appState.wifiBand
                            )
                        }

                        if appState.wifiChannel > 0 {
                            NetworkStatusLabelRow(
                                title: "Channel",
                                value: "\(appState.wifiChannel)"
                            )
                        }

                        if appState.wifiSignal != 0 {
                            NetworkStatusLabelRow(
                                title: "Signal Strength",
                                value: "\(appState.wifiSignal) dBm"
                            )
                        }
                    }
                }

                Section("Network Information") {
                    NetworkStatusLabelRow(
                        title: "Service",
                        value: appState.networkInfo.service
                    )

                    NetworkStatusLabelRow(
                        title: "IP Address",
                        value: appState.networkInfo.ipAddress
                    )

                    if !appState.networkInfo.subnetMask.isEmpty {
                        NetworkStatusLabelRow(
                            title: "Subnet Mask",
                            value: appState.networkInfo.subnetMask
                        )
                    }

                    if !appState.networkInfo.gateway.isEmpty {
                        NetworkStatusLabelRow(
                            title: "Router",
                            value: appState.networkInfo.gateway
                        )
                    }
                }

                if !appState.networkInfo.dnsServers.isEmpty {
                    Section("DNS Servers") {
                        ForEach(appState.networkInfo.dnsServers, id: \.self) { server in
                            DNSServerRow(server: server)
                        }
                    }
                }

                Section {
                    Button {
                        appState.refreshNetworkInfo()
                    } label: {
                        Label("Refresh Network Status", systemImage: "arrow.clockwise")
                        if appState.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .disabled(appState.isRefreshing)
                } header: {
                    Text("Actions")
                } footer: {
                    Text("Tap refresh to get the latest network information")
                }
            }
            .navigationTitle("Status")
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .onAppear {
                appState.refreshNetworkInfo()
            }
        }
    }
}

// MARK: - Network Status Label Row

private struct NetworkStatusLabelRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - DNS Server Row

struct DNSServerRow: View {
    let server: String

    var body: some View {
        HStack {
            Image(systemName: "server.rack")
                .foregroundStyle(.purple)
                .frame(width: 24)

            Text(server)
                .font(.body.monospacedDigit())
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "copy")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}
