# GitHub Upload Checklist — PunctoDock

> This file is for the project owner. Not intended for public repo — gitignore it if you prefer.
> Last updated: 2026-06-03

---

## Before pushing to GitHub

### Repo files — STATUS

| File | Status |
|---|---|
| `.gitignore` | ✅ Done |
| `LICENSE` | ✅ MIT |
| `README.md` | ✅ English, GitHub-ready |
| `CHANGELOG.md` | ✅ v1.0.0 entry |
| `setup_signing.sh` | ✅ Tracked |
| `generate_xcodeproj.py` | ✅ Fixed, tracked |
| `PunctoDock/Resources/Assets.xcassets` | ✅ Tracked (app icons) |
| `.github/ISSUE_TEMPLATE/` | ✅ Bug + Feature templates |
| `PROJEKT_DOKUMENTATION.md` | ✅ Gitignored (contains local paths) |
| `xcuserdata/` | ✅ Removed from tracking |

### What to check before `git push`

- [ ] Replace `YOUR_USERNAME` in README.md download link with your actual GitHub username
- [ ] Replace `../../releases` in README.md with the actual repo URL, or leave as relative (works on GitHub)
- [ ] Decide on copyright name in LICENSE (`PunctoDock Contributors` is fine as-is, or change to your name)
- [ ] Optional: add a screenshot or short GIF to README (see section below)

---

## Creating a GitHub Release (v1.0.0)

### Step 1 — Build the release binary

In Xcode:
1. Select **Product → Destination → My Mac**
2. Select **Product → Archive**
3. In the Organizer: **Distribute App → Copy App**
4. Save `PunctoDock.app` to your Desktop

### Step 2 — Create the ZIP

```bash
cd ~/Desktop
ditto -c -k --keepParent PunctoDock.app PunctoDock-1.0.0.zip
```

### Step 3 — Verify the app before releasing

```bash
# Check that it's signed
codesign -dv --verbose=4 PunctoDock.app

# Check for quarantine (should be absent in your own build)
xattr -l PunctoDock.app | grep quarantine
```

### Step 4 — Push to GitHub

```bash
cd "/Users/aryanmacminim4/Documents/Claude Code/Puncto-dock"
git remote add origin https://github.com/YOUR_USERNAME/punctodock.git
git push -u origin main
```

### Step 5 — Create GitHub Release

1. Go to your repo → **Releases → Create a new release**
2. Tag: `v1.0.0`
3. Release title: `PunctoDock 1.0.0`
4. Description: copy from CHANGELOG.md
5. Attach: `PunctoDock-1.0.0.zip`
6. Publish

---

## Screenshot / Demo (recommended but not blocking)

A single screenshot of the floating panel open in front of a text editor dramatically increases adoption for non-technical users. Ideal specs:
- 800-1200px wide
- Shows panel open near a text cursor in a recognisable app (e.g. Notes, TextEdit)
- Include both Symbols and Clipboard tabs if possible, or two separate screenshots
- Filename: `screenshot-panel.png`
- Add to repo at `/docs/screenshot-panel.png` and reference in README

---

## Known risks at GitHub launch

| Risk | Mitigation |
|---|---|
| Gatekeeper blocks first open | README explains right-click → Open clearly |
| Accessibility permission confuses users | Settings window explains it with one-click link |
| Users don't find Settings after first launch | README explains: click the app icon in Applications |
| TCC revoked after Xcode rebuild (devs only) | setup_signing.sh solves this; documented in README |
| Missing F7 on some keyboards | README and Settings mention fallback shortcut recording |

---

## Remaining open items (post-launch)

- [ ] Add English UI option (currently German-only)
- [ ] Add screenshot to README
- [ ] Code-sign with Apple Developer ID (removes Gatekeeper friction permanently)
- [ ] Notarize the app (best UX for end users, no right-click workaround needed)
- [ ] Add VoiceOver labels to panel tiles
- [ ] Consider adding a status bar menu item as optional visible presence
