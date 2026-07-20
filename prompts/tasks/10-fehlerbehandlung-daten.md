# Chunk 10 — Fehlerbehandlung bei Daten-Import & Save-IO

## Ziel
Robustheit an den IO-Grenzen: Aktordaten-Import, Save/Load und `import_imdb.py` dürfen bei kaputten Eingaben nicht crashen oder stumm falsche Zustände erzeugen.

## Schritte
1. **Godot Save/Load:** `JSON.parse`-Fehler und fehlende Pflichtfelder abfangen → Fehlermeldung + Fallback auf Neustart statt Crash (überschneidet sich mit Chunk 04 — falls dort schon erledigt, hier nur verifizieren).
2. **Aktordaten:** Laden von Daten (Seed/generiert) gegen fehlende Felder absichern (`get("key", default)` statt direkter Zugriff an allen Grenzen, wo externe Daten reinkommen).
3. **`tools/import_imdb.py`:** Download-Fehler, unvollständige TSVs und kaputte Zeilen sauber behandeln (try/except mit Zeilen-Skip + Zähler, am Ende Report); Exit-Code ≠ 0 bei Totalausfall.
4. Negativtest in `godot/tests/Test.gd`: absichtlich kaputtes Save-JSON laden → erwarteter Fallback, kein Crash.

## Akzeptanzkriterien
- [ ] Kaputtes Save + fehlende Felder crashen nicht mehr (Test belegt es)
- [ ] Tests grün, .exe neu exportiert
- [ ] Ein Commit: `fix: robuste Fehlerbehandlung für Save-IO und Datenimport`
