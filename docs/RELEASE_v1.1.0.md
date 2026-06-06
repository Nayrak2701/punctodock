# PunctoDock 1.1.0

Paste-ready body for the GitHub Release. Build the artifact with `./build_release.sh`,
then attach `dist/PunctoDock.zip`.

---

**Requires macOS 26 or later.**

### New
- 🧭 **Menu bar icon** (toggle in Settings → *Show menu bar icon*). Click to open the panel; right-click for Settings / Quit.
- 🖼️ **Reveal images in Finder** — right-click any image in the Clipboard tab.
- 📎 **Broader image support** — PNG, TIFF, JPEG, GIF, HEIC/HEIF, BMP, WebP, plus image files copied in Finder.

### Changed
- ⌨️ **Default shortcut is now ⌥V (Option+V)** instead of F7. Existing custom shortcuts are kept.
- ⚡ **More reliable pasting** into slow apps (WhatsApp, Slack, Discord, VS Code) — the clipboard is now restored only after the target has read the pasted content. See [paste compatibility](PASTE_COMPATIBILITY.md).
- 🌐 App and repository are now fully in English.

### Install
1. Download `PunctoDock.zip` below and unzip it.
2. Move `PunctoDock.app` to **Applications**.
3. **Right-click → Open** the first time (it's not from the App Store), then click **Open**.
4. Grant **Accessibility** when asked (Settings → Open Accessibility settings…).

---

## Note on Gatekeeper / notarization

This build is **self-signed**, so macOS Gatekeeper shows a warning on first launch
(hence the right-click → Open step). This is expected and safe for a local/open-source
tool.

To make downloads open with a normal double-click (no warning), the app would need to be
signed with an **Apple Developer ID** certificate and **notarized** by Apple. That
requires a paid Apple Developer account ($99/yr). If you decide to go that route later:

```bash
# after building dist/PunctoDock.app with a Developer ID identity:
xcrun notarytool submit dist/PunctoDock.zip --apple-id <id> --team-id <team> --password <app-specific-pw> --wait
xcrun stapler staple dist/PunctoDock.app
```

Until then, the right-click → Open instructions in the README cover first launch.
