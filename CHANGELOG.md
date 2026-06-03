# Changelog

All notable changes to PunctoDock are documented here.

## [1.0.0] — 2026-06-03

**Requires macOS 26 or later.**

### First public release

**Core features**
- Floating symbol panel triggered by F7 (or custom hotkey / middle-click double-press)
- Compact 3×4 grid of frequently-used punctuation; expandable to full catalog
- Direct insertion into the active app via synthetic ⌘V (requires Accessibility permission)
- Graceful fallback: places character in clipboard when Accessibility is not granted
- Pair insertion (brackets, quotes) with automatic cursor positioning between the pair

**Clipboard**
- Clipboard history monitor — recent copies visible and pasteable from the panel
- Pinned entries survive history resets

**Settings**
- Customisable hotkey (key recorder in Settings)
- Optional middle-mouse double-click trigger
- Usage-frequency sorting for the compact grid
- Login item via SMAppService (macOS 13+)
- One-click link to Accessibility settings with live status indicator

**Technical**
- Background accessory app — no Dock icon, no menu bar item
- No third-party dependencies
- Local storage only: `~/Library/Application Support/com.punctodock.app/`
- `setup_signing.sh` for stable self-signed identity (keeps Accessibility across rebuilds)
- Deterministic xcodeproj generator (`generate_xcodeproj.py`)
