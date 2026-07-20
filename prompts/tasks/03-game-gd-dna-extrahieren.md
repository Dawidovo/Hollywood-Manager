# Chunk 03 — Game.gd: Karriere-DNA-System extrahieren

## Ziel
Das Karriere-DNA-System (fünf Image-Achsen) aus `Game.gd` in ein eigenes Modul `godot/scripts/CareerDNA.gd` verschieben.

## Kontext
Betroffen: `initial_dna`, `imprint_dna`, `dna_fit`, `dna_label`, `studio_style` sowie DNA-Verfall bei Untätigkeit (im Monats-Tick suchen). Das System ist das Alleinstellungsmerkmal der Godot-Version (siehe README) und wird weiter wachsen — eigenes Modul lohnt sich.

## Voraussetzung
Chunk 02 (Util-Extraktion) ist erledigt.

## Schritte
1. `CareerDNA.gd` als Autoload oder statische Klasse anlegen; Funktionen verschieben, Signaturen beibehalten.
2. Aufrufer in `Game.gd`, `Main.gd`, `Events.gd` umstellen.
3. Mini-Test ergänzen in `godot/tests/Test.gd`: Prägung einer Rolle verschiebt die erwartete Achse in die erwartete Richtung; Hauptrolle prägt doppelt so stark wie Nebenrolle.

## Akzeptanzkriterien
- [ ] DNA-Logik vollständig aus `Game.gd` raus
- [ ] Neuer DNA-Test läuft grün, restliche Tests grün, .exe neu exportiert
- [ ] Ein Commit: `refactor: Karriere-DNA nach CareerDNA.gd + Test`
