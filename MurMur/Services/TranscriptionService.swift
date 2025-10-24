//
//  TranscriptionService.swift
//  MurMur
//
//  Created by Niraj Nair on 12/09/25.
//

import Foundation
import OSLog

class TranscriptionService: NSObject {
    static let shared = TranscriptionService()

    private var API_BASE_URL: String =
        KeychainHelper.get(key: AppGroupConstants.apiBaseUrlKey, as: String.self)!

    private let timeoutInterval: TimeInterval = 30.0

    private override init() {
        super.init()
    }

    func transcribeAudioFile(at fileURL: URL) async throws -> String {
        Logger.debug("Starting transcription for file: \(fileURL.lastPathComponent)")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Logger.error("Audio file not found at path: \(fileURL.path)")
            throw TranscriptionError.fileNotFound
        }
        let audioData: Data
        do {
            audioData = try Data(contentsOf: fileURL)
            Logger.debug("Loaded audio data: \(audioData.count) bytes")
        } catch {
            Logger.error("Failed to read audio file: \(error)")
            throw TranscriptionError.fileReadError(error)
        }
        guard let url = URL(string: API_BASE_URL + "/transcribe") else {
            Logger.error("Invalid API endpoint URL: \(API_BASE_URL + "/transcribe")")
            throw TranscriptionError.invalidEndpoint
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let contentType = getContentType(for: fileURL)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(audioData.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("MurMur/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = audioData
        request.timeoutInterval = timeoutInterval
        Logger.debug("Sending transcription request to: \(url)")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            Logger.error("Network request failed: \(error)")
            throw TranscriptionError.networkError(error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.error("Invalid HTTP response")
            throw TranscriptionError.invalidResponse
        }
        Logger.debug("Received HTTP response: \(httpResponse.statusCode)")
        guard 200...299 ~= httpResponse.statusCode else {
            Logger.error("HTTP error: \(httpResponse.statusCode)")
            throw TranscriptionError.httpError(httpResponse.statusCode)
        }
        let transcriptionResponse: TranscriptionResponse
        do {
            transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            Logger.debug("Successfully parsed transcription response")
        } catch {
            Logger.error("Failed to parse JSON response: \(error)")
            throw TranscriptionError.jsonParsingError(error)
        }
        let transcription = transcriptionResponse.transcription
        Logger.debug("Transcription received: \(transcription.prefix(50))...")
        return transcription
    }

    func transcribeRecording(
        at recordingURL: URL, completion: @escaping (Result<String, Error>) -> Void
    ) {
        Logger.debug(
            "Starting background transcription for recording: \(recordingURL.lastPathComponent)")
        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            Logger.error("Recording file not found: \(recordingURL.path)")
            completion(.failure(TranscriptionError.fileNotFound))
            return
        }
        Task {
            do {
                let transcription = try await transcribeAudioFile(at: recordingURL)
                DispatchQueue.main.async {
                    completion(.success(transcription))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func getContentType(for fileURL: URL) -> String {
        let fileExtension = fileURL.pathExtension.lowercased()
        switch fileExtension {
        case "wav":
            return "audio/wav"
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"
        case "aac":
            return "audio/aac"
        case "flac":
            return "audio/flac"
        case "ogg":
            return "audio/ogg"
        default:
            return "application/octet-stream"
        }
    }
}

struct TranscriptionResponse: Codable {
    let transcription: String

    enum CodingKeys: String, CodingKey {
        case transcription = "text"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? container.decode(String.self, forKey: .transcription) {
            transcription = text
        } else {
            let anyContainer = try decoder.container(keyedBy: AnyKey.self)
            if let text = try? anyContainer.decode(
                String.self, forKey: AnyKey(stringValue: "transcription")!)
            {
                transcription = text
            } else if let text = try? anyContainer.decode(
                String.self, forKey: AnyKey(stringValue: "result")!)
            {
                transcription = text
            } else {
                throw DecodingError.keyNotFound(
                    CodingKeys.transcription,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No transcription text found in response"
                    )
                )
            }
        }
    }
}

private struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

enum TranscriptionError: LocalizedError {
    case fileNotFound
    case fileReadError(Error)
    case invalidEndpoint
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    case jsonParsingError(Error)
    case noAudioSegments

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio file not found"
        case .fileReadError(let error):
            return "Failed to read audio file: \(error.localizedDescription)"
        case .invalidEndpoint:
            return "Invalid API endpoint URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .jsonParsingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .noAudioSegments:
            return "No audio segments found for transcription"
        }
    }
}
