import SwiftUI
import NetSwitchCore

struct WiFiScannerView: View {
    @EnvironmentObject private var appState: AppState

    @State private var searchText = ""
    @State private var showingPasswordPrompt = false
    @State private var selectedNetwork: WiFiNetwork?
    @State private var password = ""
    @State private var saveToKeychain = true

    private var filteredNetworks: [WiFiNetwork] {
        if searchText.isEmpty {
            return appState.wifiNetworks
        }
        return appState.wifiNetworks.filter {
            $0.ssid.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                if filteredNetworks.isEmpty {
                    emptyState
                } else {
                    networksList
                }
            }
            .padding(24)
        }
        .navigationTitle("Wi-Fi Networks")
        .toolbar {
            ToolbarItem {
                Button {
                    appState.scanWiFi()
                } label: {
                    Image(systemName: appState.isScanningWiFi ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .rotationEffect(.degrees(appState.isScanningWiFi ? 360 : 0))
                        .animation(
                            appState.isScanningWiFi
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: appState.isScanningWiFi
                        )
                }
                .disabled(appState.isScanningWiFi)
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search networks")
        .sheet(isPresented: $showingPasswordPrompt) {
            passwordPromptSheet
        }
        .onAppear {
            appState.scanWiFi()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.18),
                                Color.accentColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "wifi")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("Available Networks")
                    .font(.headline)
                Text("\(appState.wifiNetworks.count) networks found nearby")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if appState.isScanningWiFi {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: appState.isScanningWiFi)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No networks found" : "No matches for “\(searchText)”")
                .font(.headline)
            Text(searchText.isEmpty
                ? "Try moving closer to a router or rescan."
                : "Adjust your search to find other networks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Networks List

    private var networksList: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredNetworks) { network in
                NetworkRow(
                    network: network,
                    isConnected: network.ssid == appState.wifiName,
                    isSaved: network.isSaved
                ) {
                    handleConnect(to: network)
                }
            }
        }
    }

    // MARK: - Password Prompt

    private var passwordPromptSheet: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "wifi")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                Text("Connect to \(selectedNetwork?.ssid ?? "")")
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if selectedNetwork?.isSaved == true {
                    HStack(spacing: 5) {
                        Image(systemName: "key.fill")
                            .font(.caption2.weight(.semibold))
                        Text("Password saved in Keychain")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .separatorColor).opacity(0.3), in: Capsule())
                }
            }

            if selectedNetwork?.isSaved == false {
                VStack(spacing: 10) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Toggle(isOn: $saveToKeychain) {
                        Label("Remember this network", systemImage: "key.horizontal.fill")
                            .font(.subheadline)
                    }
                }
                .frame(width: 280)
            }

            Divider()

            HStack(spacing: 10) {
                Button("Cancel", role: .cancel) {
                    dismissPasswordPrompt()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .frame(maxWidth: .infinity)

                Button {
                    if let network = selectedNetwork {
                        appState.connect(to: network, password: password, save: saveToKeychain)
                    }
                    dismissPasswordPrompt()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi")
                        Text("Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedNetwork?.isSaved == false && password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Actions

    private func handleConnect(to network: WiFiNetwork) {
        if network.isOpen {
            appState.connect(to: network, password: "", save: false)
        } else if network.isSaved {
            appState.connect(to: network, password: "", save: false)
        } else {
            selectedNetwork = network
            password = ""
            saveToKeychain = true
            showingPasswordPrompt = true
        }
    }

    private func dismissPasswordPrompt() {
        showingPasswordPrompt = false
        selectedNetwork = nil
        password = ""
    }
}

// MARK: - Network Row

private struct NetworkRow: View {
    let network: WiFiNetwork
    let isConnected: Bool
    let isSaved: Bool
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon tile (consistent sizing — fixes the "staircase" alignment issue)
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 32, height: 32)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(network.ssid)
                    .font(.body.weight(isConnected ? .bold : .semibold))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if isConnected {
                        ChipPill(text: "Connected", systemImage: "checkmark.circle.fill", tint: .green, bold: true)
                    } else if isSaved {
                        ChipPill(text: "Saved", systemImage: "key.fill", tint: .secondary)
                    }

                    if !network.band.isEmpty {
                        ChipPill(text: network.band, tint: .secondary)
                    }

                    ChipPill(text: network.encryption, tint: .secondary)

                    if network.channel > 0 {
                        ChipPill(text: "Ch \(network.channel)", tint: .secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            // Signal + Action
            HStack(spacing: 10) {
                SignalStrengthView(dbm: network.signal)

                Text("\(network.signal) dBm")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)

                if !isConnected {
                    Button("Connect") {
                        onConnect()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 18, weight: .semibold))
                        .help("Connected")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isConnected
                        ? Color.green.opacity(0.06)
                        : Color(nsColor: .controlBackgroundColor)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isConnected ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 1, y: 0.5)
        .contentShape(Rectangle())
    }

    private var iconName: String {
        if network.isOpen { return "wifi" }
        if isSaved { return "lock.shield.fill" }
        return "lock.fill"
    }

    private var iconColor: Color {
        if isConnected { return .green }
        if network.isOpen { return .blue }
        return .orange
    }
}

// MARK: - Chip Pill (metadata label)

private struct ChipPill: View {
    let text: String
    var systemImage: String? = nil
    let tint: Color
    var bold: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 8.5, weight: .semibold))
            }
            Text(text)
                .font(.caption2.weight(bold ? .semibold : .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

// MARK: - WiFi Network Model

// TODO: Move this to your NetSwitchCore module if not already there
struct WiFiNetwork: Identifiable, Equatable {
    let id = UUID()
    let ssid: String
    let signal: Int // dBm
    let encryption: String // "WPA3", "WPA2", "Open", etc.
    let band: String // "5 GHz", "2.4 GHz"
    let channel: Int
    let isOpen: Bool
    let isSaved: Bool
}
