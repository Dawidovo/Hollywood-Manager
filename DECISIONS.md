# Hollywood Manager — Entscheidungen

> Getroffene und bindende Entscheidungen. Nicht neu diskutieren, sondern befolgen.
> Neue Entscheidungen hier ergänzen (neueste oben in ihrer Sektion), überholte als
> ~~durchgestrichen~~ markieren statt löschen. Überblick zum Projekt: [ARCHITECTURE.md](ARCHITECTURE.md).

## Plattform & Scope

- **Webversion (`index.html`, `js/`) ist eingefroren** (Juli 2026, Chunk 08): keine Features,
  keine Bugfixes, keine Refactorings, keine Analyse. Sie dient nur noch als Referenz.
  Alle Arbeit — auch von KI-Modellen — findet ausschließlich in `godot/` statt.
- **Godot 4.7 / GDScript, UI komplett in Code** (eine Szene `Main.tscn`), Systeme als Autoloads.
  Keine Szenen-/Node-basierte UI einführen.
- **Spielsprache ist Englisch** (volle englische Lokalisierung seit Commit `441defc`);
  Doku und Prompts sind teils Deutsch — das bleibt so.

## Architektur

- **Daten statt Code:** Alle Spielinhalte liegen als JSON unter `godot/data/` und werden
  über `DataLoader.gd` gemergt. Neue Inhalte = neue JSON-Datei, kein Code.
  Mods laden aus `user://data/` und gewinnen bei Konflikten — das muss erhalten bleiben.
- **Eine deklarative Effekt-Sprache** für Events, Dialoge und Briefe (gemeinsame Ops).
  Neue Wirkungen als neue Ops in dieses Vokabular einbauen, keine Sonderwege.
- **Simulation first:** Dialog-/Brieftexte lesen Simulationsfakten nur über Placeholder
  und verändern die Welt nur über Effekt-Ops. Unbekannte Ops/Placeholder = Ladewarnung.
  Text darf keine Verträge, Kontakte oder Versprechen „erfinden".
- **Wochenzug:** Der Spielzug ist wöchentlich (`Game.end_week()`, 21-Slot-Planer) —
  ersetzt den früheren Monatszug. Neue Systeme takten wöchentlich.
- **Interaktionsstufen:** Benachrichtigungen werden automatisch gestuft
  (Digest → Notiz → Kurzdialog → volle Szene); neue Systeme melden über
  `Dialogs.dispatch(kind, ctx)` statt eigener Popups.

## Spieldesign

- **Sterbejahre** echter Schauspieler sind in der Simulation aktiv, werden dem Spieler
  aber **nie angezeigt**.
- **Talent/Ego/Genre-Werte sind Spielwerte**, keine biografischen Fakten — so kommunizieren.
- **Karriere-DNA** (fünf bipolare Image-Achsen) ist das Herzstück des Castings:
  Typecasting entsteht organisch, Imagewandel nur über gezielte Rollenwahl.
- **Versprechen und Gefallen sind Verpflichtungen, keine Währung:** Versprechen werden
  mit Deadline/Zeugen/schriftlich-Flag protokolliert; Bruch kostet Loyalität/Ruf,
  schriftliche Brüche können als Beweis in der Presse landen.

## Arbeitsweise & Qualität

- **Ein Chunk pro Session, ein Commit pro Chunk** (`prompts/tasks/`). Vor Beginn
  `git status` sauber.
- **Nach jeder Code-Änderung:** Logiktest laufen lassen UND die .exe neu exportieren
  (Kommandos in ARCHITECTURE.md). Der Nutzer spielt die .exe, nicht den Editor.
- **gdlint ja, gdformat nein** (Chunk 06): gdformat wurde bewusst ausgelassen —
  ein Repo-weiter Format-Lauf erzeugt einen Riesen-Diff. Nicht nachholen.
- **SonarQube analysiert nur `tools/` (Python)** — GDScript wird nicht unterstützt,
  die Webversion ist ausgeschlossen. Für GDScript ist gdlint das Werkzeug.
- **Pre-Commit-Hook blockt** bei gdlint-Findings und SonarQube-Quality-Gate-Fehlern
  (`tools/git-hooks/pre-commit`) — Findings beheben, Hook nicht umgehen.
- **Screenshot-Hooks:** vor den `--shot-<name>`-Argumenten ist das freistehende `--`
  Pflicht, sonst startet Godot einen Endlos-Prozess.

## Daten & Lizenz

- **IMDb-Datasets nur nicht-kommerziell:** `tools/import_imdb.py` nutzt die
  IMDb Non-Commercial Datasets. Für eine kommerzielle Veröffentlichung müssen die
  Daten ersetzt werden (z. B. TMDb-API oder Wikidata).
- **Kuratierte Seed-Daten** (~100 Stars) sind die Basis; `actors_full`-Importe
  ergänzen, ersetzen sie aber nicht.
