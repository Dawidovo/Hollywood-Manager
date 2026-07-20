# Prompt für GPT Sol — Bühnen-Cluster (Minispiele)
# (Das entscheidende Vorsprechen · Der Chemistry Read)

Du arbeitest am Godot-Spiel „Hollywood Manager“ (Wirtschaftssimulation: Spieler führt eine Hollywood-Talentagentur, 1925–heute, deutsche UI, Monatstakt). **WICHTIG: Arbeite NIEMALS parallel zu einer anderen KI-Session am selben Ordner — nur nacheinander.** Ein zweites Team (Kimi) bearbeitet danach den Einschätzungs-Cluster (Script Coverage, Karrierebrett „Perfekte Rollenserie“) — überschneide dich nicht mit diesen Themen. **Die Webversion (`index.html`, `js/`) ist EINGEFROREN — niemals anfassen, nur `godot/`.**

## Bereits implementiert (NICHT neu bauen — nutzen und erweitern!)

| Feature | Status | Wo/Wie |
|---|---|---|
| Karriere-DNA (5 bipolare Image-Achsen) | ✅ | `Game.DNA_AXES`, `imprint_dna()`, `dna_fit()`, `dna_label()` |
| Gerüchtenetzwerk, Geheimnisse & Vertrauen, Gefallen & Schulden | ✅ | `state.rumors[]` (belief/industryBelief), `SECRET_TYPES`, `FAVOR_KINDS`, `grant/consume_favor` |
| Finanzbilanz | ✅ | `book(amount, cat, text)` — JEDE Geldbewegung MUSS darüber laufen |
| Zeitung, Narrative, Rivalen, Identität, Machtfiguren | ✅ | `Newspaper.gd` `build_newspaper()`, `c.narrative`, `state.rivals[]`, `state.identity`, `state.powerFigures[]` |
| Instinct & Prognosen | ✅ | `state.instinct` (0–100), `add_prediction(type, subject, guess, due_mi)` — Auflösung in `end_month` |
| Vertragsklauseln | ✅ | `c.clauses[]` / `role.filled.clauses[]` (sequelOption, creativeApproval, …), Folge-Events prüfen Klausel im `weight` |
| Mehrparteien-Verhandlung | ✅ | Nach `submit_pitch` bei großen Hauptrollen: Positions-Karten Studio/Regisseur/Klient, Zufriedenheits-Scores, Veto + Rückweg, `role.filled.billing` |
| Beziehungschemie | ✅ | `chemistry(a_key, b_key) -> {screen: -10..+10, personal: -10..+10}` deterministisch via `hashs()`, Historie `state.history_pairs` |
| Produktionssignale | ✅ | `prod.signals[]`, unzuverlässig (~70 %, mit Instinct steigend), Reaktionen je 1×/Film |
| Wochenplaner | ✅ | `state.planner`, Slot `Vorbereitung` (nächster Pitch +8 Fit) — dein Andockpunkt! |

## Projektkontext (unbedingt einhalten)

- Pfad `C:\Users\Anwender\Desktop\Hollywood Manager\godot`, Godot **4.7.1**, reines GDScript. Autoloads: `Data`, `Game` (Game.gd ~3050 Zeilen), `Ev` (Events.gd), `Jukebox`, `Newspaper`. UI in Code: `Main.gd` (~1930 Zeilen).
- **`Game.state` = reines JSON-Dictionary** (`user://hm_save.json`). Keine Callables im State. Neue Felder in `Game.load_game()` per Default-Migration nachrüsten (Muster vorhanden). Nach JSON-Load sind Zahlen floats → `int()` bei Indizes.
- UI-Helfer (Main.gd): `_lbl/_rich/_btn/_card/_grid/_bar/_chip/_chip_row`, Modal-System, Tabs via `render()` + `_render_<tab>()`. Epochen-Akzent `ACC` dynamisch, semantische Farben `GREEN/RED/AMBER/BLUE` fest.
- Designregeln: deutsche Texte mit Hollywood-Flair (`[i]„…“[/i]`-Zitate), **kein unvermeidbarer Frust** — Minispiele sind immer überspringbar (Standard-Ausgang ≈ bisheriges Verhalten ohne Minispiel), `Game.chance/rndi/pick/hashs`, `fmt_money`, Beträge × `infl(year)`, Geld NUR über `book()`.
- **UI-Fallstricke:** (1) Labels neben `SIZE_EXPAND_FILL`-Labels in HBox → `autowrap_mode = AUTOWRAP_OFF`. (2) `_clear()` macht `remove_child`+`queue_free` — so lassen. (3) Modals ohne ScrollContainer. (4) `inference_on_variant` = warn.
- **Versprechen-Regel:** Jeder neue Deal-Pfad, der eine Rolle verschafft, ruft `check_promises_on_deal(c, casting_oder_prod, role)` auf.

## Deine Features

### A. Das entscheidende Vorsprechen
Bei Hauptrollen mit Prestige ≥ 2 (und per Event gelegentlich bei Nebenrollen) kann der Spieler statt des normalen Pitches ein **Vorsprechen** wählen (Button im Pitch-Modal: „Zum Vorsprechen antreten“). Ablauf als Modal-Sequenz:
1. **Briefing:** Rolle, Regisseur (nutze die Regisseur-Figur der Mehrparteien-Verhandlung; Name deterministisch aus `hashs(prod_title)`), bekannte Konkurrenz (1–2 Rivalen-Klienten mit `dna_label`).
2. **Vier Entscheidungen:** Szene (3 Optionen aus dem Genre generiert: die große Rede / der stille Moment / die Konfrontation), Interpretation (werktreu / modern / gewagt), Auftreten (Glamour / seriös / in der Rolle erscheinen), Betonung (Charme / Professionalität / künstlerischer Mut).
3. **Begrenzte Vorbereitung:** Nur 2 der 4 Entscheidungen dürfen „vorbereitet“ werden (Bonus); mit Planner-Slot `Vorbereitung` des Klienten: 3. Unvorbereitete Entscheidungen würfeln mit.
- **Der Regisseur hat ein verstecktes Anforderungsprofil** (deterministisch aus `hashs(director_name + prod_title)` über die 4 Dimensionen — KEINE perfekte Kombination, Profil ist pro Film anders). Hinweise vorab: `scriptAccess`-Gefallen einlösen → 1 Dimension aufgedeckt; Regisseur-Chemie `personal > 3` → 1 Hinweis; hoher Instinct (≥ 60) → „Bauchgefühl“-Tendenz; Zeitungs-Archiv erwähnt Vorlieben früherer Filme desselben Regisseurs.
- **Auswertung:** Übereinstimmungs-Score + `dna_fit` + Talent vs. Konkurrenz-Wurf. Sieg → Rolle mit Gagen-Bonus +10 % und `personal`-Chemie zum Regisseur +2; knappe Niederlage → Trostpreis (Nebenrollen-Angebot oder Gefallen des Studios); klare Niederlage → nur geringer Fit-Malus fürs nächste Mal bei DIESEM Regisseur (kein Dauerschaden). Ergebnis speist Zeitung („Wer bekam die Traumrolle?“) und ggf. Narrativ-Fortschritt.
- Ablage: `state.audition = null | {castingId, roleIdx, clientId, step, choices, revealed}` (JSON-safe), Regisseur-Gedächtnis kompakt in `state.directors = {name: {liked: [...], lastSeen}}`.

### B. Der Chemistry Read
Wenn in einem Casting BEIDE Hauptrollen offen sind (oder per Event „Das Studio will ein Traumpaar“): Spieler stellt 2 Kandidaten-Paarungen aus eigenen Klienten (+ ggf. 1 NPC-Vorschlag des Studios) zusammen und wählt eine Testszene (Liebesszene / Streitszene / Komödien-Timing).
- **Kern:** Gute Einzelleistung ≠ gute Paarung. Angezeigt werden NICHT die `chemistry()`-Werte, sondern **indirekte Signale**: Körpersprache-Prosa („Sie vervollständigt seine Sätze“ / „Er weicht ihrem Blick aus“ — aus `screen`-Wert generiert, mit ~75 % Zuverlässigkeit), gemeinsame Filme aus `state.history_pairs` mit damaligem Erfolg, `personal`-Andeutungen aus dem Gerüchtenetzwerk.
- Die Testszene gewichtet: Liebesszene verlangt `screen`, Streitszene verzeiht schlechtes `personal` (Reibung nützt!), Komödie braucht beides moderat positiv.
- **Auswertung:** Beste Paarung gewählt → beide Rollen besetzt, Package-Bonus +12 % analog `try_package`, Set-Signal „Die Chemie stimmt“ vorgemerkt; mittlere Wahl → normale Besetzung; schlechteste → Studio besetzt eine Rolle fremd, aber der eigene Klient bleibt drin (Rückweg!). Ergebnis in Zeitung + `history_pairs` fortschreiben.
- Immer überspringbar („Nur einen Klienten pitchen“ = bisheriger Weg).

## Abnahme
- `tests/Test.gd` erweitern: Regisseur-Profil deterministisch (2× gleicher Seed = gleiches Profil), aufgedeckter Hinweis stimmt mit Profil überein, Sieg-Pfad besetzt Rolle + ruft `check_promises_on_deal`, Niederlage hat Rückweg ohne Dauerschaden; Chemistry Read: beste Paarung gewinnt bei fixem Seed, Signale-Prosa passt zum Vorzeichen des `screen`-Werts (bei deaktiviertem Rauschen), Fremdbesetzungs-Pfad lässt eigenen Klienten in der Rolle, Save/Load-Roundtrip von `state.audition`/`state.directors`.
- Testlauf: `"C:\Users\Anwender\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:\Users\Anwender\Desktop\Hollywood Manager\godot" res://tests/Test.tscn` → muss „0 Fehler“ enden (Tests setzen `Jukebox._current_key` vor `end_month`, Muster vorhanden).
- UI-Sichtprüfung über Screenshot-Flags (Muster `--shot-game` in Main.gd `_ready`; ergänze `--shot-audition` und `--shot-chemread`). PNGs landen im Projektroot (`shot_*.png`, gitignored).
- **Abschließend die .exe neu exportieren:** `…Godot_console.exe --headless --path godot --export-release "Windows Desktop" "build/HollywoodManager.exe"` (Templates installiert, Preset vorhanden).
