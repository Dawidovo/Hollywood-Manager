# SonarQube — lokale Code-Analyse

Analysiert `tools/` (Python) direkt. **Die GDScript-Prüfung erscheint ebenfalls im Dashboard:** `tools/gdlint-report.py` führt gdlint aus und schreibt `gdlint-report.json` (Generic Issue Format), das der Scan über `sonar.externalIssuesReportPaths` importiert — `sonar-analyze.ps1` macht beides in einem Schritt. Die Webversion (`js/`, `index.html`) ist eingefroren und ausgeschlossen.

## Installation (bereits erledigt)

- Server: SonarQube Community Build 26.7 → `C:\Users\Anwender\sonarqube`
- Scanner: SonarScanner CLI 8.1 (eigene JRE) → `C:\Users\Anwender\sonar-scanner`
- Server braucht ein **volles JDK 21+** (Elasticsearch benötigt das Modul `jdk.jdi`) — genutzt wird das installierte Temurin JDK 25 via `SONAR_JAVA_PATH` (gesetzt in `sonar-server.ps1`)

## Benutzung

1. Server starten (eigenes Fenster, offen lassen):
   ```
   powershell -File tools\sonar-server.ps1
   ```
2. Warten bis http://localhost:9000 „UP" ist (erster Start: 1–3 Min).
3. Scan ausführen:
   ```
   powershell -File tools\sonar-analyze.ps1
   ```
4. Ergebnisse: http://localhost:9000/dashboard?id=hollywood-manager

## Zugangsdaten

- Web-Login: `admin` / Passwort steht in `%USERPROFILE%\.sonar-admin-pass`
- Scanner-Token: `%USERPROFILE%\.sonar-token` (wird von `sonar-analyze.ps1` gelesen)

Beide Dateien liegen bewusst **außerhalb** des Repos.

## Konfiguration

`sonar-project.properties` im Projektroot: Quellen, Ausschlüsse (`js/actors_full.js` ist generiert), Projekt-Key `hollywood-manager`. `sonar.qualitygate.wait=true` lässt den Scan bei rotem Quality Gate mit Fehler enden.

## Automatik: Scan bei jedem Commit

Ein versionierter Pre-Commit-Hook (`tools/git-hooks/pre-commit`, aktiviert via `git config core.hooksPath tools/git-hooks` — bereits gesetzt) führt vor **jedem Commit** den Scan aus:

- Server läuft & Quality Gate grün → Commit geht durch
- Quality Gate **rot** → Commit wird abgebrochen (Findings im Dashboard beheben; bewusster Notausstieg: `git commit --no-verify`)
- Server **nicht erreichbar** → Warnung, Commit geht durch (Offline-Arbeit wird nicht blockiert — Server per `tools\sonar-server.ps1` starten)

Nach einem frischen Clone einmalig `git config core.hooksPath tools/git-hooks` ausführen.
