#!/usr/bin/env python3
"""Fuehrt gdlint aus und schreibt die Befunde als SonarQube-Report.

Ausgabe: gdlint-report.json (Generic Issue Format) im Projektroot.
Wird von tools/sonar-analyze.ps1 vor dem Scan aufgerufen, damit die
GDScript-Pruefung im SonarQube-Dashboard erscheint
(sonar.externalIssuesReportPaths in sonar-project.properties).
"""
import glob
import json
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Formatierungsnahe Regeln sind LOW, alles andere MEDIUM.
LOW_RULES = {"max-line-length", "trailing-whitespace", "mixed-tabs-and-spaces"}


def parse_finding(raw: str):
    """Zerlegt eine gdlint-Zeile: '<pfad>:<zeile>: Error: <text> (<regel>)'."""
    head, sep, rest = raw.strip().partition(": Error: ")
    if not sep or not rest.endswith(")") or " (" not in rest:
        return None
    path, _, line = head.rpartition(":")
    if not path or not line.isdigit():
        return None
    msg, _, rule = rest[:-1].rpartition(" (")
    return path, int(line), msg, rule


def gd_files() -> list[str]:
    files = sorted(glob.glob(str(ROOT / "godot" / "scripts" / "*.gd")))
    files += sorted(glob.glob(str(ROOT / "godot" / "tests" / "*.gd")))
    files += sorted(glob.glob(str(ROOT / "godot" / "tools" / "*.gd")))
    return files


def main() -> int:
    files = gd_files()
    proc = subprocess.run(
        [sys.executable, "-m", "gdtoolkit.linter", *files],
        capture_output=True, text=True, cwd=ROOT / "godot", encoding="utf-8", errors="replace",
    )
    output = (proc.stdout or "") + "\n" + (proc.stderr or "")

    issues, rules_seen = [], {}
    for raw in output.splitlines():
        parsed = parse_finding(raw)
        if parsed is None:
            continue
        path, line_no, msg, rule = parsed
        rel = os.path.relpath(path, ROOT).replace("\\", "/")
        rules_seen[rule] = {
            "id": rule,
            "name": "gdlint: %s" % rule,
            "description": "gdtoolkit-Linter-Regel '%s' (Konfiguration: godot/.gdlintrc)" % rule,
            "engineId": "gdlint",
            "cleanCodeAttribute": "CONVENTIONAL",
            "impacts": [{
                "softwareQuality": "MAINTAINABILITY",
                "severity": "LOW" if rule in LOW_RULES else "MEDIUM",
            }],
        }
        issues.append({
            "ruleId": rule,
            "primaryLocation": {
                "message": msg,
                "filePath": rel,
                "textRange": {"startLine": line_no},
            },
        })

    report = {"rules": list(rules_seen.values()), "issues": issues}
    out_path = ROOT / "gdlint-report.json"
    out_path.write_text(json.dumps(report, indent=1, ensure_ascii=False), encoding="utf-8")
    print("gdlint-report: %d Befund(e) in %d Datei(en) -> %s" % (
        len(issues), len(files), out_path.name))
    return 0  # Befunde blocken hier nicht — das Gate entscheidet im Dashboard/Hook


if __name__ == "__main__":
    sys.exit(main())
