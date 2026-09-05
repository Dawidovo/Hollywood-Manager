# QA-01 – Spielstände sicher lesen und schreiben

**Priorität:** P1 · **Status:** umgesetzt (05.09.2026) · **Abhängigkeit:** keine

> Umsetzung: Schema-Validierung vor Übernahme in `state`, atomares Speichern über
> Tempdatei + Rename mit Fehlerstatus (`Game.save_error`), Backup-Fehler werden im
> `load_error` benannt; Save-Button/Autosave melden Erfolg und Fehler in der UI.
> Nachweis gegen frische isolierte Kopie: `../../2026-09-05-qa01-retest/logs/`.

## Befund und Reproduktion

In der isolierten Testumgebung `hm_save.json` nacheinander mit `{}`, `{"saveVersion":2}` und `{"saveVersion":2,"year":1950,"agency":null}` befüllen und `Game.load_game()` aufrufen. Alle drei Dateien werden mit `true` und leerem `load_error` akzeptiert. Gleichzeitig entstehen Skriptfehler, etwa wegen fehlendem `year`; der zuvor gültige Zustand wird durch den defekten ersetzt. Nachweis: `../logs/audit.log`, Marker `AUDIT_BAD_SAVE`.

Zusätzlich einen gültigen Test-Save schreibschützen und speichern. `save_game()` ruft `store_string` auf einer Nullreferenz auf. Der Aufrufer läuft weiter, bekommt aber keinen Fehlerstatus. Kontrollierter Nachweis: `../logs/save-io.log`; die alte Datei blieb im Test bytegleich.

## Soll und Umsetzung

In `godot/scripts/Game.gd:2290` sowie `:2310` Dateizugriffe prüfen, ein explizites Ergebnis zurückgeben und das geladene Schema vor Übernahme in `state` validieren. Migration auf einer temporären Kopie ausführen. Fehlende neue optionale Felder weiterhin migrieren; fehlende Kernfelder und falsche Typen ablehnen. Backup-Fehler ebenfalls melden (`_backup_save`, Zeile 2301).

Speichern über eine temporäre Datei mit geprüftem Abschluss und Austausch umsetzen. Die letzte gültige Datei darf bei fehlgeschlagenem Schreiben nicht verloren gehen. In `Main.gd` Save-Button und Autosave-Aufrufer mit verständlicher Rückmeldung verbinden. Kein umfassender Umbau des Save-Formats in diesem Chunk.

## Abnahme

- Die drei obigen Payloads ergeben `false`, einen verständlichen Fehler und einen unveränderten aktiven Zustand.
- Bestehende v1-Fixture und normale v2-Roundtrips bestehen weiterhin.
- Fehlende Leserechte, Schreibschutz und Backup-Schreibfehler erzeugen keine Nullreferenzen.
- Erfolg wird erst nach erfolgreich abgeschlossenem Schreiben gemeldet; alter Save bleibt bei Fehler erhalten.
- Logiktests, gezielte Negativtests und anschließend EXE-Export ausführen.
