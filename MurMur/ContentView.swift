//
//  ContentView.swift
//  MurMur
//
//  Created by Niraj Nair on 12/08/25.
//

import OSLog
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @StateObject private var audioManager = AudioRecordingManager()
    @StateObject private var keyboardStatus = KeyboardStatusChecker(
        bundleId: "com.nirajnair.MurMur.Keyboard")
    @State private var isSettingUpAudio = false
    @State private var observersSetup = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if isSettingUpAudio || audioManager.isRecording {
                RecordingFlowView(
                    isSettingUp: isSettingUpAudio,
                    isRecording: audioManager.isRecording
                )
            } else {
                KeyboardSetupView(keyboardStatus: keyboardStatus)
            }
        }
        .onAppear {
            if !observersSetup {
                Logger.debug("Main app: Setting up notification observers")
                setupNotificationObservers()
                observersSetup = true
            }
            AudioSessionStatusManager.shared.checkAudioSessionStatus()
            keyboardStatus.refresh()
        }
        .onChange(of: scenePhase) { _ in
            if scenePhase == .active {
                keyboardStatus.refresh()
            }
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

struct KeyboardSetupView: View {
    @ObservedObject var keyboardStatus: KeyboardStatusChecker
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue.gradient)
                    .padding(.top, 20)

                Text("MurMur")
                    .font(.system(size: 32, weight: .bold))

                Text("AI Voice-to-Text Keyboard")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
            .background(Color(.systemGroupedBackground))

            ScrollView {
                VStack(spacing: 0) {
                    if keyboardStatus.isKeyboardEnabled {
                        KeyboardEnabledView()
                    } else {
                        KeyboardSetupInstructionsView(
                            isEnabled: keyboardStatus.isKeyboardEnabled
                        )
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            if !keyboardStatus.isKeyboardEnabled {
                Button(action: {
                    if let url = URL(string: "app-settings:") {
                        openURL(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.headline)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .background(Color(.systemGroupedBackground))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            keyboardStatus.refresh()
        }
        .onChange(of: scenePhase) { _ in
            if scenePhase == .active {
                keyboardStatus.refresh()
            }
        }
    }
}

struct KeyboardEnabledView: View {
    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)

                Circle()
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: 100, height: 100)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
                    .opacity(showCheckmark ? 1 : 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.green)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
                    .opacity(showCheckmark ? 1 : 0)
            }
            .padding(.top, 10)

            VStack(spacing: 8) {
                Text("All Set!")
                    .font(.system(size: 24, weight: .bold))

                Text("Your MurMur keyboard is ready to use")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(
                    stepNumber: 1,
                    text: "Open any app with text input"
                )
                InstructionRow(
                    stepNumber: 2,
                    text: "Tap the text field and switch to MurMur keyboard"
                )
                InstructionRow(
                    stepNumber: 3,
                    text: "Tap the microphone button to start recording"
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                showCheckmark = true
            }
        }
    }
}

struct KeyboardSetupInstructionsView: View {
    let isEnabled: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Follow these steps to enable MurMur keyboard")
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                SetupStepCard(
                    stepNumber: 1,
                    title: "Open Settings",
                    description: "Click on 'Open Setting' button > Keyboard",
                    isCompleted: isEnabled
                )
                SetupStepCard(
                    stepNumber: 2,
                    title: "Enable Keyboard & Allow Full Access",
                    description:
                        "Toggle 'Keyboard' on > Toggle 'Allow Full Access' on",
                    isCompleted: isEnabled
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

struct SetupStepCard: View {
    let stepNumber: Int
    let title: String
    let description: String
    let isCompleted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(stepNumber)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

struct InstructionRow: View {
    let stepNumber: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text("\(stepNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

struct RecordingFlowView: View {
    let isSettingUp: Bool
    let isRecording: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if isSettingUp {
                SetupRecordingView()
            } else if isRecording {
                ActiveRecordingView()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct SetupRecordingView: View {
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.blue, .blue.opacity(0.1), .blue]),
                            center: .center
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotationAngle))

                Image(systemName: "mic.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 12) {
                Text("Setting Up Mic")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Preparing to record")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

struct ActiveRecordingView: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var swipeOpacity: Double = 0.3
    @State private var swipeOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(Color.red)
                    .frame(width: 80, height: 80)

                Image(systemName: "waveform")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 30)

            VStack(spacing: 12) {
                Text("Recording Active")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Speak naturally into your device")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .offset(x: swipeOffset)
                    .opacity(swipeOpacity)

                Image(systemName: "chevron.left")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .offset(x: swipeOffset)
                    .opacity(swipeOpacity * 0.7)

                Image(systemName: "chevron.left")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .offset(x: swipeOffset)
                    .opacity(swipeOpacity * 0.4)

                Text("Swipe back to return")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.3
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                swipeOpacity = 1.0
                swipeOffset = -10
            }
        }
    }
}
