//
//  Logger.swift
//  MurMur
//
//  Created by Niraj Nair on 12/09/25.
//

import OSLog

struct Logger {
    private static let logger = os.Logger(subsystem: "com.nirajnair.MurMur", category: "general")

    static func debug(_ message: String) {
        logger.debug("DEBUG: \(message)")
    }

    static func info(_ message: String) {
        logger.info("INFO: \(message)")
    }

    static func warning(_ message: String) {
        logger.warning("WARNING: \(message)")
    }

    static func error(_ message: String) {
        logger.error("ERROR: \(message)")
    }

    static func critical(_ message: String) {
        logger.critical("CRITICAL: \(message)")
    }

    static func log(_ message: String, emoji: String? = nil, level: OSLogType = .debug) {
        let fullMessage = emoji != nil ? "\(emoji!) \(message)" : message
        switch level {
        case .debug:
            logger.debug("DEBUG: \(fullMessage)")
        case .info:
            logger.info("INFO: \(fullMessage)")
        case .default:
            logger.log("LOG: \(fullMessage)")
        case .error:
            logger.error("ERROR: \(fullMessage)")
        case .fault:
            logger.critical("CRITICAL: \(fullMessage)")
        default:
            logger.log("LOG: \(fullMessage)")
        }
    }

    static func trace(_ message: String) {
        logger.trace("TRACE: \(message)")
    }
}
