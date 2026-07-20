# Chunk 18 — RPG IV: Kontaktbuch & persistente NPC-Beziehungen

## Ziel
Aus den heute wegwerfbaren Gefallen-Kontakten und den Machtfiguren wird ein **Kontaktbuch**: wiederkehrende NPCs mit Beziehungswert, die in Events namentlich auftauchen und deren Nähe Optionen öffnet. Voraussetzung: Chunks 15–16 (Attribute/Proben), sinnvoll nach 17.

## Kontext — was heute existiert
- `Game.gd` → `FAVOR_CONTACTS` (~Zeile 75): Rollen-Pools (Studio-Boss, Kolumnistin, Produzent …), aus denen `favor_contact_for()` bei JEDEM Gefallen einen frischen Namen würfelt — dieselbe Person kcommt nie wieder.
- Gefallen/Schulden speichern den Kontakt als `{type, name, studioId}` im Marker (`grant_favor`/`owe_favor`).
- Machtfiguren: `state.powerFigures` (Ex-Klienten als Regisseur/Produzent) — bereits persistente NPCs mit Wirkung.
- NPC-Namenspools: `data/names/core.json` (`first_m`/`first_f`/`last`).
- EventEngine-Platzhalter in `subst()` (`{client}`, `{studio}` …) — hier kommt `{contact}` dazu.

## Schritte
1. **Daten:** `godot/data/contacts/core.json` — 10–14 handgeschriebene Stamm-NPCs: `{id, name, role ("kolumnist"|"produzent"|"studioboss"|"agent"|"fixer"|"gastgeberin"…), icon, desc (1 Satz Charakter), from_year, to_year, favor_kinds: […]}`. Deutsch, Hollywood-Archetypen mit Wiedererkennungswert. Laden über `Data.CONTACTS = DataLoader.load_entries("contacts")`.
2. **Zustand:** `state.contacts: Dictionary` (`id → {rel: −100…100, met: bool, lastMi}`) — nur Laufzeitwerte, Stammdaten bleiben in `Data.CONTACTS`. Migration in `load_game()`.
3. **Verdrahtung statt Neubau:**
   - `favor_contact_for(kind, studio_id)` zuerst passende Stamm-NPCs (aktive Jahre, `favor_kinds`) bevorzugen (~70 %), sonst wie bisher würfeln. Rückgabeformat `{type, name, studioId}` um `contactId` ergänzen — Gefallen-Marker bleiben kompatibel.
   - `grant_favor`/`consume_favor`/`owe_favor`/`remove_debt`: wenn `contactId` gesetzt ⇒ `contact_rel_change(id, ±3…6)` + `met = true`.
   - Gala-Woche (`_planner_client_week`) und `record_identity`-würdige Momente: kleine rel-Ticks für beteiligte Kontakte.
4. **EventEngine:**
   - Bedingung `"requires_contact": {"role": "kolumnist", "min_rel": 20}` in `check_conditions()`; bindet `ctx["contactId"]`; Platzhalter `{contact}` in `subst()`.
   - Effekt-Op `{"op": "contact_rel", "amount": ±N}` (wirkt auf `ctx.contactId`).
   - Probe-Synergie: `check` darf `"contact_rel_bonus": true` tragen ⇒ Chance + rel/400 (max +0,25).
5. **Ereignisse** (`data/events/kontakte.json`, nur JSON): 2 Events, die Kontakte lebendig machen — z. B. „Die Gastgeberin lädt“ (rel-abhängige Optionen) und „Alter Bekannter in Nöten“ (helfen = rel↑ + Schuld bei dir, ignorieren = rel↓), eines davon als 2-Glieder-Kette mit `quest`-Block (Chunk 17).
6. **UI:** Neuer Reiter „🕸 Kontakte“ ODER Karte im Agentur-Tab (bei Platznot): je bekanntem Kontakt (met) Icon, Name, Rolle, desc, rel als `_bar()` (−100…100 auf 0–100 gemappt, Farbe RED/DIM/GREEN), offene Gefallen/Schulden bei dieser Person (Marker nach `contactId` filtern).
7. **Tests:** Stamm-NPC wird bei passendem Gefallen bevorzugt (Seed/mehrfach), rel-Änderung bei grant/consume, `requires_contact` sperrt unter min_rel, `contact_rel`-Op wirkt, Save/Load-Roundtrip, alte Saves ohne `contacts` laden sauber.

## Akzeptanzkriterien
- [ ] Headless-Test grün, inkl. neuer Tests
- [ ] Gefallen-Meldungen nennen wiederkehrende Namen aus `data/contacts/core.json`
- [ ] Kontakte-Ansicht zeigt getroffene NPCs mit Beziehungsbalken (Screenshot, Hook anlegen)
- [ ] Alle neuen Inhalte in JSON; `FAVOR_CONTACTS`-Fallback bleibt funktionsfähig
- [ ] .exe neu exportiert
- [ ] Ein Commit: `feat: Kontaktbuch — persistente NPC-Beziehungen für Gefallen, Events und Proben`
