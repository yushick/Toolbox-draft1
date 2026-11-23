import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var isConfirmingHistory = false
    var isConfirmingFiles = false
    var message: String?

    func totalSizeDescription(of files: [ProcessedFile]) -> String {
        guard !files.isEmpty else { return "None" }
        let bytes = files.reduce(0) { $0 + $1.byteSize }
        return "\(files.count) file\(files.count == 1 ? "" : "s") · \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))"
    }

    /// Clears the Recent list on Home. Files themselves are untouched.
    func clearRecentHistory(in context: ModelContext) {
        do {
            let items = try context.fetch(FetchDescriptor<RecentItem>())
            for item in items {
                context.delete(item)
            }
            try context.save()
            message = "Recent history cleared."
        } catch {
            message = "Couldn't clear your recent history. Please try again."
        }
    }

    /// Deletes every file Toolbox created (and its record). A file that
    /// can't be removed keeps its record, so nothing is left untracked.
    func clearGeneratedFiles(_ files: [ProcessedFile], in context: ModelContext) {
        var removed = 0
        var failed = 0
        let recents = (try? context.fetch(FetchDescriptor<RecentItem>())) ?? []
        for file in files {
            do {
                try FileService.deleteFromDisk(file)
                removed += 1
            } catch {
                failed += 1
            }

            let filename = file.filename
            let baseName = FileService.baseName(of: file)
            for recent in recents {
                let matchesID = recent.fileID == file.id
                let matchesPath = recent.relativePath == file.relativePath || recent.relativePath == filename
                let matchesSummary = recent.summary.contains(filename) ||
                                     (!baseName.isEmpty && recent.summary.contains(baseName))
                if matchesID || matchesPath || matchesSummary {
                    context.delete(recent)
                }
            }
            context.delete(file)
        }
        try? context.save()

        if failed == 0 {
            message = removed == 1 ? "1 file deleted." : "\(removed) files deleted."
        } else {
            message = "\(removed) deleted. \(failed) couldn't be removed. Please try again."
        }
    }
}
