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
| 04 | [Save-Versionierung & Migration](04-save-migration.md) | Robustheit | erledigt (Versionskette `_migrate_save`, Backup `hm_save.bak.json`, Fehlerdialog, v1-Fixture-Test) |
| 05 | [Testsuite ausbauen](05-tests-ausbauen.md) | Qualität | erledigt (500+ Checks; Kern-Regressionen fame_at/Fit/Package/Box-Office-Determinismus/Wortbruch/Insolvenz; Exit-Code ≠ 0 verifiziert) |
| 06 | [gdlint/gdformat einführen](06-gdlint-einfuehren.md) | Tooling | erledigt (gdlint aktiv; gdformat bewusst ausgelassen — Riesen-Diff) |
| 07 | [SonarQube-Findings abarbeiten](07-sonarqube-findings.md) | Qualität | erledigt (laufende Regel) |
| 08 | [Web-Prototyp einfrieren](08-web-prototyp-einfrieren.md) | Tech Debt | entschieden |
| 09 | [Main.gd: UI in Screens aufteilen](09-main-gd-screens-aufteilen.md) | Tech Debt | offen |
| 10 | [Fehlerbehandlung Daten/Save](10-fehlerbehandlung-daten.md) | Robustheit | offen |
| 11 | [Körperdaten I: Größe & Gewicht](11-koerperdaten-basis.md) | Feature | erledigt (Commit `8cca6d8`) |
| 12 | [Körperdaten II: Gewichtsdynamik](12-koerperdaten-dynamik.md) | Feature | erledigt (Commit `b7b3bae`) |
| 13 | [Verhandlungen homogenisieren](13-verhandlungen-homogenisieren.md) | UI-Qualität | erledigt (Commit `db75888` — `_nego_header`/`_nego_actions` aktiv) |
| 14 | [Layout-Audit Buchstaben-Umbruch](14-layout-audit-buchstabenumbruch.md) | Bugfix | erledigt (inkl. Nachaudit der neuen Tabs; Header bricht jetzt um statt zu überlaufen) |
| 15 | [RPG I: Attribute der Spielfigur](15-rpg-attribute.md) | RPG | offen |
| 16 | [RPG II: Proben in Events](16-rpg-proben-events.md) | RPG | offen |
| 17 | [RPG III: Quest-Journal](17-rpg-questjournal.md) | RPG | offen |
| 18 | [RPG IV: Kontaktbuch & NPCs](18-rpg-npc-beziehungen.md) | RPG | überholt — umfangreicher umgesetzt über `Network.gd` (Kontaktbuch, Beziehungsdimensionen, Gefallen an Personen); Rest-Ideen bei Bedarf als neuer Chunk |
| 19 | [Balance: 1925-Ökonomie](19-balance-1925-oekonomie.md) | Balance | erledigt (ask_fee-Exponent 2,35, Frühzeit-Büro ×0,6, Startkapital-Era-Faktor; Sim 1925: Woche 104 bei +44K statt Pleite in Woche 80) |
| 20 | [Balance: Energie-Erosion](20-balance-energie.md) | Balance | offen (Befund aus BalanceSim: Energie fällt in allen Epochen langfristig Richtung null) |

Reihenfolge-Empfehlung: 06 → 01 → 02 → 05 → 04 → 03 → 07 → 10 → 09 → 08. (Erst Tooling & Sicherheitsnetz, dann Refactorings.)
Für die neuen Chunks 11–14: nur noch **14** offen (sichtbarer Bug).
RPG-Ausbau (Konzept: [../rpg_konzept.md](../rpg_konzept.md)): strikt 15 → 16 → 17 — jeder Chunk setzt den vorigen voraus; 18 ist durch das Netzwerk-System überholt.

> ℹ️ **Architektur-Stand seit Juli 2026** (neuer als die Chunks 01–10): Spieldaten liegen als JSON unter `godot/data/` (Loader: `DataLoader.gd`, Doku: `godot/data/README.md`), Events laufen datengetrieben über `EventEngine.gd` (`data/events/*.json`), der Spielzug ist **wöchentlich** (`Game.end_week()`, 21-Slot-Planer), Spielstart mit wählbarer Backstory. Screenshot-Hooks: `Godot_v4.7.1-stable_win64.exe --path godot --resolution 2000x1100 -- --shot-<name>` — das `--` vor den Shot-Args ist Pflicht.
