# Fuehrt den SonarQube-Scan fuer dieses Projekt aus.
# Voraussetzung: Server laeuft (tools\sonar-server.ps1), Token liegt in %USERPROFILE%\.sonar-token
$scanner = "C:\Users\Anwender\sonar-scanner\bin\sonar-scanner.bat"
$tokenFile = Join-Path $env:USERPROFILE ".sonar-token"

if (-not (Test-Path $scanner)) { Write-Error "sonar-scanner nicht gefunden: $scanner"; exit 1 }
if (-not (Test-Path $tokenFile)) { Write-Error "Token-Datei fehlt: $tokenFile (siehe tools\sonar-README.md)"; exit 1 }

# Server erreichbar?
try {
    $status = (Invoke-RestMethod -Uri "http://localhost:9000/api/system/status" -TimeoutSec 5).status
} catch {
    Write-Error "SonarQube-Server nicht erreichbar - erst tools\sonar-server.ps1 starten."
    exit 1
}
if ($status -ne "UP") { Write-Error "Server-Status: $status - kurz warten und erneut versuchen."; exit 1 }

$env:SONAR_TOKEN = (Get-Content $tokenFile -Raw).Trim()
Set-Location (Split-Path $PSScriptRoot -Parent)
& $scanner
Write-Host ""
Write-Host "Ergebnis: http://localhost:9000/dashboard?id=hollywood-manager"
