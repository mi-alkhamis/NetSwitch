import SwiftUI
import NetSwitchCore

struct PreferencesView: View {
    // Fixed placeholder IDs for the two non-profile sidebar rows.
    // These never change and are not tied to any real data, so there's
    // nothing for the system to reconstruct incorrectly on relaunch.
    private static let statusID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let wifiID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    

    @EnvironmentObject private var appState: AppState

    @State private var selection: UUID? = PreferencesView.statusID
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
        .frame(minWidth: 760, minHeight: 480)
        .onAppear {
            appState.requestWiFiAuthorization()
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showingNewProfileEditor) {
            NavigationStack {
                ProfileEditorView(profile: nil) { newProfile in
                    appState.addProfile(newProfile)
                    selection = newProfile.id
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
                    .tag(Self.statusID)

                Label("Wi-Fi Networks", systemImage: "wifi")
                    .tag(Self.wifiID)
            }

            Section {
                ForEach(filteredProfiles) { profile in
                    profileSidebarRow(profile)
                        .tag(profile.id)
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
        if selection == Self.wifiID {
            WiFiScannerView()
        } else if let id = selection, let profile = appState.profiles.first(where: { $0.id == id }) {
            ProfileDetailView(profile: profile)
        } else if let id = selection, id != Self.statusID {
            // Selection points at a profile that no longer exists
            // (e.g. it was deleted, or restored from a previous session).
            ContentUnavailableView(
                "Profile Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("Choose another profile from the sidebar.")
            )
        } else {
            StatusView()
        }
    }
}

