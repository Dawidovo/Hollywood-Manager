# Aufgaben-Chunks (Prompts)

> ⚠️ **Die Webversion (`index.html`, `js/`) ist EINGEFROREN.** Alle Chunks und alle KI-Sessions arbeiten ausschließlich am Godot-Projekt (`godot/`). Die Webversion wird weder analysiert noch verändert.

Kleine, in sich abgeschlossene Arbeitspakete — jeweils ein Chunk pro Session/Prompt an die KI (oder als eigene Arbeitseinheit). Ziel: Features liefern **und** Technical Debt klein halten.

## Arbeitsweise

1. **Einen** Chunk pro Session bearbeiten, nicht mehrere mischen.
2. Vor Beginn: `git status` sauber? Danach: pro Chunk **ein Commit**.
3. Nach jeder Code-Änderung im Godot-Projekt:
   - Logiktest: `Godot_console.exe --headless --path godot res://tests/Test.tscn`
   - .exe neu exportieren (siehe README.md im Projektroot)
4. Qualitäts-Checks: SonarQube-Scan (`tools\sonar-analyze.ps1`) — neue Findings im eigenen Code beheben, bevor committet wird.
5. Chunk erledigt → in dieser Tabelle abhaken.

## Status

| # | Chunk | Thema | Status |
|---|-------|-------|--------|
| 01 | [Balance-Konstanten](01-balance-konstanten.md) | Tech Debt | offen |
| 02 | [Game.gd: Utils extrahieren](02-game-gd-utils-extrahieren.md) | Tech Debt | offen |
| 03 | [Game.gd: DNA-System extrahieren](03-game-gd-dna-extrahieren.md) | Tech Debt | offen |
| 04 | [Save-Versionierung & Migration](04-save-migration.md) | Robustheit | offen |
| 05 | [Testsuite ausbauen](05-tests-ausbauen.md) | Qualität | offen |
| 06 | [gdlint/gdformat einführen](06-gdlint-einfuehren.md) | Tooling | offen |
| 07 | [SonarQube-Findings abarbeiten](07-sonarqube-findings.md) | Qualität | erledigt (laufende Regel) |
| 08 | [Web-Prototyp einfrieren](08-web-prototyp-einfrieren.md) | Tech Debt | entschieden |
| 09 | [Main.gd: UI in Screens aufteilen](09-main-gd-screens-aufteilen.md) | Tech Debt | offen |
| 10 | [Fehlerbehandlung Daten/Save](10-fehlerbehandlung-daten.md) | Robustheit | offen |

Reihenfolge-Empfehlung: 06 → 01 → 02 → 05 → 04 → 03 → 07 → 10 → 09 → 08. (Erst Tooling & Sicherheitsnetz, dann Refactorings.)
