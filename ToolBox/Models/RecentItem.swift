import Foundation
import SwiftData

/// A lightweight, local-only record of recent activity
/// ("PDF compressed 2 minutes ago"). No analytics, no network.
@Model
final class RecentItem {
    var id: UUID
    var toolID: String
    var summary: String        // e.g. "PDF compressed"
    var timestamp: Date

    init(toolID: ToolID, summary: String, timestamp: Date = .now) {
        self.id = UUID()
        self.toolID = toolID.rawValue
        self.summary = summary
        self.timestamp = timestamp
    }
}
