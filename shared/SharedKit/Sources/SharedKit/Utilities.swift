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
//    What it does step by step:
//    1.    Takes a bundle (default: .main)
//      By default, it uses the main app bundle, but you can pass another Bundle if you want.
//    2.    Looks for CFBundleDisplayName in the bundle’s Info.plist
//      This is the localized, user-facing name of the app (what appears under the app icon on iOS home screen).
//      See target->info-> Bundle Display Name = "not defined" proceed to step 3
//    3.    Falls back to CFBundleName if CFBundleDisplayName isn’t set
//      This is the internal short name of the bundle, often the project name.
//      See target->info->BundleName = $(PRODUCT_NAME), eg "AppTwo"
//    4.    Falls back to "App" if neither is available
//      Provides a safe default string instead of returning nil.
//
//   swift a ?? b  nil-calescing operation
//   a ?? b is a unless a is nil.  In that case the value is b.
//
//   In this case, its a ?? b ?? c
    
    public static func prettyName(_ bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "App"
    }
}
