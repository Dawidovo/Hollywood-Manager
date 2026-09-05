# QA-08 – Wiederholte oder wirkungslose Aktionen abfangen

**Priorität:** P3 · **Status:** offen · **Abhängigkeit:** keine

Diese Fehler wurden an öffentlichen Spiellogik-Methoden reproduziert. Ein normaler UI-Weg zu den exakten Aufrufen wurde nicht nachgewiesen; entsprechend keine Behauptung eines frei nutzbaren Spieler-Exploits.

## Befunde

- Nach einer Verhandlung `sign_client` zweimal aufrufen: Zwei Klienten mit derselben Actor-ID entstehen. `nego.done` wird gesetzt, beim erneuten Signing aber nicht geprüft. Nachweis `AUDIT_DUPLICATE_SIGN` in `../logs/audit.log`.
- Aktien halten und `Mogul.sell_stock(id, 0)` zehnmal aufrufen: Weder Kasse noch Stückzahl ändern sich, Finance-XP steigt dennoch von 1 auf 11. Nachweis `AUDIT_ZERO_SALE`. Die aktuelle UI verwendet „Sell all“ ohne diesen Nullparameter; der Fehler betrifft die Absicherung der Methode.

## Umsetzung

In `Game.gd:1037` abgeschlossene Verhandlungen und bereits vertretene Schauspieler ablehnen, bevor irgendwelche Kosten, Ruf- oder XP-Effekte entstehen. Laufzeitkontexte beim Spielneustart prüfen.

In `Mogul.gd:511` die Stückzahl 0 als wirkungslose/ungültige Aktion ablehnen. Das bestehende `-1` als „alles verkaufen“ ausdrücklich erhalten. Keine XP, Trades oder Buchungen für wirkungslose Aktionen erzeugen.

## Abnahme

- Zweites Signing erzeugt weder zweiten Klienten noch zusätzliche Nebenwirkungen.
- Nullverkauf verändert weder Holdings, Kasse, XP noch Trade-Historie.
- Normaler Kauf, Teilverkauf und Gesamtverkauf funktionieren unverändert.
- Bestehende Logiktests und neue Aktionsgrenzen bestehen; EXE exportieren.
