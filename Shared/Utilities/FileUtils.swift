//
//  FileUtils.swift
//  MurMur
//
//  Created by Niraj Nair on 19/09/25.
//

import Foundation
import OSLog

class FileUtils {
    static let shared = FileUtils()

    private init() {}

    static func getDocumentsPath() -> [URL] {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    }

    func createUniqueRecordingURL() -> URL? {
        let documentsPath = FileUtils.getDocumentsPath()
        let timestamp = Int(Date().timeIntervalSince1970)
        let sessionId = UUID().uuidString.prefix(8)  // Short unique identifier
        let recordingURL = documentsPath[0].appendingPathComponent(
            "recording_\(timestamp)_\(sessionId).wav")
        Logger.debug("Unique recording URL created: \(recordingURL.lastPathComponent)")
        return recordingURL
    }

    func createRecordingURL() -> URL? {
        return createUniqueRecordingURL()
    }

    func deleteRecordingFile(at url: URL) {
        deleteSpecificFile(at: url)
        cleanupStaleAudioFiles()
    }

    private func deleteSpecificFile(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.debug("No recording file to delete at: \(url.lastPathComponent)")
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
            Logger.debug("Recording file deleted: \(url.lastPathComponent)")
        } catch {
            Logger.error("Failed to delete recording file: \(error)")
        }
    }

    func cleanupStaleAudioFiles() {
        let documentsPath = FileUtils.getDocumentsPath()
        let documentsDirectory = documentsPath[0]
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            let audioFiles = fileURLs.filter { url in
                return url.lastPathComponent.lowercased().hasPrefix("recording")
            }
            var deletedCount = 0
            for audioFile in audioFiles {
                do {
                    try FileManager.default.removeItem(at: audioFile)
                    deletedCount += 1
                    Logger.debug("Deleted stale audio file: \(audioFile.lastPathComponent)")
                } catch {
                    Logger.error(
                        "Failed to delete stale audio file \(audioFile.lastPathComponent): \(error)"
                    )
                }
            }
            if deletedCount > 0 {
                Logger.debug("Cleaned up \(deletedCount) stale audio files")
            }
        } catch {
            Logger.error("Failed to scan documents directory for cleanup: \(error)")
        }
    }

    func createDirectoryIfNeeded(for url: URL) -> Bool {
        let parentDirectory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: parentDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return true
        } catch {
            Logger.error("Failed to create directory for URL \(url): \(error)")
            return false
        }
    }

    func getDocumentsDirectory() -> URL {
        let documentsPath = FileUtils.getDocumentsPath()
        return documentsPath[0]
    }

    func fileExists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }

    func performInitialCleanup() {
        Logger.debug("Performing initial cleanup of stale audio files")
        cleanupStaleAudioFiles()
    }
}
