# Chunk 08 — Web-Prototyp eingefroren (ENTSCHIEDEN)

## Status
**Entschieden Juli 2026: Die Webversion spielt keine Rolle mehr.**

- `index.html` + `js/` bleiben als Referenz im Repo, werden aber **nicht mehr angefasst**: keine Features, keine Bugfixes, keine Refactorings, keine Analyse.
- SonarQube schließt die Webversion aus (`sonar-project.properties`).
- **Anweisung an alle KI-Modelle/Sessions:** Ausschließlich in `godot/` arbeiten. Die Webversion in Prompts, Scans und Refactorings ignorieren.

## Optionaler Rest (niedrige Priorität)
Dateien nach `web-prototype/` verschieben (`git mv`), damit der Projektroot aufgeräumt ist. Dabei README-Startanleitung anpassen. Kein Muss — nur Kosmetik.
