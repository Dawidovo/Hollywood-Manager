# QA-02 – Offene Entscheidungen nach Laden wiederherstellen

**Priorität:** P1 · **Status:** umgesetzt (05.09.2026) · **Abhängigkeit:** QA-01 empfohlen

> Umsetzung: Rekonstruierbare Entscheidungen (JSON-Events + geskriptete
> Follow-ups) tragen einen serialisierbaren Bauplan und wandern in
> `state.pending`; ausgetragen wird erst beim Beantworten. Laufende Dialoge
> spiegeln sich in `state.dialogRun` (id/node/ctx) und werden nach Laden
> wieder aufgenommen, ohne Knoten-Effekte erneut anzuwenden. Nicht abgedeckt:
> einmalige Info-/Ergebnismeldungen ohne Bauplan (Release-Zusammenfassungen,
> Staff-Meldungen) — bewusst, da nicht rekonstruierbar und ohne Folgewirkung.
> Nachweis: `../../2026-09-05-qa01-retest/logs/qa02-check.log`.

## Befund und Reproduktion

Ein fälliges JSON-Follow-up `tonfilm_training` mit `due = Game.mi()` anlegen. `Game.end_week()` liefert „The test reel“, entfernt den Follow-up-Eintrag und speichert. Vor Auswahl einer Antwort neu laden: Der Follow-up-Eintrag bleibt verschwunden; der Save enthält keine ausstehende Entscheidung. Nachweis: `../logs/audit.log`, `AUDIT_EVENT_SAVE` und `AUDIT_EVENT_TITLE`.

Im Spiel entspricht das: Woche beenden, ein Entscheidungsfenster erscheint, Anwendung vor Beantwortung schließen, fortsetzen. Die UI hält die Warteschlange ausschließlich in `Main.modal_queue`; ein gerade angezeigtes Event wurde bereits daraus entfernt. Auch `Dialogs.run` ist ausdrücklich nur Laufzeitstatus. Ereignisse oder spätere Teile einer Kette können dadurch verschwinden.

## Soll und Umsetzung

Ausstehende Entscheidungen als serialisierbare Beschreibungen mit Event-/Dialog-ID, Kontext und Bearbeitungsstand in den Spielzustand aufnehmen. Keine Callables in JSON speichern. Entscheidung erst nach erfolgreicher Auflösung als erledigt markieren. Wiederherstellung darf bereits angewandte Effekte nicht erneut anwenden.

Einstiegspunkte: `Game.gd:1641` (Follow-ups), `:1670` (Autosave), `Main.gd:1222` (Wochenabschluss), `:2430` (Warteschlange), `Dialogs.gd:31` (Laufzeitdialog). Die Zeitberechnung selbst gehört zu QA-03.

## Abnahme

- Anwendung bei einem aktiven Event schließen: identische Entscheidung erscheint nach Laden wieder.
- Zwei offene Ereignisse: nach Antwort auf das erste und Neustart bleibt das zweite erhalten.
- Neustart innerhalb eines mehrstufigen Dialogs erhält Knoten und Kontext.
- Geld, Ruf und Zusagen werden nach Wiederaufnahme exakt einmal verändert.
- Alte Saves ohne Entscheidungszustand werden weiterhin geladen.
- Logiktests und Neustart-Integrationstest ausführen, danach EXE exportieren.
