import Combine
import NetSwitchCore

@MainActor
final class WiFiScannerController: ObservableObject {
    @Published private(set) var wifiNetworks: [WiFiNetwork] = []
    @Published private(set) var isScanningWiFi = false

    func scanWiFi() { /* CoreWLAN scan */ }
    func connect(to network: WiFiNetwork, password: String, save: Bool) { /* connect logic */ }
}
