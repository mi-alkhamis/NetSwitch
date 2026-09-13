import SwiftUI

@main
struct NetSwitchApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("NetSwitch") {
            PreferencesView()
                .environmentObject(appState)
        }

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
