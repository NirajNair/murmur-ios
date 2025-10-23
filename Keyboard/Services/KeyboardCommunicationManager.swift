//
//  KeyboardCommunicationManager.swift
//  MurMur
//
//  Created by Niraj Nair on 04/09/25.
//

import Foundation
import OSLog

class KeyboardCommunicationManager {
    var onTranscriptionReady: ((String) -> Void)?
    var onTranscriptionError: ((String) -> Void)?
    private var observersSetup = false

    init() {
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        if observersSetup {
            Logger.warning("KeyboardCommunicationManager: Observers already setup, skipping")
            return
        }
        Logger.debug("KeyboardCommunicationManager: Setting up transcription ready observer")
        DarwinNotificationManager.shared.addObserver(
            for: DarwinNotifications.transcriptionReady
        ) { [weak self] in
            Logger.debug("KeyboardCommunicationManager: Received transcription ready notification")
            self?.handleTranscriptionReady()
        }
        observersSetup = true
    }

    private func handleTranscriptionReady() {
        if let error = SharedUserDefaults.transcriptionError {
            onTranscriptionError?(error)
            Logger.debug(
                "KeyboardCommunicationManager: Transcription error: \(error)"
            )
            SharedUserDefaults.transcriptionError = nil
            SharedUserDefaults.transcriptionInProgress = false
            return
        }
        if let transcription = SharedUserDefaults.pendingTranscription {
            onTranscriptionReady?(transcription)
            Logger.debug(
                "KeyboardCommunicationManager: Transcription ready: \(transcription) \(SharedUserDefaults.transcriptionInProgress)"
            )
            SharedUserDefaults.pendingTranscription = nil
            SharedUserDefaults.transcriptionInProgress = false
        }
    }
}
