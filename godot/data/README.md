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
| `eras/` | Selectable start eras (optional `startCapitalMult`: scales the opening capital of that era) | List | `year` |
| `events/` | Game events & event chains | List | `id` |
| `backstories/` | Selectable player backstories | List | `id` |
| `ethnicities/` | Display names for ethnicities | Object | ethnicity code |
| `attributes/` | Player attributes (name, icon, desc; values grow through use) | Object | attribute key |
| `emotions/` | Core emotions of the social simulation (name, icon, desc, valence) | Object | emotion key |
| `needs/` | Client needs (name, icon, desc) — profile is derived, satisfaction is save state | Object | need key |
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

**Attribute checks** (RPG): a choice may carry
`"check": {"attr": "menschenkenntnis", "dc": 45, "identity": "diskret"}` —
the button then shows icon, attribute name and success percentage
(attribute = dc ⇒ 50 %, each point of difference ±1 %, optional identity
axis ±5 % per strength level, clamped 5–95 %). Success runs `effects`/
`outcome`, failure `effects_fail`/`outcome_fail`; the attribute grows on
use (more on success). `check` replaces `success_chance` (never both).
Conditions and choice `requirements` also accept
`"min_attr": {"verhandlung": 40}` (requirements: button greys out).
`requires_client` additionally filters on `voice_max` (speaking voice,
talkie era), `tv_appeal_min` (television appeal, TV/streaming eras) and
`without_flag` (skip clients that carry a given flag).

**Quest journal**: an event may carry
`"quest": {"title": "…", "icon": "🧾", "step": "…"}`. When such an event
fires a `followup`, the chain appears as a trackable story in the Journal
tab; every chain link can set the current `quest.step`. A link resolved
without a further `followup` closes the story (the chosen `outcome`
becomes the closing line). Events without a `quest` block never appear
in the journal.

## Emotions (`emotions/core.json`)

Eight core emotions (`warm`, `hopeful`, `calculating`, `wary`, `anxious`,
`irritated`, `resentful`, `resigned`), each `{name, icon, desc, valence}`.
Emotions are **derived, never stored**: the autoload `Emotions` computes the
TRUE emotion of a contact, client or rival from existing simulation facts
(relationship dimensions, mood/loyalty/trust, broken promises, debts,
grudges) — `Emotions.true_state(kind, ctx)`. What the PLAYER reads comes from
`Emotions.perceived(kind, ctx)` and depends on the insight attribute
(`menschenkenntnis`, plus a situational instinct bonus): below 30 only the
valence is readable (with a chance of a plausibly WRONG neighbor emotion),
up to 54 the emotion is read correctly but vaguely, up to 74 clearly, and
from 75 the concrete cause is named. Misreads are deterministic per subject
and week — reloading does not reroll them. Thresholds live in `Balance.gd`.

## Needs (`needs/core.json`)

Five client needs (`anerkennung`, `sicherheit`, `kunst`, `geld`, `ruhe`),
each `{name, icon, desc}`. Two layers: the **profile** (what drives this
person) is derived deterministically from the actor id with nudges (high
ego → recognition, low peak fame → security, prestige genres → art) and is
never saved; the **satisfaction** (`c.needsSat`, 0–100, starts at 55) is
save state and drifts monthly — roles and releases feed recognition, art
and money, gaps drain security, PR and galas drain peace, rest (weekly
planner) refills it. Effects run only through existing mechanics: the worst
need below 35 costs mood, below 20 additionally loyalty. The client card
shows a "What drives them" line staged by the insight attribute; the worst
need also sharpens the emotion model's stated cause. Thresholds in
`Balance.gd`, drift rates in `Needs.gd`.

Twice a year (or once per half-year when a need drops below 25) the client
asks for the **expectation talk** (`letters/erwartung.json` →
`dialogs/erwartung.json`): the bottleneck is named clearly or obliquely
depending on insight (`{need}` placeholder reads the worst need), and the
player can make a real promise with a deadline (`client_promise`: lead,
prestige picture, protected break, fee jump — tracked by the existing
promise system and a journal chain), stall (negotiation check) or decline
honestly. Kept promises refill the matching need strongly; broken ones
tear it down further.

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
  with `name`, `icon`, `ap` = contact-time cost, `energy`, `cost`, a
  `rel_min`/`rel_max` relationship gain range, a `profile` block that says
  WHICH relationship dimensions the channel builds — e.g. dinners build
  closeness+trust, written notes respect — and an optional `delay_weeks`:
  channels like `letter` only take effect once they arrive).

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
  A check may instead carry an **attribute test**
  `{"attr": "menschenkenntnis", "dc": 45, "success": "...", "fail": "..."}` —
  chance and button label reuse the event formula (attribute = dc ⇒ 50 %,
  ±1 % per point, clamped 5–95 %); the attribute grows on use.
- **Emotion gates**: a choice may carry `"requires_emotion": ["warm", ...]`
  (keys from `emotions/core.json`). The gate checks the subject's **TRUE**
  emotion, while the player only sees the *perceived* one — with poor
  insight, options appear or vanish "inexplicably". That gap is deliberate.
- **Perception line**: a node may carry
  `"reads": {"unreadable": "...", "likely": "...", "clear": "...", "certain": "..."}`
  — one body-language line per insight tier; misreads see the vague variant.
- The dialog header shows an **emotion chip** (perceived emotion + how sure
  you are) whenever the context has a subject (`ctid`, `cid` or `rid`);
  it refreshes after every choice because choices move the underlying
  values (`dims`, `mood`, …) — emotions themselves are never stored.
  A tree with several subjects in context can pin the one being read via
  `"emotion_subject": "contact" | "client" | "rival"` (interviews read the
  journalist, not the client being discussed).
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

Letter conditions also accept `requires_client` (same filter object as
events, e.g. `{"min_fame": 40}` — the picked client is bound to the letter,
so `{client}` and all client effect ops target them),
`"requires_studio": true` (binds a random active studio, so `{studio}` and
`studio_rel` effects work) and `"requires_rumor_known": true` (only when
the player knows a rumor).
Letters spawned by code can carry extra effect context (`sid`, `cid`);
it persists on the letter and flows into every choice effect and any
dialog the letter opens.

If a contact of `from_type` exists, the letter comes from them (and `dims`
effects hit that relationship); otherwise a name is drawn from the pools.
Templates with `"manual": true` (or `weight: 0`) never appear in the weekly
delivery — they are reserved for the dispatcher (see below), which spawns
them with a specific sender (`npc_rise`, `summons_meet`).

**Interaction tiers**: the game grades every notification automatically —
person (relationship, VIP), consequence (`impact`), time pressure and novelty
decide whether something becomes a one-line **digest** entry in the ticker,
a **notice** in the inbox, a **short dialog** (letter with choices) or a
**full scene** (a letter that opens a dialog tree). Mods that call
`Dialogs.dispatch(kind, ctx)` get the same grading for free.

**Simulation first**: dialog and letter text can only read simulation facts
through the placeholders and only change the world through the effect ops
listed below. Unknown ops or placeholders are reported as warnings at load —
generated text cannot invent contracts, contacts or promises.

**Conversation memory & repetition control**: dialogs with a contact in
context open with a *recall* — the person concretely brings up broken
promises, missed occasions, help given or word kept (each grievance is
voiced once; phrased facts have a cooldown). Text variants in dialog nodes
are tracked, so no line repeats until all variants have been used.

**Weekly scene budget**: only a few big scenes (dinner, club night, back
room, gala) fit into a normal week — beyond that the manager pays with
stress, and the log notes that weeks like this mean crisis.

**Promises** (`contacts/core.json` → `promise_kinds`): each promise has a
kind (with icon, text and due window), participants, witness count and an
oral/written flag. Kept in front of witnesses ⇒ more trust and standing;
broken in front of witnesses ⇒ louder damage; broken *written* promises can
surface as evidence in the press. The `promise` effect op accepts `kind`,
`witnesses` and `written`.

**Favors are obligations, not coins**: calling one in cools the relationship
a touch and sometimes creates a counter-debt; debts you owe get called in by
letter after months (`letters/debt_called`) — settle in kind, settle with
money, or refuse and be known as someone who forgets help.

**Effect ops** (events, dialogs and letters alike): the classic set
(`money`, `rep`, `fame`, `mood`, `trust`, `studio_rel`, `favor_grant`,
`favor_owe`, `rumor`, `identity`, `log`, `followup`, …) plus the
conversation ops: `dims` (relationship dimensions of the contact in
context), `fact` (subjective-reputation fact), `memory`, `promise`, `xp`,
`player` (energy/stress/health/pubRep/indRep/discretion/influence),
`money_private`, `tip` (market whisper), `rumor_reveal`, `casting_spawn`,
`meet_someone`, `seal_deal`, `gate_rel`, `memoir`, `client_promise`
(a real client promise with deadline, kinds from `Game.PROMISES`),
`press_event` (`{"op":"press_event","cat":"Press","text":"…"}`),
`rumor_belief` (the loudest rumor known to the player gains/loses belief),
`tv_contract` (`{"op":"tv_contract","months":18,"monthly_base":700}` — a
series contract via the `tvIncome` flag; the monthly amount scales with
inflation and fame, security/money needs get a boost),
and `chance` (`{"op":"chance","p":0.3,"effects":[…],"else":[…]}`).

## Staff & delegation (`staff/core.json`)

`foci` defines the desks staff can run (deal-making, research, contact care,
crisis — each with name, icon, description), `traits` the personalities that
color their recommendations (`confidence` shifts the certainty they claim,
`fee` how much money they leave on the table, `risk` their appetite; `hint`
is what a leadership-trained player reads about them). Every staffer runs in
one of three modes: paused, proposing (recommendations with reasoning and a
confidence number), or autonomous (acts alone, reports in the weekly digest —
except when your standing rules force an escalation: approval cap, VIP-client
fame line, loud scandals).

## Regenerating the core files

`tools/ExportData.gd` writes the loaded data back, freshly formatted:

```
Godot_v4.7.1-stable_win64.exe --headless --path godot --script tools/ExportData.gd
```
