import Foundation
import OSLog
import SwiftUI

struct RecordingToolbarView: View {
    let hasFullAccess: Bool
    let onStartTap: () -> Void
    let onStopTap: () -> Void
    let onCancelTap: () -> Void
    let onOpenSettings: () -> Void

    @State private var isRecording = SharedUserDefaults.isRecording
    @State private var transcriptionInProgress = SharedUserDefaults.transcriptionInProgress
    @State private var isAudioSessionActive = SharedUserDefaults.isAudioSessionActive
    @State private var isPaused = SharedUserDefaults.isPaused
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showFullAccessPrompt = false
    @State private var errorMessage: String?

    private func handleStopRecording() {
        SharedUserDefaults.transcriptionInProgress = true
        timer?.invalidate()
        timer = nil
        onStopTap()
    }

    private func updateLocalState() {
        let wasRecording = isRecording
        isRecording = SharedUserDefaults.isRecording
        transcriptionInProgress = SharedUserDefaults.transcriptionInProgress
        isAudioSessionActive = SharedUserDefaults.isAudioSessionActive
        isPaused = SharedUserDefaults.isPaused
        if isRecording && timer == nil {
            if let recordingStartTime = SharedUserDefaults.recordingStartTime {
                recordingTime = Date().timeIntervalSince(recordingStartTime)
            } else {
                recordingTime = 0
            }
            startTimer()
        } else if !isRecording && timer != nil {
            timer?.invalidate()
            timer = nil
            recordingTime = 0
        }
        if SharedUserDefaults.recordingSessionId == nil {
            isRecording = false
            isPaused = false
            isAudioSessionActive = false
            recordingTime = 0
            timer?.invalidate()
            timer = nil
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingTime += 1
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            if showFullAccessPrompt {
                VStack(spacing: 12) {
                    Text("Go to MurMur > Keyboard > Toggle 'Allow Full Access' on")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)

                    Button(action: {
                        onOpenSettings()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gear")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .medium))
                            Text("Open Settings")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(20)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            } else if transcriptionInProgress {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                        .scaleEffect(0.8)
                    Text("Transcribing...")
                        .foregroundColor(.primary)
                        .font(.system(size: 16, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .padding(.vertical, 8)
                .cornerRadius(12)
            } else if !isRecording {
                HStack {
                    Spacer()
                    Button(action: {
                        if !hasFullAccess {
                            showFullAccessPrompt = true
                        } else {
                            onStartTap()
                        }
                    }) {
                        if isAudioSessionActive {
                            Image(systemName: "mic")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 44, height: 44)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue, Color.blue.opacity(0.6),
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Circle())
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "play")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .medium))
                                Text("Start")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue, Color.blue.opacity(0.6),
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(22)
                        }
                    }
                }
                .frame(height: 42)
            } else {
                HStack {
                    Button(action: {
                        timer?.invalidate()
                        timer = nil
                        recordingTime = 0
                        onCancelTap()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(.primary)
                            .font(.system(size: 14))
                        Text(formatTime(recordingTime))
                            .foregroundColor(.primary)
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                    }
                    Spacer()
                    Button(action: handleStopRecording) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .frame(height: 42)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .toast(message: $errorMessage)
        .onReceive(NotificationCenter.default.publisher(for: .init("RecordingStateChanged"))) { _ in
            Logger.debug("RecordingStateChanged notification received")
            updateLocalState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("TranscriptionCompleted"))) {
            _ in
            updateLocalState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("TranscriptionError"))) {
            notification in
            if let error = notification.object as? String {
                Logger.debug("TranscriptionError notification received: \(error)")
                withAnimation {
                    errorMessage = error
                }
            }
        }
        .onAppear {
            updateLocalState()
            if hasFullAccess {
                showFullAccessPrompt = false
            }
            if isRecording && timer == nil {
                if let recordingStartTime = SharedUserDefaults.recordingStartTime {
                    recordingTime = Date().timeIntervalSince(recordingStartTime)
                }
                startTimer()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
