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
    let publicIPAddress: String
    let dataUsed: Int
    let testedAt: Date
    let profileName: String
    let networkName: String
}

struct SpeedTestView: View {
    private static let historyStorageKey = "netSwitch.speedTestHistory.v1"
    private static let maximumHistoryCount = 100

    @EnvironmentObject private var appState: AppState
    @State private var isRunning = false
    @State private var progress = ""
    @State private var result: SpeedTestDisplayResult? = SpeedTestView.loadHistory().first
    @State private var history: [SpeedTestDisplayResult] = SpeedTestView.loadHistory()
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Speed Test")
                            .font(.system(size: 26, weight: .bold))
                        Text("Measure your internet download and upload speeds.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: runTest) {
                        Label(isRunning ? "Testing…" : "Start Test", systemImage: isRunning ? "hourglass" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                }

                HStack(spacing: 16) {
                    metricCard(title: "DOWNLOAD", value: result.map { String(format: "%.1f", $0.downloadMbps) } ?? "—", unit: "Mbps", image: "arrow.down.circle.fill")
                    metricCard(title: "UPLOAD", value: result.map { String(format: "%.1f", $0.uploadMbps) } ?? "—", unit: "Mbps", image: "arrow.up.circle.fill")
                }

                HStack(spacing: 16) {
                    metricCard(title: "PING", value: result.map { String(format: "%.1f", $0.pingMilliseconds) } ?? "—", unit: "ms", image: "arrow.left.arrow.right")
                    metricCard(title: "JITTER", value: result.map { String(format: "%.1f", $0.jitterMilliseconds) } ?? "—", unit: "ms", image: "waveform.path")
                }

                HStack(spacing: 12) {
                    serverInfo(title: "TEST SERVER", value: result?.serverName ?? "—", image: "server.rack")
                    serverInfo(title: "SERVER LOCATION", value: result?.serverLocation ?? "—", image: "location")
                    serverInfo(title: "PUBLIC IP", value: result?.publicIPAddress ?? "—", image: "globe")
                }

                if isRunning || !progress.isEmpty {
                    Label(progress, systemImage: isRunning ? "waveform.path" : "checkmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                if let result {
                    Text("Completed at \(result.testedAt.formatted(date: .omitted, time: .shortened)) · about \(ByteCountFormatter.string(fromByteCount: Int64(result.dataUsed), countStyle: .decimal)) transferred")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                historySection

                Text("Uses Cloudflare’s speed test service. The test transfers about 12 MB; Cloudflare says completed test measurements are collected for aggregated connection quality insights.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(red: 0.975, green: 0.981, blue: 0.991))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PREVIOUS TESTS")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    historyRow(
                        date: "DATE",
                        download: "DOWNLOAD",
                        upload: "UPLOAD",
                        ping: "PING",
                        jitter: "JITTER",
                        server: "SERVER",
                        publicIP: "PUBLIC IP",
                        profile: "PROFILE",
                        network: "NETWORK",
                        isHeader: true
                    )
                    Rectangle().fill(Color.accentColor.opacity(0.14)).frame(height: 1)

                    if history.isEmpty {
                        Text("Completed speed tests will appear here.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 18)
                    } else {
                        ForEach(history) { item in
                            historyRow(
                                date: item.testedAt.formatted(date: .numeric, time: .shortened),
                                download: String(format: "%.1f Mbps", item.downloadMbps),
                                upload: String(format: "%.1f Mbps", item.uploadMbps),
                                ping: String(format: "%.1f ms", item.pingMilliseconds),
                                jitter: String(format: "%.1f ms", item.jitterMilliseconds),
                                server: "\(item.serverName) (\(item.serverLocation))",
                                publicIP: item.publicIPAddress,
                                profile: item.profileName,
                                network: item.networkName,
                                isHeader: false
                            )
                            Rectangle().fill(Color.accentColor.opacity(0.10)).frame(height: 1)
                        }
                    }
                }
                .frame(minWidth: 1145, alignment: .leading)
                .padding(.horizontal, 16)
            }
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.13)))
        }
    }

    private func historyRow(
        date: String,
        download: String,
        upload: String,
        ping: String,
        jitter: String,
        server: String,
        publicIP: String,
        profile: String,
        network: String,
        isHeader: Bool
    ) -> some View {
        HStack(spacing: 12) {
            tableCell(date, width: 130, isHeader: isHeader)
            tableCell(download, width: 100, isHeader: isHeader)
            tableCell(upload, width: 100, isHeader: isHeader)
            tableCell(ping, width: 75, isHeader: isHeader)
            tableCell(jitter, width: 75, isHeader: isHeader)
            tableCell(server, width: 175, isHeader: isHeader)
            tableCell(publicIP, width: 125, isHeader: isHeader)
            tableCell(profile, width: 150, isHeader: isHeader)
            tableCell(network, width: 130, isHeader: isHeader)
        }
        .padding(.vertical, 11)
    }

    private func tableCell(_ value: String, width: CGFloat, isHeader: Bool) -> some View {
        Text(value)
            .font(.system(size: isHeader ? 10 : 12, weight: isHeader ? .semibold : .regular, design: isHeader ? .default : .monospaced))
            .foregroundStyle(isHeader ? Color.secondary : Color.primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: width, alignment: .leading)
            .help(value)
    }

    private func serverInfo(title: String, value: String, image: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: image)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 13, weight: .medium)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.13)))
    }

    private func metricCard(title: String, value: String, unit: String, image: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: image)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(value).font(.system(size: 36, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(unit).font(.system(size: 15)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor.opacity(0.13)))
    }

    private func runTest() {
        isRunning = true
        progress = "Checking public IP…"
        errorMessage = nil
        let profileName = appState.lastAppliedProfile?.name ?? "No applied profile"
        let networkName = appState.networkInfo.ssid.isEmpty ? "Unknown" : appState.networkInfo.ssid
        Task {
            do {
                let publicIP = (try? await SpeedTestClient.publicIPAddress()) ?? "Unavailable"
                progress = "Measuring ping and jitter…"
                let latency = try await SpeedTestClient.measurePingAndJitter()
                progress = "Measuring download speed…"
                let download = try await SpeedTestClient.measureDownload()
                progress = "Measuring upload speed…"
                let upload = try await SpeedTestClient.measureUpload()
                let completedResult = SpeedTestDisplayResult(
                    id: UUID(),
                    downloadMbps: download.megabitsPerSecond,
                    uploadMbps: upload.megabitsPerSecond,
                    pingMilliseconds: latency.pingMilliseconds,
                    jitterMilliseconds: latency.jitterMilliseconds,
                    serverName: latency.serverName,
                    serverLocation: latency.serverLocation,
                    publicIPAddress: publicIP,
                    dataUsed: download.transferredBytes + upload.transferredBytes,
                    testedAt: Date(),
                    profileName: profileName,
                    networkName: networkName
                )
                result = completedResult
                history.insert(completedResult, at: 0)
                history = Array(history.prefix(Self.maximumHistoryCount))
                saveHistory()
                progress = "Speed test complete"
            } catch {
                errorMessage = error.localizedDescription
                progress = ""
            }
            isRunning = false
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
}

