import SwiftUI

struct NetworkStatusView: View {
    enum SidebarItem: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case status = "Status"
        case wifi = "WiFi Networks"
        case info = "Network Info"
    }

    @State private var selection: SidebarItem? = .status
    @State private var selectedProfile: String? = "Home (DHCP)"
    @State private var dnsServers: [String] = ["1.1.1.1", "1.0.0.1"]

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(minWidth: 220, maxWidth: 260)
                .background(Color(nsColor: .windowBackgroundColor))
                .overlay(Divider(), alignment: .trailing)

            content
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
    }

    var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("OVERVIEW")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 14)

                ForEach([SidebarItem.status, .wifi, .info]) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .strokeBorder(Color.gray.opacity(selection == item ? 0 : 0.5), lineWidth: 1)
                            .background(Circle().foregroundColor(selection == item ? Color.blue.opacity(0.2) : Color.clear))
                            .frame(width: 18, height: 18)

                        Text(item.rawValue)
                            .foregroundColor(selection == item ? .blue : .primary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(selection == item ? Color.blue.opacity(0.12) : Color.clear)
                    .cornerRadius(8)
                    .onTapGesture { selection = item }
                }
            }
            .padding(.horizontal, 16)

            Divider()
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 10) {
                Text("PROFILES")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(["Home (DHCP)", "Office (Static)", "Lab Network"], id: \.
                    self) { profile in
                    HStack(spacing: 10) {
                        Circle()
                            .strokeBorder(Color.gray.opacity(0.5), lineWidth: 1)
                            .frame(width: 16, height: 16)
                        Text(profile)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .onTapGesture { selectedProfile = profile }
                }

                Spacer()

                Button(action: {}) {
                    Text("+ New Profile")
                        .foregroundColor(Color.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 8)
                .padding(.leading, 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text("Network Status")
                    .font(.title2)
                    .bold()

                Spacer()

                Text("Connected")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(14)
            }

            // Info Cards
            HStack(spacing: 14) {
                infoCard(title: "IP ADDRESS", value: "192.168.1.42")
                infoCard(title: "SUBNET MASK", value: "255.255.255.0")
                infoCard(title: "GATEWAY", value: "192.168.1.1")
            }

            // DNS area
            VStack(alignment: .leading, spacing: 8) {
                Text("DNS SERVERS")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    ForEach(dnsServers, id: \.
                        self) { dns in
                        Text(dns)
                            .font(.system(.body, design: .monospaced))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                    }
                    Spacer()
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: {}) {
                    Text("Apply Home Profile")
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                }
                .buttonStyle(BlueButtonStyle())

                Button(action: {}) {
                    Text("Refresh")
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                }
                .buttonStyle(GrayButtonStyle())

                Button(action: {}) {
                    Text("Copy Info")
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                }
                .buttonStyle(GrayButtonStyle())

                Spacer()
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.15)))
    }

    func infoCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding()
        .frame(minWidth: 140)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
    }
}

// MARK: - Button Styles
struct BlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.blue.opacity(0.7) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

struct GrayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(NSColor.controlBackgroundColor).opacity(0.9) : Color(NSColor.controlBackgroundColor))
            .foregroundColor(.primary)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
            .cornerRadius(8)
    }
}

// MARK: - Preview
struct NetworkStatusView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkStatusView()
            .frame(width: 980, height: 540)
    }
}
