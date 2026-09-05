# QA-05 – Studio-Dinner verlieren keine Bruchteile mehr

**Priorität:** P2 · **Status:** offen · **Abhängigkeit:** keine

## Reproduktion und Ergebnis

Im Standardstart 1950 fünfmal jeweils genau einen Dinner-Slot für dasselbe Studio planen und pro Woche auswerten. Die Beziehung bleibt im Test bei 27. Laut Planerbeschreibung bringt jeder Slot +0,2; fünf Slots sollten insgesamt +1 bewirken. Nachweis: `../logs/audit.log`, `AUDIT_DINNER`.

`Planner.gd:128` rundet die Summe je Woche zu einer Ganzzahl. Ein oder zwei Slots einer normalen Woche ergeben damit 0. Die Planung wird abhängig davon, wie identische Aktivitäten über Wochen verteilt werden.

## Umsetzung

Bruchteile im Beziehungswert oder als Restwert erhalten; erst die Anzeige runden. Den Backstory-Multiplikator für Studio-Dinner berücksichtigen. Änderungen an der sonstigen Beziehungsbalance gehören nicht in diesen Chunk.

## Abnahme

- Fünf einzelne Standardslots bringen zusammen +1.
- Dieselbe Slotanzahl wirkt gebündelt und verteilt gleich, soweit keine anderen Wochenereignisse einwirken.
- Backstory-Multiplikator, Obergrenze 100 und Save/Load erhalten das korrekte Ergebnis.
- Beschreibung und tatsächlicher Effekt stimmen überein.
- Logiktests, gezielte Rundungstests, EXE-Export.
