import SwiftUI

/// Result sheet. Nothing here opens automatically: links, searches and
/// Wi-Fi joins all wait for an explicit tap.
struct ScanResultView: View {
    let code: ScannedCode

    @Environment(\.openURL) private var openURL
    @State private var copied = false
    @State private var isConnecting = false
    @State private var wifiMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                header
                details
                actions
            }
            .padding(AppSpacing.xl)
        }
        .background(AppColors.background)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: code.symbolName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 44, height: 44)
                .background(AppColors.accentSoft, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                .accessibilityHidden(true)
            Text(code.title).appTitle()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var details: some View {
        switch code.kind {
        case .url:
            card { Text(code.payload).appBody().textSelection(.enabled) }
        case .text:
            card { Text(code.payload).appBody().textSelection(.enabled) }
        case .barcode:
            card {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(code.payload)
                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                        .textSelection(.enabled)
                    detailRow("Type", code.symbologyName)
                }
            }
        case .wifi:
            if let wifi = code.wifi {
                card {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        detailRow("Network", wifi.ssid)
                        detailRow("Security", wifi.security)
                        if wifi.password != nil { detailRow("Password", "Included in code") }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            switch code.kind {
            case .url:
                if let url = code.url {
                    PrimaryButton(title: "Open", systemImage: "safari") { openURL(url) }
                }
                copyButton(secondary: true)
                shareButton

            case .text:
                copyButton(secondary: false)
                shareButton

            case .barcode:
                copyButton(secondary: false)
                if let search = BarcodeScannerService.searchURL(for: code.payload) {
                    SecondaryButton(title: "Search Web", systemImage: "magnifyingglass") { openURL(search) }
                }

            case .wifi:
                if let wifi = code.wifi {
                    PrimaryButton(title: isConnecting ? "Connecting…" : "Connect", systemImage: "wifi") {
                        connect(wifi)
                    }
                    .disabled(isConnecting)
                    copyButton(secondary: true)
                    if let wifiMessage {
                        Text(wifiMessage)
                            .appSecondary()
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.xs)
                    }
                }
            }
        }
    }

    // MARK: - Pieces

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.lg)
            .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
            )
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).appSecondary()
            Spacer()
            Text(value).appBody().multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    /// For Wi-Fi codes the useful thing to copy is the password (or the
    /// network name for open networks); for everything else, the raw text.
    private var copyValue: String {
        if code.kind == .wifi, let wifi = code.wifi { return wifi.password ?? wifi.ssid }
        return code.payload
    }

    private var copyTitle: String {
        if copied { return "Copied" }
        if code.kind == .wifi, let wifi = code.wifi { return wifi.password != nil ? "Copy Password" : "Copy Network Name" }
        return "Copy"
    }

    @ViewBuilder
    private func copyButton(secondary: Bool) -> some View {
        let icon = copied ? "checkmark" : "doc.on.doc"
        if secondary {
            SecondaryButton(title: copyTitle, systemImage: icon, action: copy)
        } else {
            PrimaryButton(title: copyTitle, systemImage: icon, action: copy)
        }
    }

    private var shareButton: some View {
        ShareLink(item: code.payload) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "square.and.arrow.up")
                Text("Share").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
        }
        .buttonStyle(.bordered)
        .tint(AppColors.primary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }

    // MARK: - Actions

    private func copy() {
        UIPasteboard.general.string = copyValue
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.snappy) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy) { copied = false }
        }
    }

    private func connect(_ wifi: WiFiNetwork) {
        isConnecting = true
        wifiMessage = nil
        Task {
            let outcome = await WiFiConnectionService.connect(wifi)
            isConnecting = false
            switch outcome {
            case .connected:
                wifiMessage = "Connected to \(wifi.ssid)."
            case .cancelled:
                wifiMessage = nil
            case .failed:
                wifiMessage = "Couldn't join automatically. Copy the password and join from Settings › Wi-Fi."
            }
        }
    }
}
