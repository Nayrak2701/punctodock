import Foundation

/// Tracks how often each single character is inserted, so the compact grid can
/// prioritise the user's most-used characters. Only single characters are counted —
/// pairs and snippets never appear in the compact view, so they are not tracked here.
struct UsageHistory: Codable {
    private(set) var counts: [String: Int]

    init(counts: [String: Int] = [:]) { self.counts = counts }

    mutating func record(_ insert: String) {
        guard SymbolCatalog.singles.contains(where: { $0.insert == insert }) else { return }
        counts[insert, default: 0] += 1
    }

    /// The 11 single characters for the compact grid, most-used first, then the
    /// spec's default order fills any remaining slots. Stable tie-breaking by
    /// character keeps the layout from jumping around between equal counts.
    func compactSlots(limit: Int = 11) -> [String] {
        let usedOrder = counts
            .filter { entry in entry.value > 0 && SymbolCatalog.singles.contains { $0.insert == entry.key } }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .map { $0.key }

        var ordered: [String] = []
        for key in usedOrder where !ordered.contains(key) {
            ordered.append(key)
            if ordered.count == limit { return ordered }
        }
        for key in SymbolCatalog.compactDefaults where !ordered.contains(key) {
            ordered.append(key)
            if ordered.count == limit { break }
        }
        return ordered
    }
}
