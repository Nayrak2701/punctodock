# PunctoDock

**A tiny macOS utility that puts punctuation, symbols, and clipboard history one keystroke away.**

Press **F7** (or your custom shortcut) from any app → a small floating panel appears near your cursor → click a character → it lands exactly where your text cursor is, no copy-paste needed.

> App UI language: German. macOS 13 Ventura or later required.

---

## What it does

The panel has three tabs:

| Tab | Contents |
|---|---|
| **Clipboard** | Your recent clipboard history — click any entry to paste it |
| **Symbole** | Punctuation, special characters, brackets, arrows, and more |
| **Emoji** | Searchable emoji catalog |

- **Direct insertion** — selected item goes into whatever app is in front, no manual ⌘V needed
- **Frequency sorting** — the symbols you use most often move to the front automatically
- **Pair insertion** — brackets and quotes insert as pairs with the cursor positioned in between
- **Runs silently** — no Dock icon, no menu bar clutter; press the trigger, use the panel, done
- **100% local** — no cloud, no telemetry, no account

---

## Requirements

| | |
|---|---|
| **macOS** | 13 Ventura or later |
| **Architecture** | Apple Silicon and Intel |
| **Permissions** | Accessibility (Bedienungshilfen) — to insert into other apps |

---

## Installation

### Option A — Download (recommended for most users)

1. Go to [Releases](../../releases) and download the latest `PunctoDock.zip`
2. Unzip it — you get `PunctoDock.app`
3. Move `PunctoDock.app` to your **Applications** folder
4. Double-click to launch

> **macOS Gatekeeper note:** Because PunctoDock is not distributed through the Mac App Store, macOS may show a warning the first time you try to open it.
>
> **How to open it anyway:**
> 1. Do **not** double-click (that shows the warning but offers no way to proceed)
> 2. Instead: **right-click** the app → **Open** → click **Open** in the dialog that appears
> 3. You only have to do this once

### Option B — Build from source

Requirements: Xcode 15 or later, macOS 13+ SDK.

```bash
git clone https://github.com/YOUR_USERNAME/punctodock.git
cd punctodock
python3 generate_xcodeproj.py   # regenerates PunctoDock.xcodeproj
```

Then open `PunctoDock.xcodeproj` in Xcode and press **⌘R**.

The `xcodeproj` is already included in the repo — `generate_xcodeproj.py` is only needed if you want to regenerate it from scratch.

---

## First launch: Accessibility permission

PunctoDock inserts characters by simulating a paste keystroke (⌘V) into the active app. macOS requires an explicit **Accessibility** permission for this.

**You will be asked once, right after the first launch.**

To approve it:

1. Click **"In den Systemeinstellungen freigeben…"** in PunctoDock's Settings window
2. System Settings opens at **Privacy & Security → Accessibility**
3. Find **PunctoDock** in the list and turn the toggle **on**
4. Come back to PunctoDock — the status shows a green checkmark

That's it. The permission is permanent; you won't be asked again unless you reinstall or move the app.

> **Without this permission**, PunctoDock still works — the chosen character is placed in your clipboard (you paste manually with ⌘V). The status indicator in Settings shows red when the permission is missing.

---

## How to use

| Action | What happens |
|---|---|
| Press **F7** | Floating panel opens near your cursor |
| Click a character | Inserted into the active app, panel closes |
| Press **Escape** | Panel closes without inserting |
| Arrow keys + Enter | Navigate and confirm selection by keyboard |
| Click the **…** button | Expand to the full character catalog |
| Click the app icon (in Applications) | Open Settings |

### Customising the trigger

Open Settings (click the app icon) → **Trigger** section:
- Record any key combination as your custom shortcut
- Or enable **Mausrad-Doppelklick** (middle-mouse double-click) as a secondary trigger

---

## Settings overview

| Setting | What it does |
|---|---|
| Tastatur-Trigger aktiv | Enable/disable the keyboard shortcut |
| Tastenkürzel | Record a custom hotkey (default: F7) |
| Mausrad-Doppelklick | Use middle-click double-press as trigger |
| Beim Anmelden starten | Auto-launch at login (background, silent) |
| Häufig genutzte Zeichen zuerst | Sort compact grid by usage frequency |
| Nutzungsverlauf zurücksetzen | Clear the frequency counter |
| Zwischenablage-Verlauf zurücksetzen | Clear clipboard history |
| Berechtigung | Accessibility status + link to System Settings |

---

## Privacy

- **What is stored:** your trigger/hotkey preference, a usage counter per symbol (e.g. `{"?": 12, ".": 30}`), and clipboard history (local, no cloud sync)
- **What is never stored:** text from other apps, app names, identity information
- **Where:** `~/Library/Application Support/com.punctodock.app/`
- **To delete everything:** quit PunctoDock, then delete that folder

---

## Known limitations

- **F7 as media key** — on some keyboards F7 is a media/brightness key without Fn. If the hotkey doesn't fire, record a different shortcut in Settings.
- **Accessibility must be re-granted after reinstall or moving the app** — this is a macOS security requirement, not a bug.
- **Some password fields ignore synthetic paste** — by design on the app side; the character lands in your clipboard as a fallback.
- **Auto-completing brackets in some apps** may produce a double bracket — PunctoDock still inserts the pair correctly.

---

## Build architecture notes (for contributors)

```
PunctoDock/
├── App/            AppDelegate + AppState (single source of truth)
├── Panel/          Floating non-activating NSPanel + SwiftUI content
├── Triggers/       Global hotkey (Carbon) + mouse monitor
├── Insertion/      Clipboard save → set → ⌘V → restore
├── Permissions/    AXIsProcessTrusted wrapper
├── LoginItem/      SMAppService (macOS 13+)
├── Model/          Settings, clipboard history, symbol catalog, persistence
└── Resources/      Info.plist, entitlements, app icon
```

No third-party dependencies. Pure Swift + AppKit + SwiftUI + Carbon.

**Accessibility/TCC stability for developers:**  
Every new Xcode build changes the app's code hash, which causes macOS to revoke and re-ask for Accessibility. Run `setup_signing.sh` once to create a stable self-signed identity — after that, rebuilds keep the existing permission. See the script for details.

---

## Contributing

Bug reports and pull requests welcome. Please open an issue first for larger changes.

---

## License

MIT — see [LICENSE](LICENSE).
