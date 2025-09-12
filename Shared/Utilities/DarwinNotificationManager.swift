//
//  DarwinNotificationManager.swift
//  MurMur
//
//  Created by Niraj Nair on 04/09/25.
//

import Foundation
import OSLog

struct DarwinNotifications {
    static let startRecording = "com.murmur.startRecording"
    static let stopRecording = "com.murmur.stopRecording"
    static let cancelRecording = "com.murmur.cancelRecording"
    static let transcriptionReady = "com.murmur.transcriptionReady"
    static let returnToHostApp = "com.murmur.returnToHostApp"
    static let recordingStateChanged = "com.murmur.recordingStateChanged"
}

class DarwinNotificationManager {
    static let shared = DarwinNotificationManager()
    private init() {}

    private var observers: [String: NSObjectProtocol] = [:]

    func postNotification(name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil, nil, true
        )
    }

    func addObserver(for name: String, callback: @escaping () -> Void) {
        Logger.debug("DarwinNotificationManager: Adding observer for: \(name)")
        if let existingObserver = observers[name] {
            NotificationCenter.default.removeObserver(existingObserver)
            observers.removeValue(forKey: name)
        }
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, _, name, _, _ in
                guard let name = name else { return }
                Logger.debug(
                    "DarwinNotificationManager: Received Darwin notification: \(name.rawValue as String)"
                )
                NotificationCenter.default.post(
                    name: Notification.Name(name.rawValue as String),
                    object: nil
                )
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
        let notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(name),
            object: nil,
            queue: .main
        ) { _ in
            Logger.debug("DarwinNotificationManager: Calling callback for: \(name)")
            callback()
        }
        observers[name] = notificationObserver
        Logger.debug("DarwinNotificationManager: Observer successfully added for: \(name)")
    }

    func removeObserver(for name: String) {
        if let observer = observers[name] {
            NotificationCenter.default.removeObserver(observer)
            observers.removeValue(forKey: name)
            Logger.debug("DarwinNotificationManager: Removed observer for: \(name)")
        }
    }

    deinit {
        for (_, observer) in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
}
