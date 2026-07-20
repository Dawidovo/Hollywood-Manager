# Chunk 05 — Headless-Testsuite ausbauen

## Ziel
`godot/tests/Test.gd` von Smoke-Test zu echter Regressionssuite ausbauen, damit die Refactoring-Chunks (01–03, 09) ein Sicherheitsnetz haben.

## Kontext
Aufruf: `Godot_console.exe --headless --path godot res://tests/Test.tscn`. Tests sollen deterministisch sein — RNG vor jedem Testfall mit festem Seed initialisieren.

## Schritte
Je einen fokussierten Testfall (eigene Funktion, klare Assertions) für:
1. **Verhandlung:** Angebot unter Erwartung → Ablehnung mit Hinweis; passendes Angebot → Annahme; gebrochenes Versprechen → Loyalität sinkt, Ruf-Schaden.
2. **Casting:** Passung steigt mit Genre-Match; Ruf-Schranke blockt zu schwache Agentur; Package-Deal setzt beide Gagen +12 %.
3. **Box-Office:** gleicher Seed → gleiches Ergebnis (Determinismus); Flop senkt Heat, Hit steigert Ruhm.
4. **Wirtschaft:** Provision fließt bei Drehbeginn; 3 Monate zahlungsunfähig → Game Over.
5. **Zeitachse:** `fame_at` folgt Karrierekurve (vor Debüt 0, Peak am Karrierehoch); Schauspieler stirbt → verschwindet aus Pool.
6. Einfachen Test-Runner-Standard etablieren: Zähler für passed/failed, Exit-Code ≠ 0 bei Fehlschlag (wichtig für spätere CI).

## Akzeptanzkriterien
- [ ] Mindestens 6 neue Testfälle, alle grün; Exit-Code ≠ 0 bei absichtlich kaputtem Assert (einmal manuell verifizieren)
- [ ] Ein Commit: `test: Regressionssuite für Verhandlung, Casting, Box-Office, Wirtschaft`
