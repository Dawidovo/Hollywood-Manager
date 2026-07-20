# Chunk 16 — RPG II: Sichtbare Proben in Event-Entscheidungen

## Ziel
Event-Choices können eine **Probe** auf ein Spieler-Attribut tragen. Der Button zeigt Attribut und Erfolgschance an; Erfolg/Fehlschlag laufen über die vorhandenen `effects`/`effects_fail`-Pfade. Bestehende JSON-Events bekommen erste Proben. Voraussetzung: Chunk 15.

## Kontext
- `godot/scripts/EventEngine.gd`: `build_event()` baut Choices (`_choice_fn` würfelt heute schon `success_chance` fix), `check_conditions()` prüft Bedingungen, `subst()` ersetzt Platzhalter. Choice-Schema siehe `data/events/core.json` (z. B. „steuerpruefung“).
- Disabled-Buttons werden unterstützt (`entry["disabled"] = true`, gerendert in `_show_next_modal`).
- Identität: `Game.identity_strength(key)` liefert −1…+2 — als situativer Modifikator nutzbar.

## Schema-Erweiterung (Choice)
```json
{
  "label": "Den Prüfer umgarnen",
  "check": {"attr": "menschenkenntnis", "dc": 45, "identity": "klientenorientiert"},
  "effects": [ … ], "effects_fail": [ … ],
  "outcome": "…", "outcome_fail": "…"
}
```
- Chance: `clampf(0.5 + (attr - dc) / 100.0 + identity_strength(identity) * 0.05, 0.05, 0.95)` — Attribut = DC ⇒ 50 %, jeder Punkt Differenz ±1 %. `identity` optional.
- `check` und `success_chance` schließen sich aus (`check` gewinnt, `push_warning` bei beidem).

## Schritte
1. **EventEngine:** `_check_chance(check: Dictionary) -> float` implementieren; in `_choice_fn()` verwenden (Erfolg ⇒ `effects`/`outcome`, sonst `effects_fail`/`outcome_fail`). Bei Erfolg **automatisch** `Game.attr_gain(attr, 0.4)`, bei Fehlschlag `0.15` (aus Fehlern lernt man weniger, aber etwas).
2. **Sichtbarkeit:** Label-Präfix im `build_event()`: `„[👁 Menschenkenntnis · 62 %] Den Prüfer umgarnen“` (Icon/Name aus `Data.ATTRIBUTES`, Prozent gerundet). Choices mit Probe nie verstecken — schlechte Chancen sind eine Spielerentscheidung.
3. **Bedingungen:** `check_conditions()` um `"min_attr": {"verhandlung": 40}` erweitern (für Choices UND Event-`conditions`/weight-`mods.if` — läuft automatisch über den gemeinsamen `_check`).
4. **Bestehende Events nachrüsten** (nur JSON): in `data/events/core.json` und `data/events/backstory_chains.json` je 1–2 passende Choices auf Proben umstellen (z. B. steuerpruefung „Anwälte einschalten“ bleibt Geld, „Aussitzen“ bleibt frei, NEU „Den Prüfer einschätzen“ = Menschenkenntnis-Probe). Insgesamt mindestens 6 Proben im Spiel.
5. **Neues Schaufenster-Event** `data/events/rpg_proben.json`: 1 Event mit drei unterschiedlichen Proben-Choices (Verhandlung/Diskretion/Netzwerk), damit das System sofort erlebbar ist.
6. **Doku:** `godot/data/README.md` — Events-Schema um `check`/`min_attr` ergänzen.
7. **Tests:** Chance-Formel (attr=dc ⇒ 0,5; Clamps), Erfolgs-/Fehlschlagpfad deterministisch (dc extrem hoch/niedrig), `attr_gain` wird bei Probe ausgelöst, `min_attr`-Bedingung sperrt/öffnet, Label enthält Prozentangabe.

## Akzeptanzkriterien
- [ ] Headless-Test grün, inkl. neuer Tests
- [ ] Probe-Buttons zeigen Attribut-Icon + Prozent; keine versteckten Proben
- [ ] Mindestens 6 Proben in bestehenden/neuen JSON-Events, 0 neue Skript-Events
- [ ] README-Doku aktualisiert
- [ ] .exe neu exportiert
- [ ] Ein Commit: `feat: Attributs-Proben in Event-Entscheidungen (EventEngine + JSON-Schema)`
