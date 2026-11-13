import Foundation
import SwiftUI
import PhotosUI
import AVFoundation
import VisionKit
import Observation

@MainActor
@Observable
final class QRScannerViewModel {
    enum CameraState {
        case checking
        case needsPermission   // not asked yet: we explain first, then ask
        case denied
        case unsupported       // no scanner hardware, or running in the simulator
        case ready
    }

    var cameraState: CameraState = .checking
    var result: ScannedCode?
    var isTorchOn = false
    var isPhotoPickerPresented = false
    var photoSelection: PhotosPickerItem?
    var alertMessage: String?

    private var lastPayload: String?
    private var lastDismissal = Date.distantPast

    /// Scanning pauses while a result is on screen, so the same code is
    /// never reported twice.
    var isScanning: Bool { cameraState == .ready && result == nil }

    // MARK: - Camera

    func prepareCamera() async {
        guard DataScannerViewController.isSupported else { cameraState = .unsupported; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraState = DataScannerViewController.isAvailable ? .ready : .unsupported
        case .notDetermined:
            cameraState = .needsPermission
        default:
            cameraState = .denied
        }
    }

    func requestCameraAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted {
            cameraState = DataScannerViewController.isAvailable ? .ready : .unsupported
        } else {
            cameraState = .denied
        }
    }

    // MARK: - Results

    func handleScan(payload: String, symbologyRaw: String, fromPhoto: Bool = false) {
        guard result == nil, !payload.isEmpty else { return }
        // After closing a result, ignore the same code for a moment so it
        // doesn't pop straight back up while the camera is still pointed at it.
        if !fromPhoto, payload == lastPayload, Date().timeIntervalSince(lastDismissal) < 2 { return }

        lastPayload = payload
        result = BarcodeScannerService.makeCode(payload: payload, symbologyRaw: symbologyRaw)
        if isTorchOn { toggleTorch() }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func resultDismissed() {
        lastDismissal = .now
    }

    // MARK: - Photo

    func scanPhoto(_ item: PhotosPickerItem) async {
        defer { photoSelection = nil }
        guard let file = try? await item.loadTransferable(type: PickedImageFile.self) else {
            alertMessage = "That photo couldn't be opened."
            return
        }
        let url = file.url
        defer { try? FileManager.default.removeItem(at: url) }

        let found = try? await Task.detached(priority: .userInitiated) {
            try BarcodeScannerService.detect(in: url)
        }.value

        guard let first = found?.first else {
            alertMessage = "No QR code or barcode was found in that photo."
            return
        }
        handleScan(payload: first.payload, symbologyRaw: first.symbologyRaw, fromPhoto: true)
    }

    // MARK: - Imported image

    /// True when opened with a photo from Home: we read that photo
    /// instead of asking for the camera.
    var isImportedMode = false
    var isReadingImage = false
    var foundCodeInImage = false

    func scanImportedImage(_ url: URL) async {
        isImportedMode = true
        isReadingImage = true
        defer {
            isReadingImage = false
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
        let found = try? await Task.detached(priority: .userInitiated) {
            try BarcodeScannerService.detect(in: url)
        }.value
        guard let first = found?.first else { return }
        foundCodeInImage = true
        handleScan(payload: first.payload, symbologyRaw: first.symbologyRaw, fromPhoto: true)
    }

    func switchToCamera() async {
        isImportedMode = false
        cameraState = .checking
        await prepareCamera()
    }

    // MARK: - Torch

    func toggleTorch() {
        guard TorchService.isAvailable else {
            alertMessage = "The flashlight isn't available on this device."
            return
        }
        if TorchService.set(!isTorchOn) { isTorchOn.toggle() }
    }

    func stopTorch() {
        if isTorchOn { TorchService.set(false); isTorchOn = false }
    }
}
