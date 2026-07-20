# Chunk 09 — Main.gd: UI in Screen-Module aufteilen

## Ziel
`Main.gd` (~1350 Zeilen, komplette UI in Code) in einzelne Screen-Skripte aufteilen, damit UI-Änderungen nicht mehr durch eine Riesendatei gehen.

## Kontext
Kandidaten für eigene Module unter `godot/scripts/ui/`: Klienten-Liste/Detail, Casting-Board, Verhandlungs-Dialog, Ereignis-Popups, Zeitungs-Ansicht (`Newspaper.gd` existiert schon — als Vorbild nehmen), Finanz-/Log-Panel.

## Voraussetzung
Chunks 02/03 erledigt (weniger Verflechtung mit Game.gd), Chunk 05 als Sicherheitsnetz.

## Schritte
1. **Ein Screen pro Arbeitsschritt**, nicht alles auf einmal — dieser Chunk darf mehrfach ausgeführt werden (ein Screen = ein Commit).
2. Screen-Skript erhält `setup(game)`-Referenz statt globaler Zugriffe; Signale statt direkter Methodenaufrufe zurück zu Main.
3. `Main.gd` behält nur Navigation/Layout und Wiring.

## Akzeptanzkriterien (pro Screen)
- [ ] Screen funktioniert sichtbar identisch (manuell durchklicken)
- [ ] Tests grün, .exe neu exportiert
- [ ] Commit: `refactor(ui): <Screen> aus Main.gd extrahiert`
