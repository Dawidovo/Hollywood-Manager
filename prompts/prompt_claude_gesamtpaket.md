# Prompt für Claude (Claude Code) — Gesamtpaket: Emotionen, Schlüsselgespräche, Presse, Klienten-Innenleben
# (Alle drei Teilpakete in einer Session-Reihe; ersetzt bei Nutzung die Einzel-Prompts für Opus/Sol/Kimi)

Setze im Godot-Projekt (`godot/`) das folgende Gesamtpaket um. Du kennst das Repo über
`CLAUDE.md` → `ARCHITECTURE.md`/`DECISIONS.md` — die dort dokumentierten Regeln gelten
(Wochentakt, englische Spieltexte, JSON-first unter `data/`, Werte nach `Balance.gd`,
Migration in `Game._apply_save_defaults()`, ein Chunk = ein Commit, nach jeder
Code-Änderung Headless-Test + .exe-Export, Screenshots mit `-- --shot-<name>
--shot-resolution=2000x1100`, gdlint via Pre-Commit-Hook, Task-Tabelle nachführen).

**Arbeite die Teile strikt in Reihenfolge A → B → C ab** (B und C konsumieren die
Emotions-API aus A). Verifiziere Balance-relevante Änderungen mit der BalanceSim
(`res://tools/BalanceSim.tscn`, 16-Kampagnen-Matrix) vorher/nachher; reine
Refactorings müssen bit-identisch bleiben, Feature-Änderungen dokumentierst du im
Commit-Text mit dem SUM-Zeilen-Vergleich. Falls die Einzel-Prompts
(`prompt_opus_emotionsdialoge.md`, `prompt_gpt_sol_presse.md`,
`prompt_kimi_k3_innenleben.md`) bereits teilweise von anderen Modellen umgesetzt
wurden: vorhandene Ergebnisse nutzen und nur die Lücken schließen — nichts doppelt
bauen (Indiz: existiert `Emotions.gd`/`Press.gd`/`Needs.gd` schon?).

---

## Teil A — Emotionsmodell & mehrstufige Schlüsselgespräche

### A1 `Emotions.gd` (neues Autoload) + `data/emotions/core.json`
- Acht Grundemotionen datengetrieben (`{name, icon, desc, valence}`): `warm` 🤗,
  `hopeful` ✨, `calculating` 🦊, `wary` 🛡, `anxious` 😟, `irritated` 😤,
  `resentful` 🌩, `resigned` 🌫. In `Data.reload()` als `Data.EMOTIONS` laden.
- **Abgeleitet, nicht gespeichert** — kein neues Save-Pflichtfeld.
- `true_state(subject_kind, ctx) -> {key, intensity 0–100, cause}` für
  `contact | client | rival`; Ableitung mit klarer Regel-Priorität aus vorhandenen
  Fakten: Kontakte über `Network.dim` (irritation/trust/liking), Grievances,
  offene Schulden (`calculating`), gebrochene Versprechen (`resentful`); Klienten
  über `mood/loyalty/trust/exhaustion`, gebrochene `promises`, Comeback-Flag
  (`anxious`), frischen Hit (`hopeful`), Feud im Raum (`irritated`); Rivalen über
  `grudge`/`rel`. `cause` benennt die auslösende Regel konkret.
- `perceived(subject_kind, ctx) -> {key, confidence, cause, wrong}` — Präzision aus
  `Game.attr("menschenkenntnis")` (+ `state.instinct / 10` situativ), vier Stufen:
  - **< 30:** nur Valenz oder `unreadable`; 25 % Chance auf FALSCHE Nachbaremotion
  - **30–54:** Emotion korrekt, `confidence: "likely"`, keine Ursache; 10 % Fehler
  - **55–74:** korrekt, `"clear"`
  - **≥ 75:** korrekt + `cause`-Zeile („…because you broke your word in March")
  Fehler deterministisch über `Util.hashs(subjekt + str(Game.wi()))` — pro Woche
  stabil, kein Savescum-Reroll. Schwellen/Prozente nach `Balance.gd`.
- API-Kommentarkopf für nachgelagerte Nutzer; Absatz in `godot/data/README.md`.

### A2 Emotionen im Dialogsystem
- **Emotions-Chip** im Dialog-Header (`ui/WorldScreens._render_dialog_view` /
  `Dialogs.start`-View): Icon + Name + Konfidenz (`😤 Irritated · you're fairly
  sure`; bei `unreadable`: `🎭 Hard to read`). Aktualisiert sich nach jeder Choice
  (Choices bewegen die Quellwerte über vorhandene `dims`/`mood`-Ops — kein neuer
  Emotions-Op, Emotionen bleiben abgeleitet).
- Schema-Erweiterungen (in `data/README.md` dokumentieren):
  - Choice-Bedingung `"requires_emotion": ["warm", …]` prüft die **WAHRE** Emotion;
    der Spieler sieht nur die WAHRGENOMMENE → Optionen fehlen/erscheinen bei
    schlechter Menschenkenntnis „unerklärlich". Diese Lücke ist gewollt.
  - Dialog-`check` um `"attr"`-Proben erweitern — Chance-Formel und Label-Optik aus
    `EvEngine.check_chance/check_label` WIEDERVERWENDEN (eine Formel, keine Kopie).
  - Optionales Knoten-Feld `"reads"`: Wahrnehmungszeile, je Präzisionsstufe
    unterschiedlich detailliert.

### A3 Vier Schlüsselbegegnungen (`data/dialogs/begegnungen.json`, nur JSON)
Je **3+ Phasen** (Eröffnung → Kern mit 2–3 Verzweigungsebenen → Auflösung),
Emotions-Gates, Attributs-Proben, echte Einsätze, `quest`-Blöcke bei Fristen:
1. **`contract_showdown`** — Vertragsverlängerung bei `loyalty < 50` oder
   gebrochenem Versprechen ersetzt die stille Auto-Verlängerung in `tick_clients`
   (Fallback: Auto-Verlängerung, wenn das Modal unbeantwortet bleibt — BalanceSim
   darf nicht blockieren).
2. **`poach_defense`** — Abwerbe-Duell (`Rivals._rival_poach_event`) wird ab Ruhm 50
   zur vollen Szene mit Emotionslage; bestehendes Modal bleibt Fallback.
3. **`crisis_confession`** — Klient gesteht das Geheimnis hinter einem wahren
   Gerücht (belief ≥ 40, 1× pro Geheimnis).
4. **`studio_summit`** — Studioboss bittet nach zwei geplatzten Deals zum Gespräch.

### A4 Tests & Sicht
Tests: Präzisionsstufen deterministisch (attr 20 vs. 80), wahre ≠ wahrgenommene
Emotion bei niedrigem Attribut nachweisbar, `requires_emotion` filtert, `check.attr`
nutzt die Event-Formel, alle vier Bäume laden warnungsfrei und je ein Pfad läuft per
`fn.call()`, Save/Load neutral. Screenshot-Hook `--shot-begegnung` (Chip einmal bei
Menschenkenntnis 20, einmal 80).

---

## Teil B — Presse: Interviews, Pressekonferenz, Ära-Formate

### B1 Interviews (nur JSON + Brief-Verdrahtung)
- `data/letters/interviews.json`: 3 Anfrage-Templates (Klienten-Porträt ab Ruhm 40,
  Agentur-Hintergrund ab Karriere 1, Gerücht-Fishing bei bekanntem Gerücht);
  Annahme kostet `ap` und öffnet den Baum (`"dialog"`-Feld).
- `data/dialogs/interviews.json`: 3 Bäume mit je **3+ Fragerunden**
  (warme Eröffnung → Kernfrage mit Falle → Nachfassen): Antworten als sichtbare
  Proben (`diskretion`/`verhandlung`/`menschenkenntnis`) + Emotions-Gates auf den
  Journalisten; Erfolge → `press_event`-Schlagzeile, `player.pubRep`, Klienten-Heat,
  ggf. `favor_grant suppressStory`; Patzer → negatives Blatt, Gerücht-belief +,
  `dims`-Schaden. Interviewer merkt sich Verhalten (`fact`/`memory`).
- Interviewer ist wenn möglich echter Kontakt (`ctid` im ctx).

### B2 Pressekonferenz bei Skandal
- Kleines Autoload `Press.gd` NUR für Auslöser/Cooldowns (Gerücht über eigenen
  Klienten erreicht belief ≥ 55, 1× pro Gerücht → Brief-Angebot); Szene als
  `data/dialogs/pressekonferenz.json`: Eröffnungsstatement mit Ton-Wahl
  (Demut/Gegenangriff/Witz, prägt Folgerunden), zwei Fragerunden mit Proben,
  Schlusswort. Wirkung über vorhandene Stellschrauben (Scandal-Funktionen, pubRep,
  mood/trust, `press_event`); Desaster möglich, aber immer mit Rückweg
  (`Mogul.has_ability("spin_doctor")` mildert). Hook `--shot-pressekonferenz`.

### B3 Ära-Formate (nur JSON, `min_year`/`max_year`-Varianten)
Radio/Fanmagazine 1925–45 (Patzer kosten `studio_rel`), Live-TV-Talk 1946–79
(härtere DCs, stärkere Heat-Zünder), Boulevard 1980–2009 (zielt auf
Geheimnisse/Privatleben, Diskretion als Kernprobe), Social/Streaming ab 2010
(verpatztes Zitat → viraler Clip als Followup-Kette mit `quest`-Block).

### B4 Tests
Brief-Bedingungen, Baum-Öffnung via `letter_choose`, ein kompletter Pfad per
`Dialogs.start/choose` mit ankommenden Effekten, Pressekonferenz-Schwelle+Cooldown,
alle vier Ära-Fenster laden warnungsfrei, Save/Load der Press-Cooldowns.
Screenshot `--shot-interview`.

---

## Teil C — Klienten-Innenleben & TV-/Streaming-Umbruch

### C1 `Needs.gd` (neues Autoload) + `data/needs/core.json`
- Fünf Bedürfnisse (`{name, icon, desc}`): `anerkennung`, `sicherheit`, `kunst`,
  `geld`, `ruhe`.
- `Needs.profile(actor)` deterministisch (`Util.hashs` + Nudges: hoher `ego` →
  `anerkennung`+, niedriger `peakFame` → `sicherheit`+, Prestige-Genres → `kunst`+);
  kein Save-Feld.
- `c.needsSat = {need: 0–100}` (Save-Feld, Migration, Start 55);
  `Needs.tick_client(c)` in `tick_clients`: Rollen/Releases füttern
  `anerkennung`/`kunst`/`geld` (Lead/Support, Prestige, Gage vs. Erwartung), Lücken
  zehren `sicherheit`, Galas/PR zehren `ruhe`, Erholung füllt sie (Planner-Kopplung).
- Wirkung NUR über bestehende Mechanik: schlechtestes Bedürfnis < 35 → `mood` −2/Monat,
  < 20 → zusätzlich `loyalty` −1. Keine Parallelwelt.
- Sichtbarkeit über Menschenkenntnis gestaffelt („What drives them"-Zeile auf der
  Klientenkarte: < 30 nichts; 30–54 Top-Icon; ≥ 55 + Engpass; ≥ 75 volles
  Mini-Profil). `Needs.grievance_cause(c)` verfeinert die Klienten-`cause` in
  `Emotions.true_state`.

### C2 Erwartungsgespräch (`data/dialogs/erwartung.json`)
Halbjährlich oder bei Bedürfnis < 25 (1×/Halbjahr/Klient): Brief → 3-Phasen-Baum;
Klient benennt den Engpass (klar oder verklausuliert, je nach Menschenkenntnis);
Spieler kann konkret zusagen (**vorhandenes Versprechens-System**, `promise`-Op mit
Frist: Lead-Rolle, Prestige-Projekt, Auszeit, Gagensprung), vertrösten
(`verhandlung`-Probe) oder ehrlich absagen (Vertrauen +, Stimmung −). Gehaltene
Zusagen füllen das Bedürfnis stark; gebrochene brechen es zusätzlich zu den
Promise-Strafen ein. `quest`-Block für die Frist.

### C3 TV-Umbruch 1948–1962 & Streaming 2015+ (exakt nach Tonfilm-Muster)
- `Util.tv_appeal(actor)` deterministisch 20–100 (Charisma-Nudge). Fenster 1948–62:
  hohe Werte ziehen TV-Angebote (`data/events/fernsehen.json`, Kette mit
  `quest`-Block): Serie = stetiges Einkommen (vorhandenes `tvIncome`-Flag nutzen),
  `sicherheit`/`geld` rauf, DNA `popular`+ / `unikat`−, Prestige-Casting-Malus
  solange aktiv. Niedrige Werte: keine Strafe, nur keine Angebote.
- Streaming (`data/events/streaming.json`): Algorithmus-Serien, Binge-Ruhm
  (schnellerer Heat-Auf- UND -Abbau nur im Fenster, klar benannter kleiner Zusatz in
  `tick_clients`), `likenessRights` als wiederkehrende Konflikt-Kette.
- Chips auf der Klientenkarte (`📺` / `📱`), Konstanten in `Balance.gd`.

### C4 Tests & Balance
Profil/`tv_appeal` deterministisch + genudged, Migration, Drift-Richtungen,
Engpass→mood, Erwartungsgespräch legt echtes Versprechen an, gehaltene Zusage füllt
Bedürfnis, TV-Kette nur im Fenster & bei hohem Appeal, Streaming-Verfall nur ab 2015,
Save/Load. **BalanceSim vorher/nachher** — Stimmungs-/Loyalitäts-/Abwerbe-Niveaus
nur moderat verschoben, Energie-/Cash-Korridore stabil; Vergleich im Commit-Text.
Screenshots `--shot-client` (Bedürfniszeile) und `--shot-fernsehen`.

---

## Abnahme (je Teil)
Headless-Test „0 Fehler" · gdlint sauber · .exe neu exportiert · Screenshots wie
angegeben · Inhalte in JSON, Werte in `Balance.gd`, Schema-Doku in
`godot/data/README.md` · `prompts/tasks/README.md` und `ARCHITECTURE.md`
(neue Autoloads `Emotions`/`Press`/`Needs`) nachgeführt.

Commit-Reihenfolge (je einer):
1. `feat: Emotionsmodell — wahre und wahrgenommene Gefühle (Emotions.gd)`
2. `feat: Emotionen im Dialogsystem — Chip, requires_emotion, Attribut-Proben`
3. `content: vier Schlüsselbegegnungen als mehrstufige Dialoge`
4. `feat: Interview-Begegnungen — Anfragen, Agenda-Dialoge, Folgen in der Presse`
5. `feat: Pressekonferenz bei Skandal (Press.gd + Podium-Dialog)`
6. `content: Ära-Formate — Radio, TV-Talk, Boulevard, Social`
7. `feat: Klienten-Innenleben — Beduerfnisse treiben Stimmung und Gespraeche`
8. `feat: Erwartungsgespraech — Beduerfnisse werden zu Versprechen`
9. `feat: Fernseh- und Streaming-Umbruch nach Tonfilm-Muster`
