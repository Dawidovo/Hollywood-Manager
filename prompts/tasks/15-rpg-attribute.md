# Chunk 15 — RPG I: Attribute der Spielfigur (Fundament)

## Ziel
Die Spielfigur bekommt fünf Attribute (0–100), die von der Backstory geseedet werden und **durch Benutzung** wachsen (Vorbild: `state.instinct`). Anzeige im Agentur-Tab. Noch keine Proben in Events — das ist Chunk 16.

## Kontext (siehe auch prompts/rpg_konzept.md)
- Vorbild-Mechanik: `state.instinct` wächst nur durch richtige Prognosen (`Game.gd`: `add_prediction`/`tick_predictions`, Wachstum z. B. `state.instinct = clampi(int(state.instinct) + 3, 0, 100)`).
- Backstories: `data/backstories/core.json`, angewendet in `Game._apply_backstory_start()`; Laufzeit-Mods über `backstory_mod(key, default)`.
- Daten liegen als JSON unter `godot/data/` (DataLoader-Merge, Doku `godot/data/README.md`).
- Der Spielzug ist wöchentlich (`end_week()`/`_month_close()`); Planer-Auswertung in `_apply_planner()`/`_planner_client_week()`.

## Die fünf Attribute
`verhandlung` 🤝 · `menschenkenntnis` 👁 · `netzwerk` 🕸 · `diskretion` 🤫 · `geschaeftssinn` 📊

## Schritte
1. **Daten:** `godot/data/attributes/core.json` (Dict-Kategorie wie `ethnicities`): je Attribut `{de, icon, desc}`. In `Data.gd` → `reload()` als `Data.ATTRIBUTES = DataLoader.load_dict("attributes")` laden.
2. **Zustand:** `state.attributes = {"verhandlung": 22, …}` in `new_game()` (Basis ~22); `load_game()`-Migration ergänzt fehlende Felder mit Basiswerten. Backstory-Seeding: `start`-Block der Backstories um `"attributes": {"verhandlung": +12, …}` erweitern und in `_apply_backstory_start()` anwenden (`data/backstories/core.json` für alle 5 Backstories sinnvoll befüllen: Anwalt → Verhandlung/Geschäftssinn, Kolumnist:in → Diskretion/Netzwerk, Ex-Studio-Junior → Netzwerk, Gescheitert → Menschenkenntnis, Aufsteiger:in → Geschäftssinn).
3. **API in Game.gd:**
   - `attr(key) -> int` (mit Default), `attr_gain(key, amount: float)` — Wachstum mit abnehmendem Ertrag: volle Wirkung bis 40, ×0,5 bis 70, ×0,25 darüber; Clamp 0–100; Zehntelpunkte erlaubt (float speichern, int anzeigen).
   - Kein Punkteverteilen, kein XP-Pool — nur `attr_gain` aus konkreten Handlungen.
4. **Wachstums-Hooks** (klein anfangen, je +0,2 bis +0,6 pro Ereignis):
   - `verhandlung`: erfolgreicher `sign_client()`-Abschluss, erfolgreiches `haggle()`, angenommener Package-Deal
   - `menschenkenntnis`: richtige Prognose (`tick_predictions`, dort wo instinct +3 vergeben wird), aufgedecktes Geheimnis entschärft
   - `netzwerk`: `grant_favor()` erhalten (nicht selbst gewährt), Gala-Woche mit Gefallen-Gewinn, Machtfigur-Deal
   - `diskretion`: Gerücht erfolgreich unterdrückt/ausgesessen (`suppress_rumor`/`wait_out_rumor`-Erfolgspfade), `suppressStory` eingelöst
   - `geschaeftssinn`: Monatsabschluss mit positivem Cashflow (`_month_close`, kleiner Tick), `buecher`-Rabatt aktiv
5. **Planer-Training (optional, klein):** Spieler-Aktion `weiterbildung` 📚 im `PLANNER_PLAYER`: ab 3 Slots/Woche +0,3 auf das schwächste Attribut. Kein gezieltes Pumpen einzelner Werte.
6. **UI:** Agentur-Tab (`_render_buero`): neue Karte „Deine Stärken“ — pro Attribut Icon, Name, Wert + `_bar()`, Tooltip mit `desc`. Backstory-Karte bleibt daneben bestehen.
7. **Tests:** Seeding je Backstory (Anwalt-Verhandlung > Basis), `attr_gain`-Ertragskurve (über 70 nur ×0,25), Save/Load-Roundtrip, Migration alter Stände.

## Akzeptanzkriterien
- [ ] Headless-Test grün, inkl. neuer Tests
- [ ] Attribute + Seeds vollständig in JSON (`data/attributes/`, `data/backstories/`), keine Werte im Code außer Basis/Kurve
- [ ] Alte Spielstände laden ohne Fehler (Basiswerte nachgerüstet)
- [ ] Screenshot Agentur-Tab zeigt die Attributskarte (`… -- --shot-game`)
- [ ] .exe neu exportiert
- [ ] Ein Commit: `feat: RPG-Attribute der Spielfigur (Seeding, Wachstum durch Benutzung, UI)`
