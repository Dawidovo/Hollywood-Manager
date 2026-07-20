# SonarQube — lokale Code-Analyse

Analysiert `js/`, `tools/` und `index.html`. **GDScript wird von SonarQube nicht unterstützt** — dafür gdlint einführen (siehe `prompts/tasks/06-gdlint-einfuehren.md`).

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

`sonar-project.properties` im Projektroot: Quellen, Ausschlüsse (`js/actors_full.js` ist generiert), Projekt-Key `hollywood-manager`.
