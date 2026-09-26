//
//  WiFiAuthorization.swift
//  NetSwitchCore
//
//  Created by Milad Alkhamis on 9/13/26.
//


import CoreLocation

/// Requests Location authorization, which macOS requires before Wi-Fi
/// SSID/signal/security details can be read via CoreWLAN.
public final class WiFiAuthorization: NSObject, CLLocationManagerDelegate {
    public static let shared = WiFiAuthorization()

    private let manager = CLLocationManager()
    private var onChange: (() -> Void)?

    override private init() {
        super.init()
        manager.delegate = self
    }

    public var isAuthorized: Bool {
        manager.authorizationStatus == .authorized
    }
    
    /// Call once at app launch. If permission isn't decided yet, this shows
    /// the system prompt; `onChange` fires once the user responds.
    public func requestAuthorization(onChange: @escaping () -> Void) {
        self.onChange = onChange
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            onChange()
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.onChange?()
        }
    }
}
