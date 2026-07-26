# Hollywood Manager — Einstieg für KI-Sessions

**Zuerst lesen, bevor du das Repo durchsuchst:**

1. [ARCHITECTURE.md](ARCHITECTURE.md) — Stand, Projektstruktur, Autoloads, Daten-System, Build-/Test-Kommandos
2. [DECISIONS.md](DECISIONS.md) — bindende Entscheidungen (nicht neu diskutieren)

Die wichtigsten Regeln in Kürze:

- Alle Arbeit findet in `godot/` statt. **`index.html` und `js/` sind eingefroren — nie anfassen.**
- Nach jeder Code-Änderung: Logiktest (`--headless --path godot res://tests/Test.tscn`) und .exe neu exportieren.
- Spielinhalte sind JSON unter `godot/data/` (Schemas: `godot/data/README.md`) — Inhalte dort ändern, nicht im Code.
- Ein Aufgaben-Chunk pro Session, ein Commit pro Chunk (`prompts/tasks/README.md`).
- Neue Architektur-Entscheidungen und Statusänderungen in DECISIONS.md bzw. ARCHITECTURE.md nachtragen.
