# Chunk 17 — RPG III: Quest-Journal (Eventketten sichtbar machen)

## Ziel
Eventketten werden zu verfolgbaren **Aufträgen**: ein Journal zeigt laufende Ketten mit aktuellem Schritt und Countdown, abgeschlossene wandern ins Archiv. Ketten bekommen dafür optionale Journal-Metadaten in den JSON-Events. Voraussetzung: Chunk 16 (nur wegen README-Schema-Abschnitt; technisch reicht die Event-Basis).

## Kontext
- Ketten heute: Effekt `{"op":"followup","event":"<id>","delay_weeks":N}` hängt `{"type":"json","event",…,"ctx","due"}` an `state.followups`; aufgelöst wöchentlich in `end_week()` über `EvEngine.build_by_id()`. Kettenglieder tragen `"followup_only": true`. Beispiele: „steuerpruefung“ → „steuer_nachspiel“ (`data/events/core.json`), alle Backstory-Ketten (`data/events/backstory_chains.json`).
- Followups sind für den Spieler **unsichtbar**, bis sie feuern — genau das ändert dieser Chunk.
- Tab-Leiste: `render()`/Tab-Array in `Main.gd` (~735); neue Tabs dort registrieren + `_render_<name>()`-Renderer.
- `mi()`/`state.week` für Zeitrechnung; Anzeige von Restzeit in Wochen: `(due - mi()) * 4` grob, besser vorhandene Helfer prüfen.

## Schema-Erweiterung (Event, optional)
```json
{
  "id": "steuerpruefung",
  "quest": {"title": "Post vom Finanzamt", "icon": "🧾",
            "step": "Die Prüfung läuft — abwarten oder eingreifen."},
  …
}
```
Jedes Kettenglied kann ein eigenes `quest.step` tragen; `quest.title` des ERSTEN Glieds benennt den Auftrag. Events ohne `quest`-Block erscheinen nicht im Journal (Alltagsrauschen bleibt draußen).

## Schritte
1. **Zustand:** `state.quests: Array` — Einträge `{id, title, icon, step, startedMi, status: "aktiv"|"abgeschlossen", ctx}`. Migration in `load_game()` (leeres Array).
2. **Verdrahtung in EventEngine:**
   - Beim `followup`-Effekt: hat das AUSLÖSENDE Event einen `quest`-Block ⇒ Quest anlegen/aktualisieren (id = Event-id des Kettenstarts), `step` aus dem Ziel-Event (falls vorhanden) oder Standardtext „Fortsetzung folgt …“ + Fälligkeitsinfo.
   - Beim Auflösen eines Kettenglieds OHNE weiteren followup-Effekt in der gewählten Choice ⇒ Quest `status = "abgeschlossen"`, Abschlusstext = gewähltes `outcome` (gekürzt).
   - Scripted Followups (`Ev.build_followup`) NICHT anfassen — nur JSON-Ketten journalfähig.
3. **UI:** Neuer Tab „📜 Aufträge“ (zwischen Zeitung und Talentpool): Karte je aktiver Quest (Icon, Titel, aktueller Schritt, „seit <Datum>“, Restzeit in Wochen falls Followup terminiert); darunter eingeklapptes Archiv (letzte 10 abgeschlossene). Leerer Zustand mit Flavor-Text („Keine offenen Geschichten — noch nicht.“).
4. **Ticker:** Bei Questabschluss `log_msg("Auftrag abgeschlossen: …", "deal")`.
5. **Bestehende Ketten nachrüsten** (nur JSON): `quest`-Blöcke für „steuerpruefung“-Kette + alle 5 Backstory-Ketten in `data/events/backstory_chains.json` (deutsche Schrittexte im Hollywood-Ton).
6. **Sidebar (klein):** Pipeline-Karte in `_render_sidebar()` bekommt eine Zeile „📜 N offene Aufträge“ als Link-Ersatz (Text reicht).
7. **Doku + Tests:** README-Events-Schema um `quest` ergänzen. Tests: Kette mit quest-Block anlegen ⇒ Quest „aktiv“ mit Schritt; Kettenende ⇒ „abgeschlossen“; Event ohne quest-Block erzeugt keinen Journal-Eintrag; Save/Load-Roundtrip.

## Akzeptanzkriterien
- [ ] Headless-Test grün, inkl. neuer Tests
- [ ] Steuer- und alle Backstory-Ketten erscheinen im Journal (Screenshot des neuen Tabs, Hook `--shot-quests` anlegen)
- [ ] Events ohne `quest`-Block verhalten sich exakt wie bisher
- [ ] .exe neu exportiert
- [ ] Ein Commit: `feat: Quest-Journal für Eventketten (Tab „Aufträge“, JSON-Metadaten)`
