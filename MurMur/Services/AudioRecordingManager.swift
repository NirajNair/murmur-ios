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
    private var currentRecordingURL: URL?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var levelTimer: Timer?

    override init() {
        super.init()
        setupAudioSession()
        setupAudioEngine()
        registerForAppLifecycleNotifications()
        restoreSessionState()
        FileUtils.shared.performInitialCleanup()
    }

    private func restoreSessionState() {
        isPaused = SharedUserDefaults.isPaused
        SharedUserDefaults.isAudioSessionActive = audioSession?.isOtherAudioPlaying ?? false
    }

    private func setupAudioSession() {
        #if canImport(UIKit)
            audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession?.setCategory(
                    .playAndRecord, mode: .default,
                    options: [.defaultToSpeaker, .allowBluetooth])
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

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            Logger.error("Failed to create AVAudioEngine")
            return
        }
        inputNode = engine.inputNode
        let inputFormat = inputNode?.outputFormat(forBus: 0)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) {
            [weak self] (buffer, time) in
            self?.calculateAudioLevel(from: buffer)
        }
        do {
            try engine.start()
            Logger.debug(
                "AVAudioEngine started successfully - microphone indicator should be visible")

            startLevelMonitoring()
        } catch {
            Logger.error("Failed to start AVAudioEngine: \(error)")
        }
    }

    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataArray = Array(
            UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))

        let rms = sqrt(
            channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))

        let decibels = 20 * log10(rms)
        DispatchQueue.main.async { [weak self] in
            if self?.isRecording == true {
                self?.recordingLevel = max(-80, decibels)
            }
        }
    }

    private func startLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
        }
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
                if let engine = audioEngine, !engine.isRunning {
                    try engine.start()
                    Logger.debug("Audio engine restarted in background")
                }
            } catch {
                Logger.error("Failed to keep audio session/engine active in background: \(error)")
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
                if let engine = audioEngine, !engine.isRunning {
                    try engine.start()
                    Logger.debug("Audio engine restarted in foreground")
                }
            } catch {
                Logger.error("Failed to reactivate audio session/engine in foreground: \(error)")
                SharedUserDefaults.isAudioSessionActive = false
            }
        #endif
    }

    @objc private func handleAppWillTerminate() {
        Logger.debug("App will terminate - cleaning up audio engine and session")
        levelTimer?.invalidate()
        levelTimer = nil
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
            inputNode?.removeTap(onBus: 0)
        }
        audioEngine = nil
        inputNode = nil
        SharedUserDefaults.isAudioSessionActive = false
        SharedUserDefaults.recordingSessionId = nil
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
                    if let engine = audioEngine, !engine.isRunning {
                        try engine.start()
                        Logger.debug("Audio engine restarted after interruption")
                    }

                    if isPaused && SharedUserDefaults.recordingSessionId != nil {
                        Logger.debug("Resuming recording after audio session interruption")
                        resumeRecording()
                    }
                } catch {
                    Logger.error(
                        "Failed to reactivate audio session/engine after interruption: \(error)")
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
        if audioRecorder != nil {
            Logger.debug("Cleaning up existing audio recorder before starting new session")
            audioRecorder?.stop()
            audioRecorder = nil
        }
        currentRecordingURL = FileUtils.shared.createUniqueRecordingURL()
        guard let recordingURL = currentRecordingURL else {
            Logger.error("Failed to create recording URL")
            return
        }
        guard createAudioRecorder(url: recordingURL, createDirectory: true) else {
            Logger.error("Failed to start recording")
            return
        }
        let sessionId = UUID().uuidString
        isRecording = true
        isPaused = false
        SharedUserDefaults.isRecording = true
        SharedUserDefaults.isPaused = false
        SharedUserDefaults.recordingSessionId = sessionId
        NotificationCenter.default.post(name: .init("RecordingStateChanged"), object: nil)
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.recordingStateChanged
        )
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.updateRecordingLevel()
        }
        startSessionTimeoutTimer()
        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //     self.returnToHostApp()
        // }
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
        NotificationCenter.default.post(name: .init("RecordingStateChanged"), object: nil)
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.recordingStateChanged
        )
        Logger.debug("Recording stopped, starting transcription")
        transcribeRecording()
    }

    func resumeRecording() {
        guard isPaused else {
            Logger.warning("Cannot resume: recording is not paused")
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
        Logger.debug("Recording resumed!")
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
            if let engine = audioEngine, !engine.isRunning {
                do {
                    try engine.start()
                    Logger.debug("Audio engine restarted to maintain microphone access")
                } catch {
                    Logger.error("Failed to restart audio engine: \(error)")
                }
            }
            SharedUserDefaults.isAudioSessionActive = true
            Logger.debug("Audio session kept active - microphone indicator remains visible")
        #endif
        isRecording = false
        isPaused = false
        SharedUserDefaults.isRecording = false
        SharedUserDefaults.isPaused = false
        SharedUserDefaults.recordingSessionId = nil
        Logger.debug(
            "endRecordingSession: isAudioSessionActive=\(SharedUserDefaults.isAudioSessionActive), isPaused=\(SharedUserDefaults.isPaused)"
        )
        NotificationCenter.default.post(name: .init("RecordingStateChanged"), object: nil)
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.recordingStateChanged
        )
        Logger.debug("Recording session ended - microphone access maintained")
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
        deleteRecordingFile()
        NotificationCenter.default.post(name: .init("RecordingStateChanged"), object: nil)
        DarwinNotificationManager.shared.postNotification(
            name: DarwinNotifications.recordingStateChanged
        )
        Logger.debug("Recording cancelled and file deleted")
    }

    func getCurrentRecordingURL() -> URL? {
        return currentRecordingURL
    }

    private func resetAudioRecorderForNextSession() {
        Logger.debug("Resetting audio recorder for next session")
        audioRecorder?.stop()
        audioRecorder = nil
        currentRecordingURL = nil
        isPaused = false
        SharedUserDefaults.isPaused = false
        Logger.debug("Audio recorder reset complete - ready for next session")
    }

    private func createAudioRecorder(url: URL, createDirectory: Bool = false) -> Bool {
        if createDirectory {
            guard FileUtils.shared.createDirectoryIfNeeded(for: url) else {
                Logger.error("Failed to create directory for recording URL")
                return false
            }
        }
        let settings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 64000,
            AVLinearPCMBitDepthKey: 16,
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            return true
        } catch {
            Logger.error("Failed to create audio recorder: \(error)")
            return false
        }
    }

    private func updateRecordingLevel() {
        if let recorder = audioRecorder, isRecording {
            recorder.updateMeters()
            recordingLevel = recorder.averagePower(forChannel: 0)
        }
    }

    private func transcribeRecording() {
        guard let recordingURL = currentRecordingURL else {
            Logger.error("No recording URL for transcription")
            return
        }
        SharedUserDefaults.transcriptionInProgress = true
        Logger.debug("Starting transcription for recording: \(recordingURL.lastPathComponent)")
        TranscriptionService.shared.transcribeRecording(at: recordingURL) {
            [weak self] result in
            DispatchQueue.main.async {
                SharedUserDefaults.transcriptionInProgress = false
                switch result {
                case .success(let transcription):
                    Logger.debug("Transcription successful: \(transcription.prefix(50))...")
                    SharedUserDefaults.pendingTranscription = transcription
                    self?.deleteRecordingFile()
                    self?.resetAudioRecorderForNextSession()
                    DarwinNotificationManager.shared.postNotification(
                        name: DarwinNotifications.transcriptionReady
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.returnToHostApp()
                    }
                case .failure(let error):
                    Logger.error("Transcription failed: \(error.localizedDescription)")
                    let fallbackMessage = "Transcription failed: \(error.localizedDescription)"
                    SharedUserDefaults.pendingTranscription = fallbackMessage
                    self?.deleteRecordingFile()
                    self?.resetAudioRecorderForNextSession()
                    DarwinNotificationManager.shared.postNotification(
                        name: DarwinNotifications.transcriptionReady
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.returnToHostApp()
                    }
                }
            }
        }
    }

    private func deleteRecordingFile() {
        guard let recordingURL = currentRecordingURL else {
            Logger.debug("No recording URL to delete")
            return
        }
        FileUtils.shared.deleteRecordingFile(at: recordingURL)
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
