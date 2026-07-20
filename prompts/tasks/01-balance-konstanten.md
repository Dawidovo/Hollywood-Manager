# Chunk 01 — Balance-Konstanten zentralisieren

## Ziel
Alle „Magic Numbers" der Spielbalance aus `godot/scripts/Game.gd` und `godot/scripts/Events.gd` in eine zentrale Konstanten-Sammlung ziehen, damit Balancing an einer Stelle passiert.

## Kontext
Werte wie Provisionsspannen (5–20 %), Package-Deal-Bonus (+12 %), Gagen-Aufschlag (+25 %), Produktionsdauer (4–7 Monate), Ruf-Schwellen, DNA-Prägungsfaktoren, Insolvenz-Frist (3 Monate) etc. sind aktuell direkt im Code verstreut.

## Schritte
1. `godot/scripts/Balance.gd` anlegen (Autoload oder `class_name Balance` mit `const`-Werten), gruppiert nach System (Verhandlung, Casting, Produktion, DNA, Events, Wirtschaft).
2. `Game.gd` und `Events.gd` durchgehen, Zahlen-Literale mit Balance-Bedeutung durch `Balance.XYZ` ersetzen. **Keine** Werte ändern — reines Refactoring.
3. Kein Literal umziehen, dessen Bedeutung unklar ist — lieber stehen lassen und mit `# TODO Balance:` markieren.

## Akzeptanzkriterien
- [ ] Headless-Test läuft grün: `--headless --path godot res://tests/Test.tscn`
- [ ] Spielverhalten unverändert (Stichprobe: neues Spiel 1925 starten, 1 Klient anwerben, 3 Monate ticken)
- [ ] .exe neu exportiert
- [ ] Ein Commit: `refactor: Balance-Konstanten nach Balance.gd extrahiert`
