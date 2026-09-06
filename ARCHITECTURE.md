# Hollywood Manager — Architektur & Stand

> Stand: Juli 2026. Diese Datei zuerst lesen (zusammen mit [DECISIONS.md](DECISIONS.md)),
> bevor Code angefasst wird — sie ersetzt das Durchsuchen des Repos für den Überblick.

## Was ist das Spiel?

Menü-Wirtschaftssimulation: Der Spieler führt eine Hollywood-Talentagentur von der
Stummfilm-Ära bis zur Streaming-Gegenwart, mit echten Schauspielern aller Epochen.
Wählbarer Epochen-Start (1925/1950/1980/2010) und biografischer Start mit Backstory.
Der Spielzug ist **wöchentlich** (`Game.end_week()`, 21-Slot-Wochenplaner).

## Projektlayout (Root)

| Pfad | Inhalt |
|---|---|
| `godot/` | **Hauptprojekt** (Godot 4.7, GDScript, UI komplett in Code) — hier findet alle Arbeit statt |
| `index.html`, `js/` | Web-Prototyp — **EINGEFROREN, nie anfassen** (siehe DECISIONS.md) |
| `prompts/tasks/` | Arbeitspakete (Chunks) mit Statusliste in `prompts/tasks/README.md` |
| `tools/` | Python-Tooling: IMDb-Import, gdlint-Report, SonarQube-Skripte, Git-Hooks |
| `shot_*.png` | Aktuelle Screenshots der Spiel-Screens (per Screenshot-Hook erzeugt) |

## Godot-Projekt (`godot/`)

Eine einzige Szene (`Main.tscn`); die gesamte UI wird in `Main.gd` in Code gebaut.
Alle Systeme sind Autoloads (Singletons):

| Autoload | Datei | Zuständigkeit | Umfang |
|---|---|---|---|
| `Balance` | `scripts/Balance.gd` | Zentrale Spielbalance-Konstanten (Wirtschaft, Gagen, Produktion, Versprechen, DNA) | klein |
| `Util` | `scripts/Util.gd` | Zustandslose Helfer: RNG-Wrapper, `hashs`, `body_of`, `infl`/`fame_at`/`age_of`/`ask_fee`, `grade`, `fmt_money`, `attrs` | klein |
| `CareerDNA` | `scripts/CareerDNA.gd` | Karriere-DNA: Achsen, Genre-Prägungsvektoren, `initial_dna`/`imprint_dna`/`dna_fit`/`dna_label`/`decay` | klein |
| `Data` | `scripts/Data.gd` | Datenzugriff, delegiert an `DataLoader.gd` (JSON-Merge) | klein |
| `Game` | `scripts/Game.gd` | Kern-Spiellogik: Verhandlung, Casting, Produktion, Box-Office, Wochenzug | ~3600 Zeilen |
| `Scandal` | `scripts/Scandal.gd` | Geheimnisse & Gerüchte: Entstehen, Verbreitung, Wirkung, Gegenmaßnahmen | ~400 Zeilen |
| `Rivals` | `scripts/Rivals.gd` | Konkurrenz-Agenturen: Signings, Attacken, Abwerbe-Duelle, Ranking | ~230 Zeilen |
| `Planner` | `scripts/Planner.gd` | Wochenplaner: 21-Slot-Kalender, Auswertung, Klienten-Autoplanung | ~220 Zeilen |
| `Predictions` | `scripts/Predictions.gd` | Instinkt-Prognosen: Wetten anlegen/auflösen, Instinkt-Wachstum | ~110 Zeilen |
| `Coverage` | `scripts/Coverage.gd` | Script-Coverage: Lektorats-Blatt, Marker, Schnitt-Rollen, Auswertung | ~280 Zeilen |
| `Ev` | `scripts/Events.gd` | Ereignis-Inhalte/Alt-Events | ~1300 Zeilen |
| `EvEngine` | `scripts/EventEngine.gd` | Datengetriebene Events aus `data/events/*.json` (conditions/weights/choices/Ketten) | ~400 Zeilen |
| `Persona` | `scripts/Persona.gd` | Spielfigur: Privatfinanzen, Energie/Stress/Gesundheit, Karriereleiter, Skills | ~1000 Zeilen |
| `Mogul` | `scripts/Mogul.gd` | Empire-Cluster: Lifestyle, Investments/Aktien, Hinterzimmer-Deals, Endgame | ~1300 Zeilen |
| `Network` | `scripts/Network.gd` | Kontaktnetz: Beziehungsdimensionen, subjektive Reputation, Wissensfluss, Gala, NPC-Karrieren | ~1000 Zeilen |
| `Emotions` | `scripts/Emotions.gd` | Emotionsmodell: wahre Emotion abgeleitet aus Fakten, wahrgenommene über Menschenkenntnis-Stufen | klein |
| `Press` | `scripts/Press.gd` | Pressekonferenz-Auslöser & Cooldowns (Szene/Brief sind Daten) | klein |
| `Needs` | `scripts/Needs.gd` | Klienten-Bedürfnisse: deterministisches Profil, gespeicherte Sättigung, Drift & Engpass-Wirkung | klein |
| `Dialogs` | `scripts/Dialogs.gd` | Dialogbäume, Wochenpost, Relevanz-Dispatcher (Digest/Notiz/Kurzdialog/Szene), Gesprächsgedächtnis | ~600 Zeilen |
| `Staff` | `scripts/Staff.gd` | Mitarbeiter & Delegation: Desks, Empfehlungen, Autonomie-Modi, Eskalationsregeln, Abspaltungen | ~400 Zeilen |
| `Newspaper` | `scripts/Newspaper.gd` | Presse/Chronik | klein |
| `Jukebox` | `scripts/MusicGen.gd` | Generative Epochen-Musik | klein |

`Main.gd` (~2650 Zeilen) hält Layout, Navigation, UI-Bausteine, Modals und
die Verhandlungs-Dialoge; **alle 16 Tabs** liegen als Screen-Module unter
`scripts/ui/` (Muster: Main-Referenz im Konstruktor, Rendern in
`main.content_box`): Finance, Personal, Contacts, Agency, Clients sowie
gebündelt MarketScreens (Pool/Castings/Gerüchte/Filme) und WorldScreens
(Post/Orte/Lifestyle/Invest/Zeitung/Journal/Chronik/Planner).

## Daten (`godot/data/`)

**Alle Spielinhalte sind JSON, kein Code nötig zum Erweitern.** Loader: `scripts/DataLoader.gd`.
Ordner pro Kategorie (actors, studios, events, dialogs, letters, contacts, staff, locations,
career, skills, stocks, backroom, eras, backstories, …). Merge-Regeln: alphabetisch geladen,
gleicher Key = feldweises Override, `user://data/` überschreibt Bundled (Mod-Support).
**Vollständige Schema-Doku: [godot/data/README.md](godot/data/README.md)** — dort stehen
Actor-/Event-/Dialog-/Brief-Schemas und alle Effekt-Ops.

Events, Dialoge und Briefe teilen **eine deklarative Effekt-Sprache** (Ops wie `money`,
`dims`, `promise`, `favor_owe`, `followup`, `chance`, …).

## Bauen, Testen, Screenshots

- **Editor/Spiel starten:** `Godot_v4.7.1-stable_win64.exe --path godot` (Editor liegt in `C:\Users\Anwender\Downloads\...`, Kopie auch im Repo-Root)
- **Logiktest:** `Godot_console.exe --headless --path godot res://tests/Test.tscn` (Tests: `godot/tests/Test.gd`)
- **Test-Runner (QA-09, bevorzugt):** `powershell -File tools\run-tests.ps1` — Timeout, Seed (`-Seed`), Logpfad, Abschlussmarker; wertet SCRIPT ERROR, fehlende Marker und FAIL-Zeilen aus und prüft, dass der echte Spielstand unverändert bleibt. Tests/Sim speichern isoliert unter `user://qa_test*/` (`Game.use_test_savedir()`).
- **.exe exportieren** (nach JEDER Code-Änderung, Pflicht): `Godot_..._console.exe --headless --path godot --export-release "Windows Desktop" "build/HollywoodManager.exe"` → `godot/build/HollywoodManager.exe`
- **Screenshots:** `Godot_....exe --path godot --resolution 2000x1100 -- --shot-<name>` — das `--` vor den Shot-Args ist Pflicht, sonst Endlos-Prozess
- **Lint:** gdlint via `tools\lint.ps1` (Konfig `godot/.gdlintrc`); läuft im Pre-Commit-Hook zusammen mit SonarQube-Quality-Gate (nur `tools/`-Python)
- **Daten-Reformat:** `tools/ExportData.gd` schreibt die Core-JSONs frisch formatiert zurück
- **Balance-Sim:** `--headless --path godot res://tools/BalanceSim.tscn` spielt pro Epoche 104 Wochen mit Standard-Heuristik und druckt Ökonomie-Kennzahlen als `SIM;`-CSV — vor/nach Balance-Änderungen laufen lassen (Befunde: Chunks 19/20). Seit QA-09 beantwortet die Sim die Ereignisse/Dialoge der Woche (erste verfügbare Wahl); Anzahl, Ignorierte und blockierte Dialoge stehen in den `SUM;`-Zeilen, Abschlussmarker `SIM_DONE`.

Spielstände/Mods: `%APPDATA%\Godot\app_userdata\Hollywood Manager\` (`hm_save.json`, `data/`).

## Offene Arbeit

Aufgaben-Chunks mit Status: [prompts/tasks/README.md](prompts/tasks/README.md).
Tech-Debt-Stand: Die Monolithen sind aufgeteilt — `Game.gd` (~3600) enthält
noch den Kern-Spielzug (end_week/Monatsabschluss/Release) und den
Verhandlungs-/Casting-Motor (bewusst dort belassen: eng an `nego`/`pitch_ctx`
gekoppelt); `Main.gd` (~2650) UI-Gerüst und Verhandlungs-Dialoge.
RPG-Ausbau-Konzept: `prompts/rpg_konzept.md` (Chunks 15–18, strikt in Reihenfolge).
