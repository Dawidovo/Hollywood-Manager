# Startet den lokalen SonarQube-Server (http://localhost:9000)
# Erster Start dauert 1-3 Minuten. Fenster offen lassen, solange analysiert wird.
$sq = "C:\Users\Anwender\sonarqube\bin\windows-x86-64\StartSonar.bat"
if (-not (Test-Path $sq)) {
    Write-Error "SonarQube nicht gefunden unter $sq"
    exit 1
}
# SonarQube 26.x braucht Java 21+ (volles JDK, Elasticsearch braucht jdk.jdi)
$env:SONAR_JAVA_PATH = "C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot\bin\java.exe"
Write-Host "Starte SonarQube... Dashboard: http://localhost:9000"
& $sq
