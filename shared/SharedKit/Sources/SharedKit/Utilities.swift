import Foundation
import os

public enum Log {
    private static let logger = Logger(subsystem: "SharedKit", category: "General")

    public static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    public static func warn(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    public static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

public struct AppInfo {
    public static func prettyName(_ bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "App"
    }
}
