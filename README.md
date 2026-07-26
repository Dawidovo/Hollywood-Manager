# Hollywood Manager

Eine Menü-Wirtschaftssimulation: Du führst eine Hollywood-Talentagentur — von der Stummfilm-Ära bis zur Streaming-Gegenwart, mit echten Schauspielern aller Epochen.

> 🤖 **Für KI-Sessions & neue Mitarbeitende:** Zuerst [ARCHITECTURE.md](ARCHITECTURE.md) (Stand & Struktur) und [DECISIONS.md](DECISIONS.md) (bindende Entscheidungen) lesen — das ersetzt das Durchsuchen des Repos.

## Godot-Version (Hauptversion)

Die vollwertige Desktop-Anwendung liegt in `godot/` (Godot 4.7, GDScript, komplette UI in Code):

```
"C:\Users\Anwender\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe" --path godot
```

Oder den Ordner `godot/` im Godot-Projektmanager importieren und auf Play drücken.

### Eigenständige .exe

Fertig gebaut unter **`godot/build/HollywoodManager.exe`** (eine einzelne Datei, PCK eingebettet — direkt startbar, kein Godot nötig). Neu bauen nach Code-Änderungen:

```
"C:\Users\Anwender\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path godot --export-release "Windows Desktop" "build/HollywoodManager.exe"
```

Die Export-Templates (4.7.1.stable) sind bereits unter `%APPDATA%\Godot\export_templates\` installiert, das Preset liegt in `godot/export_presets.cfg`. Spielstände landen in `%APPDATA%\Godot\app_userdata\Hollywood Manager\`.

- Alle Systeme der Web-Version: Epochen-Start, Verhandlung mit Gegenvorschlägen/Perks/Laufzeiten, Ruf-Schranke, Castings mit Package-Deals, Box-Office, 22 Ereignisse mit Bedingungen, Awards, Streiks, generative Epochen-Musik, Autosave (`user://hm_save.json`).
- **Exklusiv: Karriere-DNA** — fünf bipolare Image-Achsen pro Klient (Romantisch↔Bedrohlich, Populär↔Elitär, Zuverlässig↔Unberechenbar, Einzigartig↔Austauschbar, Familientauglich↔Kontrovers). Jede Rolle prägt das öffentliche Bild (Hauptrollen doppelt so stark wie Nebenrollen), Prestige-Filme machen elitär/einzigartig, Blockbuster machen populär, Ereignis-Entscheidungen wirken ebenfalls. Das Casting gleicht Rollenbild und DNA ab („Image“-Wert in der Pitch-Liste): Ein Westernstar überzeugt nicht über Nacht als Romantiker — Typecasting entsteht organisch, und Karrieren lassen sich nur über gezielt gewählte Rollen umbauen. Bei Untätigkeit verblasst das Image langsam.
- Logiktest: `Godot_console.exe --headless --path godot res://tests/Test.tscn`

## Web-Prototyp (EINGEFROREN — nicht weiterentwickeln!)

⚠️ **Die Webversion (`index.html`, `js/`) ist eingefroren und spielt keine Rolle mehr.** Sie bleibt nur als Referenz liegen: keine neuen Features, keine Bugfixes, keine Refactorings, keine Analyse. **Alle Arbeit (auch von KI-Modellen) findet ausschließlich in `godot/` statt.** Bei Bedarf startbar mit `py -3 -m http.server 8123` im Projektordner.

## Spielprinzip

- **Epochen-Start:** Wähle 1925, 1950, 1980 oder 2010. Verfügbar sind nur Schauspieler, die zu diesem Zeitpunkt leben und bereits debütiert haben — 1925 wirbst du Chaplin und die junge Greta Garbo an, 2010 DiCaprio und Jennifer Lawrence. Ruhm folgt einer Karrierekurve um das reale Karrierehoch.
- **Verhandlungen mit Versprechen:** Beim Anwerben bietest du Provision (5–20 %), Signing-Bonus und optional ein *Versprechen* („Hauptrolle in 12 Monaten", „Prestige-Projekt", „Oscar-Nominierung"). Jeder Star hat verdeckte Prioritäten (Geld / Prestige / Sicherheit) und gibt bei Ablehnung Hinweise. Versprechen werden mit Deadline protokolliert: gehalten → Loyalität steigt; gebrochen → Loyalitätseinbruch und Ruf-Schaden.
- **Castings & Package-Deals:** Studios schreiben monatlich Rollen aus. Du pitchst Klienten (Passung aus Genre, Ruhm, Heat, Studio-Beziehung), kannst +25 % Gage fordern (Risiko: Deal platzt) oder einen **Package-Deal** schnüren — ein zweiter Klient wandert in eine Nebenrolle, beide Gagen +12 %.
- **Filmlogik:** Produktion 4–7 Monate, dann Box-Office aus Budget, Star-Power, Qualität und Marktlage. Erfolge treiben Ruhm und „Heat" deiner Klienten, Flops kosten beides. Jeden Februar: Award-Saison.
- **Events & Geschichte:** Skandale (im Hays-Code-Zeitalter besonders gefährlich), Abwerbeversuche, Presse-Coups — plus fixe historische Ereignisse (Tonfilm 1927, Börsencrash 1929, Blockbuster-Ära 1975, Pandemie 2020), die den Markt bewegen.
- Provisionen fließen bei Drehbeginn. Drei Monate zahlungsunfähig = Game Over. Speichern über den Button (localStorage).

## Echte Schauspieler-Daten

Mitgeliefert sind ~100 kuratierte Stars (1910er–heute) in `js/data.js` mit historischen Geburts-/Sterbe-/Debütjahren. Talent-, Ego- und Genre-Werte sind **Spielwerte**, keine Fakten.

### Auf tausende Schauspieler skalieren (IMDb-Import)

`tools/import_imdb.py` lädt die offiziellen [IMDb Non-Commercial Datasets](https://datasets.imdbws.com/) (~300 MB) und erzeugt `js/actors_full.js`, das das Spiel automatisch statt der Seed-Daten lädt:

```
py -3 tools/import_imdb.py --top 2000
```

Bekanntheit wird aus den IMDb-Stimmenzahlen abgeleitet, Debüt/Peak aus den Jahren der bekanntesten Filme. **Lizenzhinweis:** Die IMDb-Datasets sind nur für persönliche, nicht-kommerzielle Nutzung freigegeben (siehe imdb.com/interfaces). Für ein kommerzielles Spiel müssen die Daten ersetzt werden (z. B. TMDb-API mit eigenem Key oder Wikidata).

## Code-Qualität & Aufgaben

- **Aufgaben-Chunks:** `prompts/tasks/` — kleine, abgeschlossene Arbeitspakete (Features + Technical-Debt-Abbau) mit Statusliste in `prompts/tasks/README.md`. Pro Session ein Chunk, pro Chunk ein Commit.
- **SonarQube (lokal):** analysiert nur noch `tools/` (Python) — die eingefrorene Webversion ist ausgeschlossen. Server: `powershell -File tools\sonar-server.ps1`, Scan: `powershell -File tools\sonar-analyze.ps1`, Dashboard: http://localhost:9000/dashboard?id=hollywood-manager. Details: `tools/sonar-README.md`.
- **GDScript:** wird von SonarQube nicht unterstützt → gdlint ist das Analyse-Werkzeug für den Hauptcode (Chunk 06).

## Struktur

```
index.html        UI-Shell & Styles
js/data.js        Seed-Stars, Studios, Titelgenerator, historische Events
js/game.js        Spiellogik (Verhandlung, Casting, Produktion, Box-Office, Events)
js/ui.js          Rendering, Modals, Save/Load
tools/import_imdb.py  IMDb-Dataset-Importer → js/actors_full.js
```
