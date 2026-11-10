import SwiftUI

/// Keys for everything stored in UserDefaults (via @AppStorage).
enum PreferenceKey {
    static let appearance = "appearance"
    static let imageQuality = "defaultImageQuality"
    static let pdfCompression = "defaultPDFCompression"
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// nil means "follow the system setting".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Reads saved defaults for places that aren't SwiftUI views (view models).
/// Always returns a valid value, even before the user has opened Settings.
enum AppPreferences {
    static let fallbackImageQuality = 0.75

    static var defaultImageQuality: Double {
        let stored = UserDefaults.standard.object(forKey: PreferenceKey.imageQuality) as? Double
        return min(max(stored ?? fallbackImageQuality, 0.1), 1.0)
    }

    static var defaultPDFCompression: CompressionQuality {
        let raw = UserDefaults.standard.string(forKey: PreferenceKey.pdfCompression) ?? ""
        return CompressionQuality(rawValue: raw) ?? .balanced
    }
}

/// Contact details and store links. Replace the placeholders before release.
enum AppLinks {
    /// TODO: replace with your real support address. ".example" is a reserved
    /// placeholder domain, so mail to it can never reach a stranger.
    static let supportEmail = "support@toolbox.example"

    /// TODO: set to your App Store ID once the app has one (digits only).
    /// While nil, "Rate Toolbox" uses the system rating prompt instead.
    static let appStoreID: String? = nil

    static var reviewURL: URL? {
        guard let appStoreID else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    static var supportURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Toolbox Support"),
            URLQueryItem(name: "body", value: "\n\n—\nToolbox \(AppInfo.versionString), iOS \(UIDevice.current.systemVersion)")
        ]
        return components.url
    }
}

enum AppInfo {
    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
