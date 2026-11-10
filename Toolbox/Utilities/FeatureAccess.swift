import Foundation

/// Groundwork for a future Pro tier. No paywalls exist yet — every
/// path currently resolves to `.free`. When Pro ships, gate features
/// by checking `FeatureAccess.current` rather than adding ad-hoc
/// booleans throughout the codebase.
enum FeatureAccess {
    case free
    case pro
}

enum FeatureGate {
    /// Replace with a real entitlement check when Pro is introduced
    /// (StoreKit 2 `Transaction.currentEntitlements`, etc.).
    static var current: FeatureAccess { .free }

    static func isUnlocked(_ feature: ProFeature) -> Bool {
        switch current {
        case .pro: return true
        case .free: return !feature.requiresPro
        }
    }
}

enum ProFeature {
    case unlimitedBatchProcessing
    case advancedPDFCompression
    case advancedOCR
    case batchOCR
    case unlimitedDocumentScanning
    case customCompressionPresets
    case removeMetadata

    var requiresPro: Bool { true }
}
