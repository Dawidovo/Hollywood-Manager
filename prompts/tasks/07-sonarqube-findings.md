# Chunk 07 — SonarQube-Findings abarbeiten

## Ziel
Die vom lokalen SonarQube gemeldeten Issues in `js/`, `tools/` und `index.html` auf null (bzw. begründet akzeptiert) bringen.

## Kontext
- Server starten: `tools\sonar-server.ps1` → http://localhost:9000 (Zugangsdaten in `tools/sonar-README.md`)
- Scan: `tools\sonar-analyze.ps1`
- GDScript wird nicht analysiert (dafür Chunk 06 / gdlint).

## Schritte
1. Scan laufen lassen, Issues nach Severity sortieren (Blocker/Critical zuerst).
2. Pro Datei eine kleine Fix-Runde: echte Bugs sofort fixen; Code Smells (Duplikate, tote Variablen, hohe Komplexität) beheben, wenn der Fix lokal bleibt.
3. False Positives oder bewusste Entscheidungen im SonarQube-UI als „Accepted" markieren (mit Kommentar), nicht im Code verrenken.
4. Danach Quality Gate im Dashboard prüfen: neuer Code muss grün sein.

## Akzeptanzkriterien
- [ ] Keine offenen Blocker/Critical-Issues
- [ ] Web-Prototyp im Browser gegengetestet (Spiel starten, 1 Runde spielen)
- [ ] Ein Commit: `fix: SonarQube-Findings in js/ und tools/ behoben`
