# QA-09 – Tests als verlässliche Freigabegrundlage ausbauen

**Priorität:** P2 · **Status:** umgesetzt (06.09.2026) · **Abhängigkeit:** QA-07 für die bekannte Zufallsprüfung

> Umsetzung: (1) `Game.use_test_savedir()` — Suite speichert unter
> `user://qa_test/`, BalanceSim unter `user://qa_test_sim/`; Save-Pfade sind
> jetzt Variablen (`Game.save_path` …, alte Harness-Skripte dieses Ordners
> nutzen noch die Konstanten-API und gelten nur für den alten Snapshot).
> (2) Runner `tools/run-tests.ps1`: Timeout, Seed (`-- --seed=N`, Suite druckt
> `TEST_SEED`), Logpfad, Markerpflicht, SCRIPT-ERROR-/FAIL-Auswertung und
> Hashvergleich des echten Spielstands; verifiziert rot bei Laufzeitfehler,
> Assertion und Timeout, grün bei sauberem Lauf. (3) BalanceSim beantwortet
> die Ereignisse/Dialoge der Woche (erste verfügbare Wahl); Anzahl, Ignorierte,
> Dialogschritte und Blockaden stehen in den `SUM;`-Zeilen, Marker `SIM_DONE`.
> (4) `--shot-tisch`/`--shot-verhandlung` bauen den Tisch deterministisch auf
> und brechen mit Exit ≠ 0 ab, wenn kein Tisch steht. (5) `tools/lint.ps1`
> prüft rekursiv `scripts/` (inkl. `ui/`), `tests/` und `tools/` (34 Dateien,
> 0 Findings) und meldet fehlendes gdtoolkit mit Einrichtungshinweis.
> Beobachtung aus dem neuen Sim-Standard (keine Änderung in diesem Chunk):
> solide/Seed 5000/1925 endet mit Game Over in Woche 100.

## Nachgewiesene Lücken

- `Test.gd` und `BalanceSim.gd` verwenden den normalen Save-Pfad. Standardaufrufe können den echten Autosave überschreiben; die BalanceSim warnt sogar im Dateikommentar davor. Dieser Audit musste deshalb eine Projektkopie mit umgebogenen Datenpfaden verwenden.
- Ein `SCRIPT ERROR` macht den Godot-Prozess nicht automatisch rot: Der kontrollierte Schreibfehler beendet sich mit Exit 0. Die Automation muss neben Assertions auch Laufzeitfehler auswerten.
- `BalanceSim.gd:52` ignoriert die von `end_week()` zurückgegebenen Entscheidungen. Im Zusatzlauf wurden 1.279 Antworten tatsächlich ausgeführt; die Wirtschaftsergebnisse unterscheiden sich erheblich. Siehe Bericht, keine pauschale Balanceänderung daraus ableiten.
- `--shot-tisch` und `--shot-verhandlung` liefern in diesem Lauf normale Casting-Ansichten statt des Verhandlungstischs. `Main.gd:398` hängt von zufällig erzeugten Castings und erfolgreichen Pitches ab; nach einer bindenden Absage helfen auch Wiederholungen nicht. Trotzdem wird ein Bild gespeichert und Exit 0 geliefert.
- Die dokumentierte Lint-Standardliste umfasst keine rekursiven UI-Skripte und nicht BalanceSim. Zusätzlich fehlt in dieser Umgebung die nutzbare Python/gdtoolkit-Einrichtung.

## Umsetzung

Einen expliziten isolierten Test-Datenpfad und einen Runner mit Timeout, Seed, Logpfad und Abschlussmarker einführen. Unerwartete `SCRIPT ERROR` und unvollständige Läufe müssen fehlschlagen; erwartete Negativtest-Meldungen eng abgrenzen. Echte Spielstände dürfen nicht verändert werden.

Simulation um tatsächliche Event-/Dialogbearbeitung und klare Strategien erweitern. Screenshot-Fixtures deterministisch aufbauen und den gewünschten UI-Zustand vor Aufnahme prüfen. Lint rekursiv über die Produktivskripte und relevanten Test-/Simulationsdateien laufen lassen, Abhängigkeit reproduzierbar dokumentieren.

## Abnahme

- Hash des normalen Spielstands ist vor und nach allen Tests identisch.
- Eingebrachter Laufzeitfehler, Assertion und Timeout werden jeweils als Fehler erkannt.
- Wiederholbarer Seed erzeugt denselben Ablauf; Seed und Profil stehen im Bericht.
- Verhandlungstisch-Hooks zeigen tatsächlich einen Verhandlungstisch oder schlagen explizit fehl.
- Ereignisse werden beantwortet; deren Anzahl, blockierte Dialoge und Abbrüche sind sichtbar.
- Lint deckt `scripts/ui/` und Simulation ab; Tests und EXE-Export nach Produktivänderungen ausführen.
