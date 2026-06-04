# Roadmap

Possible next features, prioritized by **impact ÷ effort** and filtered through
PunctoDock's two guiding principles: **stay 100% local/private** and **don't make the
panel slower or paste less reliable**.

Grounded in what mature macOS clipboard/symbol tools offer (Maccy, Paste, Raycast,
CleanClip, CopyClip, PopClip) — see [Sources](#sources). PunctoDock deliberately stays
small, so this list is about the highest-leverage additions, not feature parity.

## Already shipped (1.1.0)
Menu bar toggle · Reveal images in Finder · broad image formats · ⌥V default ·
hardened paste · **respects concealed/transient pasteboard markers** (passwords from
password managers are never recorded).

## Tier 1 — do next (high impact, low/medium effort)

1. **Search / filter in the Clipboard tab.** With 50 entries, a top search field
   (live filter by text, and by type: text vs image) is the single biggest usability
   win. *Effort: M.*
2. **Keyboard navigation for clipboard + type-to-search.** Arrows/Enter currently work
   only on the Symbols tab. Extend to clipboard entries and let typing filter. Big
   accessibility + speed gain. *Effort: M.*
3. **User-configurable app exclusion.** Beyond the concealed-type markers we already
   honour, let users add apps whose copies should never be recorded (e.g. banking).
   Capture the source app at copy time and check a blocklist. *Effort: M. Privacy win.*
4. **Paste as plain text (toggle / modifier).** Force plain-text insertion for rich
   captures (hold ⌥ while selecting, or a setting). Text entries are already plain;
   this covers future rich captures. *Effort: S.*

## Tier 2 — strong, medium effort

5. **Snippets** — user-defined reusable text (canned replies, email/code templates) as
   a fourth tab or an editable section, insertable like symbols. Pinned clipboard
   entries are a partial stand-in today; editable named snippets are the upgrade.
   *Effort: M–L.*
6. **Editable symbol catalog.** Let users add/remove characters and snippet "pairs"
   instead of the fixed `SymbolCatalog`. *Effort: M.*
7. **Per-entry quick actions.** Copy-without-pasting, open-URL for link entries,
   save-image-as. (Reveal in Finder already exists.) *Effort: S–M.*
8. **Configurable history size & auto-expiry.** Expose `maxEntries` and an optional
   "forget after N days" (keeps pins). *Effort: S.*

## Tier 3 — nice to have / later

9. **Rich previews** — detect URLs and hex colors; show a color swatch / favicon.
   *Effort: M.*
10. **Appearance & positioning prefs** — fixed panel position, accent color. *Effort: S–M.*
11. **In-panel emoji search** — currently delegates to the system palette. *Effort: M.*

## Explicitly out of scope (for now)

- **iCloud / cross-device sync** (Paste's headline feature). It directly conflicts with
  the "100% local, no cloud, no account" promise. Only worth it as a clearly-labeled,
  off-by-default opt-in, and it's a large amount of work (CloudKit, conflict handling,
  encryption). Low priority.
- **Team/shared pinboards** — not aligned with a personal, local utility.

## Suggested order

`1 → 2` together (they share the clipboard-tab UI work) → `3` (privacy) → `4` (cheap
win) → `5` (snippets) → the rest as interest dictates.

## Sources
- [Paste alternatives — 7 best clipboard managers (2026)](https://www.onetapapp.co/OneTap-blog-posts/paste-app-alternatives-7-best-clipboard-managers-for-mac-in-2026)
- [Clipboard manager comparison, every option ranked (2026)](https://quietclip.app/blog/clipboard-manager-comparison/)
- [15 best Mac clipboard manager apps — CleanClip](https://cleanclip.cc/gb/articles/15-best-mac-clipboard-manager-apps-comparison-and-features)
- [Our favorite clipboard managers for Mac — TheSweetBits](https://thesweetbits.com/best-clipboard-manager-mac/)
- [nspasteboard.com](http://nspasteboard.com) — the concealed/transient marker convention
