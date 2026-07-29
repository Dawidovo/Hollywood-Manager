# Aufgaben-Chunks (Prompts)

> ⚠️ **Die Webversion (`index.html`, `js/`) ist EINGEFROREN.** Alle Chunks und alle KI-Sessions arbeiten ausschließlich am Godot-Projekt (`godot/`). Die Webversion wird weder analysiert noch verändert.

Kleine, in sich abgeschlossene Arbeitspakete — jeweils ein Chunk pro Session/Prompt an die KI (oder als eigene Arbeitseinheit). Ziel: Features liefern **und** Technical Debt klein halten.

## Arbeitsweise

1. **Einen** Chunk pro Session bearbeiten, nicht mehrere mischen.
2. Vor Beginn: `git status` sauber? Danach: pro Chunk **ein Commit**.
3. Nach jeder Code-Änderung im Godot-Projekt:
   - Logiktest: `Godot_console.exe --headless --path godot res://tests/Test.tscn`
   - .exe neu exportieren (siehe README.md im Projektroot)
4. Qualitäts-Checks laufen automatisch im Pre-Commit-Hook (`tools/git-hooks/pre-commit`): **gdlint** über die geänderten `.gd`-Dateien (Konfiguration: `godot/.gdlintrc`, manuell: `tools\lint.ps1`) und **SonarQube** mit Quality Gate (`tools\sonar-analyze.ps1`; Server: `tools\sonar-server.ps1`). Findings beheben, bevor committet wird — der Hook blockt sonst.
5. Chunk erledigt → in dieser Tabelle abhaken.

## Status

| # | Chunk | Thema | Status |
|---|-------|-------|--------|
| 01 | [Balance-Konstanten](01-balance-konstanten.md) | Tech Debt | erledigt (Autoload `Balance.gd`: Wirtschaft/Gagen/Produktion/Versprechen/DNA; Events.gd bewusst ausgelassen — Alt-Inhalte, werden durch JSON-Events ersetzt) |
| 02 | [Game.gd: Utils extrahieren](02-game-gd-utils-extrahieren.md) | Tech Debt | erledigt (Autoload `Util.gd`: RNG/hashs/body_of/infl/fame_at/age_of/ask_fee/grade/fmt_money/attrs, ~450 Aufrufstellen umgestellt, BalanceSim bit-identisch; −82 statt −150 Zeilen — `required_rep`/`grade_range` lesen inzwischen State und bleiben laut Spec-Regel in Game.gd) |
| 03 | [Game.gd: DNA-System extrahieren](03-game-gd-dna-extrahieren.md) | Tech Debt | erledigt (Autoload `CareerDNA.gd` inkl. Achsen/Genre-Vektoren/Verfall; Prägungs-Tests neu; `studio_style` blieb in Game.gd — kein DNA-Code, nur interne Aufrufer) |
| 04 | [Save-Versionierung & Migration](04-save-migration.md) | Robustheit | erledigt (Versionskette `_migrate_save`, Backup `hm_save.bak.json`, Fehlerdialog, v1-Fixture-Test) |
| 05 | [Testsuite ausbauen](05-tests-ausbauen.md) | Qualität | erledigt (500+ Checks; Kern-Regressionen fame_at/Fit/Package/Box-Office-Determinismus/Wortbruch/Insolvenz; Exit-Code ≠ 0 verifiziert) |
| 06 | [gdlint/gdformat einführen](06-gdlint-einfuehren.md) | Tooling | erledigt (gdlint aktiv; gdformat bewusst ausgelassen — Riesen-Diff) |
| 07 | [SonarQube-Findings abarbeiten](07-sonarqube-findings.md) | Qualität | erledigt (laufende Regel) |
| 08 | [Web-Prototyp einfrieren](08-web-prototyp-einfrieren.md) | Tech Debt | entschieden |
| 09 | [Main.gd: UI in Screens aufteilen](09-main-gd-screens-aufteilen.md) | Tech Debt | erledigt (alle 16 Tabs in `scripts/ui/`-Module; Main.gd haelt Layout, Bausteine, Modals & Verhandlungs-Dialoge — 4023 → 2644 Zeilen) |
| 10 | [Fehlerbehandlung Daten/Save](10-fehlerbehandlung-daten.md) | Robustheit | erledigt (Save-IO & Negativtests via Chunk 04, DataLoader skippt kaputte Einträge mit Warnung+Test; import_imdb.py: Download-Fehler, Zeilen-Skip mit Zählern, Exit 2/3, UTF-8-Konsolenfix, `.json`-Output fürs Godot-Datenformat) |
| 11 | [Körperdaten I: Größe & Gewicht](11-koerperdaten-basis.md) | Feature | erledigt (Commit `8cca6d8`) |
| 12 | [Körperdaten II: Gewichtsdynamik](12-koerperdaten-dynamik.md) | Feature | erledigt (Commit `b7b3bae`) |
| 13 | [Verhandlungen homogenisieren](13-verhandlungen-homogenisieren.md) | UI-Qualität | erledigt (Commit `db75888` — `_nego_header`/`_nego_actions` aktiv) |
| 14 | [Layout-Audit Buchstaben-Umbruch](14-layout-audit-buchstabenumbruch.md) | Bugfix | erledigt (inkl. Nachaudit der neuen Tabs; Header bricht jetzt um statt zu überlaufen) |
| 15 | [RPG I: Attribute der Spielfigur](15-rpg-attribute.md) | RPG | erledigt (5 Attribute aus `data/attributes/`, Backstory-Seeds, Wachstums-Hooks, Weiterbildung im Planner, Karte im Agentur-Tab, Migration + Tests) |
| 16 | [RPG II: Proben in Events](16-rpg-proben-events.md) | RPG | erledigt (`check`-Schema mit sichtbarem Icon+Prozent-Label, `min_attr`-Bedingung, 6 Proben in JSON inkl. Schaufenster-Event `brown_derby_abend`, Doku + Tests) |
| 17 | [RPG III: Quest-Journal](17-rpg-questjournal.md) | RPG | erledigt (Tab „📜 Journal", `quest`-Metadaten in Steuer- + allen 5 Backstory-Ketten, Sidebar-Zeile, Ticker bei Abschluss, `--shot-quests`-Hook, Doku + Tests) |
| 18 | [RPG IV: Kontaktbuch & NPCs](18-rpg-npc-beziehungen.md) | RPG | überholt — umfangreicher umgesetzt über `Network.gd` (Kontaktbuch, Beziehungsdimensionen, Gefallen an Personen); Rest-Ideen bei Bedarf als neuer Chunk |
| 19 | [Balance: 1925-Ökonomie](19-balance-1925-oekonomie.md) | Balance | erledigt (ask_fee-Exponent 2,35, Frühzeit-Büro ×0,6, Startkapital-Era-Faktor; Sim 1925: Woche 104 bei +44K statt Pleite in Woche 80) |
| 20 | [Balance: Energie-Erosion](20-balance-energie.md) | Balance | erledigt (Rest-Bonus bei Stress < 40, Urlaub +22; Sim: Woche 104 bei 81–98 statt 0–35 Energie, Burnout-Spirale intakt) |
| 21 | Gesamtpaket A: Emotionen & Schlüsselgespräche (`../prompt_gesamtpaket_claude.md`) | Feature | erledigt (Autoload `Emotions.gd` + `data/emotions/`, wahre vs. wahrgenommene Emotion in 4 Menschenkenntnis-Stufen; Dialog-Chip, `requires_emotion`, Attribut-Proben mit Event-Formel, `reads`-Zeilen; 4 Schlüsselbegegnungen `data/dialogs/begegnungen.json` mit Trigger-Verdrahtung; Commits `45b79c9`–`e9dd5ab`) |
| 22 | Gesamtpaket B: Presse — Interviews, Pressekonferenz, Ära-Formate | Feature | erledigt (3 Interview-Anfragen + Bäume mit Emotions-Gates auf den Journalisten; Autoload `Press.gd` (nur Trigger/Cooldowns) + Podium-Szene mit Spin-Doctor-Rückweg; era-gebundene Formate Radio/TV-Talk/Boulevard/Social inkl. viraler Clip-Kette; Commits `7e163e1`–`ea48467`) |
| 23 | Gesamtpaket C: Klienten-Innenleben & TV-/Streaming-Umbruch | Feature | erledigt (Autoload `Needs.gd` + `data/needs/`: deterministisches Profil, gespeicherte Sättigung, Engpass → Laune/Loyalität; Erwartungsgespräch mit `client_promise`-Zusagen (neu: auszeit/gage) und Quest-Begleitung; `Util.tv_appeal`, TV-Kette 1948–62, Streaming/Binge/likenessRights ab 2015; BalanceSim stabil; Commits `b057df8`–`39b6a26`) |
| 24 | Bugfix-Sweep & Design-Review (Juli 2026) | Qualität/Balance | erledigt (Gating-Bugs: bindende Studio-Absage auf allen Wegen `959a6df`/`0f58aaf`, tvIncome-Verfall, Star-Prognose-Frühauflösung; Kreditrahmen betrags- & zeitgedeckelt `f6ca845`; Review-Punkte 1–5+7: Tisch nur noch für Großdeals + Absage-Feedback `db1a6a9`, Hit-Wette still im Filme-Tab `efb82eb`, Signing-Sperrfrist 9 Mo `b0e8cd8`, Gefallen-Fristen 12–18 Mo + aktive Verwendungen `bfe6898`, Branchenkolumne als frühe Privateinnahme `f77c9b8`; offen als Content-Chunks: Frühzeit-Briefe 1925–45, Rivalen-Hebel) |

Reihenfolge-Empfehlung: 06 → 01 → 02 → 05 → 04 → 03 → 07 → 10 → 09 → 08. (Erst Tooling & Sicherheitsnetz, dann Refactorings.)
Für die neuen Chunks 11–14: nur noch **14** offen (sichtbarer Bug).
RPG-Ausbau (Konzept: [../rpg_konzept.md](../rpg_konzept.md)): strikt 15 → 16 → 17 — jeder Chunk setzt den vorigen voraus; 18 ist durch das Netzwerk-System überholt.

> ℹ️ **Architektur-Stand seit Juli 2026** (neuer als die Chunks 01–10): Spieldaten liegen als JSON unter `godot/data/` (Loader: `DataLoader.gd`, Doku: `godot/data/README.md`), Events laufen datengetrieben über `EventEngine.gd` (`data/events/*.json`), der Spielzug ist **wöchentlich** (`Game.end_week()`, 21-Slot-Planer), Spielstart mit wählbarer Backstory. Screenshot-Hooks: `Godot_v4.7.1-stable_win64.exe --path godot --resolution 2000x1100 -- --shot-<name>` — das `--` vor den Shot-Args ist Pflicht.
