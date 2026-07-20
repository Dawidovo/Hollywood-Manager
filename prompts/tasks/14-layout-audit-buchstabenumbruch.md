# Chunk 14 — Layout-Audit: Buchstaben-Umbruch (Vertikaltext) in restlichen Fenstern

## Ziel
Den „ein Buchstabe pro Zeile“-Anzeigefehler überall ausrotten. Er wurde im Talentpool bereits behoben, tritt laut Spieler aber **noch in anderen Fenstern** auf. Systematisch finden, fixen, mit Screenshots in zwei Fenstergrößen absichern.

## Der Mechanismus (Ursache verstehen, dann suchen)
`_lbl()` (Main.gd ~344) setzt **immer** `autowrap_mode = AUTOWRAP_WORD_SMART` und keine Size-Flags. Ein autowrappendes Label meldet als Mindestbreite ~1 Zeichen. Überall dort, wo ein Container Kindern nur ihre **Mindestbreite** gibt, kollabiert so ein Label zur Buchstabensäule:
- `HBoxContainer`/`HFlowContainer` ohne `SIZE_EXPAND_FILL` auf dem Label
- `GridContainer`-Zellen (Spaltenbreite = Maximum der Mindestbreiten!)
- `CenterContainer`/`PanelContainer`-Ketten, in denen **kein** Kind eine echte Breite vorgibt — dann wird das ganze Fenster so schmal wie der breiteste Button, und lange Labels falten sich
- Verschärft bei **schmalen Fenstern**: `_recalc_scale()`/`_cols()` verkleinern Karten — bei 1280 px tauchen Fälle auf, die bei 2000 px unsichtbar sind

Vorhandene Gegenmittel: `_lbl_fill()` (Label + `SIZE_EXPAND_FILL`, für HBox/HFlow), `autowrap_mode = AUTOWRAP_OFF` (für kurze Chips/Zellen), `custom_minimum_size.x` (für feste Spalten). Referenz-Fix: Talentpool-Filterzeile (Main.gd ~1416).

## Schritte
1. **Statisches Audit:** Jede Stelle prüfen, an der ein `_lbl(...)`-Ergebnis (direkt oder über Variable) in eine HBox, HFlow oder ein Grid wandert — `grep -n "add_child(_lbl(" godot/scripts/Main.gd` plus die Variablen-Fälle (`var x := _lbl(...)` → `row.add_child(x)`). Für jede Fundstelle entscheiden: EXPAND_FILL, AUTOWRAP_OFF oder Mindestbreite. Kein pauschales Ändern von `_lbl()` selbst — lange Fließtexte in VBoxen brauchen das Autowrap.
2. **Modal-Grundbreite:** Prüfen, ob `modal_box` (siehe `_build_modal_layer`/`_open_modal`) eine `custom_minimum_size.x` hat. Falls nein: ~`720 * font_scale` setzen — das beseitigt die ganze Klasse „Modal wird so schmal wie sein breitester Button“ auf einen Schlag (betrifft z. B. Ereignis-Modals mit langen Texten und kurzen Buttons).
3. **Visueller Durchlauf in ZWEI Größen** — alle Tabs und die wichtigsten Modals einmal bei `--resolution 1280x800` und einmal bei `--resolution 2000x1100` screenshotten. Hooks existieren in `Main.gd` (~86–230): start, game, client, deal, rumors, zeitung, planner, verhandlung, coverage, karrierebrett, audition, chemread, pool, backstory. Aufruf-Muster (das `--` ist Pflicht, sonst hängt der Prozess!):
   `Godot_v4.7.1-stable_win64.exe --path godot --resolution 1280x800 -- --shot-<name>`
   Fehlende Hooks für zu prüfende Fenster kurz ergänzen (Muster kopieren).
4. **Fixen** mit den drei Gegenmitteln; pro Fix die schmale Auflösung erneut screenshotten.
5. **Regressionsschutz:** In `Test.gd` ist kein Rendering möglich — stattdessen am Ende des Chunks eine kurze Checkliste der geprüften Fenster in die Commit-Message bzw. hierher ins Dokument (Status-Abschnitt unten ergänzen).

## Bekannte Verdachtsstellen (Startpunkte, nicht abschließend)
- Ereignis-/Ergebnis-Modals (`_show_next_modal`, `_resolve_choice` — Ergebnis-Modal enthält nur RichText + einen Button)
- Mehrparteien-Tisch (`_render_table`), Chem-Read- und Audition-Modals (viele HBox-Zeilen)
- Finanzen-Tab (Grid-/Zeilenlayouts mit fixen Mindestbreiten — bei 1280 px prüfen)
- Zeitungs-Archiv und Coverage-Modals

## Akzeptanzkriterien
- [ ] Headless-Test grün (keine Logikänderung erwartet)
- [ ] Screenshots aller Tabs + der Modal-Verdachtsstellen bei 1280x800 **und** 2000x1100: nirgends mehr eine Buchstabensäule
- [ ] `modal_box`-Mindestbreite gesetzt (oder begründet, warum nicht nötig)
- [ ] .exe neu exportiert
- [ ] Ein Commit: `fix: Buchstaben-Umbruch-Audit — Labels in Shrink-Containern abgesichert`

## Status der geprüften Fenster

- Start/Vorgeschichte → ok; Modal-Grundbreite responsiv abgesichert (`Main.gd:904`).
- Agentur, Klienten, Gerüchte, Talentpool, Castings, Filme, Planer, Finanzen, Chronik → ok.
- Zeitung + Zeitungsarchiv → ok; Archiv-Screenshot-Hook ergänzt (`Main.gd:166`).
- Klienten-Anwerbung, Studio-Pitch, Mehrparteien-Tisch → ok; Pitch-Hinweis gegen Umbruch abgesichert (`Main.gd:1957`), Tischkarten mit Mindestbreite versehen (`Main.gd:2570`).
- Coverage + Coverage-Archiv, Karrierebrett, Audition, Chem-Read → ok.
- Ereignis-Entscheidung + Ereignis-Ergebnis, Produktions-Ergebnis → ok.
- Sichtprüfung vollständig bei 1280×800 und 2000×1100: je 24 Screenshots, alle mit verifizierter Zielauflösung und ohne Buchstabensäulen.
