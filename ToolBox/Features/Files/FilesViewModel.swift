import Foundation
import SwiftUI
import SwiftData
import UIKit
import PDFKit
import Observation

enum FileSort: String, CaseIterable, Identifiable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case name = "Name"
    case size = "Largest First"

    var id: String { rawValue }
    var groupsByDay: Bool { self == .newest || self == .oldest }
}

enum FileTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pdf = "PDF"
    case image = "Images"
    case text = "Text"

    var id: String { rawValue }

    func matches(_ file: ProcessedFile) -> Bool {
        switch self {
        case .all:
            return true
        case .pdf:
            return ProcessedFileKind(rawValue: file.kind) == .pdf
        case .image:
            return ProcessedFileKind(rawValue: file.kind) == .image
        case .text:
            return ProcessedFileKind(rawValue: file.kind) == .text
        }
    }
}

struct FileSection: Identifiable {
    let id: String
    let title: String?
    let files: [ProcessedFile]
}

@MainActor
@Observable
final class FilesViewModel {
    var searchText = ""
    var selectedFilter: FileTypeFilter = .all

    var isSelecting = false
    var selectedFileIDs: Set<UUID> = []
    var showBatchDeleteConfirmation = false

    var previewURL: URL?
    var fileToDelete: ProcessedFile?
    var fileToRename: ProcessedFile?
    var renameText = ""
    var alertMessage: String?

    // MARK: - Filtering, sorting, grouping

    func visibleFiles(from files: [ProcessedFile], sort: FileSort) -> [ProcessedFile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = files.filter { file in
            guard selectedFilter.matches(file) else { return false }
            return query.isEmpty || file.filename.localizedCaseInsensitiveContains(query)
        }

        switch sort {
        case .newest: return filtered.sorted { $0.createdAt > $1.createdAt }
        case .oldest: return filtered.sorted { $0.createdAt < $1.createdAt }
        case .name: return filtered.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        case .size: return filtered.sorted { $0.byteSize > $1.byteSize }
        }
    }

    func sections(from files: [ProcessedFile], sort: FileSort) -> [FileSection] {
        let sorted = visibleFiles(from: files, sort: sort)
        guard !sorted.isEmpty else { return [] }
        guard sort.groupsByDay else { return [FileSection(id: "all", title: nil, files: sorted)] }

        let calendar = Calendar.current
        var sections: [FileSection] = []
        var currentDay: Date?
        var bucket: [ProcessedFile] = []

        func flush() {
            guard let day = currentDay, !bucket.isEmpty else { return }
            sections.append(FileSection(id: "\(day.timeIntervalSince1970)",
                                        title: Self.dayTitle(for: day), files: bucket))
            bucket = []
        }

        for file in sorted {
            let day = calendar.startOfDay(for: file.createdAt)
            if day != currentDay { flush(); currentDay = day }
            bucket.append(file)
        }
        flush()
        return sections
    }

    static func dayTitle(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    func totalSizeDescription(of files: [ProcessedFile]) -> String {
        let bytes = files.reduce(0) { $0 + $1.byteSize }
        let count = files.count
        return "\(count) file\(count == 1 ? "" : "s") · \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))"
    }

    // MARK: - Selection & Batch Actions

    func toggleSelection(for file: ProcessedFile) {
        if selectedFileIDs.contains(file.id) {
            selectedFileIDs.remove(file.id)
        } else {
            selectedFileIDs.insert(file.id)
        }
    }

    func endSelection() {
        isSelecting = false
        selectedFileIDs.removeAll()
    }

    func batchShare(from files: [ProcessedFile]) {
        let urls = files
            .filter { selectedFileIDs.contains($0.id) && FileService.exists($0) }
            .map { FileService.url(for: $0) }
        guard !urls.isEmpty else { return }
        ShareSheet.present(urls)
    }

    func batchDelete(from files: [ProcessedFile], in context: ModelContext) {
        let targets = files.filter { selectedFileIDs.contains($0.id) }
        for file in targets {
            try? FileService.deleteFromDisk(file)
            context.delete(file)
        }
        try? context.save()
        endSelection()
    }

    // MARK: - Single-File Actions

    func preview(_ file: ProcessedFile) {
        guard FileService.exists(file) else { alertMessage = FileService.FileError.missing.localizedDescription; return }
        previewURL = FileService.url(for: file)
    }

    func share(_ file: ProcessedFile) {
        guard FileService.exists(file) else { alertMessage = FileService.FileError.missing.localizedDescription; return }
        ShareSheet.present([FileService.url(for: file)])
    }

    /// Presents the native iOS share sheet (which includes "Save to Files").
    func openInFiles(_ file: ProcessedFile) {
        guard FileService.exists(file) else { alertMessage = FileService.FileError.missing.localizedDescription; return }
        let url = FileService.url(for: file)
        ShareSheet.present([url])
    }

    func beginRename(_ file: ProcessedFile) {
        renameText = FileService.baseName(of: file)
        fileToRename = file
    }

    func commitRename() {
        guard let file = fileToRename else { return }
        fileToRename = nil
        do {
            try FileService.rename(file, to: renameText)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func delete(_ file: ProcessedFile, in context: ModelContext) {
        fileToDelete = nil
        do {
            try FileService.deleteFromDisk(file)
        } catch {
            alertMessage = error.localizedDescription
        }

        context.delete(file)
        try? context.save()
    }

    // MARK: - Async Thumbnails

    nonisolated static func loadThumbnail(for url: URL, kindRaw: String) async -> UIImage? {
        guard let kind = ProcessedFileKind(rawValue: kindRaw), kind != .text else { return nil }
        return await Task.detached(priority: .utility) {
            switch kind {
            case .image:
                guard let image = UIImage(contentsOfFile: url.path) else { return nil }
                return image.preparingThumbnail(of: CGSize(width: 88, height: 88)) ?? image
            case .pdf:
                guard let document = PDFDocument(url: url),
                      let page = document.page(at: 0) else { return nil }
                return page.thumbnail(of: CGSize(width: 88, height: 88), for: .cropBox)
            case .text:
                return nil
            }
        }.value
    }
}
