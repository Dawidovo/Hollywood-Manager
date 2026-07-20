# Prompt für Kimi K3 — Einschätzungs-Cluster (Minispiele)
# (Script Coverage · Die perfekte Rollenserie)

Du arbeitest am Godot-Spiel „Hollywood Manager“ (Wirtschaftssimulation: Spieler führt eine Hollywood-Talentagentur, 1925–heute, deutsche UI, Monatstakt). **WICHTIG: Arbeite NIEMALS parallel zu einer anderen KI-Session am selben Ordner — nur nacheinander.** Ein zweites Team (GPT Sol) bearbeitet den Bühnen-Cluster (Vorsprechen-Minispiel, Chemistry Read) — überschneide dich nicht mit diesen Themen. Falls dessen Ergebnisse schon im Code sind (z. B. `state.audition`, `state.directors`): nutzen, nicht umbauen. **Die Webversion (`index.html`, `js/`) ist EINGEFROREN — niemals anfassen, nur `godot/`.**

## Bereits implementiert (NICHT neu bauen — nutzen und erweitern!)

| Feature | Status | Wo/Wie |
|---|---|---|
| Karriere-DNA (5 bipolare Image-Achsen) | ✅ | `Game.DNA_AXES`, `GENRE_DNA`, `imprint_dna(c, genre, mult, prestige, ratio)`, `dna_fit()`, `dna_label()`, Decay bei Untätigkeit |
| Gerüchte, Geheimnisse, Gefallen, Finanzbilanz (`book()`), Zeitung, Narrative, Rivalen, Identität | ✅ | siehe Game.gd/Newspaper.gd — Geld NUR über `book()` |
| **Instinct & Prognosen** | ✅ | `state.instinct` (0–100, Start 20), `add_prediction(type_s, subject, guess, due_mi, note_s)` → `state.predictions[]`, Auflösung in `end_month`: richtig +3 (nie unter 5 bei falsch −1). **Dein zentraler Andockpunkt!** |
| Verdeckte Qualität & Signale | ✅ | Produktions-Qualität versteckt, `script_insight(casting)` (Genauigkeit steigt mit Instinct), `prod.signals[]` unzuverlässig |
| Vertragsklauseln | ✅ | `c.clauses[]` / `role.filled.clauses[]` (sequelOption, moralClause, profitShare, …) |
| Mehrparteien-Verhandlung, Chemie, Wochenplaner | ✅ | Veto+Rückweg, `chemistry(a,b)`, `state.planner` (Spieler-Slot `Scouting`, Klienten-Slot `Vorbereitung`) |
| Narrative (Karriereerzählungen) | ✅ | `c.narrative = {type, startedMi, progress, status}` — dein Karrierebrett muss damit verzahnen, nicht konkurrieren |

## Projektkontext (unbedingt einhalten)

- Pfad `C:\Users\Anwender\Desktop\Hollywood Manager\godot`, Godot **4.7.1**, GDScript. Autoloads: `Data`, `Game` (Game.gd ~3050 Zeilen), `Ev` (Events.gd), `Jukebox`, `Newspaper`. UI in Code: `Main.gd` (~1930 Zeilen).
- **`Game.state` = reines JSON-Dictionary** (`user://hm_save.json`). Keine Callables im State. Neue Felder in `Game.load_game()` migrieren (Muster vorhanden). Nach JSON-Load sind Zahlen floats → `int()` bei Indizes.
- Events: `Ev.all_events()` → `[{id, cd, weight: Callable->float, build: Callable->{title, text (BBCode), choices}}]`; `end_month()` liefert Modal-Dicts.
- UI-Helfer: `_lbl/_rich/_btn/_card/_grid/_bar/_chip/_chip_row`, Modal-System, Tabs via `render()` + `_render_<tab>()`. `ACC` dynamisch, `GREEN/RED/AMBER/BLUE` fest.
- Designregeln: deutsche Texte mit Hollywood-Flair, **kein unvermeidbarer Frust** — Minispiele immer überspringbar, ohne Strafe fürs Überspringen. `Game.chance/rndi/pick/hashs`, `fmt_money`, Beträge × `infl(year)`.
- **UI-Fallstricke:** (1) Labels neben `SIZE_EXPAND_FILL`-Labels in HBox → `autowrap_mode = AUTOWRAP_OFF`. (2) `_clear()` so lassen. (3) Modals ohne ScrollContainer. (4) `inference_on_variant` = warn.
- **Versprechen-Regel:** Jeder neue Deal-Pfad, der eine Rolle verschafft, ruft `check_promises_on_deal(c, casting_oder_prod, role)` auf.

## Deine Features

### C. Script Coverage
Monatlich liegt mit Wahrscheinlichkeit ~0,6 (mind. 1× pro Quartal, per `state.coverageQueue` gesteuert) ein **Coverage-Bogen** auf dem Schreibtisch: eine stark verkürzte Drehbuchübersicht zu einem KOMMENDEN Casting des Folgemonats (das Casting wird dafür 1 Monat vorab erzeugt und `hidden` gehalten).
- **Generierung aus echten Sim-Daten:** Logline aus Titel/Genre/Studio-Stil, 4–6 Aussagen-Häppchen gemischt aus echten Indikatoren (versteckte Qualitätsbasis, Budget vs. Genre-Nachfrage, Regisseur-Historie, geplante Klauseln, Rollen-Zuschnitt) und **Rauschen** (Zuverlässigkeit ~70 %, steigt mit Instinct — nutze das `script_insight`-Muster).
- **Unter Zeitdruck markieren:** Der Spieler hat nur **2 Marker** (3 ab Instinct 60) und ordnet Aussagen den Kategorien zu: `sichere Rolle` / `Prestigechance` / `schwaches Drehbuch` / `möglicher Überraschungserfolg` / `Gefahr: Rolle wird geschnitten` / `problematische Produktion`. Zeitdruck diegetisch: Der Bogen verfällt am Monatsende (kein Echtzeit-Timer — Monatstakt-Spiel!).
- **Auflösung über die Prognose-Pipeline:** Jeder gesetzte Marker wird ein `add_prediction("coverage", …)` mit passender Prüfbedingung beim Release (z. B. `schwaches Drehbuch` → ratio < 1; `Rolle geschnitten` → per Klausel/Event beim Release ausgewürfelt, Wahrscheinlichkeit aus verstecktem Zuschnitts-Flag). Richtig → Instinct +3 über die bestehende Auflösung, plus kleiner konkreter Vorteil (z. B. bei `Prestigechance` korrekt: +5 Fit beim Pitch auf dieses Casting); falsch → nur der normale Instinct-Malus.
- UI: Karte im Agentur-Tab + eigenes Modal (Bogen-Optik, Schreibmaschinen-Duktus vor 1970, Listicle-Ton ab 2010). Archiv der letzten 8 Bögen mit Treffer-Bilanz.
- Ablage: `state.coverage = {current: {castingRef, statements: [{text, truthKey, marked}], dueMi}, history: []}`, JSON-safe, Migration.

### D. Die perfekte Rollenserie (Karrierebrett)
Pro Klient ein **Karrierebrett** (Sektion im Klienten-Tab): 3 Plan-Slots für die nächsten Projekte, je Slot wählt der Spieler ein **Rollenprofil** (Genre + Rollentyp Haupt/Neben + Prestige-Stufe) — kein konkreter Film, ein Vorsatz.
- **Reihenfolge-Logik ist der Kern:** Bewerte die geplante Sequenz mit einer Vorschau der DNA-Trajektorie (nutze `GENRE_DNA` + `imprint_dna`-Formeln read-only für die Simulation): Kontrast-Sequenzen (Komödie → Thriller → Drama) erzeugen einen `Wandlungs-Bonus` (Presse feiert Vielseitigkeit, DNA-Achse „einzigartig“ +), Wiederholungs-Sequenzen (3× Action) erzeugen `Typecast-Sog` (schnellerer Fame-Gewinn kurzfristig, aber `austauschbar`-Drift und ab Slot 3 Typecast-Risiko-Flag). Die Vorschau zeigt beide Seiten ehrlich („schneller Ruhm vs. festgefahrenes Image“) — es gibt legitime Gründe für beide Wege.
- **Erfüllung:** Nimmt der Klient tatsächlich eine Rolle an, die dem nächsten offenen Slot entspricht (Genre ODER Rollentyp+Prestige passt), rückt das Brett vor: passende Rolle → `imprint_dna`-Mult ×1,5 und Slot-Bonus (Heat +1, bei komplettem 3er-Plan: Fame +4, Zeitungs-Story „Die Neuerfindung des …“, Narrativ-Fortschritt falls `c.narrative` aktiv und kompatibel). Unpassende Rolle → Brett verschiebt sich (Slot bleibt offen), KEIN Malus — Pläne ändern sich in Hollywood.
- **Verzahnung, nicht Konkurrenz zu Narrativen:** Ein aktives Narrativ (z. B. Comeback) schlägt passende Rollenprofile für die Slots vor (Ein-Klick-Übernahme). Brett-Abschluss zählt als Narrativ-Progress.
- Verfall: Slots älter als 30 Monate verfallen still (Log-Notiz, kein Schaden).
- Ablage: `c.careerBoard = {slots: [{genre, roleType, prestige, filledMi}], startedMi}`, JSON-safe, Migration in `load_game()`.

## Abnahme
- `tests/Test.gd` erweitern: Coverage-Bogen generiert ≥ 4 Aussagen aus echten Sim-Daten, Marker erzeugt Prognose, korrekte Markierung erhöht Instinct beim Release (+3) und falsche senkt nie unter 5, „Rolle geschnitten“-Auflösung feuert, Bogen verfällt am Monatsende; Karrierebrett: Kontrast-Sequenz erzeugt Wandlungs-Bonus und ×1,5-Imprint, Wiederholungs-Sequenz setzt Typecast-Risiko, unpassende Rolle erzeugt keinen Malus, kompletter 3er-Plan → Fame-Bonus + Zeitungs-Story, Save/Load-Roundtrip von `state.coverage` und `c.careerBoard`.
- Testlauf: `"C:\Users\Anwender\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:\Users\Anwender\Desktop\Hollywood Manager\godot" res://tests/Test.tscn` → muss „0 Fehler“ enden (Tests setzen `Jukebox._current_key` vor `end_month`, Muster vorhanden).
- UI-Sichtprüfung über Screenshot-Flags (Muster `--shot-game` in Main.gd `_ready`; ergänze `--shot-coverage` und `--shot-karrierebrett`). PNGs landen im Projektroot (`shot_*.png`, gitignored).
- **Abschließend die .exe neu exportieren:** `…Godot_console.exe --headless --path godot --export-release "Windows Desktop" "build/HollywoodManager.exe"` (Templates installiert, Preset vorhanden).
