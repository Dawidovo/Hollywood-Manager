# Fuehrt gdlint (gdtoolkit) ueber den GDScript-Code aus.
# Konfiguration: godot\.gdlintrc — Aufruf: powershell -File tools\lint.ps1
# Optional: -Files "pfad1.gd","pfad2.gd" um nur bestimmte Dateien zu pruefen.
# Abhaengigkeit (QA-09, reproduzierbar): Python-Launcher "py" mit
# installiertem gdtoolkit 4.x —  py -m pip install "gdtoolkit==4.*"
# Ohne diese Einrichtung schlaegt der Lauf mit klarer Meldung fehl.
param([string[]]$Files)

$repo = Split-Path $PSScriptRoot -Parent
Set-Location (Join-Path $repo "godot")

py -c "import gdtoolkit" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'gdlint: py/gdtoolkit nicht verfuegbar. Einrichtung: py -m pip install "gdtoolkit==4.*"'
    exit 3
}

if (-not $Files -or $Files.Count -eq 0) {
    # QA-09: rekursiv ueber alle Produktivskripte (inkl. scripts\ui\),
    # die Testsuite und die Werkzeug-Skripte (BalanceSim, ExportData).
    $Files = @(Get-ChildItem "scripts" -Recurse -Filter *.gd | ForEach-Object { $_.FullName })
    $Files += @(Get-ChildItem "tests" -Filter *.gd | ForEach-Object { $_.FullName })
    $Files += @(Get-ChildItem "tools" -Filter *.gd | ForEach-Object { $_.FullName })
}

py -m gdtoolkit.linter @Files
$rc = $LASTEXITCODE
if ($rc -eq 0) {
    Write-Host ("gdlint: keine Findings ({0} Dateien geprueft)." -f $Files.Count)
} else {
    Write-Host "gdlint: Findings gefunden - bitte beheben (Konfiguration: godot\.gdlintrc)."
}
exit $rc
