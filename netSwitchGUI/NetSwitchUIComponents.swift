import SwiftUI
import Combine

#if os(macOS)
import CoreWLAN
#endif

// MARK: - IP Text Field with Live Validation

struct IPTextField: View {
    let title: String
    @Binding var text: String
    @State private var hasFocused = false

    private var isValid: Bool {
        text.isEmpty || validIP(text)
    }

    private var showError: Bool {
        hasFocused && !text.isEmpty && !isValid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: $text)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(showError ? Color.red : Color.clear, lineWidth: 2)
                        .animation(.easeInOut(duration: 0.2), value: showError)
                )
                .onChange(of: text) {
                    hasFocused = true
                }

            if showError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("Enter a valid IPv4 address, e.g. 192.168.1.1")
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Signal Strength Bars

struct SignalStrengthView: View {
    let dbm: Int

    private var bars: Int {
        switch dbm {
        case -50...(-30):
            return 4
        case -65...(-51):
            return 3
        case -80...(-66):
            return 2
        default:
            return 1
        }
    }

    private var color: Color {
        switch bars {
        case 4, 3: return .green
        case 2: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(i < bars ? color : Color(nsColor: .separatorColor))
                    .frame(width: 4.5, height: CGFloat(6 + i * 5))
            }
        }
        .frame(height: 24)
    }
}

// MARK: - Flow Layout for Chips

struct FlowLayout: Layout {
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

        return CGSize(width: maxWidth, height: currentY + rowHeight)
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

// MARK: - IP Validation Helper

func validIP(_ s: String) -> Bool {
    let parts = s.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 4 else { return false }
    return parts.allSatisfy {
        guard let n = Int($0) else { return false }
        return (0...255).contains(n)
    }
}

// MARK: - Chip Label

struct ChipLabel: View {
    let text: String
    let systemImage: String
    let tint: Color
    var bold: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(text)
                .font(bold ? .caption.weight(.semibold) : .caption)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

// MARK: - Empty Network Config Row

struct EmptyNetworkConfigRow: View {
    let systemImage: String
    let desc: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Text(desc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - IP Config Row

struct IPConfigRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Wi-Fi Name Provider (macOS)

#if os(macOS)
final class WiFiNameProvider: ObservableObject {
    /// An empty string means the service is not connected to Wi‑Fi.
    @Published var ssid: String? = nil

    private let client = CWWiFiClient.shared()

    init() {
        refresh()
    }

    func refresh() {
        // CoreWLAN provides current interface details without special entitlements on macOS
        if let interface = client.interface(), let name = interface.ssid() {
            ssid = name
        } else {
            ssid = nil
        }
    }
}

struct WiFiNameView: View {
    @StateObject private var provider = WiFiNameProvider()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi")
                .foregroundStyle(.secondary)
            Text(provider.ssid ?? "Not Connected")
                .font(.body)
                .monospaced()
            Spacer()
            Button {
                provider.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh Wi‑Fi name")
        }
        .padding(.vertical, 4)
    }
}
#endif


