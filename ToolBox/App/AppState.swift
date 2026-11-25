import SwiftUI
import Observation
import UIKit

/// App-wide UI and shared staged-media state so Home, Tools, and sheets stay in sync.
@MainActor
@Observable
final class AppState {
    enum Tab: Hashable { case home, tools, files, quickActions }

    var selectedTab: Tab = .home
    var presentedTool: Tool? = nil

    /// A file imported on Home that the presented tool should start with.
    var importedMedia: ImportedMedia? = nil

    // MARK: - Shared Staged File Workspace

    var stagedMedia: ImportedMedia? = nil
    var stagedThumbnail: UIImage? = nil
    var stagedTitle: String = ""
    var stagedDetail: String = ""
    var isLoadingStaged: Bool = false

    func present(_ tool: Tool) {
        importedMedia = nil
        presentedTool = tool
    }

    func present(_ tool: Tool, with media: ImportedMedia) {
        importedMedia = media
        presentedTool = tool
    }

    func stageMedia(_ media: ImportedMedia) {
        if let previous = stagedMedia, previous.id != media.id {
            ImportService.discard(previous)
        }
        stagedMedia = media
        stagedThumbnail = nil
        let initial = ImportService.initialSummary(for: media)
        stagedTitle = initial.title
        stagedDetail = initial.detail
        isLoadingStaged = true

        Task {
            async let thumb = ImportService.previewImage(for: media)
            async let sum = ImportService.summary(for: media)
            let (thumbnail, summary) = await (thumb, sum)
            guard stagedMedia?.id == media.id else { return }
            self.stagedThumbnail = thumbnail
            self.stagedTitle = summary.title
            self.stagedDetail = summary.detail
            self.isLoadingStaged = false
        }
    }

    func clearStaged() {
        if let media = stagedMedia {
            ImportService.discard(media)
        }
        stagedMedia = nil
        stagedThumbnail = nil
        stagedTitle = ""
        stagedDetail = ""
        isLoadingStaged = false
    }
}
