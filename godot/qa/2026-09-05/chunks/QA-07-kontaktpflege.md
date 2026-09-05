# QA-07 – Kontaktpflege-Ergebnis korrekt melden und testen

**Priorität:** P2 · **Status:** offen · **Abhängigkeit:** keine

## Zwei zusammengehörige Befunde

1. In sechs vollständigen Läufen scheitert einmal der Check „Autonome Kontaktpflege wärmt den kältesten Kontakt“ (`Test.gd:1802`). `Staff._care_gesture` hat aber absichtlich eine Patzerchance von mindestens 2 %. Der Test erwartet einen garantierten Erfolg einer zufälligen Aktion. Nachweis: `../logs/logic-5.log`; die fünf anderen gültigen Läufe bestehen.
2. Im Patzerfall sinkt `liking`, der Wochen-Digest behauptet dennoch „kept … warm“. Kontrolliert mit belastetem Mitarbeiter und Seed 0: liking 21 → 20, aber positiver Digest. Nachweis: `../logs/staff-audit.log`.

## Umsetzung

`Staff.gd:300` soll ein konkretes Ergebnis liefern; `_work_care` ab Zeile 313 erstellt daraus eine wahrheitsgemäße Zusammenfassung. Den absichtlich möglichen Patzer nicht entfernen, nur um den bisherigen Test grün zu bekommen.

Den Test in Erfolg, Patzer und Zielauswahl aufteilen. Zufall kontrollieren und für die Auswahl sicherstellen, dass der erwartete Kontakt tatsächlich den kleinsten abgeleiteten Beziehungswert besitzt. Diagnosewerte und Seed bei Fehlschlag ausgeben.

## Abnahme

- Erfolg erhöht Sympathie und wird positiv gemeldet.
- Patzer senkt Sympathie und wird als Fehler gemeldet, ohne gleichzeitige Erfolgsmeldung.
- Zielauswahl und finanzieller Aufwand sind in beiden Pfaden korrekt.
- Wiederholte vollständige Tests ergeben bei identischen Voraussetzungen identische Ergebnisse.
- Gezielte Tests, gesamte Logiksuite, EXE-Export.
