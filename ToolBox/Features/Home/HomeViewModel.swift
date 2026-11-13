import Foundation
import SwiftData
import Observation

@Observable
final class HomeViewModel {
    var searchText: String = ""

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
}
