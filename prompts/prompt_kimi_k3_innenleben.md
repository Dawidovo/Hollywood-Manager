# Prompt für Kimi K3 — Klienten-Innenleben & Fernseh-Umbruch
# (Bedürfnis-System speist Stimmung und Emotionen · Erwartungsgespräche · TV-Ära 1948+ und Streaming 2015+ nach Tonfilm-Muster)

Du arbeitest am Godot-Spiel „Hollywood Manager" (Wirtschaftssimulation: Spieler führt eine Hollywood-Talentagentur, 1925–heute, **englische Spieltexte**, deutsche Doku, **Wochentakt**). **Lies ZUERST `ARCHITECTURE.md` und `DECISIONS.md` im Projektroot — bindend.** **Arbeite NIEMALS parallel zu einer anderen KI-Session am selben Ordner.** Reihenfolge der Pakete: **Opus (Emotions-Dialogsystem) → GPT Sol (Presse) → du.** Fasse `Dialogs.gd`, `Emotions.gd`, `Press.gd` und deren JSON-Bäume **nicht strukturell an**; du lieferst die Simulationstiefe DARUNTER.

## Aktueller Stand (nutzen, nicht neu bauen!)

| System | Wo | Für dich relevant |
|---|---|---|
| Klienten | `Game.state.clients[]`: `mood`, `loyalty`, `trust`, `exhaustion`, `promises`, `narrative`, `films`, Feud/Couple, Comeback, FYC | Deine Bedürfnisse ERKLÄREN diese Werte, statt sie zu ersetzen |
| Klienten-Monatstick | `Game.tick_clients()` | Andockpunkt für Bedürfnis-Drift (kleine Schritte, Muster Gewichts-Drift `_tick_client_weight`) |
| Emotionsmodell (Opus) | `Emotions.true_state("client", ctx)` | Deine dominanten Bedürfnisse verfeinern die `cause`-Zeile. **Fallback-Pflicht:** Zugriff nur via `get_node_or_null("/root/Emotions")`, nie hart referenzieren |
| Attribute & Proben | `Game.attr`, `EvEngine.check_chance/check_label`, Dialog-`check` | Erwartungsgespräch nutzt sichtbare Proben |
| Tonfilm-Umbruch (Vorbild!) | `Util.voice_of`, `Game.voice_at_risk`, `Balance.VOICE_*`/`TALKIE_*`, `data/events/tonfilm.json`, Klientenkarten-Chip | **Exakt dieses Muster** für TV & Streaming kopieren: deterministisches verdecktes Merkmal + Übergangsfenster + JSON-Kette mit `quest`-Block + Chip |
| Planner | `Planner.gd` (21 Slots, Klienten-Aktionen `erholung/pr/training/gala/vorbereitung`) | Bedürfnisse koppeln an Planner-Wochen |
| Balance-Werkzeug | `res://tools/BalanceSim.tscn` — 16-Kampagnen-Matrix (2 Profile × 2 Seeds × 4 Epochen) | **Pflicht vor/nach Balance-relevanten Änderungen**; Stimmungs-/Loyalitätsniveaus dürfen nicht kippen |
| Deterministik | `Util.hashs(seed)` (Körper, Stimme, Chemie) | Pflichtmuster für Bedürfnisprofile & TV-Tauglichkeit |

## Projektkontext (bindend)

- Godot **4.7.1**, alles unter `godot/`; **`index.html`/`js/` eingefroren.** `Game.state` = JSON-Dict; neue Klientenfelder in `Game._apply_save_defaults()` (Klienten-Migrationsblock vorhanden) nachrüsten. Inhalte als **JSON unter `data/`**, englisch. Geld nur über `book()`, × `Util.infl(year)`. Balance-Zahlen nach `Balance.gd`.
- Nach JEDER Code-Änderung: Headless-Test („0 Fehler") + `.exe`-Export; gdlint im Hook; Screenshots mit `-- --shot-<name> --shot-resolution=2000x1100`. Ein Chunk = ein Commit; `prompts/tasks/README.md`/`ARCHITECTURE.md` nachführen.

## Dein Paket

### K1 — Bedürfnis-System `Needs.gd` (neues Autoload) + `data/needs/core.json`

1. **Definitionen datengetrieben:** fünf Bedürfnisse mit `{name, icon, desc}`: `anerkennung` (applause), `sicherheit` (steady work), `kunst` (meaningful parts), `geld` (the check), `ruhe` (privacy & rest). 
2. **Profil deterministisch je Schauspieler:** `Needs.profile(actor) -> {need: gewicht 0–100}` aus `Util.hashs` + Plausibilitäts-Nudges (hoher `ego` → `anerkennung`+; `peakFame` niedrig → `sicherheit`+; Prestige-Genres → `kunst`+). Kein Save-Feld nötig.
3. **Erfüllungsstand pro Klient:** `c.needsSat = {need: 0–100}` (Save-Feld + Migration, Start 55). Monatliche Drift in `tick_clients` über EIN neues `Needs.tick_client(c)`: Rollen/Releases füttern `anerkennung`/`kunst`/`geld` (Lead vs. Support, Prestige, Gage relativ zur Erwartung), Beschäftigungslücken zehren an `sicherheit`, Galas/PR-Wochen zehren an `ruhe`, Erholung füllt sie (Planner-Kopplung über die vorhandene Wochenauswertung — kleine, klar benannte Hooks).
4. **Wirkung statt Parallelwelt:** das am schlechtesten erfüllte Bedürfnis mit Sat < 35 drückt monatlich `mood` (−2) und ab < 20 auch `loyalty` (−1). NICHTS anderes direkt — alle weiteren Folgen laufen über die bestehende Stimmungs-/Loyalitätsmechanik (Abwerbe-Duelle, Vertragsgespräche greifen dann von selbst).
5. **Sichtbarkeit gestaffelt über Menschenkenntnis** (konsequent zum Emotionsmodell): Klientenkarte zeigt eine „What drives them"-Zeile — attr < 30: nichts; 30–54: nur das Top-Bedürfnis-Icon; ≥ 55: Top-Bedürfnis + aktueller Engpass; ≥ 75: volles Mini-Profil (5 Icons mit Balken). 
6. **Emotions-Anbindung (mit Fallback):** wenn `Emotions` existiert, liefert `Needs.grievance_cause(c)` die präzisere `cause`-Zeile für Klienten-Emotionen („starving for applause since the spring").

### K2 — Das Erwartungsgespräch (JSON-Begegnung)

Halbjährlich ODER wenn ein Bedürfnis unter 25 fällt (1× pro Halbjahr pro Klient): Brief „{client} wants to talk" → Dialogbaum `data/dialogs/erwartung.json` (3 Phasen): der Klient benennt (je nach Spieler-Menschenkenntnis klar oder verklausuliert) sein Engpass-Bedürfnis; der Spieler kann **konkret zusagen** (nutzt das VORHANDENE Versprechens-System — `promise`-Op mit Frist: Lead-Rolle, Prestige-Projekt, Auszeit, Gagen-Sprung), vertrösten (Probe `verhandlung`) oder ehrlich absagen (Vertrauen +, Stimmung −). Gehaltene Zusagen füllen das Bedürfnis stark auf; gebrochene wirken doppelt (bestehende Promise-Strafen + Bedürfnis-Einbruch). `quest`-Block, damit die Frist im Journal steht.

### K3 — Fernseh-Umbruch 1948–1962 & Streaming-Umbruch 2015+ (Tonfilm-Muster)

Zwei Übergangsfenster, exakt nach dem Vorbild `tonfilm.json` + `voice_of` — aber mit CHANCEN, nicht nur Risiko:
1. **TV-Tauglichkeit** `Util.tv_appeal(actor)` (deterministisch, 20–100; Nähe/Charisma-Nudge): Im Fenster 1948–1962 bekommen Klienten mit hohem Wert TV-Angebote (Eventkette `data/events/fernsehen.json`: Serie annehmen = stetiges Einkommen + `sicherheit`/`geld`-Bedürfnisse rauf, Kino-DNA `popular`+ aber `unikat`−, Prestige-Casting-Malus solange aktiv — nutzt das vorhandene `tvIncome`-Flag statt Neubau); niedrige Werte: keine Strafe, nur keine Angebote. Ablehnen ist immer okay.
2. **Streaming 2015+** (`data/events/streaming.json`): Algorithmus-Serienangebote (kurze Laufzeiten — Produktionszeiten sind ab 2015 schon kürzer), Binge-Ruhm: schneller `heat`, schnellerer Verfall (kleines, klar benanntes Extra in `tick_clients` nur im Fenster); `likenessRights`-Klausel als wiederkehrender Konfliktpunkt (Kette mit `quest`-Block).
3. Beide Ketten: mind. je 2 Glieder, Emotions-Gates wo sinnvoll, Chips auf der Klientenkarte (`📺 TV name` / `📱 Streaming darling`), Konstanten in `Balance.gd`.

### K4 — Tests, Balance & Sichtprüfung

- `tests/Test.gd`: Profil deterministisch & plausibel genudged; `needsSat`-Migration alter Stände; Drift bewegt sich in erwarteter Richtung (Lücke → `sicherheit` sinkt; Erholungswoche → `ruhe` steigt); Engpass drückt `mood`; Erwartungsgespräch-Baum lädt & ein Pfad legt ein echtes Versprechen an; gehaltenes Versprechen füllt das Bedürfnis; `tv_appeal` deterministisch; TV-Kette nur im Fenster & nur bei hohem Appeal; Streaming-Heat-Verfall nur ab 2015; Save/Load-Roundtrip.
- **BalanceSim vorher/nachher** (16 Kampagnen): Stimmung/Loyalität/Abwerbe-Häufigkeit dürfen sich nur moderat verschieben (SUM-Zeilen vergleichen, Befund im Commit-Text dokumentieren); Energie-/Cash-Korridore unverändert.
- Screenshots: `--shot-client` (Bedürfnis-Zeile bei hoher Menschenkenntnis) und `--shot-fernsehen` (TV-Angebots-Event).

## Abnahme
- Headless-Test „0 Fehler", gdlint sauber, .exe neu exportiert, BalanceSim-Vergleich dokumentiert, Screenshots.
- Inhalte in JSON, Werte in `Balance.gd`, Schema-Ergänzungen in `godot/data/README.md`; kein struktureller Eingriff in Dialog-/Emotions-/Presse-Code.
- Commits (je einer): `feat: Klienten-Innenleben — Beduerfnisse treiben Stimmung und Gespraeche` · `feat: Erwartungsgespraech — Beduerfnisse werden zu Versprechen` · `feat: Fernseh- und Streaming-Umbruch nach Tonfilm-Muster`.
