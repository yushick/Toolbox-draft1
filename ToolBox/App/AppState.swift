import SwiftUI
import Observation

/// App-wide, lightweight UI state (selected tab, presented tool, etc).
/// Deliberately does not hold business logic — that lives in each
/// feature's Service/ViewModel.
@Observable
final class AppState {
    enum Tab: Hashable { case home, files, settings }

    var selectedTab: Tab = .home
    var presentedTool: Tool? = nil

    /// A file imported on Home that the presented tool should start with.
    var importedMedia: ImportedMedia? = nil

    func present(_ tool: Tool) {
        importedMedia = nil
        presentedTool = tool
    }

    func present(_ tool: Tool, with media: ImportedMedia) {
        importedMedia = media
        presentedTool = tool
    }
}
