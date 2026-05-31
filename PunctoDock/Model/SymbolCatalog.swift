import Foundation

/// A single insertable item: one character, a paired delimiter, or a small snippet.
struct Symbol: Identifiable, Equatable {
    enum Kind { case single, pair, snippet }

    let id: String          // stable id == the inserted text
    let insert: String      // text written to the pasteboard
    let label: String       // what the button shows
    let kind: Kind
    /// Number of Left-Arrow presses to apply after paste, to place the caret
    /// between a pair (e.g. "()" -> caret in the middle).
    let caretBackSteps: Int

    init(_ insert: String, label: String? = nil, kind: Kind = .single, caretBackSteps: Int = 0) {
        self.id = insert
        self.insert = insert
        self.label = label ?? insert
        self.kind = kind
        self.caretBackSteps = caretBackSteps
    }
}

/// Curated, practical character set. Deliberately NOT a giant Unicode lexicon:
/// everyday punctuation, common writing marks, standard specials and currency.
enum SymbolCatalog {
    /// Default order for the compact 3×4 grid (first 11 slots; the 12th is always "More").
    static let compactDefaults: [String] = ["?", "!", ".", ",", ":", ";", "(", ")", "@", "&", "€"]

    /// Single characters for the expanded view.
    static let singles: [Symbol] = [
        // Punctuation
        Symbol("."), Symbol(","), Symbol(";"), Symbol(":"), Symbol("!"), Symbol("?"),
        Symbol("…"),
        // Brackets (also offered as single chars)
        Symbol("("), Symbol(")"), Symbol("["), Symbol("]"), Symbol("{"), Symbol("}"),
        Symbol("<"), Symbol(">"),
        // Quotes
        Symbol("\""), Symbol("'"),
        Symbol("„"), Symbol("“"), Symbol("”"),
        Symbol("‚"), Symbol("‘"), Symbol("’"),
        Symbol("«"), Symbol("»"), Symbol("‹"), Symbol("›"),
        // Dashes / slashes / underscore / pipe
        Symbol("-"), Symbol("–"), Symbol("—"), Symbol("_"),
        Symbol("/"), Symbol("\\"), Symbol("|"),
        // Common specials
        Symbol("@"), Symbol("#"), Symbol("&"), Symbol("%"), Symbol("+"), Symbol("="),
        Symbol("*"), Symbol("~"),
        Symbol("§"), Symbol("¶"), Symbol("°"),
        // Currency
        Symbol("€"), Symbol("$"), Symbol("£"), Symbol("¥")
    ]

    /// Pairs (caret placed between) and small snippets (inserted as-is).
    static let pairs: [Symbol] = [
        Symbol("()", label: "( )", kind: .pair, caretBackSteps: 1),
        Symbol("[]", label: "[ ]", kind: .pair, caretBackSteps: 1),
        Symbol("{}", label: "{ }", kind: .pair, caretBackSteps: 1),
        Symbol("<>", label: "< >", kind: .pair, caretBackSteps: 1),
        Symbol("„“", label: "„ “", kind: .pair, caretBackSteps: 1),
        Symbol("\"\"", label: "\" \"", kind: .pair, caretBackSteps: 1),
        Symbol("''", label: "' '", kind: .pair, caretBackSteps: 1),
        Symbol("«»", label: "« »", kind: .pair, caretBackSteps: 1),
        Symbol("‹›", label: "‹ ›", kind: .pair, caretBackSteps: 1),
        Symbol("…", label: "…", kind: .snippet),
        Symbol("--", label: "--", kind: .snippet),
        Symbol("–", label: "–", kind: .snippet),
        Symbol("—", label: "—", kind: .snippet)
    ]

    /// Resolve a compact-grid slot (stored as plain text) to a full Symbol.
    static func symbol(for insert: String) -> Symbol {
        (singles + pairs).first { $0.insert == insert } ?? Symbol(insert)
    }
}
