# Chunk 07 — SonarQube-Findings abarbeiten (ERLEDIGT / laufend)

## Ziel
SonarQube-Issues auf null halten. **Scope ist nur noch `tools/` (Python)** — die Webversion ist eingefroren und aus der Analyse ausgeschlossen (siehe `sonar-project.properties`).

## Status Juli 2026
- Webversion (`js/`, `index.html`) aus dem Scan entfernt — wird nicht mehr gepflegt.
- `Math.random`-Findings (Spiellogik) als „Accepted" markiert.
- Verbleibende Python-Findings in `tools/import_imdb.py` behoben.

## Laufende Regel
Nach Änderungen an `tools/`: `tools\sonar-analyze.ps1` laufen lassen, neue Findings sofort beheben oder begründet akzeptieren. Für den GDScript-Hauptcode gilt Chunk 06 (gdlint).
