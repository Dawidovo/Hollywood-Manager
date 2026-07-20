# Chunk 08 — Web-Prototyp einfrieren

## Ziel
Doppelte Wartung beenden: Die Godot-Version ist laut README die Hauptversion, `js/` implementiert dieselbe Spiellogik aber nochmal (~3200 Zeilen). Der Web-Prototyp wird offiziell eingefroren.

## Kontext
Jedes neue Feature müsste sonst zweimal gebaut werden — das ist die größte Technical-Debt-Quelle im Projekt. Der Prototyp bleibt als Referenz erhalten, bekommt aber keine Features mehr.

## Schritte
1. `web-prototype/` anlegen und `index.html`, `js/` dorthin verschieben (Git: `git mv`, Historie bleibt erhalten).
2. `web-prototype/README.md`: Status „eingefroren, Referenz-Implementierung — Feature-Stand [Datum], Weiterentwicklung nur in godot/".
3. Projekt-README anpassen: Web-Abschnitt kürzen, auf Freeze hinweisen, Startanleitung auf neuen Pfad umstellen.
4. `tools/import_imdb.py` prüfen: erzeugt `js/actors_full.js` → Zielpfad auf `web-prototype/js/` anpassen **oder** (besser) einen zweiten Export für die Godot-Version vorsehen — dann als eigenes Follow-up-Chunk notieren.
5. `sonar-project.properties`: Pfade aktualisieren.

## Akzeptanzkriterien
- [ ] Web-Prototyp läuft am neuen Ort (`py -3 -m http.server` im `web-prototype/`-Ordner)
- [ ] README + sonar-Konfiguration aktualisiert
- [ ] Ein Commit: `chore: Web-Prototyp nach web-prototype/ eingefroren`
