# Chunk 02 — Game.gd: reine Hilfsfunktionen nach Util.gd extrahieren

## Ziel
`Game.gd` (~1800 Zeilen, 129 Funktionen) verkleinern: Alle zustandslosen Helfer in ein eigenes Autoload `Util.gd` verschieben.

## Kontext
Kandidaten (reine Funktionen ohne Spielzustand): `pick`, `chance`, `rndf`, `rndi`, `hashs`, `infl`, `grade`, `grade_range`, `fmt_money`, `_de_num`, `age_of`, `ask_fee`, `required_rep`, `fame_at`, `attrs`. RNG-Zugriff (`rng`) muss mitwandern oder injiziert werden — Determinismus der Tests nicht brechen.

## Schritte
1. `godot/scripts/Util.gd` als Autoload registrieren (project.godot).
2. Funktionen verschieben, Aufrufer per Suche/Ersetzen auf `Util.` umstellen (`Main.gd`, `Events.gd`, `Newspaper.gd`, Tests).
3. Prüfen, dass keine der verschobenen Funktionen doch `state` liest — solche bleiben in `Game.gd`.

## Akzeptanzkriterien
- [ ] `Game.gd` um mindestens 150 Zeilen kürzer
- [ ] Headless-Test grün, .exe neu exportiert
- [ ] Ein Commit: `refactor: zustandslose Helfer nach Util.gd`
