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

- [x] BalanceSim 1925: kein Game Over, Endstand > 0; übrige Epochen im bisherigen Korridor
- [x] Headless-Test grün, .exe neu exportiert
- [x] Ein Commit: `balance: 1925-Ökonomie überlebbar — Gagen/Kosten der Frühzeit justiert`

## Ergebnis (Juli 2026)

Drei Schrauben: `ask_fee`-Exponent 2,6 → 2,35 (hebt den unteren Ruhm-Bereich),
Bürokosten vor 1948 ×0,6 (dabei Formel-Duplikat in `_month_close` durch
gemeinsames `office_base_cost()` ersetzt), Startkapital per Era-Feld
`startCapitalMult` (1925: ×1,5, datengetrieben in `data/eras/core.json`).
Sim 1925: Woche 104 bei +44K statt Pleite in Woche 80; 1950/1980/2010
flach bis leicht positiv.
