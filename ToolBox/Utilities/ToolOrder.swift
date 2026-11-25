import Foundation

/// The user's custom order of the tool cards on Home, saved as a
/// comma-separated list of tool IDs. Tools missing from the saved list
/// (for example, ones added in a later version) keep their default position.
enum ToolOrder {
    static let storageKey = "toolOrder"

    static func ids(from raw: String) -> [ToolID] {
        raw.split(separator: ",").compactMap { ToolID(rawValue: String($0)) }
    }

    static func raw(from ids: [ToolID]) -> String {
        ids.map(\.rawValue).joined(separator: ",")
    }

    /// Tools sorted by the saved order. Unknown/unsaved tools go last, in default order.
    static func sorted(_ tools: [Tool], raw: String) -> [Tool] {
        let saved = ids(from: raw)
        func rank(_ tool: Tool) -> Int { saved.firstIndex(of: tool.id) ?? Int.max }
        return tools.enumerated()
            .sorted { lhs, rhs in
                let l = rank(lhs.element), r = rank(rhs.element)
                return l == r ? lhs.offset < rhs.offset : l < r
            }
            .map(\.element)
    }

    /// Moves `dragged` into the position currently held by `target`.
    static func moving(_ dragged: ToolID, onto target: ToolID, raw: String) -> String {
        var order = sorted(Tool.all, raw: raw).map(\.id)
        guard dragged != target,
              let from = order.firstIndex(of: dragged),
              let to = order.firstIndex(of: target) else { return raw }
        order.remove(at: from)
        order.insert(dragged, at: to)
        return Self.raw(from: order)
    }
}
