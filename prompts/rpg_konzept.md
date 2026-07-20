# RPG-Ausbau — Konzept & Anknüpfpunkte in der Codebase

> Ziel: Hollywood Manager bekommt große RPG-Anteile — eine Spielfigur mit Werten, die
> durch Handeln wachsen, sichtbare Proben in Entscheidungen, Questlinien und gepflegte
> Beziehungen zu wiederkehrenden Figuren. **Kein** Fantasy-Ballast (kein Inventar, keine
> Kämpfe): Das RPG-System IST das Sozial- und Machtspiel Hollywoods.
>
> Umsetzung in Chunks: [15](tasks/15-rpg-attribute.md) → [16](tasks/16-rpg-proben-events.md)
> → [17](tasks/17-rpg-questjournal.md) → [18](tasks/18-rpg-npc-beziehungen.md)

## Warum die Codebase dafür schon gut aufgestellt ist

Die folgenden Systeme existieren bereits und sind die natürlichen Andockpunkte. **Nichts
davon neu erfinden — erweitern.**

| Vorhandenes System | Code-Anker | Wird im RPG-Ausbau zu … |
|---|---|---|
| **Backstory** (5 wählbare Vorgeschichten mit Traits/Schwächen, exklusiven Eventketten) | `Game.gd`: `state.backstory`, `backstory_def()`, `backstory_mod()`, `_apply_backstory_start()`; `data/backstories/core.json` | Charakter-Herkunft: seedet die Start-Attribute (Chunk 15) |
| **Instinkt** (wächst NUR durch richtige Prognosen — Lernen durch Anwendung) | `Game.gd`: `state.instinct`, `add_prediction()`/`tick_predictions()` | Blaupause für ALLE Attribute: Wachstum durch Benutzung, nie durch XP-Shopping (Chunk 15) |
| **Agentur-Identität** (kuenstlerisch/kommerziell/klientenorientiert/studiotreu … mit Etiketten) | `Game.gd`: `IDENTITY_KEYS`, `record_identity()`, `identity_strength()` | Ruf-/Gesinnungsachsen der Figur — bleibt getrennt von Attributen, wird aber in Proben als Modifikator lesbar (Chunk 16) |
| **EventEngine** (JSON-Events: conditions, weight, choices mit requirements/success_chance, Ketten via followup) | `EventEngine.gd`; `data/events/*.json` | Proben-System (`check` in Choices) und Quest-Maschine (Ketten = Questlinien) (Chunks 16 + 17) |
| **Gefallen & Schulden** (konkrete Marker mit Kontakten und Ablauf) | `Game.gd`: `FAVOR_KINDS`, `FAVOR_CONTACTS`, `grant_favor()`/`owe_favor()`/`consume_favor()`, `favor_contact_for()` | Soziale Währung der Beziehungen; Kontakte werden zu persistenten NPCs (Chunk 18) |
| **Machtfiguren** (Klienten werden Regisseure/Produzenten mit Einfluss) | `Game.gd`: `state.powerFigures`, `become_power_figure()` | Bereits das Muster „NPC mit Spielwirkung“ — wird Teil des Kontaktbuchs (Chunk 18) |
| **Klienten-Beziehungswerte** (Vertrauen mit Cap, Loyalität, Laune, Versprechen, Geheimnisse) | `Game.gd`: `change_trust()`, `c.promises`, `c.secrets`, `SECRET_TYPES` | Companion-artige Bindungen — bleibt, bekommt in Quests/Proben Gewicht |
| **Wochenplaner** (7 Tage × 3 Abschnitte, Aktionen mit Slot-Effekten) | `Game.gd`: `PLANNER_PLAYER`/`PLANNER_CLIENT`, `_apply_planner()` | Zeit/Energie-Ökonomie der Figur; Attributs-Training dockt hier an (Chunk 15) |
| **Klienten-Kapazität** (vorbereitet, noch kein Limit) | `Game.gd`: `client_capacity()` | Party-Größe; Durchsetzung kommt mit dem Personal-System (separates Vorhaben) |
| **Chronik/Log + Ticker** | `Game.gd`: `log_msg()`, `state.log`; Zeitungs-/Pressefeed | Trägersystem fürs Quest-Journal (Chunk 17) |

## Die vier Bausteine

### 1. Attribute der Spielfigur (Chunk 15)
Fünf Attribute (0–100), thematisch statt D&D: **Verhandlung** 🤝, **Menschenkenntnis** 👁,
**Netzwerk** 🕸, **Diskretion** 🤫, **Geschäftssinn** 📊. Start ~20–30, geseedet von der
Backstory (Anwalt → Verhandlung, Kolumnist:in → Diskretion/Netzwerk …). Wachstum wie beim
Instinkt **durch Benutzung** (jede erfolgreiche Verhandlung, jeder eingelöste Gefallen,
jede aufgedeckte Intrige gibt Zehntelpunkte, mit abnehmendem Ertrag). Kein Levelsystem,
keine freie Punktevergabe — die Karriere formt die Figur.

### 2. Sichtbare Proben in Entscheidungen (Chunk 16)
Event-Choices können eine Probe tragen: `"check": {"attr": "verhandlung", "dc": 45}`.
Die Erfolgschance ergibt sich aus Attribut vs. Schwierigkeit, der Button zeigt es an:
`[Verhandlung 68 %] Den Deal nachverhandeln`. Erfolg/Fehlschlag nutzen die vorhandenen
`effects`/`effects_fail`-Pfade — die EventEngine kann das fast schon.

### 3. Quest-Journal (Chunk 17)
Eventketten existieren (followups mit ctx) — sie sind nur unsichtbar. Ketten bekommen
optionale Journal-Metadaten (`quest`: Titel, Schrittbeschreibung) und einen eigenen
Reiter „Aufträge“: laufende Ketten mit aktuellem Schritt, erledigte als Archiv.
Damit werden aus zufälligen Followups **verfolgbare Questlinien**.

### 4. Kontaktbuch & NPC-Beziehungen (Chunk 18)
Die Namen aus `FAVOR_CONTACTS`, Gefallen-Gebern und Machtfiguren werden persistente
NPCs mit Beziehungswert, die wiederkehren (heute: jedes Mal frisch ausgewürfelt).
Beziehungen öffnen Optionen in Events/Proben und werden im neuen Reiter sichtbar.

## Leitplanken
- **Alles datengetrieben:** Attribute, Proben-DCs, Quests, NPCs → JSON unter `godot/data/`
  (DataLoader-Merge nutzen), nichts hartkodieren.
- **Deutsch, Hollywood-Ton**, keine Fantasy-Terminologie („Probe“, nicht „Skill Check“ in der UI — intern egal).
- **Balance-Prinzip:** Attribute geben Prozente, keine Automatik-Siege (Chance-Clamps 5–95 %).
- **Ein Chunk pro Session**, Tests + .exe-Export + SonarQube/gdlint-Gate pro Commit (siehe tasks/README.md).
