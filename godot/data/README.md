# Hollywood Manager — Data

All game content lives here as JSON and is loaded automatically at startup.
**Adding new data = just drop another `.json` file into the matching folder.**
No code needed.

## Folders

| Folder | Content | Format | Key |
|---|---|---|---|
| `actors/` | Actors | List | `id` |
| `studios/` | Studios/companies | List | `id` |
| `genres/` | Genres | Object | genre code |
| `titles/` | Procedural title building blocks | Object | genre code |
| `real_titles/` | Real film titles for castings | List | `t` + `y` |
| `names/` | NPC name pools | Object | `first_m`/`first_f`/`last` |
| `history/` | Historical macro events | List | `year` + `month` |
| `eras/` | Selectable start eras | List | `year` |
| `events/` | Game events & event chains | List | `id` |
| `backstories/` | Selectable player backstories | List | `id` |
| `ethnicities/` | Display names for ethnicities | Object | ethnicity code |
| `career/` | Career ladder (Junior → Mogul) | List | `id` |
| `reputation/` | Earned reputation titles | Object | identity key |
| `locations/` | Node map (places, travel, actions) | List | `id` |
| `contacts/` | Contact roles, persons, channels, circles, notables | Object | — |
| `estate/` | Homes & status purchases | Object | — |
| `skills/` | Experience fields & unlockable abilities | Object | — |
| `stocks/` | Tradable companies (era-gated) | List | `id` |
| `backroom/` | Backroom deal templates | List | `id` |
| `dialogs/` | Conversation trees for key interactions | List | `id` |
| `letters/` | The weekly mail (letters/e-mail) | List | `id` |

## Merge rules

- All `*.json` in a folder are loaded **alphabetically** and merged.
- **Same key** (e.g. same actor `id`) ⇒ the later file **overrides field by
  field** and can **add** fields — that is how e.g. `actors/body_core.json`
  enriches `actors/core.json` by carrying only `id` + the extra field.
- **New key** ⇒ the entry is appended (this is how you add new actors, studios,
  events, and so on).
- List files are a JSON array `[{...}, {...}]` (or `{"entries":[...]}`).
- **Mods:** files under `user://data/<folder>/` (in the Godot user directory,
  on Windows `%APPDATA%\Godot\app_userdata\Hollywood Manager\data\`) are loaded
  AFTER the bundled ones and win on conflicts — this also works with the
  exported `.exe`.
- Malformed entries are skipped with a console warning; the game still starts.

## Actor schema

```json
{
	"id": "bogart", "name": "Humphrey Bogart",
	"birth": 1899, "death": 1957,
	"g": "m", "ethnicity": "white",
	"height_cm": 173, "weight_kg": 70,
	"debut": 1928, "talent": 90, "ego": 60,
	"genres": ["crime", "drama", "thriller"],
	"peak": 1944, "peakFame": 93,
	"films": [{"title": "Casablanca", "year": 1942}]
}
```

Required fields: `id`, `name`, `birth`, `g` (`"m"`/`"f"`), `debut`, `talent`,
`peak`, `peakFame`. Optional: `death` (year or `null`; never shown to the
player, but active in the simulation), `ethnicity` (default `"white"`, codes in
`ethnicities/core.json`), `films` (real filmography, shown as "Known for" in the
talent pool), `ego`, `genres`.

`height_cm` and `weight_kg` are optional and default to `0`. At `0` the game
picks a plausible value that is deterministic per actor id. Positive JSON values
always win.

## Events schema

See `events/core.json` — a declarative format with `conditions`, `weight`,
`choices` (each with `requirements`, `effects`, `outcome`) and event chains via
the effect `{"op": "followup", "event": "<id>", "delay_weeks": N}`. Chain links
carry `"followup_only": true` and never appear in the random pool.

## Career, reputation, locations & contacts (manager systems)

These four categories drive the "manager as a person" systems and are fully
moddable:

- **`career/core.json`** — a list of career levels with `id`, `name`, monthly
  `salary` and `living` cost (1925 dollars, inflation-scaled), and a `req` block
  (`rep`, `films`, `clients`, `indRep`, `influence`, `wealth`) for the promotion
  to that level. Order in the list is the ladder order.
- **`reputation/titles.json`** — maps the moral-identity keys
  (`kuenstlerisch`, `kommerziell`, `skrupellos`, `diskret`, `studiotreu`,
  `klientenorientiert`) to the earned reputation title shown to the player.
- **`locations/core.json`** — the node map. Each place has `id`, `name`, `icon`,
  travel `cost`, `energy`, an optional `months` array (season window), a
  `weekly` effect block, and an optional `action` block with `effects` and
  optional `lucky`/`risk` branches. Effect keys: `pubRep`, `indRep`,
  `influence`, `discretion`, `stress`, `energy`, `health`, `instinct`, `cash`,
  `book`, `identity`, plus `casting` (spawn N castings). `la` is the home base.
- **`contacts/core.json`** — `roles` (type → display name), `persons` (type →
  name pool the game draws contacts and favor partners from), `start_roster`
  (which roles the starting contact book is built from), and `channels` (each
  with `name`, `icon`, `ap` = contact-time cost, `energy`, `cost`, and a
  `rel_min`/`rel_max` relationship gain range).

## Dialogs & letters (shared effect language)

Dialogs (`dialogs/`) and letters (`letters/`) use the **same declarative
effect ops as `events/`** — one vocabulary for all three, fully moddable.

**Dialog schema** — a tree of nodes:

```json
{"id": "channel_meet", "title": "🤝 Dinner with {contact}", "start": "opening",
 "nodes": {
   "opening": {"text": ["…variants…"], "effects": [], "choices": [
     {"label": "Talk business", "goto": "business",
      "effects": [{"op": "dims", "respect": 1}],
      "conditions": {"dims": {"liking": 40}, "skill_level": {"negotiation": 2},
                     "min_cash_private": 100, "has_favor": "galaInvite"}},
     {"label": "Push your luck",
      "check": {"skill": "negotiation", "dim": "respect", "base": 0.45,
                "success": "win_node", "fail": "fail_node"}}
   ]},
   "end_warm": {"end": true, "text": ["…"], "effects": []}
 }}
```

- `goto: "end"` (or a node with `"end": true` and no choices) ends the dialog.
- `check` rolls: `base` + 0.06 × skill level + relationship dim / 300.
- Node `effects` run on entry, choice `effects` on selection.
- Placeholders: `{contact}`, `{sender}`, `{agency}`, `{year}`, `{money_fmt:N}`.
- Dialog ids the game launches automatically: `channel_meet`, `channel_club`
  (contact channels), `backroom_seal` (deal proposals), `gala_evening`.
  Remove or override them in a mod and the built-in fallback logic runs.

**Letter schema** — the weekly correspondence (letters before 1995, e-mail
after):

```json
{"id": "studio_lunch", "weight": 3, "from_type": "studio",
 "conditions": {"min_year": 0, "min_career": 0, "requires_contact_type": "studio", "chance": 1.0},
 "subject": "…", "body": "…", "expire_weeks": 2,
 "choices": [{"label": "Accept (1⏱)", "requirements": {"ap": 1, "min_cash_private": 0, "requires_assistant": false},
              "success_chance": 0.85, "effects": [], "effects_fail": [],
              "outcome": "…", "outcome_fail": "…", "dialog": "optional_dialog_id"}],
 "expire_effects": []}
```

If a contact of `from_type` exists, the letter comes from them (and `dims`
effects hit that relationship); otherwise a name is drawn from the pools.

**Effect ops** (events, dialogs and letters alike): the classic set
(`money`, `rep`, `fame`, `mood`, `trust`, `studio_rel`, `favor_grant`,
`favor_owe`, `rumor`, `identity`, `log`, `followup`, …) plus the
conversation ops: `dims` (relationship dimensions of the contact in
context), `fact` (subjective-reputation fact), `memory`, `promise`, `xp`,
`player` (energy/stress/health/pubRep/indRep/discretion/influence),
`money_private`, `tip` (market whisper), `rumor_reveal`, `casting_spawn`,
`meet_someone`, `seal_deal`, `gate_rel`, `memoir`, and `chance`
(`{"op":"chance","p":0.3,"effects":[…],"else":[…]}`).

## Regenerating the core files

`tools/ExportData.gd` writes the loaded data back, freshly formatted:

```
Godot_v4.7.1-stable_win64.exe --headless --path godot --script tools/ExportData.gd
```
