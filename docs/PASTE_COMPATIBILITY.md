# Paste compatibility

PunctoDock inserts characters and clipboard entries by **synthesising a paste** into
whatever app owns the text caret. This page explains how that works, which apps are
known to be tricky, and a self-test you can run in a couple of minutes.

## How insertion works

When you pick an item in the panel, PunctoDock:

1. Remembers the app that was frontmost when you opened the panel (the *target*).
2. Takes a snapshot of your current clipboard.
3. Writes the chosen content (text or image) to the clipboard.
4. Brings the target app forward and waits a short *settle* delay so its text field
   regains focus.
5. Posts a synthetic **⌘V** (Cmd+V) via a `CGEvent`.
6. Optionally moves the caret (for bracket/quote pairs).
7. Restores your original clipboard.

This relies only on the standard **Paste** command, which virtually every text surface
implements — that is why it works in native apps, browsers, and Office without any
per-app integration.

> Inserting into another app needs the **Accessibility** permission (to post the
> keystroke). Without it, PunctoDock falls back to leaving the content on your
> clipboard so you can paste manually.

## Timing (why some apps were flaky)

The single most common failure on macOS for tools like this is a **race between the
paste and the clipboard restore**. Some apps don't read the clipboard synchronously
when ⌘V arrives — Mac Catalyst and Electron/Chromium apps (WhatsApp, Slack, Discord,
VS Code) often read it a beat later, on the next run-loop or across a process hop.

If the original clipboard is restored *before* the target finishes reading, the target
pastes the **old** clipboard (or nothing, if it was empty). The symptom is "paste does
nothing" or "paste inserts the wrong thing" — intermittently, and only in certain apps.

PunctoDock uses a single hardened paste path (`InsertionManager.performPaste`) with
deliberately generous timing:

| Phase | Delay | Why |
|---|---|---|
| Settle after `activate()` (target app) | 80 ms | Let the field regain first-responder focus |
| Settle (no specific target) | 30 ms | Faster path when we paste into ourselves |
| After ⌘V, before caret move | 60 ms | Let the paste land |
| Before restoring the clipboard | 180 ms | **Outlast slow/async pasteboard reads** |

These are tuned to stay imperceptible in fast apps while giving slow apps enough head
room. If you still see misses in a specific app, the delays are all in one place
(`PunctoDock/Insertion/InsertionManager.swift`, `enum Timing`) and easy to raise.

## Self-test matrix

Open a text field in each app, press your trigger (default **⌥V**), pick a symbol
(e.g. `@`), and confirm it appears at the caret. Then pick a clipboard entry and confirm
that, too. Finally confirm your real clipboard is unchanged (⌘V pastes what you had
before).

| App | Type | Text insert | Clipboard insert | Notes |
|---|---|:---:|:---:|---|
| TextEdit | Native AppKit | | | Baseline |
| Notes | Native | | | |
| Messages | Native | | | |
| Mail (compose) | Native | | | |
| Safari (address bar / form) | Browser | | | |
| Pages / Word | Office | | | |
| WhatsApp | Mac Catalyst | | | Async pasteboard read — the main reason for the 180 ms restore delay |
| Slack | Electron | | | |
| Discord | Electron | | | |
| VS Code | Electron | | | |
| Terminal | Native | | | Some shells need bracketed-paste; ⌘V still works |

Tip: a quick way to confirm an image re-pastes is to copy a screenshot, open the panel,
pick it from the Clipboard tab, and paste into Notes or a Mail draft.

## Known limitations

- **Password fields** may ignore synthetic paste by design — the content lands on your
  clipboard as a fallback.
- **Auto-completing brackets** in some editors can produce a double bracket; PunctoDock
  still inserts the pair correctly.
- If an app is unusually slow to focus, raise `Timing.settleWithTarget`.
