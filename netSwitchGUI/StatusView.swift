import SwiftUI
import NetSwitchCore

struct StatusView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section("Connection") {
                if appState.wifiName.isEmpty {
                    LabeledContent("Status", value: "Not Connected")
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("Network") {
                        Text(appState.wifiName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    if !appState.wifiEncryption.isEmpty {
                        LabeledContent("Security", value: appState.wifiEncryption)
                    }

                    if !appState.wifiBand.isEmpty {
                        LabeledContent("Band", value: appState.wifiBand)
                    }

                    if appState.wifiChannel > 0 {
                        LabeledContent("Channel") {
                            Text("\(appState.wifiChannel)")
                                .monospacedDigit()
                                .textSelection(.enabled)
                        }
                    }

                    if appState.wifiSignal != 0 {
                        LabeledContent("Signal") {
                            Text("\(appState.wifiSignal) dBm")
                                .monospacedDigit()
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            Section("IPv4") {
                LabeledContent("Service") {
                    Text(appState.networkInfo.service)
                        .textSelection(.enabled)
                }

                LabeledContent("IP Address") {
                    Text(appState.networkInfo.ipAddress)
                        .monospacedDigit()
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if !appState.networkInfo.subnetMask.isEmpty {
                    LabeledContent("Subnet Mask") {
                        Text(appState.networkInfo.subnetMask)
                            .monospacedDigit()
                            .textSelection(.enabled)
                    }
                }

                if !appState.networkInfo.gateway.isEmpty {
                    LabeledContent("Router") {
                        Text(appState.networkInfo.gateway)
                            .monospacedDigit()
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Section("DNS Servers") {
                if appState.networkInfo.dnsServers.isEmpty {
                    Text("System default")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.networkInfo.dnsServers, id: \.self) { server in
                        DNSServerRow(server: server)
                    }
                }
            }
        }
        .navigationTitle("Status")
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.refreshNetworkInfo()
                } label: {
                    HStack(spacing: 6) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                        if appState.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(appState.isRefreshing)
            }
        }
        .onAppear {
            appState.refreshNetworkInfo()
        }
    }
}

// MARK: - DNS Server Row

struct DNSServerRow: View {
    let server: String

    var body: some View {
        HStack {
            Image(systemName: "server.rack")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(server)
                .font(.body.monospacedDigit())
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
