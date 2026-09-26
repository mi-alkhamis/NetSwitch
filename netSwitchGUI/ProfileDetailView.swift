import SwiftUI
import NetSwitchCore

struct ProfileDetailView: View {
    @EnvironmentObject private var appState: AppState

    let profile: Profile

    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPreview = false

    private var isActive: Bool {
        appState.activeProfile?.id == profile.id
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: profile.useDHCP ? "checkmark.seal.fill" : "network.badge.shield.half.filled")
                            .font(.title2)
                            .foregroundStyle(profile.useDHCP ? .green : .blue)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.headline)
                                .textSelection(.enabled)

                            Text(profile.useDHCP ? "DHCP (Automatic IP)" : "Static IP Configuration")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if appState.activeProfile?.id == profile.id {
                            ChipLabel(text: "Current", systemImage: "checkmark.circle.fill", tint: .green, bold: true)
                        }
                    }
                }

                if profile.useDHCP {
                    Section {
                        EmptyNetworkConfigRow(systemImage: "arrow.triangle.2.circlepath", desc: "IP address is assigned automatically by your router")
                    } header: {
                        Text("IP Configuration")
                    }
                } else {
                    Section {
                        IPConfigRow(title: "IP Address", value: profile.ipAddress)
                        IPConfigRow(title: "Subnet Mask", value: profile.subnetMask)
                        IPConfigRow(title: "Router / Gateway", value: profile.gateway)
                    } header: {
                        Text("Static IP Configuration")
                    }
                }

                Section(header: Text("DNS Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("DNS Servers")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(profile.dnsServers.isEmpty ? "System default" : "\(profile.dnsServers.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if profile.dnsServers.isEmpty {
                            Text("No custom DNS servers configured — using system default resolvers.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(profile.dnsServers, id: \.self) { server in
                                DNSServerRow(server: server)
                            }
                        }
                    }
                }

                if profile.dnsServers.isEmpty {
                    Section {
                        EmptyNetworkConfigRow(systemImage: "server.rack", desc: "DNS servers are using default system configuration")
                    } header: {
                        Text("DNS Servers")
                    }
                }
            }
            .navigationTitle(profile.name)
            .toolbar {
                ToolbarItem {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Apply") {
                        if appState.activeProfile?.id != profile.id {
                            appState.apply(profile)
                        }
                    }
                    .disabled(appState.activeProfile?.id == profile.id)
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                ProfileEditorView(profile: profile) { updatedProfile in
                    appState.updateProfile(updatedProfile)
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            ProfilePreviewSheet(profile: profile) {
                appState.apply(profile)
            }
        }
        .confirmationDialog(
            "Delete \(profile.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Profile", role: .destructive) {
                appState.delete(profile)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved profile. It does not change your current network settings.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(profile.name)
                        .font(.title.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Active")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12), in: Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: profile.useDHCP
                        ? "arrow.triangle.2.circlepath"
                        : "slider.horizontal.3")
                        .font(.caption2.weight(.semibold))
                    Text(profile.useDHCP ? "DHCP Automatic Configuration" : "Static IP Manual Configuration")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color(nsColor: .separatorColor).opacity(0.3), in: Capsule())
            }

            Spacer(minLength: 12)

            // Large tinted icon tile (Concept B aesthetic)
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                (profile.useDHCP ? Color.green : Color.blue).opacity(0.18),
                                (profile.useDHCP ? Color.green : Color.blue).opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(
                    systemName: profile.useDHCP
                        ? "arrow.triangle.2.circlepath.circle.fill"
                        : "network"
                )
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(profile.useDHCP ? .green : .blue)
            }
            .frame(width: 56, height: 56)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Primary action — Apply Profile
            Button {
                showingPreview = true
            } label: {
                HStack(spacing: 6) {
                    if appState.isApplying {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                    Text(appState.isApplying ? "Applying…" : "Apply Profile")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.isApplying)
            .keyboardShortcut(.return, modifiers: .command)

            Button {
                showingEditor = true
            } label: {
                Label("Edit", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            // Secondary icon-only actions (visually separated from primary)
            Button {
                appState.addProfile(duplicate(of: profile))
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Duplicate profile")

            Button("Delete", systemImage: "trash", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Delete profile")
        }
        .animation(.easeInOut(duration: 0.2), value: appState.isApplying)
    }

    /// Copies a profile under the first unused "Copy" name. Duplicating twice used to produce
    /// "<name> Copy" both times, and the second attempt was rejected as a duplicate name.
    /// Matches `ProfileStore`'s case-insensitive uniqueness rule.
    private func duplicate(of profile: Profile) -> Profile {
        let taken = Set(appState.profiles.map { $0.name.lowercased() })
        var name = "\(profile.name) Copy"
        var suffix = 2

        while taken.contains(name.lowercased()) {
            name = "\(profile.name) Copy \(suffix)"
            suffix += 1
        }

        return Profile(
            name: name,
            service: profile.service,
            useDHCP: profile.useDHCP,
            ipAddress: profile.ipAddress,
            subnetMask: profile.subnetMask,
            gateway: profile.gateway,
            dnsServers: profile.dnsServers
        )
    }
}

// MARK: - Profile Value Card

struct ProfileValueCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.15))
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)

                Text(value)
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        )
    }
}

// MARK: - Profile Preview Sheet

private struct ProfilePreviewSheet: View {
    let profile: Profile
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                Text("Review Changes")
                    .font(.title2.weight(.bold))

                Text("Confirm applying profile **\(profile.name)**")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            // Preview Section
            VStack(alignment: .leading, spacing: 12) {
                PreviewRow(label: "Mode", value: profile.useDHCP ? "DHCP" : "Static IP")
                PreviewRow(label: "Service", value: profile.service)

                if !profile.useDHCP {
                    PreviewRow(label: "IP Address", value: profile.ipAddress)
                    PreviewRow(label: "Subnet Mask", value: profile.subnetMask)
                    PreviewRow(label: "Gateway", value: profile.gateway)
                }

                PreviewRow(
                    label: "DNS",
                    value: profile.dnsServers.isEmpty ? "System default" : profile.dnsServers.joined(separator: ", ")
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Divider()

            // Actions
            HStack(spacing: 10) {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .frame(maxWidth: .infinity)

                Button {
                    onApply()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("Apply Profile")
                    }
                    .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct PreviewRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(value)
                .font(.callout.monospacedDigit().weight(.medium))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
