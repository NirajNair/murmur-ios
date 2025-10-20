//
//  KeyboardStatusChecker.swift
//  MurMur
//
//  Created by Niraj Nair on 14/10/25.
//

import Combine
import Foundation
import OSLog
import UIKit

class KeyboardStatusChecker: ObservableObject {
    @Published var isKeyboardEnabled: Bool = false
    @Published var hasFullAccess: Bool = false

    private let keyboardBundleId: String
    private var cancellables = Set<AnyCancellable>()

    init(bundleId: String) {
        self.keyboardBundleId = bundleId
        refresh()
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        #if canImport(UIKit)
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                .sink { [weak self] _ in
                    self?.refresh()
                }
                .store(in: &cancellables)

            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                .sink { [weak self] _ in
                    self?.refresh()
                }
                .store(in: &cancellables)
        #endif
        DarwinNotificationManager.shared.addObserver(
            for: DarwinNotifications.keyboardStatusUpdated
        ) { [weak self] in
            self?.readFullAccessStatusFromSharedDefaults(requestedAt: nil)
        }
    }

    func refresh() {
        checkKeyboardStatus()
        if isKeyboardEnabled {
            checkFullAccessStatus()
        } else {
            hasFullAccess = false
        }
    }

    private func checkKeyboardStatus() {
        guard let keyboards = UserDefaults.standard.object(forKey: "AppleKeyboards") as? [String]
        else {
            isKeyboardEnabled = false
            return
        }
        isKeyboardEnabled = keyboards.contains { $0.contains(keyboardBundleId) }
    }

    private func checkFullAccessStatus() {
        guard let sharedDefaults = UserDefaults(suiteName: AppGroupConstants.userDefaultsSuiteName)
        else {
            Logger.warning("Main App: Cannot access app group UserDefaults")
            hasFullAccess = false
            return
        }
        let requestTime = Date()
        sharedDefaults.set(requestTime, forKey: "statusRequestTime")
        sharedDefaults.synchronize()
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.requestKeyboardStatus
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.readFullAccessStatusFromSharedDefaults(requestedAt: requestTime)
        }
    }

    private func readFullAccessStatusFromSharedDefaults(requestedAt: Date?) {
        let storedValue = SharedUserDefaults.keyboardHasFullAccess
        let lastCheck = SharedUserDefaults.keyboardLastCheck

        guard let requestedAt = requestedAt else {
            hasFullAccess = storedValue
            return
        }
        if let lastCheck = lastCheck {
            let timeSinceRequest = lastCheck.timeIntervalSince(requestedAt)
            if timeSinceRequest > 0 {
                hasFullAccess = storedValue
            } else {
                Logger.warning(
                    "Main App: Keyboard timestamp is stale (before request) - assuming no full access"
                )
                SharedUserDefaults.keyboardHasFullAccess = false
                hasFullAccess = false
            }
        } else {
            hasFullAccess = false
        }
    }
}
