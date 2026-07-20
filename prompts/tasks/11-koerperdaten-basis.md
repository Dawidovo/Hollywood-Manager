# Chunk 11 — Körperdaten I: Größe & Gewicht (Daten + Anzeige)

## Ziel
Schauspieler bekommen die Felder **Größe (cm)** und **Gewicht (kg)**. Beides wird im Talentpool, auf der Klientenkarte und im Verhandlungsdialog angezeigt. Die Dynamik (Gewicht verändert sich über die Karriere) kommt separat in Chunk 12 — hier nur Datenmodell + Anzeige.

## Aktueller Stand (wichtig, neuer als ältere Prompts!)
- Alle Spieldaten liegen als JSON unter `godot/data/<kategorie>/` und werden von `godot/scripts/DataLoader.gd` geladen. **Merge-Regel:** alle `*.json` eines Ordners werden alphabetisch geladen; gleiche `id` ⇒ Feld-Merge (Überschreiben/Anreichern), neue `id` ⇒ Anhängen. Schema-Defaults stehen in `Data.gd` → `reload()`. Beispiel für ein Anreicherungspaket: `godot/data/actors/filmography_core.json` (nur `id` + Zusatzfeld).
- `Data.gd` ist nur noch Fassade; **niemals** Daten hart in GDScript eintragen.
- Anzeige-Helfer in `Main.gd`: `_actor_meta(a, year)` baut die Meta-Zeile der Pool-/Klientenkarten (Geschlecht · Alter · Geburtsjahr · Ethnie · Genres), `_lbl_fill()` für Labels in HBoxen.
- Format-Doku für Modder: `godot/data/README.md` — bei Schemaänderungen mitpflegen.

## Schritte
1. **Schema:** Actor-Felder `height_cm` (int, statisch) und `weight_kg` (int, Basiswert) einführen. In `Data.gd` → `reload()` bei den Actor-Defaults `"height_cm": 0, "weight_kg": 0` ergänzen (0 = „prozedural bestimmen“).
2. **Prozedurale Defaults:** In `Game.gd` einen Helfer `body_of(a) -> Dictionary` (`{height, weight}`) anlegen: deterministisch aus `hashs(str(a.id))` + Geschlecht (m: ~168–193 cm, f: ~155–180 cm; Gewicht aus BMI ~19–26 auf die Größe gerechnet). Gleicher Schauspieler ⇒ immer gleiche Werte. Liegen echte Werte (> 0) im JSON, gewinnen die.
3. **Datenpaket:** `godot/data/actors/body_core.json` anlegen — Anreicherungsliste `[{"id": "bogart", "height_cm": 173, "weight_kg": 70}, …]` mit realistischen Werten für ~40 bekannte Schauspieler (Chaplin, Bogart, Monroe, Wayne, Schwarzenegger, Zendaya …). Rest läuft über die prozeduralen Defaults.
4. **Anzeige:** `_actor_meta()` in `Main.gd` erweitern: `… · 178 cm · 74 kg` (bei Klienten später das dynamische Gewicht aus Chunk 12, hier erstmal der Basiswert). Verhandlungsdialog (`_render_negotiation`, Info-Zeile bei Main.gd ~1497) ebenfalls ergänzen.
5. **Doku:** `godot/data/README.md` — Actor-Schema um die zwei Felder + Hinweis auf `body_core.json` ergänzen.
6. **Tests** (`godot/tests/Test.gd`, `check()`-Stil): `body_of()` deterministisch (2× gleicher Actor ⇒ gleiche Werte, Wertebereiche plausibel); JSON-Wert überschreibt Prozedur-Wert (bogart 173 cm); DataLoader-Merge greift (Actor hat nach dem Laden `height_cm` > 0 für einen body_core-Eintrag).

## Akzeptanzkriterien
- [ ] Headless-Test grün: `--headless --path godot res://tests/Test.tscn`
- [ ] Pool-Screenshot zeigt cm/kg: `Godot_v4.7.1-stable_win64.exe --path godot --resolution 2000x1100 -- --shot-pool` (Achtung: `--` vor den Shot-Args ist Pflicht)
- [ ] Keine Werte in GDScript hartkodiert — alles über `data/actors/*.json` bzw. `body_of()`
- [ ] .exe neu exportiert (`--headless --path godot --export-release "Windows Desktop" build/HollywoodManager.exe`)
- [ ] Ein Commit: `feat: Größe & Gewicht für Schauspieler (Daten + Anzeige)`
