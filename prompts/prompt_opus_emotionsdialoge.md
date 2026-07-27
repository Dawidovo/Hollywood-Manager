# Prompt für Claude Opus — Emotions-Dialogsystem für wichtige Begegnungen
# (Wahrgenommene Emotionen · Wahrnehmungspräzision über Menschenkenntnis · mehrstufige Schlüsselgespräche)

Du arbeitest am Godot-Spiel „Hollywood Manager" (Wirtschaftssimulation: Spieler führt eine Hollywood-Talentagentur, 1925–heute, **englische Spieltexte**, deutsche Doku, **Wochentakt**). **Lies ZUERST `ARCHITECTURE.md` und `DECISIONS.md` im Projektroot — sie ersetzen das Durchsuchen des Repos und sind bindend.** **Arbeite NIEMALS parallel zu einer anderen KI-Session am selben Ordner.** Zwei weitere Pakete existieren (GPT Sol: Presse & Interviews; Kimi: Klienten-Innenleben) — sie SETZEN auf deiner Emotions-API auf. Dein Paket kommt daher **zuerst**. Überschneide dich nicht mit deren Themen (Interviews/Pressekonferenzen bzw. Bedürfnis-System).

## Aktueller Stand (nutzen, nicht neu bauen!)

| System | Wo | Für dich relevant |
|---|---|---|
| Dialogbäume + Wochenpost | `Dialogs.gd` (Autoload), `data/dialogs/`, `data/letters/` | DEIN Kern-Andockpunkt. Schema: `godot/data/README.md`. Knoten mit `text`-Varianten, `choices` (`goto`, `effects`, `conditions`, `check`), Gesprächsgedächtnis/Recalls, Interaktionsstufen via `Dialogs.dispatch(kind, ctx)` |
| Spieler-Attribute | `Game.attr(key)`, `Game.attr_gain(key, amount)`, Definitionen `data/attributes/core.json` | **`menschenkenntnis` ist deine Präzisions-Quelle.** Wachstum nur durch Benutzung (Kurve in `Balance.gd`) |
| Sichtbare Proben | `EvEngine.check_chance/check_label`, Dialog-`check`-Rolls in `Dialogs.gd` | Muster für „sichtbare Unsicherheit im Button" — übernimm die Optik `[👁 Insight · 62 %]` |
| Kontakte & Beziehungsdimensionen | `Network.gd`: `dim(ct, "trust"/"liking"/"irritation"/"closeness")`, Fakten, Grievances; `Persona.gd`: Kontaktbuch, Erinnerungen | Quellenmaterial für WAHRE Emotionen |
| Klienten | `Game.state.clients[]`: `mood`, `loyalty`, `trust`, `exhaustion`, `promises[]` (broken!), `narrative`, Feud-/Couple-Flags | Quellenmaterial für Klienten-Emotionen |
| Rivalen | `Rivals.gd`: `grudge`, `rel`; Abwerbe-Duell `_rival_poach_event` (scripted Modal) | Kandidat für eine wichtige Begegnung |
| Skandale | `Scandal.gd`: Geheimnisse, Gerüchte | Krisengespräch-Anlässe |
| Quest-Journal | Events mit `quest`-Block erscheinen als verfolgbare Aufträge (Tab „Journal") | Mehrstufige Begegnungen mit Folgeterminen dürfen Journal-Einträge tragen |
| Deterministik-Muster | `Util.hashs(seed_string)` für stabile „Zufalls"-Werte (Körperdaten, Stimme, Chemie, `grade_range`) | **Pflichtmuster für Wahrnehmungs-Rauschen** — kein Savescum-Reroll |

## Projektkontext (bindend)

- Godot **4.7.1**, alles unter `godot/`. **`index.html`/`js/` sind eingefroren — nie anfassen.** `Game.state` = reines JSON-Dict, neue Felder in `_apply_save_defaults()` migrieren (Muster vorhanden). Spielinhalte als **JSON unter `data/`** — Texte englisch, Hollywood-Ton.
- UI in Code: `Main.gd` = Gerüst/Bausteine/Modals; Tab-Renderer in `scripts/ui/*Screen*.gd` (Muster: Main-Referenz, `main._lbl(...)` etc.). Die Dialog-Ansicht lebt in `ui/WorldScreens.gd::_render_dialog_view` + `Dialogs.start/choose`.
- Nach JEDER Code-Änderung: Logiktest `Godot_console.exe --headless --path godot res://tests/Test.tscn` (muss „0 Fehler") und `.exe` neu exportieren (`--export-release "Windows Desktop" "build/HollywoodManager.exe"`). gdlint läuft im Pre-Commit-Hook. Screenshots: `Godot.exe --path godot -- --shot-<name> --shot-resolution=2000x1100` (das freistehende `--` ist Pflicht; `--shot-resolution` verwenden, Godots `--resolution` greift nicht).
- Ein Chunk pro Session, ein Commit pro Chunk. Statusänderungen in `prompts/tasks/README.md` und Architektur-Neuerungen in `ARCHITECTURE.md` nachtragen.

## Dein Paket: Emotionen & Schlüsselgespräche

### E1 — Emotionsmodell `Emotions.gd` (neues Autoload)

Emotionen werden **abgeleitet, nicht gespeichert** (kein neues Save-Feld; alles rekonstruierbar aus vorhandenem Zustand).

1. **Definitionen datengetrieben:** `data/emotions/core.json` (Dict-Kategorie, in `Data.reload()` als `Data.EMOTIONS` laden): je Emotion `{name, icon, desc, valence: -1|0|1}`. Acht Grundemotionen: `warm` 🤗, `hopeful` ✨, `calculating` 🦊, `wary` 🛡, `anxious` 😟, `irritated` 😤, `resentful` 🌩, `resigned` 🌫.
2. **`Emotions.true_state(subject_kind, ctx) -> {key, intensity (0–100), cause (String)}`** für `subject_kind` ∈ `contact | client | rival`. Ableitung aus Simulationsfakten mit klaren Prioritäten (erste zutreffende Regel gewinnt, `cause` benennt sie konkret):
   - Kontakt: unbeglichene Schuld beim Spieler → `calculating`; Grievance/gebrochenes Versprechen → `resentful`; `irritation` hoch → `irritated`; `trust`+`liking` hoch → `warm`; alles niedrig/neu → `wary` …
   - Klient: Versprechen gebrochen → `resentful`; `mood` < 35 → `irritated`; `loyalty` < 30 → `calculating` (hört sich anderswo um); Comeback aktiv → `anxious`; Karrierehoch/Hit frisch → `hopeful`; Feud-Partner im Raum → `irritated` …
   - Rivale: `grudge` ≥ 60 → `resentful`; `rel` ≥ 20 → `calculating`-freundlich … 
3. **`Emotions.perceived(subject_kind, ctx) -> {key, confidence, cause, wrong}`** — die Spielersicht. Präzision = `Game.attr("menschenkenntnis")` (+ situativ `state.instinct / 10` als Bonus). Stufen:
   - **< 30:** nur Valenz oder `unreadable` („Hard to read"); zusätzlich 25 % Chance auf eine FALSCHE Nachbaremotion.
   - **30–54:** Emotion korrekt, `confidence: "likely"`, keine Ursache; 10 % Fehlerchance.
   - **55–74:** korrekt, `confidence: "clear"`.
   - **≥ 75:** korrekt + `cause`-Zeile wird angezeigt („…because you broke your word in March").
   Fehler-/Grenzfälle **deterministisch** über `Util.hashs(subjektname + str(Game.wi()))` — pro Woche stabil, Dialog-Neustart würfelt nicht neu. Schwellen/Prozente als Konstanten nach `Balance.gd` (Sektion „Emotionen/Wahrnehmung").
4. **API für die anderen Pakete dokumentieren** (Kommentarkopf in `Emotions.gd` + Absatz in `godot/data/README.md`): Sol/Kimi greifen ausschließlich über `true_state`/`perceived` zu.

### E2 — Emotionen im Dialogsystem sichtbar & wirksam

1. **Anzeige:** Der Dialog-Header (`_render_dialog_view` bzw. der von `Dialogs.start()` gelieferte View) zeigt einen **Emotions-Chip** des Gegenübers: Icon + Name + Konfidenz (`😤 Irritated · you're fairly sure` / bei `unreadable`: `🎭 Hard to read`). Der Chip **aktualisiert sich nach jeder Choice** (Emotionen kippen, wenn Choices die Quellwerte bewegen — das passiert automatisch über die vorhandenen `dims`-/`mood`-Ops).
2. **Schema-Erweiterung** (Doku in `data/README.md` mitpflegen):
   - Choice-Bedingung `"requires_emotion": ["warm", "hopeful"]` — die Option existiert nur, wenn die **WAHRE** Emotion passt. Der Spieler sieht aber nur die WAHRGENOMMENE → bei schlechter Menschenkenntnis fehlen Optionen „unerklärlich" oder tauchen überraschend auf. Genau diese Lücke ist das Spielgefühl; nichts glätten.
   - Dialog-`check` um `"attr"` erweitern (Attributs-Probe analog Events, Chance-Formel und Label-Optik aus `EvEngine.check_chance/check_label` wiederverwenden — EINE Formel, keine Kopie).
   - Knoten-Feld `"reads"` (optional): kurze Wahrnehmungszeile, die je Präzisionsstufe unterschiedlich detailliert ausgespielt wird (Stufe 1: nichts, Stufe 4: volle Beobachtung).
3. **Ops:** kein neuer `emotion`-Op — Emotionen sind abgeleitet. Stattdessen prüfen: alle vorhandenen Wege (dims, mood, promise, favor) reichen als Stellschrauben; falls ein Dialog gezielt Ursachen setzen muss, existieren `fact`/`memory` bereits.

### E3 — Vier wichtige Begegnungen als mehrstufige Dialogbäume (nur JSON)

Neue Datei `data/dialogs/begegnungen.json`, mind. vier Bäume mit je **3+ Phasen** (Eröffnung → Kern mit 2–3 Verzweigungsebenen → Auflösung), Emotions-Gates, Attributs-Proben und spürbaren Einsätzen. Automatische Auslösung über die vorhandenen Dispatcher-/Event-Wege:

1. **`contract_showdown`** — Vertragsverlängerung eines Klienten mit `loyalty < 50` ODER gebrochenem Versprechen (statt stiller Auto-Verlängerung in `tick_clients`: bei kritischen Fällen diesen Dialog ausspielen). Ausgang: Verlängerung (ggf. teurer), Neuverhandlung der Provision, oder Abgang mit Würde/Krach.
2. **`poach_defense`** — das Abwerbe-Duell (`Rivals._rival_poach_event`) wird bei Klienten mit Ruhm ≥ 50 zur vollen Szene: gleiche drei Auswege wie heute, aber als Gespräch mit Emotionslage des Klienten und Zwischentönen. Das bestehende Modal bleibt als Fallback für kleine Namen.
3. **`crisis_confession`** — Klient gesteht das Geheimnis hinter einem Gerücht (löst aus, wenn ein wahres Gerücht über ihn ≥ 40 belief erreicht und ein Geheimnis dahinter liegt, 1× pro Geheimnis): Zuhören/versprechen/distanzieren — mit Folgen über Scandal-/Promise-Systeme.
4. **`studio_summit`** — der Studioboss bittet nach zwei geplatzten Deals in Folge zum Gespräch (Beziehung retten, Exklusivität anbieten, Stolz zeigen).

Jede Begegnung: `quest`-taugliche Nachwehen, wo eine Frist entsteht (Journal!), Ticker-/Memoir-Zeilen, und mindestens eine Stelle, an der **falsch gelesene** Emotionen richtig wehtun können.

### E4 — Tests & Sichtprüfung

- `tests/Test.gd`: Präzisionsstufen deterministisch (attr 20 → unreadable/Valenz, attr 80 → korrekt + cause); WAHRE vs. WAHRGENOMMENE Emotion weichen bei niedrigem Attribut nachweisbar ab (feste hash-Konstellation suchen wie beim Chemie-Test-Muster); `requires_emotion` blendet Choices korrekt ein/aus; `check.attr` in Dialogen nutzt dieselbe Chance-Formel wie Events; die vier Begegnungen laden ohne Warnungen und sind durchspielbar (je ein Pfad per `fn.call()`); Save/Load neutral (keine neuen Pflichtfelder).
- Screenshot-Hook `--shot-begegnung` anlegen (contract_showdown mit sichtbarem Emotions-Chip, einmal mit Menschenkenntnis 20 und einmal 80 — zwei PNGs).
- BalanceSim (`res://tools/BalanceSim.tscn`) muss weiter durchlaufen (Dialoge werden dort nicht gespielt, aber `contract_showdown` darf den Sim-Lauf nicht blockieren: als Event in die normale Modal-Queue, die die Sim ignoriert — Auto-Verlängerung als Fallback, wenn das Modal nie beantwortet wird).

## Abnahme
- Headless-Test „0 Fehler", gdlint sauber, .exe neu exportiert, Screenshots wie oben.
- Alle Inhalte in JSON; Schema-Erweiterungen in `godot/data/README.md` dokumentiert; `Emotions`-API-Kommentar für die Folge-Pakete.
- Commits (je einer): `feat: Emotionsmodell — wahre und wahrgenommene Gefühle (Emotions.gd)` · `feat: Emotionen im Dialogsystem — Chip, requires_emotion, Attribut-Proben` · `content: vier Schlüsselbegegnungen als mehrstufige Dialoge`.
