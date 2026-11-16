import SwiftUI
import NetSwitchCore

private struct SpeedTestDisplayResult: Identifiable, Codable {
    let id: UUID
    let downloadMbps: Double
    let uploadMbps: Double
    let pingMilliseconds: Double
    let jitterMilliseconds: Double
    let serverName: String
    let serverLocation: String
    let serverRequestID: String?
    let publicIPAddress: String
    let dataUsed: Int
    let testedAt: Date
    let profileName: String
    let networkName: String
}

struct SpeedTestView: View {
    private static let historyStorageKey = "netSwitch.speedTestHistory.v1"
    private static let maximumHistoryCount = 100
    private static let automaticServerID = "auto"

    @EnvironmentObject private var appState: AppState
    @AppStorage("netSwitch.speedTestServerID") private var preferredServerID = automaticServerID
    @State private var isRunning = false
    @State private var progress = ""
    @State private var result: SpeedTestDisplayResult?
    @State private var history: [SpeedTestDisplayResult] = SpeedTestView.loadHistory()
    @State private var selectedHistoryID: UUID?
    @State private var errorMessage: String?
    @State private var showingClearHistoryConfirmation = false
    @State private var downloadSamples: [Double] = []
    @State private var uploadSamples: [Double] = []
    @State private var currentLatency: SpeedTestLatency?
    @State private var routeLatency: SpeedTestLatency?
    @State private var currentPublicIP: String?
    @State private var liveNetworkInfo: NetworkInfo?
    @State private var speedTestServers: [SpeedTestServer] = [.cloudflare]
    @State private var recommendedServer: SpeedTestServerRecommendation?
    @State private var isLoadingServers = true
    @State private var isCheckingServer = false
    @State private var didLoadServers = false
    @State private var testTask: Task<Void, Never>?

    private var activeNetworkName: String {
        let info = liveNetworkInfo ?? appState.networkInfo
        let name = info.ssid.isEmpty ? info.service : info.ssid
        return name.isEmpty ? "No active network" : name
    }

    private var activeInterfaceName: String {
        let name = liveNetworkInfo?.service ?? appState.networkInfo.service
        return name.isEmpty ? "None" : name
    }

    private var connectionDescription: String {
        let info = liveNetworkInfo ?? appState.networkInfo
        let service = info.service.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAddress = !info.ipAddress.isEmpty && info.ipAddress != "—"
        if !info.ssid.isEmpty {
            let band = appState.wifiBand.isEmpty ? "" : " (\(appState.wifiBand))"
            return "Wi-Fi\(band) · \(info.ssid)"
        }
        if hasAddress {
            return service.localizedCaseInsensitiveContains("wi-fi")
                ? "Wi-Fi · Connected"
                : "Connected · \(service.isEmpty ? "Network adapter" : service)"
        }
        return "Not connected"
    }

    private var selectedSpeedTestServer: SpeedTestServer {
        if preferredServerID == Self.automaticServerID {
            return recommendedServer?.server ?? .cloudflare
        }
        return speedTestServers.first { $0.id == preferredServerID }
            ?? recommendedServer?.server
            ?? .cloudflare
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                }
                observatory
                routeFingerprint
                historySection

                Text("Speed measurements use the selected test server. Each run transfers about 12 MB. The selected server and Cloudflare’s public IP service receive your connection request and public IP address.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(red: 0.975, green: 0.981, blue: 0.991))
        .task { await refreshLiveRouteDetails() }
        .onChange(of: preferredServerID) { _, _ in
            selectedHistoryID = nil
            result = nil
            currentLatency = nil
            routeLatency = nil
            Task { await refreshSelectedServerLatency() }
        }
        .confirmationDialog("Clear all saved speed tests?", isPresented: $showingClearHistoryConfirmation, titleVisibility: .visible) {
            Button("Clear All History", role: .destructive, action: clearHistory)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all saved speed test results from this Mac.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "speedometer")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed Test")
                        .font(.system(size: 26, weight: .bold))
                    Text("Check your internet speed, latency and connection quality.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                statusBadge
                Button(action: toggleTest) {
                    Label(isRunning ? "Stop Test" : "Start Test", systemImage: isRunning ? "stop.fill" : "play.fill")
                        .frame(minWidth: 118)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .red : .accentColor)
            }

            HStack(spacing: 10) {
                Label("TEST SERVER", systemImage: "server.rack")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.55)
                    .foregroundStyle(.secondary)
                Menu {
                    Button {
                        preferredServerID = Self.automaticServerID
                    } label: {
                        Label(
                            "Best available · \(recommendedServer?.server.location ?? "Finding server…")",
                            systemImage: preferredServerID == Self.automaticServerID ? "checkmark.circle.fill" : "sparkles"
                        )
                    }
                    Divider()
                    ForEach(speedTestServers) { server in
                        Button {
                            preferredServerID = server.id
                        } label: {
                            if preferredServerID == server.id {
                                Label(server.name, systemImage: "checkmark")
                            } else {
                                Text(server.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Text(selectedSpeedTestServer.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.15)))
                }
                .menuStyle(.borderlessButton)
                .disabled(isRunning || isLoadingServers)
                .help("Choose a speed test server")

                if isLoadingServers || isCheckingServer {
                    ProgressView().controlSize(.small)
                } else if preferredServerID == Self.automaticServerID {
                    Text("Recommended by lowest ping")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isRunning ? Color.orange : (errorMessage == nil ? Color.green : Color.red))
                .frame(width: 8, height: 8)
            Text(isRunning ? (progress.isEmpty ? "Testing" : progress) : (errorMessage == nil ? (selectedHistoryID != nil ? "Viewing saved result" : (result == nil ? "Ready to test" : "Test complete")) : "Test failed"))
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.055), in: Capsule())
    }

    private var observatory: some View {
        GeometryReader { geometry in
            let globeWidth = min(280, max(190, geometry.size.width * 0.32))
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 48) {
                    throughputPanel(
                        title: "Download",
                        value: throughputValue(samples: downloadSamples, finalValue: result?.downloadMbps),
                        samples: downloadSamples,
                        color: Color.blue,
                        symbol: "arrow.down.circle"
                    )
                    precisionMetric(title: "Ping", value: currentLatency?.pingMilliseconds ?? result?.pingMilliseconds, color: .green, symbol: "point.3.connected.trianglepath.dotted")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                NetworkObservatoryGlobe(
                    isTesting: isRunning,
                    hasResult: result != nil,
                    progress: progress,
                    samples: isUploading ? uploadSamples : downloadSamples,
                    historyTimestamp: selectedHistoryID == nil ? nil : result?.testedAt
                )
                .frame(width: globeWidth, height: 370)
                .accessibilityLabel(isRunning ? "Network test in progress" : "Network test globe")

                VStack(alignment: .leading, spacing: 48) {
                    throughputPanel(
                        title: "Upload",
                        value: throughputValue(samples: uploadSamples, finalValue: result?.uploadMbps),
                        samples: uploadSamples,
                        color: Color.purple,
                        symbol: "arrow.up.circle"
                    )
                    precisionMetric(title: "Jitter", value: currentLatency?.jitterMilliseconds ?? result?.jitterMilliseconds, color: .teal, symbol: "waveform.path")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.92), Color(red: 0.955, green: 0.971, blue: 0.995)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: Color.blue.opacity(0.045), radius: 18, y: 8)
            }
        }
        .frame(height: 400)
    }

    private var isUploading: Bool {
        isRunning && progress.localizedCaseInsensitiveContains("upload")
    }

    private func throughputValue(samples: [Double], finalValue: Double?) -> Double {
        if isRunning { return samples.last ?? 0 }
        return finalValue ?? 0
    }

    private func throughputPanel(title: String, value: Double, samples: [Double], color: Color, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.09), in: Circle())
                    .overlay(Circle().stroke(color.opacity(0.16), lineWidth: 1))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.82))
            }
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(String(format: "%.2f", value))
                    .font(.system(size: 37, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("Mbps")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            ZStack {
                Capsule().fill(color.opacity(0.11)).frame(height: 5)
                ThroughputTrace(samples: samples)
                    .stroke(
                        LinearGradient(colors: [color.opacity(0.45), color, .teal.opacity(0.8)], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
            }
            .frame(height: 32)
            .animation(.easeOut(duration: 0.25), value: samples.count)
            Text(samples.last.map { String(format: "∿  %.2f Mbps", $0) } ?? "∿  — Mbps")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func precisionMetric(title: String, value: Double?, color: Color, symbol: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.09), in: Circle())
                .overlay(Circle().stroke(color.opacity(0.16), lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("ms").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            }
        }
    }

    private var routeFingerprint: some View {
        HStack(spacing: 0) {
            fingerprintCell("PUBLIC IP ADDRESS", value: displayedPublicIPAddress, detail: nil, symbol: "globe")
            fingerprintDivider
            fingerprintCell(
                "SERVER",
                value: displayedServerName,
                detail: displayedRequestID.map { "Request ID · \($0)" },
                symbol: "server.rack"
            )
            fingerprintDivider
            fingerprintCell("SERVER LOCATION", value: displayedServerLocation ?? selectedSpeedTestServer.location, detail: nil, symbol: "mappin.and.ellipse")
            fingerprintDivider
            fingerprintCell("CONNECTION", value: selectedHistoryID == nil ? connectionDescription : (result?.networkName ?? "—"), detail: "Interface · \(selectedHistoryID == nil ? activeInterfaceName : (result?.networkName ?? "—"))", symbol: "wifi")
        }
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.accentColor.opacity(0.13)))
    }

    private var displayedPublicIPAddress: String {
        if selectedHistoryID != nil { return result?.publicIPAddress ?? "—" }
        return currentPublicIP ?? result?.publicIPAddress ?? "—"
    }

    private var displayedServerName: String {
        if selectedHistoryID != nil { return result?.serverName ?? "—" }
        return routeLatency?.serverName ?? currentLatency?.serverName ?? result?.serverName ?? selectedSpeedTestServer.name
    }

    private var displayedServerLocation: String? {
        if selectedHistoryID != nil { return result?.serverLocation }
        return routeLatency?.serverLocation ?? currentLatency?.serverLocation ?? result?.serverLocation
    }

    private var displayedRequestID: String? {
        if selectedHistoryID != nil { return result?.serverRequestID }
        return routeLatency?.serverRequestID ?? currentLatency?.serverRequestID ?? result?.serverRequestID
    }

    private var fingerprintDivider: some View {
        Rectangle().fill(Color.accentColor.opacity(0.12)).frame(width: 1).padding(.vertical, 16)
    }

    private func fingerprintCell(_ title: String, value: String, detail: String?, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(value)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(detail)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PREVIOUS TESTS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(history.count)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                Button("Clear All") { showingClearHistoryConfirmation = true }
                    .buttonStyle(.borderless)
                    .disabled(history.isEmpty)
            }
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    historyRow(date: "DATE", download: "DOWNLOAD", upload: "UPLOAD", ping: "PING", jitter: "JITTER", server: "SERVER", publicIP: "PUBLIC IP", profile: "PROFILE", network: "NETWORK", isHeader: true)
                    Rectangle().fill(Color.accentColor.opacity(0.14)).frame(height: 1)
                    if history.isEmpty {
                        Text("Completed tests will be saved here on this Mac.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 17)
                    } else {
                        ForEach(history) { item in
                            HStack(spacing: 8) {
                                historyRow(
                                    date: item.testedAt.formatted(date: .numeric, time: .shortened),
                                    download: String(format: "%.1f Mbps", item.downloadMbps),
                                    upload: String(format: "%.1f Mbps", item.uploadMbps),
                                    ping: String(format: "%.1f ms", item.pingMilliseconds),
                                    jitter: String(format: "%.1f ms", item.jitterMilliseconds),
                                    server: item.serverName,
                                    publicIP: item.publicIPAddress,
                                    profile: item.profileName,
                                    network: item.networkName,
                                    isHeader: false
                                )
                                .background(selectedHistoryID == item.id ? Color.accentColor.opacity(0.08) : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { showHistoryItem(item) }
                                .contextMenu {
                                    Button("Show in Live Panel", systemImage: "arrow.up.right.square") { showHistoryItem(item) }
                                    Button("Delete Result", systemImage: "trash", role: .destructive) { deleteHistoryItem(item) }
                                }
                                Button(role: .destructive) { deleteHistoryItem(item) } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.borderless)
                                .help("Delete this saved test")
                            }
                            .frame(minWidth: 1260, alignment: .leading)
                            .help("Click to show this saved test in the live panel. Right-click to delete.")
                            Rectangle().fill(Color.accentColor.opacity(0.10)).frame(height: 1)
                        }
                    }
                }
                .frame(minWidth: 1230, alignment: .leading)
                .padding(.horizontal, 14)
            }
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.13)))
        }
    }

    private func historyRow(date: String, download: String, upload: String, ping: String, jitter: String, server: String, publicIP: String, profile: String, network: String, isHeader: Bool) -> some View {
        HStack(spacing: 12) {
            tableCell(date, width: 125, isHeader: isHeader)
            tableCell(download, width: 100, isHeader: isHeader)
            tableCell(upload, width: 100, isHeader: isHeader)
            tableCell(ping, width: 72, isHeader: isHeader)
            tableCell(jitter, width: 72, isHeader: isHeader)
            tableCell(server, width: 220, isHeader: isHeader)
            tableCell(publicIP, width: 125, isHeader: isHeader)
            tableCell(profile, width: 150, isHeader: isHeader)
            tableCell(network, width: 150, isHeader: isHeader)
        }
        .padding(.vertical, 10)
    }

    private func tableCell(_ value: String, width: CGFloat, isHeader: Bool) -> some View {
        Text(value)
            .font(.system(size: isHeader ? 10 : 11, weight: isHeader ? .semibold : .regular, design: isHeader ? .default : .monospaced))
            .foregroundStyle(isHeader ? Color.secondary : Color.primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: width, alignment: .leading)
            .help(value)
    }

    private func toggleTest() {
        if isRunning {
            testTask?.cancel()
            progress = "Test stopped"
            return
        }
        runTest()
    }

    private func runTest() {
        isRunning = true
        progress = "Checking public IP…"
        errorMessage = nil
        result = nil
        selectedHistoryID = nil
        downloadSamples = []
        uploadSamples = []
        currentLatency = nil
        routeLatency = nil
        currentPublicIP = nil

        let profileName = appState.lastAppliedProfile?.name ?? "No applied profile"
        let networkName = activeNetworkName
        let testServer = selectedSpeedTestServer

        testTask = Task {
            do {
                currentPublicIP = try? await SpeedTestClient.publicIPAddress()
                progress = "Measuring ping and jitter…"
                let latency = try await SpeedTestClient.measurePingAndJitter(server: testServer)
                currentLatency = latency
                routeLatency = latency

                progress = "Measuring download speed…"
                let download = try await SpeedTestClient.measureDownload(server: testServer) { sample in
                    downloadSamples.append(sample)
                }

                progress = "Measuring upload speed…"
                let upload = try await SpeedTestClient.measureUpload(server: testServer) { sample in
                    uploadSamples.append(sample)
                }

                let completedResult = SpeedTestDisplayResult(
                    id: UUID(),
                    downloadMbps: download.megabitsPerSecond,
                    uploadMbps: upload.megabitsPerSecond,
                    pingMilliseconds: latency.pingMilliseconds,
                    jitterMilliseconds: latency.jitterMilliseconds,
                    serverName: latency.serverName,
                    serverLocation: latency.serverLocation,
                    serverRequestID: latency.serverRequestID,
                    publicIPAddress: currentPublicIP ?? "Unavailable",
                    dataUsed: download.transferredBytes + upload.transferredBytes,
                    testedAt: Date(),
                    profileName: profileName,
                    networkName: networkName
                )
                result = completedResult
                history.insert(completedResult, at: 0)
                history = Array(history.prefix(Self.maximumHistoryCount))
                saveHistory()
                progress = "Test complete"
            } catch is CancellationError {
                progress = "Test stopped"
            } catch {
                if Task.isCancelled {
                    progress = "Test stopped"
                } else {
                    errorMessage = error.localizedDescription
                    progress = "Test failed"
                    downloadSamples = []
                    uploadSamples = []
                    currentLatency = nil
                    result = nil
                }
            }
            isRunning = false
            testTask = nil
        }
    }

    private static func loadHistory() -> [SpeedTestDisplayResult] {
        guard let data = UserDefaults.standard.data(forKey: historyStorageKey),
              let saved = try? JSONDecoder().decode([SpeedTestDisplayResult].self, from: data) else {
            return []
        }
        return Array(saved.prefix(maximumHistoryCount))
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyStorageKey)
    }

    private func showHistoryItem(_ item: SpeedTestDisplayResult) {
        guard !isRunning else { return }
        result = item
        selectedHistoryID = item.id
        errorMessage = nil
        downloadSamples = []
        uploadSamples = []
        currentLatency = nil
    }

    private func deleteHistoryItem(_ item: SpeedTestDisplayResult) {
        history.removeAll { $0.id == item.id }
        if selectedHistoryID == item.id {
            selectedHistoryID = nil
            result = nil
        }
        saveHistory()
    }

    private func clearHistory() {
        history.removeAll()
        selectedHistoryID = nil
        result = nil
        saveHistory()
    }

    private func refreshLiveRouteDetails() async {
        if currentPublicIP == nil {
            currentPublicIP = try? await SpeedTestClient.publicIPAddress()
        }
        if !didLoadServers {
            didLoadServers = true
            isLoadingServers = true
            speedTestServers = await SpeedTestClient.availableServers()
            recommendedServer = await SpeedTestClient.recommendServer(from: speedTestServers)
            if preferredServerID != Self.automaticServerID,
               !speedTestServers.contains(where: { $0.id == preferredServerID }) {
                preferredServerID = Self.automaticServerID
            }
            isLoadingServers = false
            await refreshSelectedServerLatency()
        }

        while !Task.isCancelled {
            appState.refreshNetworkInfo()
            let detectedInfo = await Task.detached(priority: .utility) {
                let services = (try? NetworkClient.services()) ?? []
                let candidates = services.compactMap { try? NetworkClient.info(for: $0) }
                let active = candidates.first { $0.ipAddress != "—" && !$0.ipAddress.isEmpty && $0.gateway != "—" }
                    ?? candidates.first { $0.ipAddress != "—" && !$0.ipAddress.isEmpty }
                guard var active else { return NetworkInfo(service: "") }
                // NetworkClient reports the associated Wi-Fi SSID globally, so
                // retain it only when the selected service is the Wi-Fi service.
                let isWiFiService = active.service.localizedCaseInsensitiveContains("wi-fi")
                    || active.service.localizedCaseInsensitiveContains("wifi")
                if !isWiFiService { active.ssid = "" }
                return active
            }.value
            liveNetworkInfo = detectedInfo
            if !isRunning && selectedHistoryID == nil {
                if let publicIP = try? await SpeedTestClient.publicIPAddress() {
                    currentPublicIP = publicIP
                }
                await refreshSelectedServerLatency(sampleCount: 2)
            }
            do {
                try await Task.sleep(nanoseconds: 60_000_000_000)
            } catch {
                break
            }
        }
    }

    private func refreshSelectedServerLatency(sampleCount: Int = 2) async {
        guard !isRunning, selectedHistoryID == nil else { return }
        let server = selectedSpeedTestServer
        isCheckingServer = true
        defer { isCheckingServer = false }
        if preferredServerID == Self.automaticServerID,
           let recommendation = recommendedServer,
           recommendation.server.id == server.id {
            routeLatency = recommendation.latency
        } else if let latency = try? await SpeedTestClient.measurePingAndJitter(
            server: server,
            sampleCount: sampleCount
        ) {
            routeLatency = latency
        }
    }
}

private struct ThroughputTrace: Shape {
    var samples: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !samples.isEmpty else {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
        let values = Array(samples.suffix(24))
        let maxValue = max(values.max() ?? 1, 1)
        for (index, value) in values.enumerated() {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
            let y = rect.maxY - rect.height * CGFloat(value / maxValue)
            let point = CGPoint(x: x, y: min(max(y, rect.minY + 2), rect.maxY - 2))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

private struct NetworkObservatoryGlobe: View {
    let isTesting: Bool
    let hasResult: Bool
    let progress: String
    let samples: [Double]
    let historyTimestamp: Date?

    private var isTransferring: Bool {
        progress.localizedCaseInsensitiveContains("download") || progress.localizedCaseInsensitiveContains("upload")
    }

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isTesting || !isTransferring)) { timeline in
                Image("SpeedTestGlobe")
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        if isTesting && isTransferring {
                            Canvas { context, size in
                                drawTransferPackets(
                                    in: &context,
                                    size: size,
                                    time: timeline.date.timeIntervalSinceReferenceDate
                                )
                            }
                        }
                    }
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(isTesting ? progress : (historyTimestamp.map { "Saved result · \($0.formatted(date: .abbreviated, time: .shortened))" } ?? (hasResult ? "Measurement complete" : "Ready to measure")))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(height: 18)
            ThroughputTrace(samples: samples)
                .stroke(
                    LinearGradient(colors: [.blue.opacity(0.2), .blue, .purple, .teal], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .frame(height: 20)
                .padding(.horizontal, 34)
        }
    }

    private func drawTransferPackets(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        // Keep the transfer animation tied to actual download/upload phases.
        let routes: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: 0.38, y: 0.79), CGPoint(x: 0.50, y: 0.45), CGPoint(x: 0.73, y: 0.46)),
            (CGPoint(x: 0.24, y: 0.40), CGPoint(x: 0.34, y: 0.66), CGPoint(x: 0.48, y: 0.66)),
            (CGPoint(x: 0.51, y: 0.35), CGPoint(x: 0.63, y: 0.39), CGPoint(x: 0.73, y: 0.46))
        ]

        for (index, route) in routes.enumerated() {
            let (start, control, end) = route
            let phase = (time * 0.66 + Double(index) / Double(routes.count)).truncatingRemainder(dividingBy: 1)
            let t = CGFloat(phase)
            let inverse = 1 - t
            let point = CGPoint(
                x: size.width * (inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x),
                y: size.height * (inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y)
            )
            let glowRect = CGRect(x: point.x - 13, y: point.y - 13, width: 26, height: 26)
            context.fill(
                Path(ellipseIn: glowRect),
                with: .radialGradient(
                    Gradient(colors: [Color.cyan.opacity(0.75), Color.blue.opacity(0.26), .clear]),
                    center: point,
                    startRadius: 0,
                    endRadius: 13
                )
            )
            let core = Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
            context.fill(core, with: .color(.white))
            context.stroke(core, with: .color(Color.cyan.opacity(0.95)), lineWidth: 1)
        }
    }
}
