//
//  MurMurApp.swift
//  MurMur
//
//  Created by Niraj Nair on 12/08/25.
//

import FirebaseCore
import FirebaseRemoteConfig
import KeyboardKit
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        setupRemoteConfig()
        return true
    }

    private func setupRemoteConfig() {
        let remoteConfig = RemoteConfig.remoteConfig()
        let defaults: [String: NSObject] = [
            AppGroupConstants.appVersionKey: "1.0.0" as NSObject,
            AppGroupConstants.recordingSessionTimeoutDurationKey: 300 as NSObject,  // 5 min,
        ]
        remoteConfig.setDefaults(defaults)
        let settings = RemoteConfigSettings()
        remoteConfig.configSettings = settings
        remoteConfig.fetch { [weak self] status, error in
            if let error = error {
                Logger.error("Remote Config fetch failed: \(error.localizedDescription)")
                return
            }
            if status == .success {
                remoteConfig.activate { [weak self] changed, error in
                    if let error = error {
                        print("Remote Config activation failed: \(error.localizedDescription)")
                        return
                    }
                    self?.storeRemoteConfigValues(remoteConfig)
                }
            }
        }
    }

    private func storeRemoteConfigValues(_ remoteConfig: RemoteConfig) {
        let configKeys = [
            AppGroupConstants.appVersionKey,
            AppGroupConstants.recordingSessionTimeoutDurationKey,
            AppGroupConstants.apiBaseUrlKey,
        ]
        for key in configKeys {
            let value = remoteConfig[key]
            if key == AppGroupConstants.recordingSessionTimeoutDurationKey {
                let duration = value.numberValue.doubleValue
                KeychainHelper.save(key: key, value: duration)
                SharedUserDefaults.recordingSessionTimeoutDuration = duration
            } else if key == AppGroupConstants.appVersionKey {
                KeychainHelper.save(key: key, value: value.stringValue ?? "1.0.0")
            } else if key == AppGroupConstants.apiBaseUrlKey {
                KeychainHelper.save(key: key, value: value.stringValue ?? "")
            }
        }
        Logger.debug("Remote Config values stored in Keychain")
    }
}

@main
struct MurMurApp: App {
    @StateObject private var deepLinkManager = DeepLinkManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            KeyboardAppView(for: .murMur) {
                ContentView()
                    .environmentObject(deepLinkManager)
                    .onOpenURL { url in
                        deepLinkManager.handleURL(url)
                    }
                    .preferredColorScheme(.dark)
            }
        }
    }
}
