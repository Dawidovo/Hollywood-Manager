# Prompt für GPT Sol — Presse-Begegnungen: Interviews, Pressekonferenzen & Ära-Formate
# (Mehrstufige Pressegespräche · Journalisten mit Agenda · Skandal-Auftritte · vom Radiointerview zur Talkshow)

Du arbeitest am Godot-Spiel „Hollywood Manager" (Wirtschaftssimulation: Spieler führt eine Hollywood-Talentagentur, 1925–heute, **englische Spieltexte**, deutsche Doku, **Wochentakt**). **Lies ZUERST `ARCHITECTURE.md` und `DECISIONS.md` im Projektroot — bindend.** **Arbeite NIEMALS parallel zu einer anderen KI-Session am selben Ordner.** Reihenfolge der Pakete: **Opus (Emotions-Dialogsystem) zuerst, dann du, dann Kimi.** Fasse `Dialogs.gd`, `Emotions.gd` und `data/dialogs/begegnungen.json` **nicht strukturell an** — du konsumierst deren Schema und API nur über JSON-Inhalte und Aufrufe.

## Aktueller Stand (nutzen, nicht neu bauen!)

| System | Wo | Für dich relevant |
|---|---|---|
| Dialogbäume | `Dialogs.gd`, Schema in `godot/data/README.md` | Deine Interviews sind **reine JSON-Dialogbäume** — Knoten, Choices, `check` (inkl. `attr`-Proben nach Opus-Paket), Platzhalter |
| Emotionsmodell (Opus-Paket) | `Emotions.true_state/perceived` | Journalisten-Emotionen im Interview anzeigen. **Fallback-Pflicht:** falls das Paket noch fehlt, via `Engine.get_main_loop().root.get_node_or_null("/root/Emotions")` prüfen und ohne Chip weiterspielen — niemals hart referenzieren |
| Skandal-System | `Scandal.gd`: Gerüchte (`belief`, `holders`), Gegenmaßnahmen, Geheimnisse | Auslöser & Munition der Pressekonferenz |
| Zeitung | `Newspaper.gd`, `state.newspaper`, `press_event(cat, text)` | Deine Auftritte erzeugen Schlagzeilen — IMMER über `press_event` |
| Attribute & Proben | `Game.attr("diskretion"/"verhandlung"/…)`, `EvEngine.check_chance/check_label` | Antworten im Interview sind sichtbare Proben |
| Kontakte | `Network.gd` (Dimensionen, Fakten), Kolumnisten/Journalisten als Kontakttypen | Der Interviewer ist wenn möglich ein ECHTER Kontakt (`ctid` im ctx) — Beziehung färbt Fragen und Folgen |
| Briefe/Dispatcher | `data/letters/` (`manual: true`-Templates), `Dialogs.spawn_letter_for`, `dispatch` | Interview-Anfragen kommen als Post; Annahme öffnet den Dialogbaum (`"dialog"`-Feld im Brief-Choice) |
| Ären | `Util.infl`, `min_year/max_year`-Bedingungen überall, Tonfilm-Muster (`data/events/tonfilm.json`) | Formatwechsel je Epoche |

## Projektkontext (bindend)

- Godot **4.7.1**, alles unter `godot/`; **`index.html`/`js/` eingefroren.** `Game.state` = JSON-Dict, Migration in `Game._apply_save_defaults()`. Inhalte als **JSON unter `data/`**, englische Texte mit Hollywood-Flair. Geld nur über `Game.book()` (Agentur) bzw. `Persona.book()` (privat), Beträge × `Util.infl(year)`.
- UI: `Main.gd` = Gerüst; Tabs in `scripts/ui/`. Für dich reicht fast überall die Brief→Dialog-Schiene; neue Screens nur, wenn unvermeidbar (dann `ui/`-Muster mit Main-Referenz).
- Nach JEDER Code-Änderung: Headless-Test (`… res://tests/Test.tscn`, „0 Fehler") + `.exe`-Export. gdlint im Pre-Commit-Hook. Screenshots: `-- --shot-<name> --shot-resolution=2000x1100`. Ein Chunk = ein Commit; `prompts/tasks/README.md` und `ARCHITECTURE.md` nachführen.

## Dein Paket: Die Presse als Bühne

### P1 — Interview-Anfragen & mehrstufige Interview-Dialoge (nur JSON + minimale Verdrahtung)

1. **Anfragen als Post:** 3 Brief-Templates in `data/letters/interviews.json` — (a) Porträt über einen Klienten (braucht Klient mit Ruhm ≥ 40), (b) Hintergrundgespräch über die Agentur (ab Karriere-Stufe 1), (c) „Zwischen den Zeilen" — ein Kolumnist fischt nach einem laufenden Gerücht (`requires` sinngemäß: bekanntes Gerücht existiert). Annahme kostet Kontaktzeit (`ap`) und öffnet den jeweiligen Dialogbaum.
2. **Drei Interviewbäume** in `data/dialogs/interviews.json`, je **3+ Fragerunden** mit Agenda-Dramaturgie: warme Eröffnungsfrage → Kernfrage mit Falle → Nachfassen je nach Antwort. Bausteine:
   - Antworten als **sichtbare Proben** (`check` auf `diskretion`, `verhandlung` oder `menschenkenntnis`) und **Emotions-Gates** (`requires_emotion` — der Journalist öffnet Türen nur, wenn er `warm`/`hopeful` ist).
   - Einsätze: gute Antworten → `press_event`-Schlagzeile positiv, `player.pubRep +`, Klienten-`heat +`, evtl. `favor_grant suppressStory`; Patzer → negatives Blatt, Gerücht-`belief +` (über bestehende Ops), `dims`-Schaden beim Interviewer.
   - Der Interviewer merkt sich Verhalten (`fact`/`memory`-Ops): wer zweimal ausweicht, bekommt beim nächsten Mal härtere Eröffnungen (Bedingung über `dims`/Fakten).
3. **Verdrahtung:** ausschließlich über vorhandene Letter-/Dialog-Mechanik; keinerlei Änderungen an `Dialogs.gd`-Logik. Falls ein fehlender Effekt-Op nötig scheint: erst prüfen, ob `chance`/`player`/`dims`/`rumor`-Kombination reicht — neue Ops nur mit gutem Grund und Doku.

### P2 — Pressekonferenz bei Skandal (`Press.gd`, klein)

Wenn ein Gerücht über einen eigenen Klienten `belief ≥ 55` erreicht, bietet ein Brief die **Pressekonferenz** an (einmal pro Gerücht): kleines neues Autoload `Press.gd` NUR für die Auslöse-/Buchhaltungslogik (welches Gerücht, Cooldowns), die Szene selbst ist ein Dialogbaum `data/dialogs/pressekonferenz.json`:
- Podium-Dramaturgie: Eröffnungsstatement (Ton wählen: Demut/Gegenangriff/Witz — prägt die Folgerunden), zwei Fragerunden mit Proben, Schlusswort.
- Ausgang skaliert über die bestehenden Stellschrauben: `belief`-Senkung (nutze `Scandal`-Funktionen statt Rohwerte zu schreiben, wo vorhanden), `pubRep`, Klienten-`mood/trust`, Schlagzeile über `press_event`. Ein katastrophaler Auftritt darf das Gerücht ZUR Story machen (belief +, zweite Schlagzeile) — aber immer mit Rückweg (Spin-Doctor-Fähigkeit `Mogul.has_ability("spin_doctor")` mildert).
- Screenshot-Hook `--shot-pressekonferenz`.

### P3 — Ära-Formate: vom Radiointerview zur Talkshow (nur JSON)

Die Interview-Templates bekommen **epochenspezifische Varianten** (über `min_year`/`max_year` + eigene Texte, gleiche Bäume als Vorlage kopieren und färben):
- **1925–1945 Radio & Fanmagazine:** höflich, Studios hören mit — Patzer kosten `studio_rel` statt `pubRep`.
- **1946–1979 TV-Talk:** live, kein Schnitt — Proben-DCs härter, Erfolge zünden stärker (`heat`).
- **1980–2009 Boulevard-TV:** Privatleben im Visier — Fragen zielen auf Geheimnisse/Privatleben (`private_life`-Bezüge), Diskretion wird zur Kernprobe.
- **ab 2010 Social/Streaming:** ein verpatztes Zitat wird zum viralen Clip (Followup-Event nach 1–2 Wochen mit Nachbeben) — Ketten über `followup` + `quest`-Block, damit es im Journal verfolgbar ist.

### P4 — Tests & Sichtprüfung

- `tests/Test.gd`: Interview-Brief erscheint nur mit passenden Bedingungen; Annahme öffnet den Baum (`letter_choose` liefert `dialog`); ein kompletter Interviewpfad per `Dialogs.start/choose` durchspielbar, Effekte kommen an (pubRep/press_event gezählt); Pressekonferenz nur ab belief-Schwelle und 1× pro Gerücht; Ära-Varianten laden ohne Warnungen (alle vier Zeitfenster je 1 Template geprüft); Save/Load-Roundtrip neuer Felder (Press-Cooldowns).
- Emotions-Fallback getestet: Testlauf muss auch OHNE `Emotions`-Autoload grün sein (Node-Check simulieren).
- Screenshots: `--shot-interview` (mit Emotions-Chip, sofern vorhanden) und `--shot-pressekonferenz`.

## Abnahme
- Headless-Test „0 Fehler", gdlint sauber, .exe neu exportiert, beide Screenshots.
- Alle Inhalte in JSON; keine Struktur-Änderungen an `Dialogs.gd`/`Emotions.gd`; Schema-Ergänzungen in `godot/data/README.md`.
- Commits (je einer): `feat: Interview-Begegnungen — Anfragen, Agenda-Dialoge, Folgen in der Presse` · `feat: Pressekonferenz bei Skandal (Press.gd + Podium-Dialog)` · `content: Ära-Formate — Radio, TV-Talk, Boulevard, Social`.
