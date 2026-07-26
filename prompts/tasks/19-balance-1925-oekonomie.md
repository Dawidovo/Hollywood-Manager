# Chunk 19 — Balance: Die 1925-Kampagne ist wirtschaftlich kaum überlebbar

## Befund (Balance-Sim, Juli 2026)

`godot/tools/BalanceSim.gd` (Aufruf: `godot --headless --path godot res://tools/BalanceSim.tscn`)
spielt pro Epoche 104 Wochen mit solider Standard-Heuristik: 4 Klienten signen,
beste Passung pitchen, Post beantworten, monatlich Urlaub/Arzt. Ergebnis:

| Epoche | Agentur-Cash Start → Woche 104 | Game Over? |
|---|---|---|
| 1925 | 118K → **−17K** | **Woche 80 pleite** (trotz 31 vermittelter Filme) |
| 1950 | 249K → 253K | nein (trägt sich knapp) |
| 1980 | 603K → 558K | nein (leicht defizitär bis stabil) |
| 2010 | 1,47M → 1,33M | nein (leicht defizitär) |

Die Provisionserlöse decken in der Stummfilm-Ära die (inflationsskalierten) laufenden
Kosten nicht — der Verlauf ist monoton fallend, es gibt keinen Hebel, der das bei
normaler Spielweise auffängt. 1925 ist damit faktisch ein Hardcore-Modus, ohne dass
das Spiel es sagt.

## Ziel

Eine 1925-Kampagne mit solider Spielweise (volles Roster, regelmäßige Deals) soll
sich knapp tragen — anspruchsvoll bleiben, aber nicht strukturell verlieren.

## Schritte

1. **Diagnose verfeinern:** In der Sim (oder per Ledger-Auswertung) aufschlüsseln,
   wo 1925 das Geld hingeht: Overhead vs. Perk-Kosten vs. Gagenniveau (niedrige
   Fame-Werte ⇒ `ask_fee` mit Potenz 2,6 ⇒ Mini-Provisionen?). Wahrscheinlichster
   Kandidat: Provisionen skalieren mit `fame^2.6`, Fixkosten nur mit Inflation.
2. **Stellschrauben** (klein drehen, Sim nach jeder Änderung neu laufen lassen):
   Grundgage/`ask_fee`-Untergrenze der frühen Ära anheben, Overhead der ersten
   Karrierestufe senken, oder Startkapital 1925 erhöhen (stumpfester Hebel, zuletzt).
   Balance-Werte gehören als Konstanten zusammengefasst (siehe Chunk 01).
3. **Regressionsschutz:** Sim-Lauf 1925 als Akzeptanzkriterium — Woche 104 ohne
   Game Over und Cash-Endstand > 0 bei Seed 2925.
4. 1950/1980/2010 gegenprüfen (dürfen nicht ins Positive kippen — leicht defizitär
   bis knapp tragend ist gewollt).

## Akzeptanzkriterien

- [ ] BalanceSim 1925: kein Game Over, Endstand > 0; übrige Epochen im bisherigen Korridor
- [ ] Headless-Test grün, .exe neu exportiert
- [ ] Ein Commit: `balance: 1925-Ökonomie überlebbar — Gagen/Kosten der Frühzeit justiert`
