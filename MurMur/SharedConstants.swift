import Foundation

struct AppGroupConstants {
    static let groupIdentifier = "group.com.nirajnair.MurMur"  // IMPORTANT: Replace with your actual App Group ID
    static let userDefaultsSuiteName = groupIdentifier
    static let isRecordingKey = "isRecording"
    static let transcribedTextKey = "transcribedText"
}

struct URLSchemeConstants {
    static let scheme = "murmur"
    static let host = "record"
}
