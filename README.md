<p align="center">
  <img src="docs/marketing/hero.png" width="820" alt="PunctoDock — punctuation, symbols & clipboard, one keystroke away">
</p>

# PunctoDock

**A tiny macOS utility that puts punctuation, symbols, and clipboard history one keystroke away.**

Press **⌥V** (Option+V — or your custom shortcut) from any app → a small floating panel appears near your cursor → click a character → it lands exactly where your text cursor is, no copy-paste needed.

<p align="center">
  <img src="docs/screenshot-panel.png" width="420" alt="PunctoDock panel — Clipboard tab">
</p>

<p align="center">
  <img src="docs/marketing/features.png" width="820" alt="Why PunctoDock — insert anywhere, clipboard history, 100% local">
</p>

> **Requires macOS 26 or later** (uses the Liquid Glass UI).

---

## What it does

The panel has three tabs:

| Tab | Contents |
|---|---|
| **Clipboard** | Your recent clipboard history — click any entry to paste it |
| **Symbols** | Punctuation, special characters, brackets, arrows, and more |
| **Emoji** | The system emoji catalog |

- **Direct insertion** — the selected item goes into whatever app is in front, no manual ⌘V needed
- **Frequency sorting** — the symbols you use most move to the front automatically
- **Pair insertion** — brackets and quotes insert as pairs with the cursor positioned between them
- **Clipboard history** — text and images; pin the entries you want to keep
- **Reveal images in Finder** — any image entry can be exported and shown in Finder
- **Broad image support** — PNG, TIFF, PDF, JPEG, GIF, HEIC/HEIF, BMP, WebP, plus image files copied in Finder
- **Menu bar icon** — optional; click to open the panel, right-click for a quick menu
- **100% local** — no cloud, no telemetry, no account

---

## Requirements

| | |
|---|---|
| **macOS** | 26 or later |
| **Architecture** | Apple Silicon and Intel |
| **Permissions** | Accessibility — to insert into other apps |

---

## Installation

### Option A — Download (recommended for most users)

1. Go to [Releases](../../releases) and download the latest `PunctoDock.zip`
2. Unzip it — you get `PunctoDock.app`
3. Move `PunctoDock.app` to your **Applications** folder
4. Double-click to launch

> **macOS Gatekeeper note:** Because PunctoDock is not distributed through the Mac App Store, macOS may show a warning the first time you open it.
>
> **How to open it anyway:**
> 1. Do **not** double-click (that shows the warning but offers no way to proceed)
> 2. Instead: **right-click** the app → **Open** → click **Open** in the dialog that appears
> 3. You only have to do this once

### Option B — Build from source

Requirements: Xcode 26 or later (the project targets macOS 26).

```bash
git clone https://github.com/Nayrak2701/punctodock.git
cd punctodock
./setup_signing.sh             # one-time: stable self-signed identity (keeps Accessibility across rebuilds)
python3 generate_xcodeproj.py  # regenerates PunctoDock.xcodeproj
```

Then open `PunctoDock.xcodeproj` in Xcode and press **⌘R**.

The `xcodeproj` is already included in the repo — `generate_xcodeproj.py` is only needed if you want to regenerate it from scratch.

---

## First launch: Accessibility permission

PunctoDock inserts characters by simulating a paste keystroke (⌘V) into the active app. macOS requires an explicit **Accessibility** permission for this.

**You will be asked once, right after the first launch.**

To approve it:

1. Click **"Open Accessibility settings…"** in PunctoDock's Settings window
2. System Settings opens at **Privacy & Security → Accessibility**
3. Find **PunctoDock** in the list and turn the toggle **on**
4. Come back to PunctoDock — the status shows a green checkmark

That's it. The permission is permanent; you won't be asked again unless you reinstall or move the app.

> **Without this permission**, PunctoDock still works — the chosen character is placed on your clipboard (you paste manually with ⌘V). The status indicator in Settings shows red when the permission is missing.

---

## How to use

| Action | What happens |
|---|---|
| Press **⌥V** | Floating panel opens near your cursor |
| Click a character | Inserted into the active app, panel closes |
| Press **Escape** | Panel closes without inserting |
| Arrow keys + Enter | Navigate and confirm a selection by keyboard (Symbols tab) |
| Right-click a clipboard entry | Pin, delete, clear, or (for images) reveal in Finder |
| Click the menu bar icon | Opens the panel; right-click for Settings / Quit |
| Click the app icon (in Applications) | Opens Settings |

### Customising the trigger

Open Settings → **Trigger** section:
- Record any key combination as your custom shortcut
- Or enable **middle-click double-press** as a secondary trigger

See [docs/PASTE_COMPATIBILITY.md](docs/PASTE_COMPATIBILITY.md) for how insertion works and a per-app test matrix.

---

## Settings overview

| Setting | What it does |
|---|---|
| Keyboard trigger | Enable/disable the keyboard shortcut |
| Shortcut | Record a custom hotkey (default: ⌥V) |
| Middle-click double-press | Use a middle-click double-press as trigger |
| Start at login | Auto-launch at login (background, silent) |
| Most-used characters first | Sort the compact grid by usage frequency |
| Reset usage history | Clear the frequency counter |
| Keep pinned entries when clearing | Preserve pins when clearing clipboard history |
| Clear history | Clear clipboard history |
| Show menu bar icon | Show/hide the menu bar item |
| Permission | Accessibility status + link to System Settings |

---

## Privacy

- **What is stored:** your trigger/hotkey preference, a usage counter per symbol (e.g. `{"?": 12, ".": 30}`), and clipboard history (local, no cloud sync)
- **What is never stored:** text from other apps, app names, identity information
- **Where:** `~/Library/Application Support/com.punctodock.app/`
- **To delete everything:** quit PunctoDock, then delete that folder

---

## Known limitations

- **Accessibility must be re-granted after reinstall or moving the app** — this is a macOS security requirement, not a bug.
- **Some password fields ignore synthetic paste** — by design on the app side; the character lands on your clipboard as a fallback.
- **Auto-completing brackets in some apps** may produce a double bracket — PunctoDock still inserts the pair correctly.

See [docs/PASTE_COMPATIBILITY.md](docs/PASTE_COMPATIBILITY.md) for details and tuning.

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
