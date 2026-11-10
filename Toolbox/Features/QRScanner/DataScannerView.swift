import SwiftUI
import UIKit
import VisionKit
import Vision

/// Hosts VisionKit's scanner as a child controller (DataScannerViewController
/// can't be subclassed). Scanning starts and stops only while this screen is
/// actually on screen, because VisionKit requires the view to be in a window.
final class ScannerHostController: UIViewController {
    let scanner: DataScannerViewController
    var wantsScanning = false { didSet { syncScanning() } }

    init(scanner: DataScannerViewController) {
        self.scanner = scanner
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(scanner)
        scanner.view.frame = view.bounds
        scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scanner.view)
        scanner.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if scanner.isScanning { scanner.stopScanning() }
    }

    func syncScanning() {
        guard isViewLoaded, view.window != nil else { return }
        if wantsScanning, !scanner.isScanning {
            try? scanner.startScanning()
        } else if !wantsScanning, scanner.isScanning {
            scanner.stopScanning()
        }
    }
}

/// SwiftUI wrapper around VisionKit's live barcode scanner. Detection,
/// highlighting and pinch-to-zoom come from the system scanner.
struct DataScannerView: UIViewControllerRepresentable {
    let isScanning: Bool
    /// (payload, symbology raw value)
    let onScan: (String, String) -> Void

    func makeUIViewController(context: Context) -> ScannerHostController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: BarcodeScannerService.symbologies)],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        let host = ScannerHostController(scanner: scanner)
        host.wantsScanning = isScanning
        return host
    }

    func updateUIViewController(_ host: ScannerHostController, context: Context) {
        context.coordinator.onScan = onScan
        host.wantsScanning = isScanning
    }

    static func dismantleUIViewController(_ host: ScannerHostController, coordinator: Coordinator) {
        host.wantsScanning = false
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String, String) -> Void
        init(onScan: @escaping (String, String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            report(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            report([item])
        }

        private func report(_ items: [RecognizedItem]) {
            for item in items {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onScan(payload, barcode.observation.symbology.rawValue)
                    return
                }
            }
        }
    }
}
