# Aufgaben-Chunks (Prompts)

> ⚠️ **Die Webversion (`index.html`, `js/`) ist EINGEFROREN.** Alle Chunks und alle KI-Sessions arbeiten ausschließlich am Godot-Projekt (`godot/`). Die Webversion wird weder analysiert noch verändert.

Kleine, in sich abgeschlossene Arbeitspakete — jeweils ein Chunk pro Session/Prompt an die KI (oder als eigene Arbeitseinheit). Ziel: Features liefern **und** Technical Debt klein halten.

## Arbeitsweise

1. **Einen** Chunk pro Session bearbeiten, nicht mehrere mischen.
2. Vor Beginn: `git status` sauber? Danach: pro Chunk **ein Commit**.
3. Nach jeder Code-Änderung im Godot-Projekt:
   - Logiktest: `Godot_console.exe --headless --path godot res://tests/Test.tscn`
   - .exe neu exportieren (siehe README.md im Projektroot)
4. Qualitäts-Checks laufen automatisch im Pre-Commit-Hook (`tools/git-hooks/pre-commit`): **gdlint** über die geänderten `.gd`-Dateien (Konfiguration: `godot/.gdlintrc`, manuell: `tools\lint.ps1`) und **SonarQube** mit Quality Gate (`tools\sonar-analyze.ps1`; Server: `tools\sonar-server.ps1`). Findings beheben, bevor committet wird — der Hook blockt sonst.
5. Chunk erledigt → in dieser Tabelle abhaken.

## Status

| # | Chunk | Thema | Status |
|---|-------|-------|--------|
| 01 | [Balance-Konstanten](01-balance-konstanten.md) | Tech Debt | offen |
| 02 | [Game.gd: Utils extrahieren](02-game-gd-utils-extrahieren.md) | Tech Debt | offen |
| 03 | [Game.gd: DNA-System extrahieren](03-game-gd-dna-extrahieren.md) | Tech Debt | offen |
| 04 | [Save-Versionierung & Migration](04-save-migration.md) | Robustheit | offen |
| 05 | [Testsuite ausbauen](05-tests-ausbauen.md) | Qualität | offen |
| 06 | [gdlint/gdformat einführen](06-gdlint-einfuehren.md) | Tooling | erledigt (gdlint aktiv; gdformat bewusst ausgelassen — Riesen-Diff) |
| 07 | [SonarQube-Findings abarbeiten](07-sonarqube-findings.md) | Qualität | erledigt (laufende Regel) |
| 08 | [Web-Prototyp einfrieren](08-web-prototyp-einfrieren.md) | Tech Debt | entschieden |
| 09 | [Main.gd: UI in Screens aufteilen](09-main-gd-screens-aufteilen.md) | Tech Debt | offen |
| 10 | [Fehlerbehandlung Daten/Save](10-fehlerbehandlung-daten.md) | Robustheit | offen |
| 11 | [Körperdaten I: Größe & Gewicht](11-koerperdaten-basis.md) | Feature | offen |
| 12 | [Körperdaten II: Gewichtsdynamik](12-koerperdaten-dynamik.md) | Feature | offen |
| 13 | [Verhandlungen homogenisieren](13-verhandlungen-homogenisieren.md) | UI-Qualität | offen |
| 14 | [Layout-Audit Buchstaben-Umbruch](14-layout-audit-buchstabenumbruch.md) | Bugfix | offen |
| 15 | [RPG I: Attribute der Spielfigur](15-rpg-attribute.md) | RPG | offen |
| 16 | [RPG II: Proben in Events](16-rpg-proben-events.md) | RPG | offen |
| 17 | [RPG III: Quest-Journal](17-rpg-questjournal.md) | RPG | offen |
| 18 | [RPG IV: Kontaktbuch & NPCs](18-rpg-npc-beziehungen.md) | RPG | offen |

Reihenfolge-Empfehlung: 06 → 01 → 02 → 05 → 04 → 03 → 07 → 10 → 09 → 08. (Erst Tooling & Sicherheitsnetz, dann Refactorings.)
Für die neuen Chunks 11–14: **14 zuerst** (sichtbarer Bug), dann 13 → 11 → 12 (12 setzt 11 voraus).
RPG-Ausbau (Konzept: [../rpg_konzept.md](../rpg_konzept.md)): strikt 15 → 16 → 17 → 18 — jeder Chunk setzt den vorigen voraus.

> ℹ️ **Architektur-Stand seit Juli 2026** (neuer als die Chunks 01–10): Spieldaten liegen als JSON unter `godot/data/` (Loader: `DataLoader.gd`, Doku: `godot/data/README.md`), Events laufen datengetrieben über `EventEngine.gd` (`data/events/*.json`), der Spielzug ist **wöchentlich** (`Game.end_week()`, 21-Slot-Planer), Spielstart mit wählbarer Backstory. Screenshot-Hooks: `Godot_v4.7.1-stable_win64.exe --path godot --resolution 2000x1100 -- --shot-<name>` — das `--` vor den Shot-Args ist Pflicht.
