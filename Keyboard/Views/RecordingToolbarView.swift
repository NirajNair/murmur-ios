import Foundation
import OSLog
import SwiftUI

struct RecordingToolbarView: View {
    let onStartTap: () -> Void
    let onStopTap: () -> Void
    let onCancelTap: () -> Void

    @State private var isRecording = false
    @State private var transcriptionInProgress = false
    @State private var isAudioSessionActive = false
    @State private var isPaused = false

    private func handleStopRecording() {
        SharedUserDefaults.transcriptionInProgress = true
        onStopTap()
    }

    private func updateLocalState() {
        isRecording = SharedUserDefaults.isRecording
        transcriptionInProgress = SharedUserDefaults.transcriptionInProgress
        isAudioSessionActive = SharedUserDefaults.isAudioSessionActive
        isPaused = SharedUserDefaults.isPaused
        if SharedUserDefaults.recordingSessionId == nil {
            isRecording = false
            isPaused = false
            isAudioSessionActive = false
        }
    }

    var body: some View {
        HStack {
            if transcriptionInProgress {
                HStack {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(.green)
                    Text("Transcription in progress...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            } else if !isRecording {
                Button(action: onStartTap) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.blue)
                        Text("Start")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
            } else {
                HStack {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                        Text("Recording...")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }

                    Spacer()

                    Button(action: handleStopRecording) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(.green)
                            Text("Stop")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }

                    Button(action: onCancelTap) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Cancel")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.05))
        .onReceive(NotificationCenter.default.publisher(for: .init("RecordingStateChanged"))) { _ in
            Logger.debug("RecordingStateChanged notification received")
            updateLocalState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("TranscriptionCompleted"))) {
            _ in
            updateLocalState()
        }
        .onAppear {
            AudioSessionStatusManager.shared.checkAudioSessionStatus()
            updateLocalState()
        }
    }
}
