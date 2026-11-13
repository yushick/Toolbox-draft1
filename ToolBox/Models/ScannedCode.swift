import Foundation

struct WiFiNetwork: Equatable, Sendable {
    let ssid: String
    let password: String?
    /// Human-readable, e.g. "WPA/WPA2", "WEP", "None".
    let security: String
    let isWEP: Bool
    let isHidden: Bool
}

struct ScannedCode: Identifiable, Equatable {
    enum Kind: Equatable { case url, wifi, text, barcode }

    let id = UUID()
    let kind: Kind
    let payload: String
    /// e.g. "QR Code", "EAN-13", "Code 128".
    let symbologyName: String
    let url: URL?
    let wifi: WiFiNetwork?

    var title: String {
        switch kind {
        case .url: return "Website"
        case .wifi: return "Wi-Fi Network"
        case .text: return "Text"
        case .barcode: return "Barcode"
        }
    }

    var symbolName: String {
        switch kind {
        case .url: return "safari"
        case .wifi: return "wifi"
        case .text: return "text.alignleft"
        case .barcode: return "barcode"
        }
    }
}

/// Plain value returned from photo scanning (safe to move between threads).
struct DetectedBarcode: Sendable {
    let payload: String
    let symbologyRaw: String
}
