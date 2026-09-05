# Nachtests und Artefakte

Die konkrete Testkopie liegt lokal unter `project/`. Sie ist ein Snapshot des im Bericht genannten Commits und wird nicht von Git erfasst. Die Zusatzskripte sind dauerhaft unter `harness/` abgelegt. Die ursprünglichen Produktivskripte wurden nicht verändert.

## Einen vorhandenen Nachtest ausführen

Aus dem Repository-Verzeichnis in PowerShell den folgenden Block verwenden. Die Ausführung erfolgt absichtlich mit `Start-Process` und `WaitForExit`, da die Windows-GUI-EXE sonst unter Umständen asynchron zurückkehrt.

```powershell
$qaRoot = Join-Path (Get-Location) 'godot/qa/2026-09-05'
$qaExe = Join-Path (Get-Location) 'Godot_v4.7.1-stable_win64.exe'
$qaScene = 'res://tests/Audit.tscn'
$qaLog = Join-Path $qaRoot 'logs/audit-retest.log'
$qaArgs = '--headless --path "' + "$qaRoot/project" + '" --log-file "' + $qaLog + '" ' + $qaScene
$qaProcess = Start-Process -FilePath $qaExe -ArgumentList $qaArgs -WindowStyle Hidden -PassThru
if (-not $qaProcess.WaitForExit(30000)) {
    $qaProcess.Kill()
    throw 'Testzeit überschritten'
}
Get-Content $qaLog
"Exit: $($qaProcess.ExitCode)"
```

| Szene | Zweck / erwarteter Abschluss |
|---|---|
| `res://tests/Test.tscn` | Vorhandene Suite, `FERTIG`; ursprünglichen Fehlerzähler und Log gemeinsam prüfen |
| `res://tests/Audit.tscn` | Kredit, Signing, Aktien, Saves, offene Events; `AUDIT_DONE` |
| `res://tests/Timing.tscn` | Follow-up-Fristen; `TIMING_DONE` |
| `res://tests/StaffAudit.tscn` | Positiver Digest trotz Patzer; `STAFF_MISHAP` |
| `res://tests/SaveIO.tscn` | Speichern ohne Erfolgssignal; siehe unten |
| `res://tests/UISmoke.tscn` | 24 Starts / 408 Tab-Render; `UI_SMOKE_DONE` |
| `res://tools/BalanceSim.tscn` | Originale 16 Kampagnen, 16 `SUM;`-Zeilen |
| `res://tools/BalanceEvents.tscn` | Dieselbe Heuristik mit ersten verfügbaren Ereignisantworten; 16 `SUM;`-Zeilen |

Diese Audit-Skripte protokollieren Ist-Werte und sind noch keine fertigen Regressionstests mit Soll-Assertions. Einige erzeugen **absichtlich** defekte Test-Saves und Skriptfehler. Exit 0 allein bedeutet dort keinen bestandenen Test. Immer Logs, Marker und die Abnahmekriterien des Chunks vergleichen. Die ursprüngliche Suite besitzt bereits eigene Assertions.

Alle schreibenden Tests **nacheinander** ausführen, da sie sich den isolierten Test-Save teilen. Für spätere Fix-Verifikation eine frische Kopie des dann aktuellen Produktivcodes verwenden; ein Nachtest nur gegen den alten Snapshot würde den Fix nicht prüfen.

## Grafik-Nachtest

Für `res://tests/UISize.tscn` im obigen Aufruf `--headless` durch `--windowed --audio-driver Dummy --rendering-method gl_compatibility` ersetzen. Das Skript prüft drei Fenstergrößen und schreibt sechs Bilder. Die ersten 40 Bilder entstanden über die vorhandenen `--shot-*`-Hooks mit `--windowed --resolution 1366x768` und **nach einem separaten `--`** dem jeweiligen Hook plus `--shot-resolution=1366x768`.

Nicht bloß prüfen, ob ein Bild existiert: Die Verhandlungstisch-Hooks fallen aktuell auf eine andere Ansicht zurück. Details in QA-09.

## Kontrollierter Schreibfehler

Nur `project/qa_userdata/hm_save.json` schreibschützen, niemals den normalen Spielstand. Den vorhandenen Attributwert sichern, `IsReadOnly = $true` setzen, `SaveIO.tscn` ausführen und **bis zum Prozessende warten**. Im `finally`-Block den vorherigen Attributwert wiederherstellen. Der Audit führte genau diesen Ablauf aus; der Dateihash blieb unverändert, die Methode erzeugte eine Nullreferenz und der Prozess endete trotzdem mit 0.

## Eine neue isolierte Kopie vorbereiten

1. Einen neuen Unterordner unter `godot/qa/` anlegen; der vorhandene `.gdignore` schützt das eigentliche Projekt vor Import dieser Dateien.
2. Aus dem dann aktuellen Projekt `scripts/`, `data/`, `tests/`, `tools/`, `assets/`, `Main.tscn` und `project.godot` kopieren. Keine rekursive Kopie von `godot/`, sonst würde sich `qa/` selbst mitkopieren.
3. Ausschließlich in kopierten `.gd`-Dateien die Literale `user://` durch `res://qa_userdata/` ersetzen und diesen Datenordner erzeugen. Den kopierten Projektnamen auf `Hollywood Manager QA` setzen. Keine Produktionsdateien umschreiben.
4. Harness-Dateien nach `tests/` kopieren; `BalanceEvents.*` gehört nach `tools/`. Diese abgeleitete Simulation basiert auf dem Audit-Stand; bei Änderungen an BalanceSim die kleine Erweiterung zur Ereignisbearbeitung erneut auf die aktuelle Fassung übertragen.
5. Die Kopie headless importieren, dann Tests sequenziell ausführen. Logs mit absoluten Pfaden schreiben.

Diese manuelle Isolation ist ein Behelf für den Audit. Ein offiziell unterstützter Test-Datenpfad und automatisches Fehler-Gating sind Teil von QA-09.
