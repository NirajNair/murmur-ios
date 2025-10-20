import Foundation
import KeyboardKit
import OSLog
import SwiftUI
import UIKit

class KeyboardViewController: KeyboardInputViewController {
    private let communicationManager = KeyboardCommunicationManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        AudioSessionStatusManager.shared.checkAudioSessionStatus()
        setupCommunication()
        setupStatusRequestListener()
        recordFullAccessStatus()

        setup(for: .murMur) { result in
            if case let .failure(error) = result {
                Logger.error("Keyboard setup failed: \(error)")
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        recordFullAccessStatus()
    }

    private func setupStatusRequestListener() {
        DarwinNotificationManager.shared.addObserver(
            for: DarwinNotifications.requestKeyboardStatus
        ) { [weak self] in
            Logger.debug("Keyboard: Received status request from main app")
            self?.recordFullAccessStatus()
            DarwinNotificationManager.shared.postNotification(
                name: DarwinNotifications.keyboardStatusUpdated
            )
        }
    }

    private func recordFullAccessStatus() {
        SharedUserDefaults.keyboardHasFullAccess = self.hasFullAccess
        SharedUserDefaults.keyboardLastCheck = Date()
    }

    override func viewWillSetupKeyboardView() {
        setupKeyboardView { controller in
            KeyboardKit.KeyboardView(
                state: controller.state,
                services: controller.services,
                buttonContent: { $0.view },
                buttonView: { $0.view },
                collapsedView: { $0.view },
                emojiKeyboard: { $0.view },
                toolbar: { [weak self] _ in
                    RecordingToolbarView(
                        hasFullAccess: self?.hasFullAccess ?? false,
                        onStartTap: { [weak self] in
                            self?.handleStartTap()
                        },
                        onStopTap: { [weak self] in
                            self?.handleStopTap()
                        },
                        onCancelTap: { [weak self] in
                            self?.handleCancelTap()
                        },
                        onOpenSettings: { [weak self] in
                            self?.handleOpenSettings()
                        }
                    )
                }
            )
        }
    }

    private func setupCommunication() {
        communicationManager.onTranscriptionReady = { [weak self] transcription in
            self?.insertTranscription(transcription)
        }
        DarwinNotificationManager.shared.addObserver(
            for: DarwinNotifications.recordingStateChanged
        ) {
            Logger.debug("Keyboard received recordingStateChanged notification")
            NotificationCenter.default.post(name: .init("RecordingStateChanged"), object: nil)
        }
    }

    private func handleStartTap() {
        if SharedUserDefaults.isAudioSessionActive {
            Logger.debug(
                "Keyboard: Audio session active - starting/resuming recording via notification")
            DarwinNotificationManager.shared.postNotification(
                name: DarwinNotifications.startRecording
            )
            return
        }
        if let url = URL(string: "murmur://startRecording") {
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url)
                    break
                }
                responder = responder?.next
            }
        }
    }

    private func handleStopTap() {
        Logger.debug("Keyboard: Sending stop recording notification")
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.stopRecording
        )
        Logger.debug("Keyboard: Stop recording notification sent")
    }

    private func handleCancelTap() {
        Logger.debug("Keyboard: Sending cancel recording notification")
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.cancelRecording
        )
        Logger.debug("Keyboard: Cancel recording notification sent")
    }

    private func handleOpenSettings() {
        Logger.debug("Keyboard: Opening Settings")
        if let url = URL(string: UIApplication.openSettingsURLString) {
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url)
                    break
                }
                responder = responder?.next
            }
        }
    }

    private func insertTranscription(_ transcription: String) {
        SharedUserDefaults.transcriptionInProgress = false
        textDocumentProxy.insertText(transcription)
        SharedUserDefaults.pendingTranscription = nil
        NotificationCenter.default.post(name: .init("TranscriptionCompleted"), object: nil)
    }
}
