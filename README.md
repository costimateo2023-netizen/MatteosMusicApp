# MusicStream – Deine persönliche Musik-App 🎵

## Was kann die App?

- 🎵 **Eigene Musik importieren** – MP3, AAC, WAV, AIFF aus deinen Dateien
- 🏷️ **Metadaten automatisch holen** – Titel, Artist, Album, Cover über iTunes API (benötigt Internet)
- 📴 **Offline abspielen** – Musik liegt lokal auf deinem iPhone, kein Internet nötig
- ♾️ **Nonstop-Playlists** – Song endet → nächster startet automatisch, am Ende beginnt alles von vorne
- 📋 **Playlists erstellen** – beliebig viele, Songs per Tap hinzufügen
- 🎛️ **Vollständiger Player** – Seek-Bar, Lautstärke, Shuffle, Repeat, Lock-Screen-Steuerung
- 🔍 **Suchfunktion** – Titel, Artist oder Album durchsuchen

---

## Installation (Schritt für Schritt)

### Methode 1: Mac + Xcode (empfohlen)
### Voraussetzungen
- Mac mit **Xcode 15** oder neuer ([kostenlos im Mac App Store](https://apps.apple.com/app/xcode/id497799835))
- iPhone mit **iOS 16** oder neuer
- Apple ID (kostenlos)

### Schritte

1. **ZIP entpacken** – Doppelklick auf `MusicStream.zip`

2. **Xcode öffnen** – Doppelklick auf `MusicStream.xcodeproj`

3. **Team einstellen:**
   - Links oben im Projekt-Navigator: `MusicStream` Projekt auswählen
   - Tab **Signing & Capabilities** öffnen
   - Bei **Team** deine Apple ID auswählen (oder hinzufügen)
   - Bundle Identifier ändern, z.B. `com.deinname.musicstream`

4. **iPhone verbinden** – per USB-Kabel

5. **Gerät auswählen** – oben in Xcode dein iPhone auswählen

6. **Starten** – ▶️ Play-Button drücken

7. **Beim ersten Mal:**
   - iPhone: *Einstellungen → Allgemein → VPN & Geräteverwaltung*
   - Deiner Apple ID vertrauen

---

### Methode 2: Windows → GitHub Actions (Cloud-Build, kein Developer Account nötig)

Du kannst die .ipa ohne Mac und ohne Apple Developer Account bauen.

1. **GitHub Repository erstellen** (privat oder öffentlich)
2. **Projekt hochladen** – alle Dateien per Git push
3. **Workflow starten:**
   - Gehe zu *Actions → Build IPA (unsigned) → Run workflow*
4. **.ipa herunterladen:**
   - Nach ~5 Minuten siehst du **Matteos-Music-App** als Artifact
   - Auf dein iPhone sideloaden mit **Sideloadly** (Windows, kostenlos: sideloadly.io)

---

## Musik importieren

1. In der App auf **+** tippen (oben rechts)
2. Dateien-App öffnet sich → MP3/AAC auswählen
3. Song wird importiert und erscheint in der Bibliothek
4. Auf **☁️** tippen → Metadaten (Titel, Artist, Cover) automatisch über iTunes holen

---

## Technische Details

| Feature | Technologie |
|---------|------------|
| UI | SwiftUI |
| Audio | AVFoundation |
| Metadaten (lokal) | AVAsset Metadata |
| Metadaten (online) | iTunes Search API |
| Lock Screen | MPNowPlayingInfoCenter |
| Speicherung | UserDefaults + Dokumente-Ordner |
| Min. iOS | 16.0 |

---

## Hinweis

Diese App ist für persönlichen Gebrauch auf deinem eigenen Gerät gedacht (Sideloading).
Für den App Store wäre ein bezahlter Apple Developer Account nötig (99€/Jahr).
