import SwiftUI
import AppKit
import Combine
import NetSwitchCore

struct StatusView: View {
    @EnvironmentObject private var appState: AppState
    @State private var lastUpdated: Date?

    private var isConnected: Bool {
        !appState.wifiName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var securityName: String {
        appState.wifiEncryption.isEmpty ? "-" : appState.wifiEncryption
    }

    private var signalDescription: String {
        appState.wifiSignal == 0 ? "-" : "\(appState.wifiSignal) dBm"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader
                connectionCard
                ipv4Section
                dnsSection
                footer
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.975, green: 0.981, blue: 0.991))
        .navigationTitle("")
        .onReceive(appState.networkInfoPublisher.dropFirst()) { _ in
            lastUpdated = Date()
        }
        .onAppear { appState.refreshNetworkInfo() }
    }

    private var pageHeader: some View {
        HStack(alignment: .center) {
            Text("Status")
                .font(.system(size: 26, weight: .bold))
            Spacer()
            Button { appState.refreshNetworkInfo() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.09)))
            }
            .buttonStyle(.plain)
            .disabled(appState.isRefreshing)
            .help("Refresh network information")
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("CONNECTION")
            HStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: "wifi")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 52)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(isConnected ? appState.wifiName : "Not Connected")
                            .font(.system(size: 19, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack(spacing: 7) {
                            Circle().fill(isConnected ? Color.green : Color.secondary).frame(width: 9, height: 9)
                            Text(isConnected ? "Connected" : "Disconnected")
                                .font(.system(size: 14))
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                metricDivider
                metric("Security", value: securityName, image: "lock.fill")
                metricDivider
                metric("Band", value: appState.wifiBand.isEmpty ? "-" : appState.wifiBand, image: "dot.radiowaves.left.and.right")
                metricDivider
                metric("Channel", value: appState.wifiChannel > 0 ? "\(appState.wifiChannel)" : "-", image: "antenna.radiowaves.left.and.right")
                metricDivider
                HStack(spacing: 10) {
                    SignalBars(dbm: appState.wifiSignal)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Signal").font(.system(size: 14)).foregroundStyle(.secondary)
                        Text(signalDescription).font(.system(size: 15, weight: .medium, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .frame(minHeight: 100)
            .background(Color(red: 0.953, green: 0.963, blue: 0.978), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(18)
        .background(cardBackground)
    }

    private var ipv4Section: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("IPV4 CONFIGURATION")
            VStack(spacing: 0) {
                informationRow("IP Address", value: appState.networkInfo.ipAddress, image: "desktopcomputer")
                rowDivider
                informationRow("Subnet Mask", value: appState.networkInfo.subnetMask, image: "point.3.connected.trianglepath.dotted")
                rowDivider
                informationRow("Gateway", value: appState.networkInfo.gateway, image: "wifi.router")
                rowDivider
                HStack(spacing: 16) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 19, weight: .medium)).foregroundStyle(.secondary).frame(width: 28)
                    Text("Configuration").foregroundStyle(.secondary)
                    Spacer()
                    Text(appState.lastAppliedProfile?.name ?? "-")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 320, alignment: .leading)
                }
                .padding(.horizontal, 20).frame(height: 52)
            }
            .padding(.horizontal, 6)
            .background(cardBackground)
        }
    }

    private var dnsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("DNS SERVERS")
                Spacer()
                Text(appState.networkInfo.dnsServers.isEmpty ? "-" : "\(appState.networkInfo.dnsServers.count) servers")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                if appState.networkInfo.dnsServers.isEmpty {
                    dnsRow(index: 1, server: "-", copyValue: nil)
                } else {
                    ForEach(Array(appState.networkInfo.dnsServers.enumerated()), id: \.offset) { index, server in
                        dnsRow(index: index + 1, server: server, copyValue: server)
                        if index < appState.networkInfo.dnsServers.count - 1 { rowDivider }
                    }
                }
            }
            .padding(.horizontal, 6)
            .background(cardBackground)
        }
    }

    private var lastUpdatedText: String {
        guard let lastUpdated else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: lastUpdated)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock").foregroundStyle(.secondary)
            Text("Last updated: \(lastUpdatedText)").font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer()
            Button { copyAllDetails() } label: {
                Label("Copy All Details", systemImage: "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.secondary)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(nsColor: .textBackgroundColor).opacity(0.92))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor.opacity(0.12), lineWidth: 1))
    }

    private var metricDivider: some View {
        Rectangle().fill(Color.primary.opacity(0.09)).frame(width: 1, height: 54).padding(.horizontal, 8)
    }

    private func metric(_ title: String, value: String, image: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: image).font(.system(size: 17, weight: .semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 14)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 15, weight: .medium)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func informationRow(_ title: String, value: String, image: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: image).font(.system(size: 19, weight: .medium)).foregroundStyle(.secondary).frame(width: 28)
            Text(title).font(.system(size: 15))
            Spacer()
            Text(displayValue(value)).font(.system(size: 15, weight: .medium, design: .monospaced)).lineLimit(1)
                .frame(width: 320, alignment: .leading)
            copyButton(value)
        }
        .padding(.horizontal, 20).frame(height: 52)
    }

    private func dnsRow(index: Int, server: String, copyValue: String?) -> some View {
        HStack(spacing: 16) {
            Text(String(format: "%02d", index))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1), in: Circle())
            Text(server).font(.system(size: 15, weight: .medium, design: .monospaced))
            Spacer()
            if let copyValue { copyButton(copyValue) }
        }
        .padding(.horizontal, 20).frame(height: 56)
    }

    private var rowDivider: some View {
        Rectangle().fill(Color.accentColor.opacity(0.12)).frame(height: 1).padding(.leading, 20)
    }

    private func copyButton(_ value: String) -> some View {
        Button { copyToClipboard(value) } label: {
            Image(systemName: "doc.on.doc").foregroundStyle(.secondary).frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(value.isEmpty || value == "-" || value == "—")
        .help("Copy")
    }

    private func displayValue(_ value: String) -> String {
        value.isEmpty || value == "—" ? "-" : value
    }

    private func copyAllDetails() {
        let dns = appState.networkInfo.dnsServers.isEmpty ? ["-"] : appState.networkInfo.dnsServers
        let details = [
            "Network: \(isConnected ? appState.wifiName : "Not Connected")",
            "Status: \(isConnected ? "Connected" : "Disconnected")",
            "Security: \(securityName)",
            "Band: \(appState.wifiBand.isEmpty ? "-" : appState.wifiBand)",
            "Channel: \(appState.wifiChannel > 0 ? "\(appState.wifiChannel)" : "-")",
            "Signal: \(signalDescription)",
            "IP Address: \(displayValue(appState.networkInfo.ipAddress))",
            "Subnet Mask: \(displayValue(appState.networkInfo.subnetMask))",
            "Gateway: \(displayValue(appState.networkInfo.gateway))",
            "DNS: \(dns.joined(separator: ", "))",
            "Configuration: \(appState.lastAppliedProfile?.name ?? "-")",
            "Last updated: \(lastUpdatedText)"
        ].joined(separator: "\n")
        copyToClipboard(details)
    }

    private func copyToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private struct SignalBars: View {
    let dbm: Int

    private var bars: Int {
        guard dbm != 0 else { return 0 }
        switch dbm {
        case Int.min ..< -85: return 1
        case -85 ..< -75: return 2
        case -75 ..< -65: return 3
        default: return 4
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Capsule().fill(index < bars ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 5, height: CGFloat(7 + index * 4))
            }
        }
        .frame(height: 22)
        .accessibilityLabel("Signal strength: \(bars) of 4 bars")
    }
}
