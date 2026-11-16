import SwiftUI
import NetSwitchCore

struct DNSBenchmarkView: View {
    @State private var isRunning = false
    @State private var results: [DNSBenchmarkResult] = []
    @State private var errorMessage: String?

    private var fastestResolverID: String? {
        results.first(where: { $0.successfulQueries == 3 })?.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("DNS Benchmark")
                            .font(.system(size: 26, weight: .bold))
                        Text("Compare public DNS resolvers on this network.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: runBenchmark) {
                        Label(isRunning ? "Checking…" : "Find Fastest", systemImage: isRunning ? "hourglass" : "chart.line.uptrend.xyaxis")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                }

                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        resolverRow(result, rank: index + 1)
                        if index < results.count - 1 {
                            Rectangle().fill(Color.accentColor.opacity(0.12)).frame(height: 1).padding(.leading, 18)
                        }
                    }
                    if results.isEmpty {
                        ContentUnavailableView("No Results Yet", systemImage: "server.rack", description: Text("Run the benchmark to check resolver connectivity and latency."))
                            .padding(.vertical, 28)
                    }
                }
                .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor.opacity(0.13)))

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                Text("Tests use three DNS-over-HTTPS lookups per provider. The fastest fully reachable resolver is marked; the listed IP can be added to a profile manually.")
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

    private func resolverRow(_ result: DNSBenchmarkResult, rank: Int) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", rank))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color.secondary.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(result.name).font(.system(size: 15, weight: .semibold))
                    if result.id == fastestResolverID {
                        Text("FASTEST")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
                Text(result.address)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let latency = result.averageLatencyMilliseconds {
                Text(String(format: "%.0f ms", latency))
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            } else {
                Text("Unreachable")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Image(systemName: result.successfulQueries == 3 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(result.successfulQueries == 3 ? .green : .orange)
        }
        .padding(.horizontal, 18)
        .frame(height: 68)
    }

    private func runBenchmark() {
        isRunning = true
        results = []
        errorMessage = nil
        Task {
            results = await DNSBenchmarkClient.run()
            if results.allSatisfy({ $0.successfulQueries == 0 }) {
                errorMessage = "Could not reach the DNS benchmark services. Check your internet connection and try again."
            }
            isRunning = false
        }
    }
}
