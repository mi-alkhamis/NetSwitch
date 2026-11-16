import SwiftUI
import NetSwitchCore

private enum SidebarDestination: Hashable {
    case status
    case wifi
    case speedTest
    case dnsBenchmark
    case profile(UUID)
}

struct PreferencesView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selection: SidebarDestination? = .status
    @State private var showingNewProfileEditor = false
    @State private var showingRemoveProfileConfirmation = false
    @State private var profileToRemove: Profile?
    @State private var searchText = ""
    @State private var localBanner: AppAlert?

    private var filteredProfiles: [Profile] {
        if searchText.isEmpty {
            return appState.profiles
        }
        return appState.profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            appState.requestWiFiAuthorization()
        }
        .sheet(isPresented: $showingNewProfileEditor) {
            NavigationStack {
                ProfileEditorView(profile: nil) { newProfile in
                    appState.addProfile(newProfile)
                    selection = .profile(newProfile.id)
                }
            }
        }
        .confirmationDialog(
            "Remove \(profileToRemove?.name ?? "profile")?",
            isPresented: $showingRemoveProfileConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Profile", role: .destructive) {
                guard let profile = profileToRemove else { return }
                appState.delete(profile)
                profileToRemove = nil
            }
            Button("Cancel", role: .cancel) { profileToRemove = nil }
        } message: {
            Text("This removes the profile from this Mac.")
        }
        .onChange(of: appState.alert?.id) { _, _ in
            guard let newValue = appState.alert else { return }
            localBanner = newValue

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if localBanner?.id == newValue.id {
                    localBanner = nil
                }
            }
        }
        .onChange(of: appState.profiles.map(\.id)) { _, profileIDs in
            if case let .profile(id) = selection, !profileIDs.contains(id) {
                selection = .status
            }
        }
        .overlay(alignment: .top) {
            if let localBanner {
                HStack(spacing: 6) {
                    Image(systemName: localBanner.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(localBanner.kind == .success ? .green : .red)
                    Text(localBanner.message)
                        .font(.caption)
                        .lineLimit(2)
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: localBanner.id)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                searchField

                VStack(alignment: .leading, spacing: 8) {
                    sidebarSectionTitle("OVERVIEW")
                    sidebarNavigationRow(
                        "Status",
                        systemImage: "chart.bar.fill",
                        destination: .status
                    )
                    sidebarNavigationRow(
                        "Wi-Fi Networks",
                        systemImage: "wifi",
                        destination: .wifi
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    sidebarSectionTitle("TOOLS")
                    sidebarNavigationRow(
                        "Speed Test",
                        systemImage: "speedometer",
                        destination: .speedTest
                    )
                    sidebarNavigationRow(
                        "DNS Benchmark",
                        systemImage: "server.rack",
                        destination: .dnsBenchmark,
                        badge: "SOON"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("PROFILES")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(0.35)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            showingNewProfileEditor = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 22, height: 22)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("New Profile")
                        Text("\(appState.profiles.count)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 4)

                    if filteredProfiles.isEmpty {
                        Text(searchText.isEmpty ? "No profiles" : "No matching profiles")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filteredProfiles) { profile in
                            profileSidebarRow(profile)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.925, green: 0.937, blue: 0.953))
        .scrollIndicators(.visible)
        .navigationTitle("NetSwitch")
        .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 350)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.secondary)
            TextField("Search profiles", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .accessibilityLabel("Search profiles")
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color.primary.opacity(0.055), in: Capsule())
    }

    private func sidebarSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .tracking(0.35)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private func sidebarNavigationRow(
        _ title: String,
        systemImage: String,
        destination: SidebarDestination,
        badge: String? = nil
    ) -> some View {
        let isSelected = selection == destination

        return Button {
            selection = destination
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.3)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.accentColor.opacity(0.2))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func profileSidebarRow(_ profile: Profile) -> some View {
        let destination = SidebarDestination.profile(profile.id)
        let isSelected = selection == destination
        let subtitle = profile.useDHCP ? "DHCP" : "\(profile.ipAddress)  •  Static"

        return Button {
            selection = destination
        } label: {
            HStack(spacing: 12) {
                Image(systemName: profile.useDHCP
                    ? "arrow.triangle.2.circlepath.circle.fill"
                    : "wifi")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.name)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.accentColor.opacity(0.2))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            guard !appState.isApplying else { return }
            appState.apply(profile)
        })
        .contextMenu {
            Button("Remove Profile", systemImage: "trash", role: .destructive) {
                profileToRemove = profile
                showingRemoveProfileConfirmation = true
            }
        }
        .help("Click to view · Double-click to apply")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .wifi:
            WiFiScannerView()
        case .speedTest:
            SpeedTestView()
        case .dnsBenchmark:
            ZStack {
                DNSBenchmarkView()
                    .blur(radius: 5)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                VStack(spacing: 10) {
                    Image(systemName: "clock.badge.hourglass")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                    Text("Coming Soon")
                        .font(.system(size: 22, weight: .semibold))
                    Text("DNS Benchmark is under development.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.primary.opacity(0.08)))
            }
        case let .profile(id):
            if let profile = appState.profiles.first(where: { $0.id == id }) {
                ProfileDetailView(profile: profile)
            } else {
                ContentUnavailableView(
                    "Profile Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Choose another profile from the sidebar.")
                )
            }
        case .status, nil:
            StatusView()
        }
    }
}

