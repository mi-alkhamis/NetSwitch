import SwiftUI
import NetSwitchCore

struct StatusView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                statusSummary

                HStack(spacing: 16) {
                    NetworkStatusCard(
                        title: "IP Address",
                        value: appState.networkInfo.ipAddress,
                        systemImage: "network"
                    )

                    NetworkStatusCard(
                        title: "Subnet Mask",
                        value: appState.networkInfo.subnetMask,
                        systemImage: "rectangle.3.group"
                    )

                    NetworkStatusCard(
                        title: "Gateway",
                        value: appState.networkInfo.gateway,
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                }

                dnsSection

                HStack {
                    Button {
                        appState.refreshNetworkInfo()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(appState.isRefreshing)

                    if appState.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()
                }
            }
            .padding(28)
        }
        .navigationTitle("Network Status")
        .onAppear {
            appState.refreshNetworkInfo()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Network")
                    .font(.headline)

                Text("Wi-Fi: \(appState.wifiName)")
                    .foregroundStyle(.secondary)

                Text("Service: \(appState.networkInfo.service)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.green.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var statusSummary: some View {
        HStack {
            Image(systemName: "wifi")
                .font(.largeTitle)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 3) {
                Text(appState.wifiName)
                    .font(.title2.weight(.semibold))

                Text("Network details shown below are loaded from Wi-Fi.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var dnsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("DNS Servers", systemImage: "server.rack")
                .font(.headline)

            if appState.networkInfo.dnsServers.isEmpty {
                Text("No DNS servers reported for this service.")
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(appState.networkInfo.dnsServers, id: \.self) { server in
                        Text(server)
                            .font(.body.monospacedDigit())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.quaternary)
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(
            width: maxWidth,
            height: currentY + rowHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )

            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
