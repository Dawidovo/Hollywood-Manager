# QA-06 – Dialoge an die verfügbare Fensterhöhe anpassen

**Priorität:** P2 · **Status:** umgesetzt (06.09.2026) · **Abhängigkeit:** keine

> Umsetzung: Der Modal-Inhalt (`modal_box`) steckt jetzt in einem
> ScrollContainer; `_update_modal_width` deckelt die Höhe auf den Viewport
> (−112 px Ränder) und führt sie bei Inhalts- oder Fensteränderungen nach
> (`minimum_size_changed` + bestehender Resize-Handler). Mausrad scrollt
> nativ, `follow_focus` hält per Tastatur fokussierte Antworten sichtbar.
> Nachweis: `../../2026-09-05-qa01-retest/logs/ui-size-retest.log` — alle
> sechs Messungen innerhalb des Fensters (Backstory 1024×600: unten 564
> statt 897; Vertragsdialog 631 → 564), Sichtprüfung produktiv bei 1024×600.

## Reproduktion und Nachweis

Fenster auf 1024×600 stellen und die Backstory-Auswahl öffnen: Das Panel ist 897 Pixel hoch. Spätere Startgeschichten und „Back“ liegen außerhalb des Fensters. Ein Vertragsdialog für 2010 ist 631 Pixel hoch; die Aktionszeile wird unten abgeschnitten. Es gibt keinen ScrollContainer im Modal.

Bei 1280×720 ist die Backstory-Auswahl 727 Pixel hoch. Bei 1920×1080 passen beide getesteten Dialoge. Nachweise: `../logs/ui-size.log`, `../size-backstory-1024x600.png`, `../size-negotiation2010-1024x600.png`.

## Umsetzung

In `Main.gd:1116` das Modal auf die verfügbare Höhe begrenzen und den Inhalt vertikal scrollbar machen. Aktionszeile möglichst sichtbar halten. Fokus, Tastaturbedienung und Mausrad berücksichtigen. `_update_modal_width` berücksichtigt derzeit nur die Breite. Die UI bleibt vollständig in Code, wie im Projekt vereinbart.

Alternativ wäre eine ausdrücklich definierte Mindestfenstergröße möglich; bloßes Abschneiden ohne Hinweis ist kein akzeptabler Zustand.

## Abnahme

- Backstory, Signing mit Gegenvorschlag und sämtlichen epochenabhängigen Klauseln sowie langer Eventtext bei 1024×600, 1280×720, 1366×768 und 1920×1080 prüfen.
- Alle Antworten, „Cancel“/„Back“ und die letzte Startgeschichte sind erreichbar.
- Während eines offenen Dialogs verkleinern und wieder vergrößern; kein verlorener Fokus oder abgeschnittener Inhalt.
- Screenshotprüfung zusätzlich zu Logiktests; EXE exportieren.
