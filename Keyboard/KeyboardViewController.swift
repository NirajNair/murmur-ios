import Foundation
import OSLog
import SwiftUI
import UIKit

class KeyboardViewController: UIInputViewController {
    private let communicationManager = KeyboardCommunicationManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        AudioSessionStatusManager.shared.checkAudioSessionStatus()
        setupCommunication()
        setupKeyboardView()
    }

    private func setupKeyboardView() {
        let keyboardView = KeyboardView(
            onStartTap: { [weak self] in
                self?.handleStartTap()
            },
            onStopTap: { [weak self] in
                self?.handleStopTap()
            },
            onCancelTap: { [weak self] in
                self?.handleCancelTap()
            }
        )
        let hostingController = UIHostingController(rootView: keyboardView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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
        if SharedUserDefaults.isAudioSessionActive && SharedUserDefaults.isPaused {
            Logger.debug("Keyboard: Sending resume recording notification")
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

    private func insertTranscription(_ transcription: String) {
        SharedUserDefaults.transcriptionInProgress = false
        textDocumentProxy.insertText(transcription)
        SharedUserDefaults.pendingTranscription = nil
        NotificationCenter.default.post(name: .init("TranscriptionCompleted"), object: nil)
    }
}
