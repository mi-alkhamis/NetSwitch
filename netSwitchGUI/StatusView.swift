import SwiftUI
import NetSwitchCore

struct StatusView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section("Connection") {
                if appState.wifiName.isEmpty {
                    LabeledContent("Status", value: "Not Connected")
                } else {
                    LabeledContent("Network Name") {
                        Text(appState.wifiName)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
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
                        LabeledContent("Signal Strength") {
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
                        .lineLimit(1)
                        .truncationMode(.middle)
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
                            .lineLimit(1)
                            .truncationMode(.middle)
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

            if !appState.networkInfo.dnsServers.isEmpty {
                Section("DNS Servers") {
                    ForEach(appState.networkInfo.dnsServers, id: \.self) { server in
                        DNSServerRow(server: server)
                    }
                }
            }
        }
        .navigationTitle("Status")
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .toolbar {
            ToolbarItem {
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
                .foregroundStyle(.purple)
                .frame(width: 24)

            Text(server)
                .font(.body.monospacedDigit())
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}
