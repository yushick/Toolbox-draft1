
import SwiftUI
import VisionKit
import Vision

// MARK: - Scanner Container

final class ScannerContainerController: UIViewController {

    let scanner: DataScannerViewController

    var wantsScanning = false {
        didSet {
            syncScanning()
        }
    }

    init(scanner: DataScannerViewController) {
        self.scanner = scanner
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(scanner)
        view.addSubview(scanner.view)

        scanner.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scanner.view.topAnchor.constraint(equalTo: view.topAnchor),
            scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        scanner.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if scanner.isScanning {
            scanner.stopScanning()
        }
    }

    func syncScanning() {
        guard isViewLoaded, view.window != nil else {
            return
        }

        guard DataScannerViewController.isSupported,
              DataScannerViewController.isAvailable else {
            return
        }

        if wantsScanning && !scanner.isScanning {
            try? scanner.startScanning()
        } else if !wantsScanning && scanner.isScanning {
            scanner.stopScanning()
        }
    }
}

// MARK: - SwiftUI Scanner

struct DataScannerView: UIViewControllerRepresentable {

    let isScanning: Bool

    // Payload and symbology
    let onScan: (String, String) -> Void

    func makeUIViewController(context: Context) -> ScannerContainerController {

        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: BarcodeScannerService.symbologies)
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )

        scanner.delegate = context.coordinator

        let container = ScannerContainerController(scanner: scanner)

        container.wantsScanning = isScanning

        return container
    }

    func updateUIViewController(
        _ controller: ScannerContainerController,
        context: Context
    ) {
        context.coordinator.onScan = onScan
        controller.wantsScanning = isScanning
    }

    static func dismantleUIViewController(
        _ controller: ScannerContainerController,
        coordinator: Coordinator
    ) {
        controller.wantsScanning = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {

        var onScan: (String, String) -> Void

        init(onScan: @escaping (String, String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            report(addedItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            report([item])
        }

        private func report(_ items: [RecognizedItem]) {

            for item in items {

                if case .barcode(let barcode) = item,
                   let payload = barcode.payloadStringValue {

                    onScan(
                        payload,
                        barcode.observation.symbology.rawValue
                    )

                    return
                }
            }
        }
    }
}

