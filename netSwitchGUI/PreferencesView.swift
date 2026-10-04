import SwiftUI
import NetSwitchCore

private enum SidebarDestination: Hashable {
    case status
    case wifi
    case profile(UUID)
}

struct PreferencesView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selection: SidebarDestination? = .status
    @State private var showingNewProfileEditor = false
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
        
        .onChange(of: appState.alert?.id) { _, _ in
            guard let newValue = appState.alert else { return }
            localBanner = newValue

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if localBanner?.id == newValue.id {
                    localBanner = nil
                }
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
        List(selection: $selection) {
            Section("Overview") {
                Label("Status", systemImage: "chart.bar.fill")
                    .tag(SidebarDestination.status)

                Label("Wi-Fi Networks", systemImage: "wifi")
                    .tag(SidebarDestination.wifi)
            }

            Section {
                ForEach(filteredProfiles) { profile in
                    profileSidebarRow(profile)
                        .tag(SidebarDestination.profile(profile.id))
                }
            } header: {
                HStack {
                    Text("Profiles")
                    Spacer()
                    Text("\(appState.profiles.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("NetSwitch")
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search profiles")
        .toolbar {
            ToolbarItem {
                Button {
                    showingNewProfileEditor = true
                } label: {
                    Label("New Profile", systemImage: "plus")
                }
            }
        }
    }

    private func profileSidebarRow(_ profile: Profile) -> some View {
        let isActive = appState.activeProfile?.id == profile.id

        return Label {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(profile.name)
                        .font(.system(size: 13, weight: isActive ? .semibold : .regular))

                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                Text(profile.useDHCP ? "DHCP" : "\(profile.ipAddress) • Static")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(
                systemName: profile.useDHCP
                    ? "arrow.triangle.2.circlepath.circle.fill"
                    : "network.badge.shield.half.filled"
            )
            .foregroundStyle(isActive ? .green : (profile.useDHCP ? .blue : .orange))
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .wifi:
            WiFiScannerView()
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

