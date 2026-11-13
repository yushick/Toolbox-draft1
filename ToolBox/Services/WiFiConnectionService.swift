import Foundation
import NetworkExtension

/// Joins a Wi-Fi network from a scanned code. iOS shows its own
/// confirmation prompt, and the app needs the "Hotspot Configuration"
/// capability (see Info.plist.additions.md).
enum WiFiConnectionService {
    enum Outcome {
        case connected
        case cancelled
        case failed
    }

    static func connect(_ network: WiFiNetwork) async -> Outcome {
        let configuration: NEHotspotConfiguration
        if let password = network.password, !password.isEmpty {
            configuration = NEHotspotConfiguration(ssid: network.ssid, passphrase: password, isWEP: network.isWEP)
        } else {
            configuration = NEHotspotConfiguration(ssid: network.ssid)
        }
        configuration.hidden = network.isHidden
        configuration.joinOnce = false

        do {
            try await NEHotspotConfigurationManager.shared.apply(configuration)
            return .connected
        } catch {
            let nsError = error as NSError
            guard nsError.domain == NEHotspotConfigurationErrorDomain else { return .failed }
            switch nsError.code {
            case NEHotspotConfigurationError.alreadyAssociated.rawValue: return .connected
            case NEHotspotConfigurationError.userDenied.rawValue: return .cancelled
            default: return .failed
            }
        }
    }
}
