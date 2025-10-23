import Foundation

struct AppGroupConstants {
    static let groupIdentifier = "group.com.nirajnair.MurMur"
    static let userDefaultsSuiteName = groupIdentifier
    static let isRecordingKey = "isRecording"
    static let transcribedTextKey = "transcribedText"
    static let audioSessionTimeoutDuration: TimeInterval = 5 * 60
}

struct URLSchemeConstants {
    static let scheme = "murmur"
    static let host = "record"
}
