# Hollywood Manager – Testbericht und Fix-Chunks

**Datum:** 05.09.2026 · **Quellstand:** `036ce23e635e1b45da5309bf5fe756123c12528a` · **Engine:** Godot 4.7.1, Windows.

Die Kernfunktionen laufen über viele simulierte Wochen und Startkonfigurationen. Die wichtigsten offenen Fehler betreffen jedoch **Spielstandsicherheit, verlorene Entscheidungen und Kreditgrenzen**. Ein grüner Lauf der bisherigen Testsuite reicht deshalb nicht als Freigabe. Die Ergebnisse sind in neun unabhängig bearbeitbare Chunks aufgeteilt. Es wurden keine Produktivfehler behoben und keine neue Spiel-EXE gebaut.

## Testumfang und Ergebnisse

| Prüfung | Ergebnis und Aussagegrenze |
|---|---|
| Bestehende Logiktests, sechs vollständige Läufe | Je 740 Checks; fünf Läufe fehlerfrei, ein Lauf mit einem Fehler bei automatischer Kontaktpflege. Insgesamt 4.439 bestandene und 1 fehlgeschlagene Prüfung. |
| Mitgelieferte Balance-Simulation | 16 Kampagnen: vier Epochen × zwei Seeds × zwei Spielprofile, jeweils 104 Wochen. Alle beendet, kein Game Over. Ein ungefangener Schreibfehler im ausgewerteten Lauf, trotz Prozess-Exit 0. |
| Ergänzte Simulation mit Ereignisantworten | Weitere 16 Kampagnen à 104 Wochen; 1.279 Ereignisantworten verarbeitet, keine Skriptfehler oder blockierten Dialoge im Log. Kein Game Over; fünf Kampagnen enden mit negativer Agenturkasse. |
| Startkonfigurationen und Navigation | Alle vier Epochen × fünf Backstories plus Standardstart: 24 Starts, jeweils alle 17 Tabs; 408 Render-Aufrufe ohne Skriptfehler. Dies sind programmatische Aufrufe der echten UI-Methoden, keine manuellen Mausklicks. |
| Bildschirm-/Dialog-Screenshots | 40 vorhandene Screenshot-Hooks bei 1366×768: alle erzeugen Bilder und enden mit Exit 0; Übersichtsbilder gesichtet, ausgewählte Ansichten zusätzlich in voller Größe geprüft. Zwei Hooks zeigen allerdings nicht den angekündigten Verhandlungstisch. |
| Fenstergrößen | Backstory und Vertragsdialog zusätzlich bei 1024×600, 1280×720 und 1920×1080: sechs Bilder plus Messung der Panelgrenzen. Vertikaler Überlauf bei kleinen Fenstern bestätigt. |
| Gezielte Negativ- und Grenztests | Save-Schema, schreibgeschützter Save, Ereignisverlust beim Laden, Fristen, Kreditrahmen, Rundung, wiederholtes Signing, Null-Verkäufe und falscher Mitarbeiter-Digest geprüft. |
| Vorhandene Release-EXE | Start-Smoke-Test ohne Grafik mit begrenzter Laufzeit: Exit 0, keine Spiel-Skriptfehler. Kein vollständiger interaktiver Durchlauf des exportierten Builds. |
| Lint | Nicht ausgeführt: das dokumentierte Skript wird durch die lokale Ausführungsrichtlinie blockiert; `py` ist nicht verfügbar, und die verfügbare Python-Laufzeit enthält `gdtoolkit` nicht. Kein Lint-Erfolg behauptet. |

Die beiden ausgewerteten Simulationsvarianten ergeben zusammen **3.328 simulierte Wochen**. Sie verwenden einfache Heuristiken und zwei Seeds je Profil/Epoche. Das ist eine breite Funktionsprüfung, kein Nachweis einer ausgewogenen Langzeitbalance oder vollständiger Pfadabdeckung.

## Empfohlene Reihenfolge

P1 = hohe Priorität wegen Daten-/Entscheidungsverlust oder Regelbruch. P2 = regulärer Fehler mit konkreter Auswirkung. P3 = defensive Absicherung ohne nachgewiesenen normalen UI-Auslöser.

| Chunk | Priorität | Aufgabe |
|---|---|---|
| [QA-01](chunks/QA-01-spielstaende.md) | P1 | Spielstände validieren, Schreibfehler behandeln und sicher speichern |
| [QA-02](chunks/QA-02-offene-entscheidungen.md) | P1 | Offene Ereignisse und Dialogentscheidungen über Laden erhalten |
| [QA-04](chunks/QA-04-kreditrahmen.md) | P1 | Kreditrahmen für Planung durchsetzen; kostenloses Signing im Minus erlauben |
| [QA-03](chunks/QA-03-wochenfristen.md) | P2 | Ereignisketten nach echten Wochen terminieren |
| [QA-06](chunks/QA-06-dialoghoehe.md) | P2 | Überlange Dialoge scrollbar und vollständig bedienbar machen |
| [QA-07](chunks/QA-07-kontaktpflege.md) | P2 | Mitarbeiterergebnis korrekt melden und Zufallstests stabilisieren |
| [QA-05](chunks/QA-05-planer-rundung.md) | P2 | Bruchteile bei Studio-Dinnern erhalten |
| [QA-09](chunks/QA-09-testinfrastruktur.md) | P2 | Tests isolieren, Laufzeitfehler erkennen und Simulation vervollständigen |
| [QA-08](chunks/QA-08-aktionsinvarianten.md) | P3 | Wiederholte Signings und wirkungslose Aktienverkäufe abfangen |

Jeder Chunk enthält Reproduktion, Ist/Soll, betroffene Stellen, Grenzen und Abnahmekriterien. QA-09 kann früh bearbeitet werden, wenn zunächst verlässliche automatische Nachtests gewünscht sind. Die Nummern sind eigenständige QA-IDs und ersetzen nicht die vorhandene Aufgabenliste unter `prompts/tasks/`.

## Was die Balance-Simulation bislang verdeckt

Die ursprüngliche Simulation ruft `Game.end_week()` auf, verwirft aber die zurückgegebenen Ereignisse. Der Zusatzlauf beantwortet jeweils die erste verfügbare Entscheidung und durchläuft gegebenenfalls den Dialog. Dadurch ändern sich auch spätere Zufallsfolgen; die Zahlen sind ein Vergleich zweier Strategien, kein isolierter kausaler Effekt einzelner Events.

Beispiele für das Endkapital nach 104 Wochen:

| Epoche / Profil / Seed-Offset | Ohne Ereignisantworten | Mit Ereignisantworten |
|---|---:|---:|
| 1925 / solide / 5000 | $68.616 | −$132.793 |
| 1980 / solide / 0 | $1.057.110 | −$326.379 |
| 2010 / aggressiv / 5000 | $3.341.906 | $294.228 |

Im Zusatzlauf erreichen einzelne Kampagnen Stress 100 oder Energie 1. Das sind **Beobachtungen zur weiteren Balanceprüfung**, keine eigenständigen Balance-Bugs: Die erste verfügbare Antwort ist nicht zwingend wirtschaftlich sinnvoll. Vor pauschalen Kostenanpassungen sollte QA-09 umgesetzt werden.

## Testumgebung und Schutz vorhandener Daten

Getestet wurde in `project/`, einer isolierten Kopie des Godot-Projekts. Ausschließlich dort wurden alle `user://`-Literale in GDScript auf `res://qa_userdata/` umgebogen. Produktivskripte und vorhandene Spielstände wurden nicht verändert. Das ursprüngliche Projekt, die eingefrorene Webversion und die Spiel-EXE blieben unverändert. `godot/qa/.gdignore` hält die Testartefakte aus dem normalen Godot-Import heraus; die große Projektkopie ist zusätzlich lokal per `.gitignore` ausgeschlossen.

Die ersten Einrichtungsversuche mit einem benutzerdefinierten Datenpfad scheiterten an Godots Pfadbereinigung. `import.log` und `logic-1.log` sind deshalb **keine gültigen Baseline-Ergebnisse**. Die sechs gültigen Logikläufe sind `logic-2.log` bis `logic-7.log`. Die abgesonderte Pfadumleitung beschränkt die Aussage zu realen Installationsrechten; Schreibfehler wurden zusätzlich kontrolliert über eine schreibgeschützte Testdatei reproduziert.

Zertifikatsspeicher- und Shader-Cache-Meldungen stammen aus dieser eingeschränkten Testumgebung und werden nicht als Spielfehler gewertet. Der Schreibfehler aus `save-io.log` ist dagegen gezielt reproduziert. Ein Ogg-Metadatenhinweis und vereinzelte Ressourcenreste bei einem explorativen Simulationsende sind dokumentierte Nebenbeobachtungen, keine belegten Gameplay-Blocker.

Nicht abgedeckt: manuelle Maus-/Tastaturbedienung aller Aktionen, Hörprüfung der Musik, fremde Mod-Pakete, sämtliche Zweige jedes Dialogs, jahrzehntelange Kampagnen und die vollständige Grafikprüfung mit dem Standardrenderer. Die Bilder entstanden mit dem OpenGL-Kompatibilitätsrenderer.

## Nachweise

- [Wiederholter Logiktest mit Fehler](logs/logic-5.log), [erster gültiger erfolgreicher Lauf](logs/logic-2.log)
- [Gezielter Audit](logs/audit.log), [kontrollierter Schreibfehler](logs/save-io.log), [Fristentests](logs/timing.log), [Mitarbeiter-Fehlmeldung](logs/staff-audit.log)
- [Ursprüngliche Balance-Simulation](logs/balance-clean.log), [Simulation mit Entscheidungen](logs/balance-events.log)
- [408 UI-Aufrufe](logs/ui-smoke.log), [Fenster-/Dialogmaße](logs/ui-size.log), [EXE-Start](logs/release-startup.log)
- Screenshotübersichten: [1](overview-1.png), [2](overview-2.png), [3](overview-3.png), [4](overview-4.png), [5](overview-5.png)
- [Abgeschnittene Startgeschichten](size-backstory-1024x600.png), [abgeschnittener Vertragsdialog](size-negotiation2010-1024x600.png)
- [Ausführung und Testskripte](NACHTESTEN.md)
