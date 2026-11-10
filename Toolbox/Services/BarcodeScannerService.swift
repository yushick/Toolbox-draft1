import Foundation
import Vision
import AVFoundation

/// Parsing, naming and photo-detection for QR codes and barcodes.
/// Everything here runs on-device.
enum BarcodeScannerService {

    static let symbologies: [VNBarcodeSymbology] = [
        .qr, .microQR, .ean13, .ean8, .upce,
        .code128, .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum,
        .code93, .code93i, .itf14, .i2of5, .i2of5Checksum,
        .pdf417, .microPDF417, .aztec, .dataMatrix, .codabar,
        .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited
    ]

    // MARK: - Classification

    static func makeCode(payload: String, symbologyRaw: String) -> ScannedCode {
        let symbology = VNBarcodeSymbology(rawValue: symbologyRaw)
        let name = displayName(for: symbology, payload: payload)

        // Product codes (EAN, UPC, Code 128…) are shown as plain numbers.
        // Only 2D codes are inspected for links and Wi-Fi details.
        guard isTwoDimensional(symbology) else {
            return ScannedCode(kind: .barcode, payload: payload, symbologyName: name, url: nil, wifi: nil)
        }
        if let wifi = parseWiFi(payload) {
            return ScannedCode(kind: .wifi, payload: payload, symbologyName: name, url: nil, wifi: wifi)
        }
        if let url = webURL(from: payload) {
            return ScannedCode(kind: .url, payload: payload, symbologyName: name, url: url, wifi: nil)
        }
        return ScannedCode(kind: .text, payload: payload, symbologyName: name, url: nil, wifi: nil)
    }

    private static func isTwoDimensional(_ symbology: VNBarcodeSymbology) -> Bool {
        switch symbology {
        case .qr, .microQR, .aztec, .dataMatrix, .pdf417, .microPDF417: return true
        default: return false
        }
    }

    static func displayName(for symbology: VNBarcodeSymbology, payload: String) -> String {
        switch symbology {
        case .qr: return "QR Code"
        case .microQR: return "Micro QR"
        // Vision reports UPC-A as a 13-digit EAN with a leading 0.
        case .ean13: return (payload.count == 13 && payload.hasPrefix("0")) ? "UPC-A" : "EAN-13"
        case .ean8: return "EAN-8"
        case .upce: return "UPC-E"
        case .code128: return "Code 128"
        case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum: return "Code 39"
        case .code93, .code93i: return "Code 93"
        case .itf14: return "ITF-14"
        case .i2of5, .i2of5Checksum: return "Interleaved 2 of 5"
        case .pdf417: return "PDF417"
        case .microPDF417: return "Micro PDF417"
        case .aztec: return "Aztec"
        case .dataMatrix: return "Data Matrix"
        case .codabar: return "Codabar"
        case .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited: return "GS1 DataBar"
        default: return symbology.rawValue.replacingOccurrences(of: "VNBarcodeSymbology", with: "")
        }
    }

    // MARK: - Parsing

    /// Only plain web links are treated as links. Anything else
    /// (tel:, sms:, custom app schemes…) stays as text so the app never
    /// offers to open something unexpected.
    static func webURL(from payload: String) -> URL? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    /// Parses the standard `WIFI:T:WPA;S:name;P:password;H:true;;` format,
    /// including backslash-escaped characters.
    static func parseWiFi(_ payload: String) -> WiFiNetwork? {
        guard payload.uppercased().hasPrefix("WIFI:") else { return nil }
        let body = String(payload.dropFirst(5))

        var fields: [String: String] = [:]
        var key = "", value = ""
        var readingKey = true, escaped = false

        for character in body {
            if escaped {
                if readingKey { key.append(character) } else { value.append(character) }
                escaped = false
                continue
            }
            if character == "\\" { escaped = true; continue }
            if readingKey {
                if character == ":" { readingKey = false }
                else if character == ";" { key = "" }
                else { key.append(character) }
            } else if character == ";" {
                fields[key.uppercased()] = value
                key = ""; value = ""; readingKey = true
            } else {
                value.append(character)
            }
        }
        if !readingKey, !key.isEmpty { fields[key.uppercased()] = value }

        guard let ssid = fields["S"], !ssid.isEmpty else { return nil }
        let type = (fields["T"] ?? "").uppercased()
        let isOpen = type.isEmpty || type == "NOPASS"
        let isWEP = type == "WEP"
        let security = isOpen ? "None" : (isWEP ? "WEP" : "WPA/WPA2")
        let password = isOpen ? nil : fields["P"]
        let hidden = (fields["H"] ?? "").lowercased() == "true"
        return WiFiNetwork(ssid: ssid, password: password, security: security, isWEP: isWEP, isHidden: hidden)
    }

    static func searchURL(for code: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: code)]
        return components?.url
    }

    // MARK: - Photo scanning

    static func detect(in url: URL) throws -> [DetectedBarcode] {
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(url: url, options: [:])
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let payload = observation.payloadStringValue, !payload.isEmpty else { return nil }
            return DetectedBarcode(payload: payload, symbologyRaw: observation.symbology.rawValue)
        }
    }
}

/// Flashlight control. The scanner owns the camera session; the torch is
/// toggled on the same capture device.
enum TorchService {
    static var isAvailable: Bool { AVCaptureDevice.default(for: .video)?.hasTorch ?? false }

    @discardableResult
    static func set(_ on: Bool) -> Bool {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return false }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if on { try device.setTorchModeOn(level: 1.0) } else { device.torchMode = .off }
            return true
        } catch {
            return false
        }
    }
}
