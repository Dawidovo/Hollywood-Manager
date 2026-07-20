# Chunk 13 — Verhandlungs-Dialoge homogenisieren

## Ziel
Alle Verhandlungs-Oberflächen sehen gleich aus und bedienen sich gleich: gleicher Kopfbereich, gleiche Stimmungs-/Fortschrittsanzeige, gleiche Button-Reihenfolge und -Beschriftung, gleiche Ergebnis-Modals. **Reines UI-Refactoring — keine Änderung an der Verhandlungslogik in `Game.gd`.**

## Kontext: die fünf Verhandlungs-UIs in `godot/scripts/Main.gd`
| UI | Funktion(en) | Eigenheiten heute |
|---|---|---|
| Klienten-Anwerbung | `_render_negotiation` (~1492) | Slider + Runden-Zähler „Runde x/y“, Hinweistexte, 2-Spalten-Layout |
| Studio-Pitch | `_open_pitch` (~1704) → `_render_studio_offer` (~1999) | Angebot als RichText, Buttons „Nachverhandeln“/„Package“, **BBCode-Tippfehler** `[b]%s[\b]` in Zeile ~2005 (muss `[/b]` heißen) |
| Mehrparteien-Tisch | `_render_table` (~2320) | „Zugeständnisse übrig: N“ statt Runden, eigener Kopfstil |
| Produktions-Nachverhandlung | `prod_renegotiate`/`prod_pull_client`/`prod_demand_share` via `_show_simple_modal` (~2277) | Nur Ergebnistext, kein einheitlicher Kopf |
| Event-Entscheidungen mit Verhandlungscharakter | `_show_next_modal`/`_resolve_choice` (~2283) | Ergebnis-Modal trägt als Titel nur „…“ |

Vorhandene Bausteine: `_lbl`/`_lbl_fill`/`_rich`/`_btn(text, cb, primary)`/`_chip`/`_chip_row`, `Game.mood_label(score)` (liefert [Text, pos/neg]), `Game.fmt_money()`. Geld **immer** über `fmt_money`, nie eigene Formatierung.

## Schritte
1. **Bestandsaufnahme:** Alle fünf UIs durchgehen und Abweichungen listieren (Kopf, Untertitel, Stimmung, Buttons, Abbruch-Beschriftung, Ergebnis-Modal). Erst danach bauen.
2. **Gemeinsame Bausteine** in Main.gd:
   - `_nego_header(icon_title: String, subtitle: String, chips: Array = [])` — Titelzeile (22, ACC), DIM-Untertitel, optionale Chip-Zeile (z. B. „Runde 2/4“, Stimmungs-Chip). Überall verwenden.
   - `_nego_actions(primary, secondary, cancel)` — feste Reihenfolge: Primäraktion (primary=true) oben/links, dann Sekundäraktionen, **Abbruch immer zuletzt und immer „Abbrechen“** (nicht „Zurück“, nicht „Nur einen Klienten pitchen“ — solche Sonderfälle als Sekundäraktion mit sprechendem Label über dem Abbrechen-Button).
   - `_show_outcome_modal(title: String, bbcode: String)` — ersetzt die „…“-Titel in `_resolve_choice` durch den Titel des auslösenden Ereignisses + „ — Ergebnis“.
3. **Stimmung vereinheitlichen:** Wo ein Score existiert (`Game.mood_label`), überall derselbe Chip (Farbe GREEN/RED/DIM nach pos/neg). Runden bzw. Zugeständnisse als Chip im Kopf, gleiche Optik.
4. **Umbauen:** die fünf UIs auf die Bausteine umstellen; BBCode-Fehler `[\b]` fixen; dabei nichts an Aufruf-Reihenfolgen oder `Game.*`-Logik ändern.
5. **Screenshots:** bestehende Hooks nutzen/ergänzen (`--shot-verhandlung` existiert; ggf. `--shot-pitch`, `--shot-tisch` analog zu den vorhandenen Hooks in `Main.gd` ~86–230 anlegen). Aufruf: `Godot_v4.7.1-stable_win64.exe --path godot --resolution 2000x1100 -- --shot-verhandlung` (das `--` ist Pflicht).

## Akzeptanzkriterien
- [ ] Headless-Test grün (Verhandlungslogik-Tests unverändert bestanden)
- [ ] Alle fünf UIs nutzen `_nego_header`/`_nego_actions`; kein Ergebnis-Modal mit „…“-Titel mehr
- [ ] BBCode-Fehler in `_render_studio_offer` behoben
- [ ] Screenshots der Verhandlungs-UIs sehen einheitlich aus (Kopf, Chips, Button-Reihenfolge)
- [ ] .exe neu exportiert
- [ ] Ein Commit: `refactor: Verhandlungs-Dialoge auf gemeinsame UI-Bausteine vereinheitlicht`
