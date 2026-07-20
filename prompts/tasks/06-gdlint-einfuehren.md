# Chunk 06 — gdlint/gdformat (gdtoolkit) einführen

## Ziel
Statische Analyse für GDScript etablieren. SonarQube (siehe `tools/sonar-analyze.ps1`) versteht **kein** GDScript — den Großteil des Codes deckt erst gdtoolkit ab.

## Schritte
1. Installation: `py -3 -m pip install "gdtoolkit==4.*"` (Python 3.14 ist als `py` installiert).
2. `gdlint godot/scripts godot/tests` laufen lassen; `.gdlintrc` im Projektroot anlegen und zu strenge Regeln bewusst konfigurieren (z. B. `max-file-lines` vorerst hoch setzen, bis Chunks 02/03/09 erledigt sind — mit Kommentar im File).
3. Alle verbleibenden Findings beheben (ungenutzte Variablen, Shadowing, Naming).
4. `gdformat --check godot/scripts godot/tests`; bei überschaubarem Diff formatieren und als **separaten** Commit committen.
5. Aufruf in `tools/lint.ps1` skripten und in `prompts/tasks/README.md` + Projekt-README dokumentieren.

## Akzeptanzkriterien
- [ ] `gdlint` läuft ohne Findings durch
- [ ] Tests grün, .exe neu exportiert (falls Code angefasst wurde)
- [ ] Commits: `chore: gdlint konfiguriert + Findings behoben` (+ ggf. `style: gdformat`)
