//
//  AudioSessionStatusManager.swift
//  MurMur
//
//  Created by Niraj Nair on 04/09/25.
//

import AVFoundation
import Foundation
import OSLog

class AudioSessionStatusManager {
    static let shared = AudioSessionStatusManager()

    private init() {}

    func checkAudioSessionStatus() {
        Logger.debug("AudioSessionStatusManager: Starting audio session status check")
        let deviceStatus = getDeviceAudioSessionStatus()
        let storedSessionData = getStoredSessionData()
        let actualState = determineActualState(
            deviceStatus: deviceStatus, storedData: storedSessionData)

        updateSharedDefaults(with: actualState)
        logStatusCheck(
            deviceStatus: deviceStatus, storedData: storedSessionData, actualState: actualState)
    }

    private func getDeviceAudioSessionStatus() -> DeviceAudioSessionStatus {
        var status = DeviceAudioSessionStatus()
        #if canImport(UIKit)
            let audioSession = AVAudioSession.sharedInstance()
            status.isSessionActive = audioSession.isOtherAudioPlaying == false
            status.recordingPermission = audioSession.recordPermission
            status.currentCategory = audioSession.category
            status.supportsRecording = audioSession.availableInputs?.isEmpty == false
            status.categorySupportsRecording =
                audioSession.category == .record || audioSession.category == .playAndRecord
        #endif
        return status
    }

    private func getStoredSessionData() -> StoredSessionData {
        return StoredSessionData(
            recordingSessionId: SharedUserDefaults.recordingSessionId,
            isRecording: SharedUserDefaults.isRecording,
            isPaused: SharedUserDefaults.isPaused,
            isAudioSessionActive: SharedUserDefaults.isAudioSessionActive,
            transcriptionInProgress: SharedUserDefaults.transcriptionInProgress
        )
    }

    private func determineActualState(
        deviceStatus: DeviceAudioSessionStatus, storedData: StoredSessionData
    ) -> ActualAudioSessionState {
        var actualState = ActualAudioSessionState()
        let isSessionValid = SharedUserDefaults.isSessionValid()
        let hasStoredSession = storedData.recordingSessionId != nil
        if hasStoredSession && !isSessionValid {
            Logger.debug("Session expired during status check - clearing all state")
            actualState.isAudioSessionActive = false
            actualState.isRecording = false
            actualState.isPaused = false
            actualState.transcriptionInProgress = false
            actualState.recordingSessionId = nil
            return actualState
        }
        let hasValidStoredSession = hasStoredSession && isSessionValid
        if hasValidStoredSession {
            actualState.isAudioSessionActive = true
            actualState.isRecording = storedData.isRecording
            actualState.isPaused = storedData.isPaused
            actualState.transcriptionInProgress = storedData.transcriptionInProgress
            actualState.recordingSessionId = storedData.recordingSessionId
        } else {
            actualState.isAudioSessionActive = false
            actualState.isRecording = false
            actualState.isPaused = false
            actualState.transcriptionInProgress = false
            actualState.recordingSessionId = nil
        }
        return actualState
    }

    private func updateSharedDefaults(with state: ActualAudioSessionState) {
        SharedUserDefaults.isAudioSessionActive = state.isAudioSessionActive
        SharedUserDefaults.isRecording = state.isRecording
        SharedUserDefaults.isPaused = state.isPaused
        SharedUserDefaults.transcriptionInProgress = state.transcriptionInProgress
        SharedUserDefaults.recordingSessionId = state.recordingSessionId
    }

    private func logStatusCheck(
        deviceStatus: DeviceAudioSessionStatus, storedData: StoredSessionData,
        actualState: ActualAudioSessionState
    ) {
        Logger.debug("Audio Session Status Check Results:")
        Logger.debug("   Device Status:")
        Logger.debug("      - Session Active: \(deviceStatus.isSessionActive)")
        Logger.debug("      - Recording Permission: \(deviceStatus.recordingPermission.rawValue)")
        Logger.debug("      - Current Category: \(deviceStatus.currentCategory.rawValue)")
        Logger.debug("      - Supports Recording: \(deviceStatus.supportsRecording)")
        Logger.debug(
            "      - Category Supports Recording: \(deviceStatus.categorySupportsRecording)")

        Logger.debug("   Stored Data:")
        Logger.debug("      - Recording Session ID: \(storedData.recordingSessionId ?? "nil")")
        Logger.debug("      - Is Recording: \(storedData.isRecording)")
        Logger.debug("      - Is Paused: \(storedData.isPaused)")
        Logger.debug("      - Audio Session Active: \(storedData.isAudioSessionActive)")
        Logger.debug("      - Transcription In Progress: \(storedData.transcriptionInProgress)")

        Logger.debug("   Final State:")
        Logger.debug("      - Audio Session Active: \(actualState.isAudioSessionActive)")
        Logger.debug("      - Is Recording: \(actualState.isRecording)")
        Logger.debug("      - Is Paused: \(actualState.isPaused)")
        Logger.debug("      - Transcription In Progress: \(actualState.transcriptionInProgress)")
        Logger.debug("      - Recording Session ID: \(actualState.recordingSessionId ?? "nil")")
    }
}

private struct DeviceAudioSessionStatus {
    var isSessionActive: Bool = false
    var recordingPermission: AVAudioSession.RecordPermission = .undetermined
    var currentCategory: AVAudioSession.Category = .ambient
    var supportsRecording: Bool = false
    var categorySupportsRecording: Bool = false
}

private struct StoredSessionData {
    let recordingSessionId: String?
    let isRecording: Bool
    let isPaused: Bool
    let isAudioSessionActive: Bool
    let transcriptionInProgress: Bool
}

private struct ActualAudioSessionState {
    var isAudioSessionActive: Bool = false
    var isRecording: Bool = false
    var isPaused: Bool = false
    var transcriptionInProgress: Bool = false
    var recordingSessionId: String? = nil
}
