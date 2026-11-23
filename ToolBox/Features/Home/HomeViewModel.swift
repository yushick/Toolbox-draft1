import Foundation
import SwiftData
import Observation
import UIKit

@MainActor
@Observable
final class HomeViewModel {
    var searchText: String = ""

    // MARK: - Staged File Workspace
    var stagedMedia: ImportedMedia? = nil
    var stagedThumbnail: UIImage? = nil
    var stagedTitle: String = ""
    var stagedDetail: String = ""
    var isLoadingStaged: Bool = false
    var isImporting: Bool = false
    var importAlert: String? = nil

    var searchResults: [Tool] {
        Tool.search(searchText)
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    var primaryTools: [Tool] { Tool.all.filter(\.isPrimary) }

    func tools(in category: ToolCategory) -> [Tool] {
        Tool.all.filter { $0.category == category && !$0.isPrimary }
    }

    /// Small, deterministic greeting — no network, no personalization
    /// beyond the device clock.
    var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Staging Actions

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
