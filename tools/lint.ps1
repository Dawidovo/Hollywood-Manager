# Fuehrt gdlint (gdtoolkit) ueber den GDScript-Code aus.
# Konfiguration: godot\.gdlintrc — Aufruf: powershell -File tools\lint.ps1
# Optional: -Files "pfad1.gd","pfad2.gd" um nur bestimmte Dateien zu pruefen.
param([string[]]$Files)

$repo = Split-Path $PSScriptRoot -Parent
Set-Location (Join-Path $repo "godot")

if (-not $Files -or $Files.Count -eq 0) {
    $Files = @(Get-ChildItem "scripts\*.gd" | ForEach-Object { $_.FullName })
    $Files += (Join-Path $repo "godot\tests\Test.gd")
    $Files += (Join-Path $repo "godot\tools\ExportData.gd")
}

py -m gdtoolkit.linter @Files
$rc = $LASTEXITCODE
if ($rc -eq 0) {
    Write-Host "gdlint: keine Findings."
} else {
    Write-Host "gdlint: Findings gefunden - bitte beheben (Konfiguration: godot\.gdlintrc)."
}
exit $rc
