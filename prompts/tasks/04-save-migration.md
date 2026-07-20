# Chunk 04 — Save-Versionierung & Migration

## Ziel
Spielstände (`user://hm_save.json`) bekommen eine Versionsnummer und einen Migrationspfad, damit Refactorings (Chunks 01–03, 09) keine alten Saves zerstören.

## Kontext
Autosave schreibt den kompletten `state` als JSON. Jede Strukturänderung (neue Felder, umbenannte Keys) macht alte Saves aktuell stillschweigend kaputt oder führt zu `null`-Zugriffen.

## Schritte
1. `save_version: int` in den Save-Payload aufnehmen (Start: 1).
2. Beim Laden: fehlende Version = 0. Migrationskette `_migrate_save(data, from_version)` mit einem `match`/Schleife pro Versionssprung.
3. Fehlende Felder defensiv mit Defaults auffüllen (z. B. `dna` bei Klienten aus Alt-Saves via `initial_dna` nachziehen).
4. Bei nicht-migrierbarem Save: sauberer Dialog „Spielstand inkompatibel" statt Crash; Save nicht überschreiben, sondern als `hm_save.bak.json` sichern.
5. Test: Alt-Save-Fixture (ohne Version, ohne DNA) in `godot/tests/` ablegen, Laden + Migration im Headless-Test prüfen.

## Akzeptanzkriterien
- [ ] Alt-Save-Fixture lädt ohne Fehler und ist voll bespielbar
- [ ] Tests grün, .exe neu exportiert
- [ ] Ein Commit: `feat: Save-Versionierung mit Migration und Backup`
