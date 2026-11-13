import XCTest
import SwiftData
import PDFKit
import UIKit
import ImageIO
import Vision

// If the build says "No such module", change this to your app target's
// name exactly as it appears in Xcode (for example `ToolBox`).
@testable import Toolbox

// MARK: - Helpers

private enum TestMedia {
    static func rendererFormat() -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return format
    }

    /// A busy, colourful JPEG, so compression has real detail to remove.
    static func makeJPEG(width: Int, height: Int) throws -> URL {
        let size = CGSize(width: width, height: height)
        let image = UIGraphicsImageRenderer(size: size, format: rendererFormat()).image { context in
            for y in stride(from: 0, to: height, by: 4) {
                for x in stride(from: 0, to: width, by: 4) {
                    UIColor(red: CGFloat(x) / CGFloat(width),
                            green: CGFloat(y) / CGFloat(height),
                            blue: CGFloat((x * y) % 255) / 255,
                            alpha: 1).setFill()
                    context.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.95))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: url)
        return url
    }

    static func solidImage(_ color: UIColor, size: CGSize = CGSize(width: 300, height: 400)) -> UIImage {
        UIGraphicsImageRenderer(size: size, format: rendererFormat()).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func textImage(_ text: String) -> UIImage {
        let size = CGSize(width: 1200, height: 300)
        return UIGraphicsImageRenderer(size: size, format: rendererFormat()).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (text as NSString).draw(at: CGPoint(x: 40, y: 80), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 110),
                .foregroundColor: UIColor.black
            ])
        }
    }

    static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: width, height: height)
    }

    static func write(_ data: Data, ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        try data.write(to: url)
        return url
    }
}

// MARK: - Tool search

final class ToolSearchTests: XCTestCase {
    func testSearchFindsToolsByTitleAndSubtitle() {
        let ids = Tool.search("pdf").map(\.id)
        XCTAssertTrue(ids.contains(.compressPDF))
        XCTAssertTrue(ids.contains(.scanDocument), "Scan Document's subtitle mentions PDF")
    }

    func testSearchFindsToolsByCategory() {
        let ids = Tool.search("images").map(\.id)
        XCTAssertTrue(ids.contains(.compressImage))
        XCTAssertTrue(ids.contains(.resizeImage))
    }

    func testSearchIsCaseInsensitive() {
        XCTAssertEqual(Tool.search("OCR").map(\.id), Tool.search("ocr").map(\.id))
        XCTAssertFalse(Tool.search("OCR").isEmpty)
    }

    func testBlankAndUnmatchedQueriesReturnNothing() {
        XCTAssertTrue(Tool.search("   ").isEmpty)
        XCTAssertTrue(Tool.search("zzzzqqq").isEmpty)
    }

    func testToolIDsAreUnique() {
        XCTAssertEqual(Set(Tool.all.map(\.id)).count, Tool.all.count)
    }
}

// MARK: - Image resizing

final class ImageResizingTests: XCTestCase {
    func testFitShrinksInsideTheBoxKeepingAspectRatio() {
        let landscape = ImageResizeService.outputSize(source: CGSize(width: 4000, height: 3000),
                                                      target: CGSize(width: 1080, height: 1080), mode: .fit)
        XCTAssertEqual(landscape, CGSize(width: 1080, height: 810))

        let portrait = ImageResizeService.outputSize(source: CGSize(width: 3000, height: 4000),
                                                     target: CGSize(width: 1080, height: 1080), mode: .fit)
        XCTAssertEqual(portrait, CGSize(width: 810, height: 1080))
    }

    func testFitNeverEnlarges() {
        let size = ImageResizeService.outputSize(source: CGSize(width: 500, height: 400),
                                                 target: CGSize(width: 1080, height: 1080), mode: .fit)
        XCTAssertEqual(size, CGSize(width: 500, height: 400))
    }

    func testFillIsExactlyTheTarget() {
        let size = ImageResizeService.outputSize(source: CGSize(width: 4000, height: 3000),
                                                 target: CGSize(width: 1080, height: 1350), mode: .fill)
        XCTAssertEqual(size, CGSize(width: 1080, height: 1350))
    }

    func testPresetsMatchTheSpec() {
        XCTAssertEqual(ResizePreset.instagramPost.size, CGSize(width: 1080, height: 1080))
        XCTAssertEqual(ResizePreset.instagramPortrait.size, CGSize(width: 1080, height: 1350))
        XCTAssertEqual(ResizePreset.instagramStory.size, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(ResizePreset.landscapeHD.size, CGSize(width: 1920, height: 1080))
        XCTAssertNil(ResizePreset.custom.size)
    }

    func testRealResizeProducesTheExpectedPixels() throws {
        let source = try TestMedia.makeJPEG(width: 1200, height: 800)
        defer { try? FileManager.default.removeItem(at: source) }

        let fill = try ImageResizeService.resize(sourceURL: source, target: CGSize(width: 600, height: 600),
                                                 mode: .fill, format: .jpeg, quality: 0.9)
        XCTAssertEqual(TestMedia.pixelSize(of: fill.data), CGSize(width: 600, height: 600))

        let fit = try ImageResizeService.resize(sourceURL: source, target: CGSize(width: 600, height: 600),
                                                mode: .fit, format: .jpeg, quality: 0.9)
        XCTAssertEqual(TestMedia.pixelSize(of: fit.data), CGSize(width: 600, height: 400))
    }

    func testUnreadableFileThrows() throws {
        let junk = try TestMedia.write(Data("not an image".utf8), ext: "jpg")
        defer { try? FileManager.default.removeItem(at: junk) }
        XCTAssertThrowsError(try ImageResizeService.resize(sourceURL: junk, target: CGSize(width: 100, height: 100),
                                                           mode: .fit, format: .jpeg, quality: 0.9))
    }
}

// MARK: - Compression calculations

final class CompressionTests: XCTestCase {
    func testTargetSizesInBytes() {
        XCTAssertEqual(TargetSize.under500KB.bytes, 500_000)
        XCTAssertEqual(TargetSize.under1MB.bytes, 1_000_000)
        XCTAssertEqual(TargetSize.under2MB.bytes, 2_000_000)
        XCTAssertEqual(TargetSize.under5MB.bytes, 5_000_000)
        XCTAssertEqual(TargetSize.custom(1_234_567).bytes, 1_234_567)
    }

    func testQualityPresetsGetProgressivelySmaller() {
        let max = CompressionQuality.maximumQuality.settings
        let balanced = CompressionQuality.balanced.settings
        let smallest = CompressionQuality.smallestFile.settings
        XCTAssertGreaterThan(max.jpegQuality, balanced.jpegQuality)
        XCTAssertGreaterThan(balanced.jpegQuality, smallest.jpegQuality)
        XCTAssertGreaterThan(max.maxDimension, balanced.maxDimension)
        XCTAssertGreaterThan(balanced.maxDimension, smallest.maxDimension)
    }

    func testLowerQualityMakesAnImageSmaller() throws {
        let source = try TestMedia.makeJPEG(width: 1200, height: 800)
        defer { try? FileManager.default.removeItem(at: source) }
        let original = ImageProcessingService.fileSize(at: source)

        let compressed = try ImageProcessingService.compress(sourceURL: source, format: .jpeg,
                                                             quality: 0.3, maxPixelSize: nil)
        XCTAssertLessThan(compressed.count, original)
    }

    func testMaxPixelSizeLimitsDimensionsAndNeverUpscales() throws {
        let source = try TestMedia.makeJPEG(width: 1200, height: 800)
        defer { try? FileManager.default.removeItem(at: source) }

        let small = try ImageProcessingService.compress(sourceURL: source, format: .jpeg, quality: 0.8, maxPixelSize: 300)
        let smallSize = try XCTUnwrap(TestMedia.pixelSize(of: small))
        XCTAssertLessThanOrEqual(max(smallSize.width, smallSize.height), 300)

        let large = try ImageProcessingService.compress(sourceURL: source, format: .jpeg, quality: 0.8, maxPixelSize: 5000)
        XCTAssertEqual(TestMedia.pixelSize(of: large), CGSize(width: 1200, height: 800))
    }
}

// MARK: - File naming and file operations

@MainActor
final class FileNamingTests: XCTestCase {
    private var cleanup: [URL] = []

    override func tearDown() {
        cleanup.forEach { try? FileManager.default.removeItem(at: $0) }
        cleanup = []
        super.tearDown()
    }

    private func makeFile(named name: String) throws -> ProcessedFile {
        let url = FileService.documentsDirectory.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        cleanup.append(url)
        return ProcessedFile(filename: name, kind: .pdf, byteSize: 1, relativePath: name)
    }

    func testSanitizingRemovesIllegalCharacters() {
        XCTAssertEqual(FileService.sanitizedBaseName("a/b:c"), "a-b-c")
        XCTAssertEqual(FileService.sanitizedBaseName("My Scan?"), "My Scan-")
        XCTAssertEqual(FileService.sanitizedBaseName(".hidden"), "hidden")
        XCTAssertEqual(FileService.sanitizedBaseName("  padded  "), "padded")
    }

    func testSanitizingRejectsEmptyAndCapsLength() {
        XCTAssertNil(FileService.sanitizedBaseName("   "))
        XCTAssertNil(FileService.sanitizedBaseName("..."))
        XCTAssertEqual(FileService.sanitizedBaseName(String(repeating: "a", count: 200))?.count, 100)
    }

    func testDefaultNamesAreReadable() {
        XCTAssertTrue(ScannerViewModel.defaultName().hasPrefix("Scan "))
        XCTAssertTrue(OCRViewModel.defaultName().hasPrefix("Extracted Text "))
    }

    func testRenameKeepsExtensionAndMovesTheFile() throws {
        let id = UUID().uuidString
        let file = try makeFile(named: "ut-\(id).pdf")
        cleanup.append(FileService.documentsDirectory.appendingPathComponent("ut-\(id)-new.pdf"))

        try FileService.rename(file, to: "ut-\(id)-new")

        XCTAssertEqual(file.filename, "ut-\(id)-new.pdf")
        XCTAssertEqual(file.relativePath, "ut-\(id)-new.pdf")
        XCTAssertTrue(FileService.exists(file))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: FileService.documentsDirectory.appendingPathComponent("ut-\(id).pdf").path))
    }

    func testRenameDoesNotDoubleTheExtension() throws {
        let id = UUID().uuidString
        let file = try makeFile(named: "ut-\(id).pdf")
        cleanup.append(FileService.documentsDirectory.appendingPathComponent("ut-\(id)-b.pdf"))

        try FileService.rename(file, to: "ut-\(id)-b.pdf")
        XCTAssertEqual(file.filename, "ut-\(id)-b.pdf")
    }

    func testRenameRefusesATakenNameAndAnEmptyName() throws {
        let id = UUID().uuidString
        let first = try makeFile(named: "ut-\(id)-1.pdf")
        _ = try makeFile(named: "ut-\(id)-2.pdf")

        XCTAssertThrowsError(try FileService.rename(first, to: "ut-\(id)-2")) { error in
            XCTAssertEqual(error as? FileService.FileError, .nameTaken)
        }
        XCTAssertThrowsError(try FileService.rename(first, to: "   ")) { error in
            XCTAssertEqual(error as? FileService.FileError, .emptyName)
        }
        XCTAssertEqual(first.filename, "ut-\(id)-1.pdf", "A failed rename must not change the record")
    }

    func testOutputFilesNeverOverwrite() throws {
        let name = "ut-unique-\(UUID().uuidString)"
        let first = try OutputFiles.write(Data("1".utf8), name: name, ext: "txt")
        let second = try OutputFiles.write(Data("2".utf8), name: name, ext: "txt")
        cleanup.append(contentsOf: [first, second])

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(second.lastPathComponent, "\(name) (2).txt")
        XCTAssertEqual(try Data(contentsOf: first), Data("1".utf8))
    }
}

// MARK: - PDF operations

final class PDFTests: XCTestCase {
    private func makePages(_ count: Int) -> [ScannedPage] {
        (0..<count).map { _ in ScannedPage(originalImage: TestMedia.solidImage(.systemTeal)) }
    }

    func testCreatingAPDFHasOnePagePerScan() async throws {
        let data = try await DocumentScannerService.createPDF(from: makePages(3), enhancement: .color)
        XCTAssertEqual(PDFDocument(data: data)?.pageCount, 3)
    }

    func testCreatingAPDFWithNoPagesFails() async {
        do {
            _ = try await DocumentScannerService.createPDF(from: [], enhancement: .color)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? DocumentScannerService.ScannerError, .noPages)
        }
    }

    func testCompressedPDFKeepsAllPages() async throws {
        let original = try await DocumentScannerService.createPDF(from: makePages(2), enhancement: .color)
        let url = try TestMedia.write(original, ext: "pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        let byQuality = try await PDFCompressionService.compress(url: url, quality: .smallestFile)
        XCTAssertEqual(PDFDocument(data: byQuality)?.pageCount, 2)

        let byTarget = try await PDFCompressionService.compress(url: url, target: .under500KB)
        XCTAssertEqual(PDFDocument(data: byTarget)?.pageCount, 2)
    }

    func testCorruptPDFIsRejectedWithAClearError() async throws {
        let url = try TestMedia.write(Data("definitely not a pdf".utf8), ext: "pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await PDFCompressionService.compress(url: url, quality: .balanced)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? PDFCompressionService.CompressionError, .cannotOpen)
        }
    }

    func testTextToPDFFlowsOntoMultiplePages() throws {
        let longText = (1...400).map { "Line number \($0)" }.joined(separator: "\n")
        let document = try XCTUnwrap(PDFDocument(data: OCRService.makePDF(from: longText)))
        XCTAssertGreaterThan(document.pageCount, 1)

        let short = try XCTUnwrap(PDFDocument(data: OCRService.makePDF(from: "Hello")))
        XCTAssertEqual(short.pageCount, 1)
    }
}

// MARK: - OCR

final class OCRTests: XCTestCase {
    func testReadsTextFromARenderedImage() throws {
        let input = try XCTUnwrap(OCRService.input(from: TestMedia.textImage("TOOLBOX OCR")))
        let text = try OCRService.recognize(input)
        XCTAssertTrue(text.uppercased().contains("TOOLBOX"), "Recognised: \(text)")
    }

    func testBlankImageGivesNoText() throws {
        let input = try XCTUnwrap(OCRService.input(from: TestMedia.solidImage(.white)))
        let text = try OCRService.recognize(input)
        XCTAssertTrue(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

// MARK: - QR / barcode parsing

final class BarcodeParsingTests: XCTestCase {
    func testParsesAWiFiCode() throws {
        let network = try XCTUnwrap(BarcodeScannerService.parseWiFi("WIFI:T:WPA;S:HomeWiFi;P:secret123;H:false;;"))
        XCTAssertEqual(network.ssid, "HomeWiFi")
        XCTAssertEqual(network.password, "secret123")
        XCTAssertEqual(network.security, "WPA/WPA2")
        XCTAssertFalse(network.isHidden)
    }

    func testParsesEscapedCharactersAndOpenNetworks() throws {
        let escaped = try XCTUnwrap(BarcodeScannerService.parseWiFi("WIFI:T:WPA;S:My\;Net;P:pa\\:ss;;"))
        XCTAssertEqual(escaped.ssid, "My;Net")
        XCTAssertEqual(escaped.password, "pa:ss")

        let open = try XCTUnwrap(BarcodeScannerService.parseWiFi("WIFI:T:nopass;S:Cafe;;"))
        XCTAssertEqual(open.security, "None")
        XCTAssertNil(open.password)
    }

    func testNonWiFiTextIsNotParsedAsWiFi() {
        XCTAssertNil(BarcodeScannerService.parseWiFi("hello world"))
        XCTAssertNil(BarcodeScannerService.parseWiFi("WIFI:T:WPA;P:nossid;;"))
    }

    func testOnlyWebLinksAreTreatedAsLinks() {
        XCTAssertNotNil(BarcodeScannerService.webURL(from: "https://example.com/path?q=1"))
        XCTAssertNotNil(BarcodeScannerService.webURL(from: "http://example.com"))
        XCTAssertNil(BarcodeScannerService.webURL(from: "ftp://example.com"))
        XCTAssertNil(BarcodeScannerService.webURL(from: "javascript:alert(1)"))
        XCTAssertNil(BarcodeScannerService.webURL(from: "tel:+911234567890"))
        XCTAssertNil(BarcodeScannerService.webURL(from: "https://exa mple.com"))
    }

    func testClassifiesScannedCodes() {
        let qrRaw = VNBarcodeSymbology.qr.rawValue
        XCTAssertEqual(BarcodeScannerService.makeCode(payload: "https://example.com", symbologyRaw: qrRaw).kind, .url)
        XCTAssertEqual(BarcodeScannerService.makeCode(payload: "Hello World", symbologyRaw: qrRaw).kind, .text)
        XCTAssertEqual(BarcodeScannerService.makeCode(payload: "WIFI:T:WPA;S:Net;P:pass1234;;", symbologyRaw: qrRaw).kind, .wifi)

        // A product barcode stays a number even if its digits look like something else.
        let ean = BarcodeScannerService.makeCode(payload: "5901234123457", symbologyRaw: VNBarcodeSymbology.ean13.rawValue)
        XCTAssertEqual(ean.kind, .barcode)
        XCTAssertEqual(ean.symbologyName, "EAN-13")
    }

    func testNamesBarcodeTypes() {
        XCTAssertEqual(BarcodeScannerService.makeCode(payload: "0123456789012",
                                                      symbologyRaw: VNBarcodeSymbology.ean13.rawValue).symbologyName, "UPC-A")
        XCTAssertEqual(BarcodeScannerService.makeCode(payload: "ABC-123",
                                                      symbologyRaw: VNBarcodeSymbology.code128.rawValue).symbologyName, "Code 128")
    }

    func testWebSearchURLEncodesTheCode() throws {
        let url = try XCTUnwrap(BarcodeScannerService.searchURL(for: "8901234567890"))
        XCTAssertTrue(url.absoluteString.contains("q=8901234567890"))
    }
}

// MARK: - Settings persistence

final class SettingsPersistenceTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private var saved: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        for key in [PreferenceKey.imageQuality, PreferenceKey.pdfCompression, PreferenceKey.appearance] {
            saved[key] = defaults.object(forKey: key)
        }
    }

    override func tearDown() {
        for (key, value) in saved {
            if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        super.tearDown()
    }

    func testImageQualityFallsBackAndIsClamped() {
        defaults.removeObject(forKey: PreferenceKey.imageQuality)
        XCTAssertEqual(AppPreferences.defaultImageQuality, 0.75, accuracy: 0.0001)

        defaults.set(0.4, forKey: PreferenceKey.imageQuality)
        XCTAssertEqual(AppPreferences.defaultImageQuality, 0.4, accuracy: 0.0001)

        defaults.set(9.0, forKey: PreferenceKey.imageQuality)
        XCTAssertEqual(AppPreferences.defaultImageQuality, 1.0, accuracy: 0.0001)
        defaults.set(-3.0, forKey: PreferenceKey.imageQuality)
        XCTAssertEqual(AppPreferences.defaultImageQuality, 0.1, accuracy: 0.0001)
    }

    func testPDFCompressionDefaultRoundTripsAndRejectsGarbage() {
        defaults.set(CompressionQuality.smallestFile.rawValue, forKey: PreferenceKey.pdfCompression)
        XCTAssertEqual(AppPreferences.defaultPDFCompression, .smallestFile)

        defaults.set("nonsense", forKey: PreferenceKey.pdfCompression)
        XCTAssertEqual(AppPreferences.defaultPDFCompression, .balanced)

        defaults.removeObject(forKey: PreferenceKey.pdfCompression)
        XCTAssertEqual(AppPreferences.defaultPDFCompression, .balanced)
    }

    func testAppearanceMapsToColorSchemes() {
        XCTAssertNil(AppAppearance.system.colorScheme)
        XCTAssertEqual(AppAppearance.light.colorScheme, .light)
        XCTAssertEqual(AppAppearance.dark.colorScheme, .dark)
        XCTAssertEqual(AppAppearance(rawValue: "dark"), .dark, "Saved values from older builds must still load")
    }
}

// MARK: - Recent history, Files list and storage clearing

@MainActor
final class StorageAndHistoryTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: RecentItem.self, ProcessedFile.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    func testRecentItemRecordsTheTool() {
        let item = RecentItem(toolID: .compressPDF, summary: "PDF compressed")
        XCTAssertEqual(item.toolID, ToolID.compressPDF.rawValue)
        XCTAssertEqual(item.summary, "PDF compressed")
    }

    func testClearingRecentHistoryEmptiesTheList() throws {
        let context = try makeContext()
        for index in 0..<3 { context.insert(RecentItem(toolID: .ocr, summary: "Text extracted \(index)")) }
        try context.save()

        let viewModel = SettingsViewModel()
        viewModel.clearRecentHistory(in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<RecentItem>()).count, 0)
        XCTAssertEqual(viewModel.message, "Recent history cleared.")
    }

    func testClearingGeneratedFilesRemovesFilesAndRecords() throws {
        let context = try makeContext()
        let name = "ut-clear-\(UUID().uuidString).txt"
        let url = FileService.documentsDirectory.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let file = ProcessedFile(filename: name, kind: .text, byteSize: 1, relativePath: name)
        context.insert(file)
        try context.save()

        SettingsViewModel().clearGeneratedFiles([file], in: context)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProcessedFile>()).count, 0)
    }

    func testFilesAreSearchedAndSorted() {
        let viewModel = FilesViewModel()
        let files = [
            ProcessedFile(filename: "Invoice.pdf", kind: .pdf, byteSize: 500, relativePath: "Invoice.pdf"),
            ProcessedFile(filename: "Photo.jpg", kind: .image, byteSize: 9_000, relativePath: "Photo.jpg"),
            ProcessedFile(filename: "Notes.txt", kind: .text, byteSize: 40, relativePath: "Notes.txt")
        ]

        XCTAssertEqual(viewModel.visibleFiles(from: files, sort: .name).map(\.filename),
                       ["Invoice.pdf", "Notes.txt", "Photo.jpg"])
        XCTAssertEqual(viewModel.visibleFiles(from: files, sort: .size).map(\.filename),
                       ["Photo.jpg", "Invoice.pdf", "Notes.txt"])

        viewModel.searchText = "inv"
        XCTAssertEqual(viewModel.visibleFiles(from: files, sort: .name).map(\.filename), ["Invoice.pdf"])
    }

    func testFilesGroupByDayOnlyWhenSortedByDate() {
        let viewModel = FilesViewModel()
        let noonToday = Calendar.current.startOfDay(for: .now).addingTimeInterval(12 * 3600)
        let older = noonToday.addingTimeInterval(-3 * 86_400)
        let files = [
            ProcessedFile(filename: "a.pdf", kind: .pdf, byteSize: 1, relativePath: "a.pdf", createdAt: noonToday),
            ProcessedFile(filename: "b.pdf", kind: .pdf, byteSize: 1, relativePath: "b.pdf", createdAt: noonToday),
            ProcessedFile(filename: "c.pdf", kind: .pdf, byteSize: 1, relativePath: "c.pdf", createdAt: older)
        ]

        let byDate = viewModel.sections(from: files, sort: .newest)
        XCTAssertEqual(byDate.count, 2)
        XCTAssertEqual(byDate.first?.title, "Today")
        XCTAssertEqual(byDate.first?.files.count, 2)

        let byName = viewModel.sections(from: files, sort: .name)
        XCTAssertEqual(byName.count, 1)
        XCTAssertNil(byName.first?.title)
    }
}

// MARK: - Import

final class ImportServiceTests: XCTestCase {

    private func item(_ name: String) -> ImportedItem {
        ImportService.item(for: URL(fileURLWithPath: "/tmp/\(name)"))
    }

    func testClassifiesByExtension() {
        XCTAssertEqual(ImportService.kind(of: URL(fileURLWithPath: "/a/b.pdf")), .pdf)
        XCTAssertEqual(ImportService.kind(of: URL(fileURLWithPath: "/a/b.JPG")), .image)
        XCTAssertEqual(ImportService.kind(of: URL(fileURLWithPath: "/a/b.heic")), .image)
        XCTAssertNil(ImportService.kind(of: URL(fileURLWithPath: "/a/b.zip")))
    }

    func testImagesWinOverPDFsInMixedBatch() {
        let media = ImportService.makeMedia(from: [item("a.pdf"), item("b.png"), item("c.jpg"), item("d.zip")])
        XCTAssertEqual(media?.kind, .image)
        XCTAssertEqual(media?.items.count, 2)
        XCTAssertEqual(media?.skipped, 2)
    }

    func testOnlyFirstPDFIsUsed() {
        let media = ImportService.makeMedia(from: [item("a.pdf"), item("b.pdf")])
        XCTAssertEqual(media?.kind, .pdf)
        XCTAssertEqual(media?.items.count, 1)
        XCTAssertEqual(media?.skipped, 1)
    }

    func testUnsupportedBatchGivesNil() {
        XCTAssertNil(ImportService.makeMedia(from: [item("a.zip")]))
        XCTAssertNil(ImportService.makeMedia(from: []))
    }

    func testOfferedActions() {
        let pdf = ImportService.makeMedia(from: [item("a.pdf")])!
        XCTAssertEqual(ImportService.actions(for: pdf).map(\.id), [.compressPDF, .ocr])

        let one = ImportService.makeMedia(from: [item("a.png")])!
        XCTAssertEqual(ImportService.actions(for: one).map(\.id),
                       [.compressImage, .resizeImage, .ocr, .qrBarcodeScanner])

        let many = ImportService.makeMedia(from: [item("a.png"), item("b.png")])!
        XCTAssertFalse(ImportService.actions(for: many).map(\.id).contains(.qrBarcodeScanner))
    }
}
