# QA-03 – Follow-ups nach echten Wochen terminieren

**Priorität:** P2 · **Status:** offen · **Abhängigkeit:** keine; Save-Migration mit QA-01 abstimmen

## Befund

`delay_weeks` wird in `EventEngine.gd:363` durch vier geteilt und gerundet; `Game.gd:1641` prüft den Monatsindex. Der aktuelle Wochentag innerhalb des Monats wird dabei nicht berücksichtigt. `../logs/timing.log` belegt die tatsächlich nötigen `end_week()`-Aufrufe:

| Konfigurierte Wochen | Start in Woche 1 | Start in Woche 4 |
|---:|---:|---:|
| 1 | 5 | 2 |
| 4 | 5 | 2 |
| 5 | 5 | 2 |
| 6 | 9 | 6 |
| 12 | 13 | 10 |

Fünf- und Sechs-Wochen-Fristen kommen in den ausgelieferten Ereignisdaten vor, beispielsweise `data/events/backstory_chains.json`. Es handelt sich daher nicht nur um hypothetische Mod-Werte.

## Umsetzung

Absoluten Wochenindex für neue Follow-ups verwenden und den genauen Fälligkeitszeitpunkt relativ zur Spielerentscheidung definieren. Quest-Fristen (`EventEngine.gd:502`) mit derselben Berechnung anzeigen. Alte `due`-Monatswerte bewusst migrieren und bereits überfällige Einträge genau einmal zustellen.

Nebenbefund: Die Follow-up-Erzeugung kopiert nur `cid`, `sid` und `_questId`; ein übergebener `ctid` und `sender` geht im Test verloren. Beim Umbau festlegen, welche Kontextfelder unterstützt und gespeichert werden. Dafür ist noch kein konkreter ausgelieferter Gameplay-Ausfall nachgewiesen.

## Abnahme

- Verzögerungen 1, 4, 5, 6 und 12 wirken unabhängig von Startwoche 1–4.
- Monats- und Jahreswechsel sowie Save/Load verändern den Termin nicht.
- Questanzeige und tatsächliche Zustellung stimmen überein.
- Migration vorhandener Follow-ups und kein doppeltes Feuern.
- Bestehende Logiktests und neue Fristenmatrix, danach EXE-Export.
