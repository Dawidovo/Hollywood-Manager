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
| `Data` | `scripts/Data.gd` | Datenzugriff, delegiert an `DataLoader.gd` (JSON-Merge) | klein |
| `Game` | `scripts/Game.gd` | Kern-Spiellogik: Verhandlung, Casting, Produktion, Box-Office, Karriere-DNA, Wochenzug | ~4500 Zeilen |
| `Ev` | `scripts/Events.gd` | Ereignis-Inhalte/Alt-Events | ~1300 Zeilen |
| `EvEngine` | `scripts/EventEngine.gd` | Datengetriebene Events aus `data/events/*.json` (conditions/weights/choices/Ketten) | ~400 Zeilen |
| `Persona` | `scripts/Persona.gd` | Spielfigur: Privatfinanzen, Energie/Stress/Gesundheit, Karriereleiter, Skills | ~1000 Zeilen |
| `Mogul` | `scripts/Mogul.gd` | Empire-Cluster: Lifestyle, Investments/Aktien, Hinterzimmer-Deals, Endgame | ~1300 Zeilen |
| `Network` | `scripts/Network.gd` | Kontaktnetz: Beziehungsdimensionen, subjektive Reputation, Wissensfluss, Gala, NPC-Karrieren | ~1000 Zeilen |
| `Dialogs` | `scripts/Dialogs.gd` | Dialogbäume, Wochenpost, Relevanz-Dispatcher (Digest/Notiz/Kurzdialog/Szene), Gesprächsgedächtnis | ~600 Zeilen |
| `Staff` | `scripts/Staff.gd` | Mitarbeiter & Delegation: Desks, Empfehlungen, Autonomie-Modi, Eskalationsregeln, Abspaltungen | ~400 Zeilen |
| `Newspaper` | `scripts/Newspaper.gd` | Presse/Chronik | klein |
| `Jukebox` | `scripts/MusicGen.gd` | Generative Epochen-Musik | klein |

`Main.gd` (~4000 Zeilen) rendert alle Screens (Start, Spiel, Filme, Kontakte, Orte,
Post, Privat, Invest, Lifestyle, Deal, Dialog, Chronik — vgl. `shot_*.png`).

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
- **.exe exportieren** (nach JEDER Code-Änderung, Pflicht): `Godot_..._console.exe --headless --path godot --export-release "Windows Desktop" "build/HollywoodManager.exe"` → `godot/build/HollywoodManager.exe`
- **Screenshots:** `Godot_....exe --path godot --resolution 2000x1100 -- --shot-<name>` — das `--` vor den Shot-Args ist Pflicht, sonst Endlos-Prozess
- **Lint:** gdlint via `tools\lint.ps1` (Konfig `godot/.gdlintrc`); läuft im Pre-Commit-Hook zusammen mit SonarQube-Quality-Gate (nur `tools/`-Python)
- **Daten-Reformat:** `tools/ExportData.gd` schreibt die Core-JSONs frisch formatiert zurück
- **Balance-Sim:** `--headless --path godot res://tools/BalanceSim.tscn` spielt pro Epoche 104 Wochen mit Standard-Heuristik und druckt Ökonomie-Kennzahlen als `SIM;`-CSV — vor/nach Balance-Änderungen laufen lassen (Befunde: Chunks 19/20)

Spielstände/Mods: `%APPDATA%\Godot\app_userdata\Hollywood Manager\` (`hm_save.json`, `data/`).

## Offene Arbeit

Aufgaben-Chunks mit Status: [prompts/tasks/README.md](prompts/tasks/README.md).
Größte bekannte Tech-Debt-Posten: `Game.gd` und `Main.gd` sind Monolithen
(Chunks 01–03, 09), Save-Migration fehlt (04), Testsuite dünn (05).
RPG-Ausbau-Konzept: `prompts/rpg_konzept.md` (Chunks 15–18, strikt in Reihenfolge).
