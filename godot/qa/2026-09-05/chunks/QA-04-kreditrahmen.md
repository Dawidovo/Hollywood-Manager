# QA-04 – Kreditregeln für Planung und Signing vereinheitlichen

**Priorität:** P1 · **Status:** umgesetzt (05.09.2026) · **Abhängigkeit:** keine

> Umsetzung: PR/Galas laufen nur noch mit Deckung (`Planner._affordable_slots`
> gegen `Game.can_spend`, inkl. Buchungsrundung) — bei teilweiser Deckung wirkt
> genau die bezahlbare Slot-Anzahl, der Rest entfällt ersatzlos mit
> Ticker-Meldung („no coverage, no effect“). Automatische PR-Planung ohne
> Deckung wird zur freien Erholung (Ersatzplanung). Der Signing-Bonus hängt an
> der zentralen Kreditregel (`can_spend`): Bonus 0 gelingt bei roter Kasse,
> positive Boni nutzen den Rahmen, darüber hinaus `{"broke": true}`.
> Laufende Kosten (book) bleiben ungebremst, Insolvenzregel unverändert.
> Nachweis: `../../2026-09-05-qa01-retest/logs/audit-retest-qa04.log` —
> AUDIT_CREDIT_PR/GALA ohne Kassenänderung, AUDIT_SIGN_CREDIT accepted.

## Befund und Reproduktion

1950 starten, Monroe verpflichten, Agenturkasse auf `-Game.credit_limit()` setzen. Im Planer alle Klientenslots mit PR füllen und auswerten. Die Kasse sinkt trotz ausgeschöpftem Rahmen von −70.142 auf −71.021. Bei Gala-Planung sinkt sie auf −71.607. Nachweis: `../logs/audit.log`, `AUDIT_CREDIT_PR` und `AUDIT_CREDIT_GALA`.

Umgekehrt verweigert `sign_client` bei Kasse −1 einen Vertrag mit Signing-Bonus 0 (`{"broke":true}`), obwohl `can_spend(0)` wahr ist. Nachweis: `AUDIT_SIGN_CREDIT`. Die Projektentscheidung erlaubt aktive Ausgaben innerhalb des Kreditrahmens.

## Umsetzung

`Planner.gd:176` bucht PR/Galas direkt und gewährt die Wirkungen ohne Deckungsprüfung. Vor bezahlten Aktivitäten Deckung prüfen, bei Nichtausführung keine Wirkung gewähren und dem Spieler die Ursache nennen. Auch die automatische PR-Planung berücksichtigen. Das Verhalten bei einer nur teilweise finanzierbaren Woche ausdrücklich definieren.

`Game.gd:1040` für den Signing-Bonus an die zentrale Kreditregel anschließen. Verpflichtende laufende Kosten dürfen weiterhin negative Salden erzeugen; diese nicht versehentlich pauschal blockieren. Private Entnahmen und autonome Mitarbeiterausgaben bleiben entsprechend Projektentscheidung kreditfrei.

## Abnahme

- Am Kreditlimit verursachen PR/Gala weder zusätzliche Schulden noch kostenlose Wirkungen.
- Letzter bezahlbarer Slot wird korrekt behandelt; danach transparenter Abbruch oder Ersatzplanung.
- Kostenloses Signing bei Kasse −1 gelingt; positiver Bonus nur innerhalb des erlaubten Rahmens.
- Insolvenz nach drei negativen Monaten funktioniert weiterhin.
- Bestehende Kredit-/Insolvenztests und neue Planer-Grenzfälle bestehen; EXE exportieren.
