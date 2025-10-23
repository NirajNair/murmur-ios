//
//  SharedDefaults.swift
//  MurMur
//
//  Created by Niraj Nair on 04/09/25.
//

import Foundation

struct SharedUserDefaults {
    static let shared = UserDefaults(suiteName: "group.com.nirajnair.MurMur")!

    enum Keys {
        static let isRecording = "isRecording"
        static let isAudioSessionActive = "isAudioSessionActive"
        static let recordingSessionId = "recordingSessionId"
        static let lastTranscription = "lastTranscription"
        static let pendingTranscription = "pendingTranscription"
        static let transcriptionInProgress = "transcriptionInProgress"
        static let isPaused = "isPaused"
        static let currentRecordingSegment = "currentRecordingSegment"
        static let keyboardHasFullAccess = "keyboardHasFullAccess"
        static let keyboardLastCheck = "keyboardLastCheck"
        static let statusRequestTime = "statusRequestTime"
        static let transcriptionError = "transcriptionError"
    }

    static var isRecording: Bool {
        get { shared.bool(forKey: Keys.isRecording) }
        set {
            shared.set(newValue, forKey: Keys.isRecording)
            shared.synchronize()
        }
    }

    static var isAudioSessionActive: Bool {
        get { shared.bool(forKey: Keys.isAudioSessionActive) }
        set {
            shared.set(newValue, forKey: Keys.isAudioSessionActive)
            shared.synchronize()
        }
    }

    static var lastTranscription: String? {
        get { shared.string(forKey: Keys.lastTranscription) }
        set {
            shared.set(newValue, forKey: Keys.lastTranscription)
            shared.synchronize()
        }
    }

    static var pendingTranscription: String? {
        get { shared.string(forKey: Keys.pendingTranscription) }
        set {
            shared.set(newValue, forKey: Keys.pendingTranscription)
            shared.synchronize()
        }
    }

    static var transcriptionInProgress: Bool {
        get { shared.bool(forKey: Keys.transcriptionInProgress) }
        set {
            shared.set(newValue, forKey: Keys.transcriptionInProgress)
            shared.synchronize()
        }
    }

    static var recordingSessionId: String? {
        get { shared.string(forKey: Keys.recordingSessionId) }
        set {
            shared.set(newValue, forKey: Keys.recordingSessionId)
            shared.synchronize()
        }
    }

    static var isPaused: Bool {
        get { shared.bool(forKey: Keys.isPaused) }
        set {
            shared.set(newValue, forKey: Keys.isPaused)
            shared.synchronize()
        }
    }

    static var currentRecordingSegment: Int {
        get { shared.integer(forKey: Keys.currentRecordingSegment) }
        set {
            shared.set(newValue, forKey: Keys.currentRecordingSegment)
            shared.synchronize()
        }
    }

    static var keyboardHasFullAccess: Bool {
        get { shared.bool(forKey: Keys.keyboardHasFullAccess) }
        set {
            shared.set(newValue, forKey: Keys.keyboardHasFullAccess)
            shared.synchronize()
        }
    }

    static var keyboardLastCheck: Date? {
        get { shared.object(forKey: Keys.keyboardLastCheck) as? Date }
        set {
            shared.set(newValue, forKey: Keys.keyboardLastCheck)
            shared.synchronize()
        }
    }

    static var statusRequestTime: Date? {
        get { shared.object(forKey: Keys.statusRequestTime) as? Date }
        set {
            shared.set(newValue, forKey: Keys.statusRequestTime)
            shared.synchronize()
        }
    }

    static var transcriptionError: String? {
        get { shared.string(forKey: Keys.transcriptionError) }
        set {
            shared.set(newValue, forKey: Keys.transcriptionError)
            shared.synchronize()
        }
    }
}
