import SwiftUI

@main
struct NetSwitchApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("NetSwitch", systemImage: "network") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}
