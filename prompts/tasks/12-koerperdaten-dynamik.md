# Chunk 12 — Körperdaten II: Gewicht verändert sich über die Karriere

## Ziel
Das Gewicht von **Klienten** ist kein statischer Wert mehr: Es driftet mit Alter, Disziplin und Erschöpfung, reagiert auf Planer-Aktionen und kann durch Ereignisse (Rollen-Transformation, Krisen) gezielt verändert werden. Voraussetzung: Chunk 11 ist umgesetzt.

## Aktueller Stand (wichtig, neuer als ältere Prompts!)
- **Wochenrhythmus:** Der Spielzug ist `Game.end_week()`; nach jeder 4. Woche läuft `_month_close()` (dort u. a. `tick_clients()` — monatliche Klienten-Drifts). Der Planer hat 21 Slots/Woche (7 Tage × 3 Abschnitte); Klienten-Wochen werden in `_planner_client_week(c, counts)` aufgelöst (Effekte pro Slot skaliert, z. B. erholung −0,6/Slot).
- **Events sind datengetrieben:** `godot/data/events/*.json`, interpretiert von `godot/scripts/EventEngine.gd` (Autoload `EvEngine`). Effekt-Ops stehen in `_apply_effect()` (money, fame, trust, followup für Ketten …). Neue Ops dort ergänzen. Ereignisketten: Effekt `{"op":"followup","event":"<id>","delay_weeks":N}`, Kettenglieder mit `"followup_only": true`.
- Klienten-Dict wird in `Game.sign_client()` gebaut (Game.gd ~1490); Alt-Save-Felder werden in `load_game()` per `if not c.has(...)`-Block nachgerüstet.

## Schritte
1. **Zustand:** Beim Signing `c["weightKg"] = float(body_of(actor).weight)` setzen; in der `load_game()`-Klientenmigration nachrüsten. `c["weightTrend"]` (float, für den Pfeil in der UI) mitführen.
2. **Monatliche Drift** in `tick_clients()`: kleine Schritte (±0,1–0,4 kg/Monat). Einflüsse: Alter (ab ~40 leichte Zunahme), Disziplin (hohe Disziplin hält das Basisgewicht), Erschöpfung > 60 (Stressveränderung, Richtung per Actor-Hash deterministisch). Clamp auf ±25 % vom Basisgewicht. **Keine** Todes-/Gesundheitslogik — nur Zahlen + Flavor.
3. **Planer-Kopplung** in `_planner_client_week()`: `training`-Slots ziehen das Gewicht leicht Richtung Basiswert (~0,05 kg/Slot), viele `gala`-Abende leicht davon weg.
4. **Neue Effekt-Op** `weight` in `EventEngine._apply_effect()`: `{"op":"weight","amount":±N}` (kg, geclampt wie oben).
5. **Ereignisse** (`godot/data/events/koerper.json`, deutsch, 2–5 Choices im Stil von `data/events/core.json`):
   - `rollen_transformation` (Kette, 2 Glieder): Studio verlangt ±10 kg für eine Prestige-Rolle — zusagen (Erschöpfung ↑, Gewicht ändert sich über Followup, bei Release Ruhm-Bonus-Chance), Double/Kostüm verhandeln (Studio-Beziehung ↓), ablehnen.
   - `boulevard_figur`: Klatschblatt lästert über die Figur eines Klienten (nur wenn Gewicht deutlich vom Basiswert abweicht — Bedingung dafür braucht ggf. eine kleine Erweiterung von `check_conditions`, z. B. `requires_client: {"weight_dev_min": 8}`) — Optionen: PR-Konter, Gerücht aussitzen, Diät-Story inszenieren.
6. **Anzeige:** Klientenkarte zeigt aktuelles Gewicht + Trend (`↗/↘` ab |Trend| > 0,1), Talentpool weiterhin den Basiswert aus Chunk 11.
7. **Tests:** Drift nach 4× `end_week()` verändert `weightKg` in plausibler Spanne; Clamp greift; `weight`-Op wirkt; `training`-Woche zieht Richtung Basis; Save/Load erhält `weightKg`.

## Nicht in diesem Chunk
Kein Casting-Malus/Bonus nach Gewicht (heikel + Balance-Fass) — nur als Kommentar-Erweiterungspunkt an `fit_score()` notieren.

## Akzeptanzkriterien
- [ ] Headless-Test grün, inkl. neuer Tests
- [ ] Die zwei Ereignisse sind reine JSON-Daten (kein neuer Skript-Event-Code außer ggf. der `weight_dev_min`-Bedingung + `weight`-Op)
- [ ] Alte Spielstände laden ohne Fehler (Migration greift)
- [ ] .exe neu exportiert
- [ ] Ein Commit: `feat: Gewichtsdynamik über die Karriere (Drift, Planer, Events)`
