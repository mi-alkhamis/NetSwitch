import SwiftUI

@main
struct NetSwitchApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        Window("NetSwitch", id: "management") {
            PreferencesView()
                .environmentObject(appState)
        }
        .defaultSize(width: 1200, height: 800)

        MenuBarExtra("NetSwitch", systemImage: "network") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
