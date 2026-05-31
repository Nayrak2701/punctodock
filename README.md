# Puncto-dock

Eine kleine, native macOS-Utility. Auf Trigger (Standard **F7**) öffnet sich nahe
am Mauszeiger ein schwebendes Panel mit Satz- und Sonderzeichen sowie ein paar
Zeichenpaaren/Bausteinen. Das gewählte Zeichen wird in die App eingefügt, in der
gerade dein Textcursor steht.

- Lokal, offline, keine Telemetrie, kein Account, keine Cloud.
- Bundle-ID: `com.punctodock.app`
- Daten zentral unter `~/Library/Application Support/com.punctodock.app/`
- Swift + SwiftUI (UI) + AppKit/Carbon (Systemintegration). Keine Drittanbieter-Pakete.

Status: lauffähiger erster Prototyp. Alle Quelldateien sind per
`swiftc -typecheck` (Swift 5 mode, Ziel macOS 13) fehlerfrei geprüft.

---

## Architektur

Kleine, flache Struktur – eine Datei pro Verantwortung, keine Überschichtung.

```
PunctoDock/
├── App/
│   ├── AppDelegate.swift          @main, Lifecycle, verdrahtet Trigger↔Panel↔Settings
│   └── AppState.swift             Einzige Datenquelle: Settings + Usage (ObservableObject)
├── Settings/
│   ├── SettingsView.swift         SwiftUI-Einstellungen + Hotkey-Recorder + Onboarding-Text
│   └── SettingsWindowController.swift   Verwaltet das eine Einstellungsfenster
├── Panel/
│   ├── FloatingPanel.swift        Borderless, non-activating NSPanel
│   ├── PanelController.swift      Anzeigen/Schließen, Position, Tastatur/Outside-Click
│   ├── PanelView.swift            Kompaktes 3×4-Raster + scrollbare erweiterte Ansicht
│   └── PanelViewModel.swift       UI-Zustand: Modus, Auswahl, Navigation
├── Triggers/
│   ├── TriggerManager.swift       Bündelt Hotkey + Maus, ein onTrigger-Callback
│   ├── HotkeyManager.swift        Globaler Hotkey via Carbon RegisterEventHotKey
│   └── MouseTriggerMonitor.swift  Mausrad-Doppelklick via NSEvent-Monitore
├── Insertion/
│   └── InsertionManager.swift     Clipboard sichern → setzen → ⌘V → Caret → wiederherstellen
├── Permissions/
│   └── PermissionManager.swift    Accessibility-Status + Wege in die Systemeinstellungen
├── LoginItem/
│   └── LoginItemManager.swift     Opt-in Start bei Login via SMAppService
├── Model/
│   ├── SymbolCatalog.swift        Kuratierte Zeichen- und Paarliste
│   ├── AppSettings.swift          Persistierte Einstellungen (Codable)
│   ├── UsageHistory.swift         Häufigkeitszählung der Einzelzeichen
│   ├── KeyCombo.swift             Hotkey-Repräsentation (+ Carbon-Mapping, Anzeigename)
│   └── PersistenceManager.swift   JSON-Lesen/Schreiben in Application Support
└── Resources/
    ├── Info.plist                 LSUIElement, Bundle-ID, Mindest-OS
    └── PunctoDock.entitlements     Sandbox bewusst aus (siehe unten)
```

### Wesentliche Entscheidungen (kurz begründet)

- **App-Modell:** Accessory-App (`LSUIElement` + `.accessory`). Läuft unauffällig im
  Hintergrund ohne Dock-Icon/Menüleiste. Start über das App-Icon öffnet die
  Einstellungen (`applicationShouldHandleReopen`). Keine Menüleisten-Komponente nötig.
- **Floating Panel:** Borderless **non-activating** `NSPanel`. Das ist der Knackpunkt:
  ein `.nonactivatingPanel` kann *key* werden (und damit Pfeiltasten/Enter/Escape
  empfangen), **ohne** unsere App zu aktivieren. Dadurch bleibt die Ziel-App vorn und
  das spätere ⌘V landet dort. Tasten werden über einen lokalen `NSEvent`-Monitor
  abgegriffen (und konsumiert), Auswahl per Maus über normale SwiftUI-Buttons.
- **Hotkey-Technik:** Carbon `RegisterEventHotKey` – die Standard-API für globale
  Shortcuts. Funktioniert ohne Accessibility-Recht und im Hintergrund. Kein
  Drittanbieter-Paket nötig. Default **F7** (`kVK_F7`).
- **Mausrad-Doppelklick:** passiver `NSEvent`-Global/Local-Monitor auf
  `.otherMouseDown`, Button 2; zwei Klicks innerhalb des (geclampten) System-
  Doppelklick-Intervalls. Maus-Monitoring braucht **keine** Accessibility-Freigabe.
- **Accessibility:** wird **nur** fürs Einfügen (synthetisches ⌘V) gebraucht. Status
  via `AXIsProcessTrusted()`; Prompt + Direktlink in die Systemeinstellungen.
- **Insert/Paste:** Zwischenablage sichern → Zeichen setzen → ⌘V senden →
  (bei Paaren) n× ← → Zwischenablage wiederherstellen. Robust in beliebigen Apps,
  weil nur das Standard-Paste genutzt wird.
- **Clipboard-Restore:** `ClipboardSnapshot` sichert **alle** lesbaren Typen je
  Pasteboard-Item und schreibt sie nach kurzer Verzögerung zurück (nachdem die
  Ziel-App gelesen hat). Wiederherstellung ist Pflicht und passiert immer.
- **Persistenz:** zwei JSON-Dateien in `~/Library/Application Support/com.punctodock.app/`
  (`com.punctodock.settings.json`, `com.punctodock.usage.json`), atomar geschrieben.
  Kein UserDefaults, keine DB. Login-Status wird live aus `SMAppService` gelesen.
- **Start bei Login:** `SMAppService.mainApp` (macOS 13+), reines Opt-in, kein Helper-Target.
- **Toggle:** Ist das Panel offen und der Trigger feuert erneut → schließen.
  Einfachstes robustes Verhalten.

---

## Xcode-Einrichtung (Schritt für Schritt)

Es liegt bewusst **keine `.xcodeproj`** bei (handgeschriebene pbxproj sind fragil).
Stattdessen erzeugst du in ~2 Minuten ein sauberes Projekt und ziehst die Dateien rein:

1. **Xcode → File → New → Project… → macOS → App.**
   - Product Name: `PunctoDock`
   - Team: dein Team (oder „None“ für lokales Ausprobieren)
   - Organization Identifier: `com.punctodock` → Bundle Identifier wird `com.punctodock.app`
   - Interface: **SwiftUI**, Language: **Swift**
   - „Use Core Data“/„Tests“ aus.
2. **Erzeugte Vorlagedateien löschen:** `PunctoDockApp.swift`, `ContentView.swift`
   (und ggf. `Persistence`/Asset-Demos). Wir nutzen unseren eigenen `@main`-AppDelegate.
3. **Quelldateien hinzufügen:** den Ordner `PunctoDock/` aus diesem Repo per
   Drag&Drop ins Projekt ziehen → „Copy items if needed“, „Create groups“.
   (App, Settings, Panel, Triggers, Insertion, Permissions, LoginItem, Model).
4. **Info.plist:** Inhalt aus `PunctoDock/Resources/Info.plist` übernehmen.
   - Entweder die Datei als Info.plist des Targets setzen, **oder** im Target unter
     *Info* diese Schlüssel setzen: `Application is agent (UIElement)` = **YES**
     (`LSUIElement`), `Bundle identifier` = `com.punctodock.app`, Min-Deployment ≥ 13.0.
   - In *General → Minimum Deployments*: **macOS 13.0**.
5. **App Sandbox ausschalten:** Target → *Signing & Capabilities* → falls „App Sandbox“
   vorhanden, **entfernen** (Mülltonne). Grund: Sandbox blockiert das systemweite ⌘V
   und würde den Datenpfad in einen Container umleiten. Die mitgelieferte
   `PunctoDock.entitlements` setzt `com.apple.security.app-sandbox = false`.
6. **Signing:** *Automatically manage signing* an. Für lokale Nutzung reicht „Sign to Run
   Locally“. Wichtig: Nach jedem Neubau, der die Signatur ändert, muss die
   Accessibility-Freigabe ggf. neu erteilt werden (TCC bindet an die Signatur).
7. **Build & Run** (⌘R). Beim ersten Start öffnet sich das Einstellungsfenster und der
   Accessibility-Prompt. Freigeben → fertig.

> Hinweis zur Verifikation: Die Quellen wurden mit
> `xcrun --sdk macosx swiftc -typecheck -swift-version 5 -target arm64-apple-macosx13.0 $(find PunctoDock -name '*.swift')`
> fehlerfrei geprüft. Ein echter App-Build/Codesign passiert in Xcode (siehe oben).

---

## Benötigte Berechtigungen

| Berechtigung | Wofür | Wann |
|---|---|---|
| **Bedienungshilfen (Accessibility)** | synthetisches ⌘V und ← in die Ziel-App posten (CGEvent) | nur fürs **Einfügen** nötig |
| *(keine)* für globalen Hotkey | Carbon `RegisterEventHotKey` braucht kein TCC-Recht | – |
| *(keine)* für Mausrad-Trigger | passives `NSEvent`-Mausmonitoring braucht kein TCC-Recht | – |

Ohne Accessibility funktioniert die App weiter, fügt aber nicht ein: das gewählte
Zeichen landet als ehrlicher Fallback in der Zwischenablage (du kannst manuell ⌘V
drücken). Die Einstellungen zeigen den Status und führen mit einem Klick zu
*Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen*.

---

## Datenschutz / Daten

- **Was** wird gespeichert: Einstellungen (Trigger, Optionen) und eine
  Häufigkeitszählung der **Einzelzeichen** (z. B. `{"?": 12, ".": 30}`). **Keine**
  eingegebenen Texte, keine Inhalte aus anderen Apps, keine Identifikatoren.
- **Warum:** damit Trigger/Optionen erhalten bleiben und die kompakte Ansicht deine
  meistgenutzten Zeichen zuerst zeigt.
- **Wo:** `~/Library/Application Support/com.punctodock.app/`
  (`com.punctodock.settings.json`, `com.punctodock.usage.json`).
- **Löschen:** Ordner `com.punctodock.app` löschen (oder „Nutzungsverlauf zurücksetzen“
  in den Einstellungen für nur die Häufigkeiten). Keine weiteren Spuren außer dem
  System-Login-Item (falls aktiviert), das macOS selbst verwaltet.

---

## Testplan (manuell)

**Trigger**
1. F7 in Browser/Word/Notizen → Panel öffnet nahe der Maus.
2. Einstellungen → Tastenkürzel aufnehmen (z. B. ⌃⌥7) → neuer Hotkey öffnet, alter nicht.
3. „Auf F7 zurücksetzen“ → F7 wieder aktiv.
4. Mausrad-Doppelklick aktivieren → Mittelklick-Doppelklick öffnet Panel.
5. Tastatur-Trigger AUS + Maus AN → nur Maus öffnet; Warnhinweis bei beidem AUS.
6. Beide AN → beide funktionieren parallel.

**Panel**
7. Panel erscheint nahe Cursor mit kleinem Offset (Cursor nicht auf Button).
8. Trigger nah am rechten/unteren Bildschirmrand → Panel klappt nach links/oben, nie abgeschnitten.
9. Zweiter Monitor: Trigger dort → Panel auf dem richtigen Screen, geclampt.
10. „Mehr“ (…) → erweiterte, scrollbare Ansicht; „Zurück“ → kompakt.

**Auswahl & Schließen**
11. Maus-Klick auf Zeichen → eingefügt, Panel schließt.
12. Pfeiltasten bewegen die Auswahl (sichtbarer Rahmen), Enter fügt ein.
13. Escape schließt; Klick in andere App schließt; nach Auswahl schließt.

**Einfügen**
14. In Browser-Textfeld, Word, Notizen, Website-Formular je ein Zeichen einfügen.
15. Paar `()` einfügen → Cursor steht zwischen den Klammern (1× ←).
16. Zwischenablage vorher mit Text/Bild füllen → nach dem Einfügen unverändert.
17. Snippet `…`/`—` einfügen → korrekt, kein Caret-Sprung.

**Berechtigung**
18. Ohne Accessibility: Auswahl legt Zeichen in die Zwischenablage (Fallback), Status rot.
19. Nach Freigabe + „Status aktualisieren“: Status grün, echtes Einfügen.

**Persistenz & Login**
20. Einstellungen ändern, App neu starten → Werte erhalten.
21. Zeichen mehrfach nutzen, neu starten → kompakte Ansicht priorisiert diese (Slot 12 bleibt „Mehr“).
22. Frische Installation (Ordner gelöscht) → Startbelegung `? ! . , : ; ( ) @ & €` + Mehr.
23. „Beim Anmelden starten“ an → Eintrag in *Systemeinstellungen → Allgemein → Anmeldeobjekte*; aus → weg.
24. Dark/Light Mode umschalten → Panel/Settings lesbar (natives Material).

---

## Bekannte Grenzen / Edge Cases

- **F7 als Medientaste:** Auf manchen Tastaturen ist F7 ohne Fn eine Medien-/Helligkeitstaste.
  `RegisterEventHotKey` greift den virtuellen Keycode meist zuvor ab; falls nicht, einfach
  in den Einstellungen ein anderes Kürzel aufnehmen. Default bleibt wie gefordert F7.
- **Tastatur-Navigation im Panel** hängt am `.nonactivatingPanel`-Verhalten. In seltenen
  Konfigurationen kann der Fokus abweichen; Maus-Auswahl und Einfügen sind davon unabhängig
  und bleiben zuverlässig (bewusste Prioritätswahl).
- **Einfügen via ⌘V** setzt voraus, dass die Ziel-App ⌘V als Einfügen versteht (praktisch
  überall der Fall). Apps mit ungewöhnlichem Paste oder eigenem Sicherheits-Sandbox
  (z. B. einige Passwortfelder) können abweichen.
- **Caret zwischen Paaren** über 1× ← funktioniert für einstellige Klammern/Quotes. In Apps
  mit Auto-Vervollständigung von Klammern kann es zu einer Extra-Klammer kommen — dann wird
  zumindest das Paar sauber eingefügt (ehrlicher Fallback).
- **Clipboard-Restore** stellt alle *lesbaren* Datentypen wieder her. Sehr exotische
  „promised“/lazy Pasteboard-Inhalte mancher Apps lassen sich prinzipiell nicht 1:1 sichern.
- **Login-Launch vs. manueller Start:** Ist „Start bei Login“ aktiv, öffnet ein
  *manueller* Start die Einstellungen nicht automatisch (wir nehmen an, es ist der
  Login-Start) — ein erneuter Klick aufs App-Icon (Reopen) öffnet sie. Bei deaktiviertem
  Login-Item öffnet jeder Start die Einstellungen.

## Bewusste Vereinfachungen in v1

- Keine eigene Bearbeitung/Anpassung der kompakten Belegung (sie folgt automatisch der
  Häufigkeit bzw. der Default-Liste).
- Keine Mehrsprachigkeit (UI-Texte deutsch), kein Custom-App-Icon enthalten.
- Erweiterte Ansicht ohne „Zurück per Tastatur“ (Maus-Button vorhanden; Escape schließt ganz).
- Feste Panelgrößen (kompakt 220×248, erweitert 380×400 pt) statt dynamischer Messung.

## Sinnvolle nächste Schritte

- Custom App-Icon + SF-Symbol-Feinschliff.
- Optionales „Einfügen via Accessibility-API direkt ins Textfeld“ als Alternative zu ⌘V
  (umgeht die Zwischenablage ganz, dafür app-abhängiger).
- Editor zum Anheften/Ausblenden einzelner Zeichen in der kompakten Ansicht.
- Lokalisierung (de/en) und VoiceOver-Labels für die Tiles.
- Kleines Unit-Test-Target für `UsageHistory.compactSlots` und `ClipboardSnapshot`.
```
