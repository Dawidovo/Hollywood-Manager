# QA-09: Test-Runner mit Timeout, Seed, Logpfad und Fehlererkennung.
# Ein Lauf gilt nur als gruen, wenn:
#   - der Prozess vor dem Timeout endet,
#   - der Abschlussmarker im Log steht (FERTIG / SIM_DONE / eigener Marker),
#   - kein SCRIPT ERROR im Log auftaucht,
#   - bei der Testsuite "FERTIG: 0 Fehler" gemeldet wird,
#   - der echte Spielstand (hm_save.json im normalen user://) unveraendert ist.
# Aufruf-Beispiele:
#   powershell -File tools\run-tests.ps1
#   powershell -File tools\run-tests.ps1 -Scene res://tools/BalanceSim.tscn -TimeoutSec 900
#   powershell -File tools\run-tests.ps1 -Seed 1234 -LogPath C:\tmp\lauf.log
param(
    [string]$Scene = 'res://tests/Test.tscn',
    [int]$TimeoutSec = 420,
    [int]$Seed = 9052026,
    [string]$LogPath = '',
    [string]$Marker = ''
)

$repo = Split-Path $PSScriptRoot -Parent
$exe = Join-Path $repo 'Godot_v4.7.1-stable_win64.exe'
if (-not (Test-Path $exe)) { Write-Host "FAIL: Godot-Exe nicht gefunden: $exe"; exit 2 }
if (-not $LogPath) { $LogPath = Join-Path $env:TEMP ('hm-testrun-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log') }
if (-not $Marker) {
    $Marker = 'DONE'
    if ($Scene -like '*Test.tscn') { $Marker = 'FERTIG' }
    if ($Scene -like '*BalanceSim*') { $Marker = 'SIM_DONE' }
}

# Echten Spielstand vor/nach dem Lauf vergleichen (Tests speichern isoliert
# unter user://qa_test*; jede Abweichung hier ist ein Fehler).
$realSave = Join-Path $env:APPDATA 'Godot\app_userdata\Hollywood Manager\hm_save.json'
$hashBefore = ''
if (Test-Path $realSave) { $hashBefore = (Get-FileHash $realSave).Hash }

$godotArgs = '--headless --path godot --log-file "' + $LogPath + '" ' + $Scene + ' -- --seed=' + $Seed
Write-Host "Runner: $Scene (Seed $Seed, Timeout ${TimeoutSec}s, Marker '$Marker')"
Write-Host "Log:    $LogPath"
$proc = Start-Process -FilePath $exe -ArgumentList $godotArgs -WorkingDirectory $repo -WindowStyle Hidden -PassThru
if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
    $proc.Kill()
    Write-Host "FAIL: Timeout nach ${TimeoutSec}s - Lauf unvollstaendig."
    if (Test-Path $LogPath) {
        $hung = @(Select-String -Path $LogPath -Pattern 'SCRIPT ERROR')
        if ($hung.Count -gt 0) {
            Write-Host "Ursache im Log: $($hung.Count) SCRIPT ERROR, z. B.:"
            $hung | Select-Object -First 3 | ForEach-Object { Write-Host ('  ' + $_.Line) }
        }
    }
    exit 2
}

if (-not (Test-Path $LogPath)) { Write-Host 'FAIL: Kein Log geschrieben.'; exit 2 }
$logText = Get-Content $LogPath -Raw

$failCount = 0
$scriptErrors = @(Select-String -Path $LogPath -Pattern 'SCRIPT ERROR')
if ($scriptErrors.Count -gt 0) {
    Write-Host "FAIL: $($scriptErrors.Count) SCRIPT ERROR im Log:"
    $scriptErrors | Select-Object -First 5 | ForEach-Object { Write-Host ('  ' + $_.Line) }
    $failCount++
}
if ($logText -notmatch [regex]::Escape($Marker)) {
    Write-Host "FAIL: Abschlussmarker '$Marker' fehlt - Lauf unvollstaendig oder abgebrochen."
    $failCount++
}
if ($logText -match 'FERTIG: (\d+) Fehler') {
    $n = [int]$Matches[1]
    if ($n -gt 0) { Write-Host "FAIL: Testsuite meldet $n Fehler."; $failCount++ }
    else { Write-Host 'Testsuite: 0 Fehler.' }
}
$failLines = @(Select-String -Path $LogPath -Pattern '^\s*FAIL ')
if ($failLines.Count -gt 0) {
    $failLines | Select-Object -First 10 | ForEach-Object { Write-Host ('  ' + $_.Line) }
}

if (Test-Path $realSave) {
    $hashAfter = (Get-FileHash $realSave).Hash
    if ($hashBefore -ne $hashAfter) {
        Write-Host 'FAIL: Der echte Spielstand wurde durch den Testlauf veraendert!'
        $failCount++
    } else {
        Write-Host 'Echter Spielstand: unveraendert.'
    }
} elseif ($hashBefore -ne '') {
    Write-Host 'FAIL: Der echte Spielstand wurde durch den Testlauf geloescht!'
    $failCount++
}

if ($failCount -gt 0) { Write-Host "ERGEBNIS: ROT ($failCount Problem(e))."; exit 1 }
Write-Host "ERGEBNIS: GRUEN (Seed $Seed, Marker '$Marker' gefunden)."
exit 0
