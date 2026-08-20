import SwiftUI
import NetSwitchCore

struct PreferencesView: View {
    enum Selection: Hashable {
        case status
        case profile(UUID)
    }

    @EnvironmentObject private var appState: AppState

    @State private var selection: Selection? = .status
    @State private var showingNewProfileEditor = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Overview") {
                    Label("Status", systemImage: "chart.bar.fill")
                        .tag(Selection.status)
                }

                Section("Profiles") {
                    ForEach(appState.profiles) { profile in
                        Label(
                            profile.name,
                            systemImage: profile.useDHCP
                                ? "arrow.triangle.2.circlepath"
                                : "network"
                        )
                        .tag(Selection.profile(profile.id))
                    }
                }
            }
            .navigationTitle("NetSwitch")
            .toolbar {
                ToolbarItem {
                    Button {
                        showingNewProfileEditor = true
                    } label: {
                        Label("New Profile", systemImage: "plus")
                    }
                }
            }
        } detail: {
            detailView
        }
        .frame(minWidth: 860, minHeight: 560)
        .sheet(isPresented: $showingNewProfileEditor) {
            NavigationStack {
                ProfileEditorView(profile: nil) { newProfile in
                    appState.addProfile(newProfile)
                    selection = .profile(newProfile.id)
                }
            }
        }
        .alert(item: $appState.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .status, .none:
            StatusView()

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
        }
    }
}
