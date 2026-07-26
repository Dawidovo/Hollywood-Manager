# Chunk 20 — Balance: Energie des Managers erodiert langfristig gegen null

## Befund (Balance-Sim, Juli 2026)

`godot/tools/BalanceSim.gd` spielt 104 Wochen pro Epoche **inklusive** monatlichem
Palm-Springs-Urlaub (Energie +18, Stress −22) und Arztbesuch, sobald Stress > 50
bzw. Gesundheit < 70. Stress bleibt damit beherrschbar (~40–60). Die **Energie**
fällt trotzdem in allen Epochen langfristig Richtung null:

| Epoche | Energie Woche 13 → 52 → 104 |
|---|---|
| 1925 | 99 → 19 → 13 |
| 1950 | 99 → 83 → 35 |
| 1980 | 100 → 68 → **0** |
| 2010 | 99 → 78 → 26 |

Der wöchentliche Grundverbrauch übersteigt alle verfügbaren Erholungsquellen —
selbst wer alles richtig macht, endet im zweiten Jahr im Dauertief. Ohne Energie
werden Orte/Aktionen unbenutzbar; das Spiel wird zäh statt spannend.

## Ziel

Energie soll ein **taktisches** Budget sein (Wochen mit Raubbau ↔ Wochen mit
Erholung), kein struktureller Abwärtstrend. Ein Spieler, der monatlich erholt,
soll langfristig um 50–70 pendeln.

## Schritte

1. **Verbrauchsquellen inventarisieren:** Alle `player.energy`-Abzüge (Persona-Tick,
   Orte, Kanäle, Szenen, Planner) auflisten und die Wochensumme bei Normalspielweise
   beziffern (die Sim liefert die Kurve, `Persona.gd` die Einzelposten).
2. **Regeneration einführen/stärken:** z. B. passive Wochenregeneration bei Stress
   < 40 (+2 bis +4), Wochenende-Effekt im leeren Planner, oder Lifestyle-Stufen
   geben Energie-Regeneration statt nur Prestige. Eine Quelle reicht — klein
   anfangen, Sim erneut laufen lassen.
3. **Urlaub prüfen:** +18 einmal im Monat gegen ~20–30 Verbrauch pro Monat ist zu
   schwach; ggf. auf +25–30 anheben oder Zweitnutzung mit abnehmendem Ertrag.
4. **Regressionsschutz:** Sim-Akzeptanz — in Woche 104 Energie ≥ 40 in allen vier
   Epochen (Seeds wie im Tool).

## Akzeptanzkriterien

- [ ] BalanceSim: Energie pendelt langfristig (Woche 104 ≥ 40 in allen Epochen), Stress bleibt im bisherigen Korridor
- [ ] Headless-Test grün, .exe neu exportiert
- [ ] Ein Commit: `balance: Energie-Ökonomie — Regeneration gegen den Dauertief-Drift`
