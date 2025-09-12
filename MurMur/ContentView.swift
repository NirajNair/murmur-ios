//
//  ContentView.swift
//  MurMur
//
//  Created by Niraj Nair on 12/08/25.
//

import OSLog
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @StateObject private var audioManager = AudioRecordingManager()
    @State private var isSettingUpAudio = false
    @State private var observersSetup = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("MurMur")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if isSettingUpAudio {
                    SetupView()
                } else if audioManager.isRecording {
                    BackgroundRecordingView()
                } else {
                    VStack(spacing: 20) {
                        Text("Your AI voice keyboard is ready!")
                            .font(.title2)

                        Text("Open any app, switch to MurMur Keyboard, and tap the Start button.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        Button("Test Recording") {
                            Task {
                                await audioManager.startRecording()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .navigationTitle("Voice Keyboard")
        }
        .onAppear {
            if !observersSetup {
                Logger.debug("Main app: Setting up notification observers")
                setupNotificationObservers()
                observersSetup = true
            }
            AudioSessionStatusManager.shared.checkAudioSessionStatus()
        }
        .onChange(of: deepLinkManager.shouldStartRecording) { shouldStart in
            if shouldStart {
                Task {
                    isSettingUpAudio = true
                    let setupSuccess = await audioManager.configureAudioSessionForRecording()
                    if setupSuccess {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                        await audioManager.startRecording()
                    }
                    isSettingUpAudio = false
                }
                deepLinkManager.shouldStartRecording = false
            }
        }
        .onChange(of: deepLinkManager.shouldReturnToHost) { shouldReturn in
            if shouldReturn {
                deepLinkManager.shouldReturnToHost = false
            }
        }
    }

    private func setupNotificationObservers() {
        DarwinNotificationManager.shared.addObserver(
            for: DarwinNotifications.startRecording
        ) { [audioManager] in
            Logger.debug("Main app received start recording notification")
            audioManager.startRecordingSync()
        }
        DarwinNotificationManager.shared.addObserver(
            for: DarwinNotifications.stopRecording
        ) { [audioManager] in
            Logger.debug("Main app received stop recording notification")
            audioManager.stopRecording()
        }
        DarwinNotificationManager.shared.addObserver(
            for: DarwinNotifications.cancelRecording
        ) { [audioManager] in
            Logger.debug("Main app received cancel recording notification")
            audioManager.cancelRecording()
        }
    }
}

struct BackgroundRecordingView: View {
    var body: some View {
        VStack(spacing: 30) {
            Circle()
                .fill(Color.red)
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 3)
                        .scaleEffect(1.3)
                        .opacity(0.7)
                )

            Text("Recording in Background")
                .font(.title2)
                .fontWeight(.medium)

            Text("Return to your app and use the keyboard controls to stop or cancel the recording")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Return to Previous App") {
                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct SetupView: View {
    var body: some View {
        VStack(spacing: 30) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)

            Text("Setting up audio session...")
                .font(.title2)
                .fontWeight(.medium)

            Text("Configuring microphone access")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct RecordingView: View {
    @ObservedObject var audioManager: AudioRecordingManager

    var body: some View {
        VStack(spacing: 30) {
            Circle()
                .fill(Color.red)
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 4)
                        .scaleEffect(1.5)
                        .opacity(0.7)
                )

            Text("Recording...")
                .font(.title)
                .fontWeight(.medium)

            Text("Speak naturally")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Stop Recording") {
                audioManager.stopRecording()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
