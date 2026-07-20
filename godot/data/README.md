# Hollywood Manager — Datenbanken

Alle Spieldaten liegen hier als JSON und werden beim Start automatisch geladen.
**Neue Datenbanken einspielen = einfach eine weitere `.json`-Datei in den passenden
Ordner legen.** Kein Code nötig.

## Ordner

| Ordner | Inhalt | Format | Schlüssel |
|---|---|---|---|
| `actors/` | Schauspieler | Liste | `id` |
| `studios/` | Studios/Unternehmen | Liste | `id` |
| `genres/` | Genres | Objekt | Genre-Kürzel |
| `titles/` | Prozedurale Titelbausteine | Objekt | Genre-Kürzel |
| `real_titles/` | Reale Filmtitel für Castings | Liste | `t` + `y` |
| `names/` | NPC-Namenspools | Objekt | `first_m`/`first_f`/`last` |
| `history/` | Historische Makro-Ereignisse | Liste | `year` + `month` |
| `eras/` | Wählbare Start-Ären | Liste | `year` |
| `events/` | Spiel-Events & Eventketten | Liste | `id` |
| `backstories/` | Wählbare Spieler-Backstories | Liste | `id` |
| `ethnicities/` | Anzeige-Namen für Ethnien | Objekt | Ethnie-Kürzel |

## Merge-Regeln

- Alle `*.json` eines Ordners werden **alphabetisch** geladen und zusammengeführt.
- **Gleicher Schlüssel** (z. B. gleiche Actor-`id`) ⇒ die spätere Datei
  **überschreibt Feld für Feld** und kann Felder **ergänzen** — so funktionieren
  z. B. `actors/ethnicity_core.json` und `actors/filmography_core.json`: sie
  tragen nur `id` + das Zusatzfeld und reichern `actors/core.json` an.
- **Neuer Schlüssel** ⇒ der Eintrag wird angehängt (so fügt man neue
  Schauspieler, Studios, Events usw. hinzu).
- Listen-Dateien sind ein JSON-Array `[{...}, {...}]` (oder `{"entries":[...]}`).
- **Mods:** Dateien unter `user://data/<ordner>/` (im Godot-Benutzerverzeichnis,
  unter Windows `%APPDATA%\Godot\app_userdata\Hollywood Manager\data\`) werden
  NACH den mitgelieferten geladen und gewinnen bei Konflikten — funktioniert
  auch mit der exportierten .exe.
- Fehlerhafte Einträge werden mit einer Warnung in der Konsole übersprungen,
  das Spiel startet trotzdem.

## Schauspieler-Schema

```json
{
	"id": "bogart", "name": "Humphrey Bogart",
	"birth": 1899, "death": 1957,
	"g": "m", "ethnicity": "white",
	"debut": 1928, "talent": 90, "ego": 60,
	"genres": ["crime", "drama", "thriller"],
	"peak": 1944, "peakFame": 93,
	"films": [{"title": "Casablanca", "year": 1942}]
}
```

Pflichtfelder: `id`, `name`, `birth`, `g` (`"m"`/`"f"`), `debut`, `talent`,
`peak`, `peakFame`. Optional: `death` (Jahr oder `null`; wird dem Spieler NIE
angezeigt, wirkt aber in der Simulation), `ethnicity` (Standard `"white"`,
Kürzel siehe `ethnicities/core.json`), `films` (reale Filmografie, im
Talentpool als „Bekannt aus“ sichtbar), `ego`, `genres`.

Hinweis zu `ethnicity`: Best-Effort-Daten mit Standardwert — Korrekturen sind
ausdrücklich erwünscht und gehören in eine eigene JSON-Datei (wie
`ethnicity_core.json`), nicht in den Code.

## Events-Schema

Siehe `events/core.json` — deklaratives Format mit `conditions`, `weight`,
`choices` (je mit `requirements`, `effects`, `outcome`) und Eventketten über
den Effekt `{"op": "followup", "event": "<id>", "delay_weeks": N}`.
Kettenglieder tragen `"followup_only": true` und erscheinen nie im Zufallspool.

## Kern-Dateien regenerieren

`tools/ExportData.gd` schreibt die geladenen Daten neu formatiert zurück:

```
Godot_v4.7.1-stable_win64.exe --headless --path godot --script tools/ExportData.gd
```
