//
//  AudioRecordingManager.swift
//  MurMur
//
//  Created by Niraj Nair on 04/09/25.
//

import AVFoundation
import Foundation
import OSLog

#if canImport(UIKit)
    import UIKit
#endif

class AudioRecordingManager: NSObject, ObservableObject {
    static let shared = AudioRecordingManager()
    private let AUDIO_SESSION_TIMEOUT_DURATION: TimeInterval = 5 * 60

    @Published var isRecording = false
    @Published var recordingLevel: Float = 0.0
    @Published var isPaused = false

    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    private var recordingTimer: Timer?
    private var sessionTimeoutTimer: DispatchSourceTimer?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var currentSessionId: String?
    private var recordingSegments: [URL] = []

    override init() {
        super.init()
        setupAudioSession()
        registerForAppLifecycleNotifications()
        restoreSessionState()
    }

    private func restoreSessionState() {
        currentSessionId = SharedUserDefaults.recordingSessionId
        isPaused = SharedUserDefaults.isPaused
        SharedUserDefaults.isAudioSessionActive = audioSession?.isOtherAudioPlaying ?? false
        if let sessionId = currentSessionId {
            loadRecordingSegments(for: sessionId)
        }
    }

    private func loadRecordingSegments(for sessionId: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let sessionFolder = documentsPath[0].appendingPathComponent("recordings/\(sessionId)")
        guard FileManager.default.fileExists(atPath: sessionFolder.path) else { return }
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: sessionFolder, includingPropertiesForKeys: nil)
            recordingSegments = files.filter { $0.pathExtension == "m4a" }.sorted {
                $0.lastPathComponent < $1.lastPathComponent
            }
            Logger.debug(
                "Loaded \(recordingSegments.count) recording segments for session \(sessionId)")
        } catch {
            Logger.error("Failed to load recording segments: \(error)")
        }
    }

    private func setupAudioSession() {
        #if canImport(UIKit)
            audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession?.setCategory(
                    .playAndRecord, mode: .default,
                    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
                try audioSession?.setActive(true)
                SharedUserDefaults.isAudioSessionActive = true
                Logger.debug("Audio session successfully configured for recording")
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(handleAudioSessionInterruption),
                    name: AVAudioSession.interruptionNotification,
                    object: nil
                )
                Logger.debug("Audio session interrupt listener registered")
            } catch {
                Logger.error("Failed to set up audio session: \(error)")
                SharedUserDefaults.isAudioSessionActive = false
            }
        #endif
    }

    private func registerForAppLifecycleNotifications() {
        #if canImport(UIKit)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAppDidEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAppWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAppWillTerminate),
                name: UIApplication.willTerminateNotification,
                object: nil
            )
        #endif
    }

    @objc private func handleAppDidEnterBackground() {
        #if canImport(UIKit)
            do {
                try audioSession?.setActive(true)
                SharedUserDefaults.isAudioSessionActive = true
                Logger.debug("Audio session kept active in background")
            } catch {
                Logger.error("Failed to keep audio session active in background: \(error)")
                SharedUserDefaults.isAudioSessionActive = false
            }
        #endif
    }

    @objc private func handleAppWillEnterForeground() {
        #if canImport(UIKit)
            do {
                try audioSession?.setActive(true)
                SharedUserDefaults.isAudioSessionActive = true
                Logger.debug("Audio session reactivated in foreground")
            } catch {
                Logger.error("Failed to reactivate audio session in foreground: \(error)")
                SharedUserDefaults.isAudioSessionActive = false
            }
        #endif
    }

    @objc private func handleAppWillTerminate() {
        Logger.debug("App will terminate - marking audio session as inactive")
        SharedUserDefaults.isAudioSessionActive = false
        if isRecording {
            endRecordingSession()
        }
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }
        Logger.debug("Audio session interruption: \(type == .began ? "began" : "ended")")
        switch type {
        case .began:
            Logger.warning("Audio session interrupted - pausing recording if active")
            SharedUserDefaults.isAudioSessionActive = false
            if isRecording {
                cancelRecording()
                Logger.warning("Recording cancelled due to audio session interruption")
            }

        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                Logger.warning("Audio session interruption ended - no resume options")
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                Logger.debug("Audio session interruption ended - attempting to resume")
                do {
                    try audioSession?.setActive(true)
                    SharedUserDefaults.isAudioSessionActive = true
                    Logger.debug("Audio session successfully reactivated after interruption")
                    if isPaused && currentSessionId != nil {
                        Logger.debug("Resuming recording after audio session interruption")
                        resumeRecording()
                    }
                } catch {
                    Logger.error("Failed to reactivate audio session after interruption: \(error)")
                    SharedUserDefaults.isAudioSessionActive = false
                }
            } else {
                Logger.debug("Audio session interruption ended - manual resume required")
                SharedUserDefaults.isAudioSessionActive = false
            }

        @unknown default:
            Logger.warning("Unknown audio session interruption type")
        }
    }

    func configureAudioSessionForRecording() async -> Bool {
        guard await requestPermissions() else {
            Logger.error("Audio recording permission denied")
            return false
        }
        do {
            try audioSession?.setCategory(
                .playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession?.setActive(true)
            SharedUserDefaults.isAudioSessionActive = true
            Logger.debug("Audio session successfully configured and activated for recording")
            return true
        } catch {
            Logger.error("Failed to configure audio session for recording: \(error)")
            SharedUserDefaults.isAudioSessionActive = false
            return false
        }
    }

    func requestPermissions() async -> Bool {
        return await withCheckedContinuation { continuation in
            audioSession?.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() async {
        guard await requestPermissions() else { return }
        startRecordingInternal()
    }

    func startRecordingSync() {
        #if canImport(UIKit)
            guard AVAudioSession.sharedInstance().recordPermission == .granted else {
                Logger.warning("Recording permission not granted")
                return
            }
        #endif
        if isPaused {
            Logger.debug("Resuming existing paused session")
            resumeRecording()
        } else {
            Logger.debug("Starting new recording session")
            startRecordingInternal()
        }
    }

    private func startRecordingInternal() {
        cleanupTemporarySessionKeeper()
        if currentSessionId == nil {
            currentSessionId = UUID().uuidString
            SharedUserDefaults.recordingSessionId = currentSessionId
            SharedUserDefaults.currentRecordingSegment = 0
            recordingSegments.removeAll()
        }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let sessionFolder = documentsPath[0].appendingPathComponent(
            "recordings/\(currentSessionId!)")

        try? FileManager.default.createDirectory(
            at: sessionFolder, withIntermediateDirectories: true, attributes: nil)

        let currentSegment = SharedUserDefaults.currentRecordingSegment
        let audioFilename = sessionFolder.appendingPathComponent("segment_\(currentSegment).m4a")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            isPaused = false
            SharedUserDefaults.isRecording = true
            SharedUserDefaults.isPaused = false
            NotificationCenter.default.post(name: .init("RecordingStateChanged"), object: nil)
            DarwinNotificationManager.shared.postNotification(
                name: DarwinNotifications.recordingStateChanged
            )
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.updateRecordingLevel()
            }
            startSessionTimeoutTimer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.returnToHostApp()
            }
        } catch {
            Logger.error("Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        guard let recorder = audioRecorder else { return }
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        isPaused = true
        SharedUserDefaults.isRecording = false
        SharedUserDefaults.isPaused = true
        SharedUserDefaults.isAudioSessionActive = true
        saveCurrentSegmentAndPrepareNext()
        NotificationCenter.default.post(name: .init("RecordingStateChanged"), object: nil)
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.recordingStateChanged
        )
        Logger.debug("Recording segment saved, recorder kept active for instant resume")
        simulateTranscription()
    }

    private func saveCurrentSegmentAndPrepareNext() {
        guard let recorder = audioRecorder else { return }
        let recordingURL = recorder.url
        recordingSegments.append(recordingURL)
        Logger.debug("Recording segment saved: \(recordingURL.lastPathComponent)")
        let timestamp = Int(Date().timeIntervalSince1970)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let sessionFolder = documentsPath[0].appendingPathComponent(
            "recordings/\(currentSessionId!)")
        let currentSegment = SharedUserDefaults.currentRecordingSegment
        let timestampedFile = sessionFolder.appendingPathComponent(
            "segment_\(currentSegment)_\(timestamp).m4a")
        do {
            try FileManager.default.copyItem(at: recordingURL, to: timestampedFile)
            Logger.debug("Audio segment saved to: \(timestampedFile.lastPathComponent)")
        } catch {
            Logger.error("Failed to copy audio segment: \(error)")
        }
        let newSegment = SharedUserDefaults.currentRecordingSegment + 1
        SharedUserDefaults.currentRecordingSegment = newSegment
        createNewRecorderForNextSegment()
    }

    private func createNewRecorderForNextSegment() {
        audioRecorder?.stop()
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let sessionFolder = documentsPath[0].appendingPathComponent(
            "recordings/\(currentSessionId!)")
        let nextSegment = SharedUserDefaults.currentRecordingSegment
        let audioFilename = sessionFolder.appendingPathComponent("segment_\(nextSegment).m4a")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            Logger.debug("New recorder created for segment \(nextSegment), session stays active")
        } catch {
            Logger.error("Failed to create new recorder: \(error)")
        }
    }

    func resumeRecording() {
        guard isPaused, currentSessionId != nil else {
            Logger.warning("Cannot resume: recording is not paused or no active session")
            return
        }
        isRecording = true
        isPaused = false
        SharedUserDefaults.isRecording = true
        SharedUserDefaults.isPaused = false
        startRecordingTimer()
        NotificationCenter.default.post(name: .init("RecordingStateChanged"), object: nil)
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.recordingStateChanged
        )
        Logger.debug("Recording resumed instantly - no delay!")
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.updateRecordingLevel()
        }
    }

    private func startSessionTimeoutTimer() {
        sessionTimeoutTimer?.cancel()
        sessionTimeoutTimer = nil
        #if canImport(UIKit)
            backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(
                withName: "AudioSessionTimeout"
            ) { [weak self] in
                self?.endBackgroundTask()
            }
        #endif
        sessionTimeoutTimer = DispatchSource.makeTimerSource(
            queue: DispatchQueue.global(qos: .background))
        sessionTimeoutTimer?.schedule(deadline: .now() + AUDIO_SESSION_TIMEOUT_DURATION)
        sessionTimeoutTimer?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                Logger.warning(
                    "Recording session timed out after \(self?.AUDIO_SESSION_TIMEOUT_DURATION ?? 0) seconds - automatically ending session"
                )
                self?.endRecordingSession()
            }
        }
        sessionTimeoutTimer?.resume()
        Logger.debug(
            "Background-compatible session timeout timer started - will auto-end session in \(AUDIO_SESSION_TIMEOUT_DURATION) seconds"
        )
    }

    private func endBackgroundTask() {
        #if canImport(UIKit)
            if backgroundTaskIdentifier != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                backgroundTaskIdentifier = .invalid
            }
        #endif
    }

    func endRecordingSession() {
        if isRecording {
            cancelRecording()
        }
        recordingTimer?.invalidate()
        recordingTimer = nil
        sessionTimeoutTimer?.cancel()
        sessionTimeoutTimer = nil
        endBackgroundTask()
        audioRecorder?.stop()
        audioRecorder = nil
        #if canImport(UIKit)
            do {
                try audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
                SharedUserDefaults.isAudioSessionActive = false
                Logger.debug("Audio session deactivated successfully")
            } catch {
                Logger.error("Failed to deactivate audio session: \(error)")
            }
        #endif
        isRecording = false
        isPaused = false
        SharedUserDefaults.isRecording = false
        SharedUserDefaults.isPaused = false
        currentSessionId = nil
        SharedUserDefaults.recordingSessionId = nil
        SharedUserDefaults.currentRecordingSegment = 0
        NotificationCenter.default.post(name: .init("RecordingStateChanged"), object: nil)
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.recordingStateChanged
        )
        Logger.debug("Recording session ended successfully")
    }

    func cancelRecording() {
        guard let recorder = audioRecorder else { return }
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        isPaused = true
        SharedUserDefaults.isRecording = false
        SharedUserDefaults.isPaused = true
        SharedUserDefaults.isAudioSessionActive = true
        saveCurrentSegmentAndPrepareNext()
        NotificationCenter.default.post(name: .init("RecordingStateChanged"), object: nil)
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.recordingStateChanged
        )
        Logger.debug("Recording cancelled, but session kept active for instant resume")
    }

    private func keepRecorderActiveForNextSession() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let tempRecordingURL = documentsPath[0].appendingPathComponent("temp_session_keeper.m4a")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: tempRecordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            Logger.debug("Temporary recorder created to keep audio session active")
        } catch {
            Logger.error("Failed to create temporary recorder: \(error)")
        }
    }

    private func cleanupTemporarySessionKeeper() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let tempRecordingURL = documentsPath[0].appendingPathComponent("temp_session_keeper.m4a")
        do {
            if FileManager.default.fileExists(atPath: tempRecordingURL.path) {
                try FileManager.default.removeItem(at: tempRecordingURL)
                Logger.debug("Temporary session keeper file cleaned up")
            }
        } catch {
            Logger.error("Failed to cleanup temporary session keeper file: \(error)")
        }
    }

    func getRecordingSegments() -> [URL] {
        return recordingSegments
    }

    func getCurrentSessionId() -> String? {
        return currentSessionId
    }

    func getSessionFolder() -> URL? {
        guard let sessionId = currentSessionId else { return nil }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return documentsPath[0].appendingPathComponent("recordings/\(sessionId)")
    }

    private func updateRecordingLevel() {
        audioRecorder?.updateMeters()
        recordingLevel = audioRecorder?.averagePower(forChannel: 0) ?? 0.0
    }

    private func simulateTranscription() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let transcription = "This is a simulated transcription of your voice recording."
            SharedUserDefaults.pendingTranscription = transcription
            DarwinNotificationManager.shared.postNotification(
                name: DarwinNotifications.transcriptionReady
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.returnToHostApp()
            }
        }
    }

    private func returnToHostApp() {
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.returnToHostApp
        )
        #if canImport(UIKit)
            UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        #endif
    }
}

extension AudioRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            Logger.debug("Recording finished successfully")
        }
    }
}
