extends Node
# =====================================================================
# Hollywood Manager (Godot) — Spiellogik
# Port der Web-Version plus neues Feature: Karriere-DNA.
# state ist ein reines JSON-Dictionary (Save/Load via user://).
# =====================================================================

const MONTHS = ["January","February","March","April","May","June","July","August","September","October","November","December"]

const PERKS = {
	"pr":        {"name":"PR handling",        "cost":1500, "desc":"Softens scandals and leaks, mood +1/month"},
	"travel":    {"name":"First-class comfort","cost":1200, "desc":"Mood +2/month, recovery is faster"},
	"script":    {"name":"Script approval",    "cost":0,    "desc":"Client declines roles with fit < 35, +5 fit on genre matches"},
	"coach":     {"name":"Private coach",      "cost":1800, "desc":"Talent grows slowly (up to +10)"},
	"assistant": {"name":"Personal assistant", "cost":800,  "desc":"Halves on-set exhaustion, loyalty +1/month"},
}

const PROMISES = {
	"lead12":   {"label":"a lead role within 12 months",          "months":12},
	"prestige": {"label":"a prestige project within 18 months",   "months":18},
	"oscar":    {"label":"an Oscar nomination within 24 months",  "months":24},
}

const CONTRACT_YEARS = [2, 3, 5, 7]


# ---------------------------------------------------------------------
# Karriere-DNA: fünf bipolare Image-Achsen (-100 … +100, 0 = ungeprägt).
# Rollen prägen das öffentliche Bild; das Casting gleicht Rollenbild und
# Karriere-DNA ab — Typecasting entsteht organisch.
# ---------------------------------------------------------------------

# Reichweite wird als monatliche Weitergabechance gelesen. Zuverlässigkeit
# beeinflusst, wie stark ein Gerücht beim Weitertragen an Glauben gewinnt.

# ---------------------------------------------------------------------
# Gefallen & Schulden: konkrete Marker statt abstraktem Netzwerk-Wert.
# state.favors[] / state.debts[] = {id, kind, from: {type, name, studioId?},
#   gainedMi, expiresMi (-1 = kein Verfall), note}
# ---------------------------------------------------------------------
const FAVOR_KINDS = {
	"extraAudition": {"name": "Extra audition", "desc": "A rejected client may pitch for a role again"},
	"suppressStory": {"name": "Suppress a story", "desc": "Defuses a scandal, leak or photo event"},
	"scriptAccess": {"name": "Script access", "desc": "Reveals a casting's hidden quality base before the pitch"},
	"billing": {"name": "Billing placement", "desc": "+fame for a client at the next release"},
	"galaInvite": {"name": "Exclusive invitation", "desc": "A gala that can bring new contacts or an instant deal"},
}

# ---------------------------------------------------------------------
# Finanzbuchhaltung: jede Geldbewegung läuft über book() ins Ledger.
# ---------------------------------------------------------------------
const LEDGER_CATS = {
	"provision": "Commissions",
	"bonus": "Signing & loyalty bonuses",
	"buero": "Office & fixed costs",
	"gehalt": "Salary & private draws",
	"reisen": "Travel & expenses",
	"perks": "Client perks",
	"pr_recht": "PR, lawyers & campaigns",
	"events": "Events",
	"tv": "Television",
	"investition": "Investments",
	"abfindung": "Severances",
	"sonstiges": "Miscellaneous",
}

const LEDGER_MAX := 600
const LEDGER_MONTHS_MAX := 240

const IDENTITY_KEYS := ["klientenorientiert", "studiotreu", "skrupellos", "diskret", "kuenstlerisch", "kommerziell"]
const IDENTITY_LABELS := {
	"klientenorientiert": "client-first", "studiotreu": "studio-loyal",
	"skrupellos": "ruthless", "diskret": "discreet",
	"kuenstlerisch": "artistic", "kommerziell": "commercial",
}

const NARRATIVE_TYPES := {
	"kinderstar_ernst": {"label":"From child star to character actor", "desc":"An adult prestige role shatters the cute youth image."},
	"comeback": {"label":"The great comeback", "desc":"After a slump in fame, a strong new success writes chapter two."},
	"spaetberufen": {"label":"Finally center stage", "desc":"Years of supporting parts finally lead to the first big lead."},
	"action_prestige": {"label":"From action star to prestige", "desc":"Box-office hits are traded for a demanding lead role."},
	"skandal_respekt": {"label":"From scandal to respect", "desc":"A controversial image is rewritten through reliable work."},
	"ensemble_star": {"label":"From the second row to stardom", "desc":"A proven ensemble face finally claims the center of the screen."},
}

const RIVAL_STYLE_INFO := {
	"aggressiv": {"label":"Aggressive", "icon":"🦈"},
	"nachwuchs": {"label":"Up-and-coming", "icon":"🌱"},
	"studiotreu": {"label":"Studio-loyal", "icon":"🏛"},
	"prestige": {"label":"Prestige", "icon":"🎩"},
}

# Bühnen-Cluster: Die vier Entscheidungen eines Vorsprechens. Die Werte sind
# bewusst genreunabhängige Schlüssel; nur ihre Texte wechseln mit dem Film.
const AUDITION_DIMS := ["scene", "interpretation", "appearance", "emphasis"]
const AUDITION_OPTIONS := {
	"scene": ["speech", "quiet", "confrontation"],
	"interpretation": ["faithful", "modern", "bold"],
	"appearance": ["glamour", "serious", "in_character"],
	"emphasis": ["charm", "professional", "courage"],
}
const AUDITION_LABELS := {
	"interpretation": {"faithful":"faithful", "modern":"modern", "bold":"daring"},
	"appearance": {"glamour":"glamour", "serious":"serious", "in_character":"arrive in character"},
	"emphasis": {"charm":"charm", "professional":"professionalism", "courage":"artistic courage"},
}
const CHEM_READ_SCENES := {
	"love": "love scene",
	"conflict": "argument scene",
	"comedy": "comedy timing",
}

var state = null
var nego = null
var pitch_ctx = null
var chem_read = null
var actor_by_id: Dictionary = {}

func _ready() -> void:
	randomize()
	for a in Data.ACTORS:
		actor_by_id[a.id] = a

# ---------- Zufall & zustandslose Helfer: siehe Autoload Util.gd (Chunk 02) ----------
# Tonfilm-Umbruch: steht die Karriere dieses Klienten wegen seiner
# Sprechstimme auf dem Spiel? (Übergangsfenster, schwache Stimme, kein
# Training absolviert — die Stummfilm-Nische akzeptiert das Risiko bewusst.)
func voice_at_risk(c: Dictionary) -> bool:
	if int(state.year) < Balance.TALKIE_YEAR or int(state.year) > Balance.TALKIE_TRANSITION_END:
		return false
	if c.flags.get("voiceTrained", false) or c.flags.get("voiceNiche", false):
		return false
	var actor: Dictionary = actor_by_id.get(str(c.get("aid", "")), {})
	if actor.is_empty():
		return false
	return Util.voice_of(actor) < Balance.VOICE_WEAK_THRESHOLD

func client_base_weight(c: Dictionary) -> float:
	var actor: Dictionary = actor_by_id.get(str(c.get("aid", "")), {})
	if actor.is_empty():
		return maxf(float(c.get("weightKg", 1.0)), 1.0)
	return float(Util.body_of(actor).weight)

func clamp_client_weight(c: Dictionary, value: float) -> float:
	var base := client_base_weight(c)
	return clampf(value, base * 0.75, base * 1.25)

func change_client_weight(c: Dictionary, amount: float) -> float:
	var before := float(c.get("weightKg", client_base_weight(c)))
	var after := snappedf(clamp_client_weight(c, before + amount), 0.01)
	c["weightKg"] = after
	c["weightTrend"] = after - before
	return after - before

func _tick_client_weight(c: Dictionary, actor: Dictionary, discipline: float) -> void:
	var seed := Util.hashs(str(actor.id) + "weight_drift")
	var natural_dir := 1.0 if seed % 2 == 0 else -1.0
	var delta := natural_dir * (0.10 + float(int(seed / 2) % 3) * 0.05)
	var age := Util.age_of(actor, state.year)
	if age >= 40:
		delta += minf(0.15, 0.08 + float(age - 40) * 0.002)
	var base := client_base_weight(c)
	var current := float(c.get("weightKg", base))
	if discipline >= 70.0:
		delta += clampf((base - current) * 0.08, -0.20, 0.20)
	elif discipline < 40.0:
		delta += natural_dir * 0.05
	if float(c.exhaustion) > 60.0:
		var stress_dir := 1.0 if Util.hashs(str(actor.id) + "weight_stress") % 2 == 0 else -1.0
		delta += stress_dir * 0.15
	delta = clampf(delta, -0.40, 0.40)
	if absf(delta) < 0.10:
		var fallback_dir := 1.0 if delta > 0.0 or (is_zero_approx(delta) and age >= 40) else -1.0
		delta = fallback_dir * 0.10
	change_client_weight(c, delta)

# ---------- RPG-Attribute der Spielfigur (Chunk 15) ----------
# Kein Punkteverteilen, kein XP-Pool: Attribute wachsen ausschließlich
# durch konkrete Handlungen (attr_gain-Hooks), mit abnehmendem Ertrag.
func attr(key: String) -> int:
	if state == null:
		return roundi(Balance.ATTR_BASE)
	return roundi(float(state.get("attributes", {}).get(key, Balance.ATTR_BASE)))

func attr_gain(key: String, amount: float) -> void:
	if state == null or not state.has("attributes"):
		return
	var cur := float(state.attributes.get(key, Balance.ATTR_BASE))
	var mult := 1.0
	if cur >= Balance.ATTR_SOFTCAP_2:
		mult = 0.25
	elif cur >= Balance.ATTR_SOFTCAP_1:
		mult = 0.5
	state.attributes[key] = clampf(cur + amount * mult, 0.0, 100.0)

# ---------- Ökonomie & Karriere-Mathematik (zustandslose Teile: Util.gd) ----------
func required_rep(fame: float) -> int:
	var req := 0 if fame <= 45 else roundi((fame - 45.0) * 1.1)
	# Backstory-Schwäche (z. B. Aufsteiger): A-Lister verlangen zusätzlichen Ruf
	if fame >= 70.0:
		req += int(backstory_mod("required_rep_add", 0.0))
	return req

func grade_range(v: float, spread: float, seed_s: String) -> String:
	# Backstory-Trait (z. B. gescheiterte:r Schauspieler:in): engere Einschätzung
	if state != null:
		spread = maxf(2.0, spread + backstory_mod("grade_spread_add", 0.0))
		# Talenturteil (Feature 6): das scharfe Auge sieht die Note, nicht die Spanne
		if Mogul.has_ability("sharp_eye"):
			spread = 2.0
	var jitter: float = float(Util.hashs(seed_s) % 9) - 4.0
	var center: float = clampf(v + jitter, 3.0, 100.0)
	var lo := Util.grade(clampf(center - spread, 0.0, 100.0))
	var hi := Util.grade(clampf(center + spread, 0.0, 100.0))
	return lo if lo == hi else "%s – %s" % [lo, hi]

# ---------- Karriere-DNA: siehe Autoload CareerDNA.gd (Chunk 03) ----------
func snapshot_client(c: Dictionary) -> void:
	if not c.has("fameHistory"):
		c["fameHistory"] = []
	if not c.has("dnaHistory"):
		c["dnaHistory"] = []
	c.fameHistory.append({"mi":mi(), "v":float(c.fame)})
	c.dnaHistory.append({"mi":mi(), "romantik":float(c.dna.romantik), "popular":float(c.dna.popular), "verlass":float(c.dna.verlass), "unikat":float(c.dna.unikat), "familie":float(c.dna.familie)})
	while c.fameHistory.size() > 60:
		c.fameHistory.pop_front()
	while c.dnaHistory.size() > 60:
		c.dnaHistory.pop_front()

func narrative_candidate_types(c: Dictionary) -> Array:
	var actor: Dictionary = actor_by_id[c.aid]
	var age := Util.age_of(actor, state.year)
	var films: Array = c.get("films", [])
	var support_n: int = films.filter(func(f): return not bool(f.get("lead", false))).size()
	var action_n: int = films.filter(func(f): return str(f.get("genre", "")) == "action").size()
	var fame_high := float(c.fame)
	var fame_low := float(c.fame)
	for point in c.get("fameHistory", []):
		fame_high = maxf(fame_high, float(point.get("v", c.fame)))
		fame_low = minf(fame_low, float(point.get("v", c.fame)))
	var family_low := float(c.dna.familie)
	for point in c.get("dnaHistory", []):
		family_low = minf(family_low, float(point.get("familie", c.dna.familie)))
	var out: Array = []
	if int(actor.debut) - int(actor.birth) <= 16 and age >= 20:
		out.append("kinderstar_ernst")
	if fame_high - fame_low >= 12.0 and (float(c.fame) - fame_low >= 3.0 or fame_high - float(c.fame) >= 10.0):
		out.append("comeback")
	if age >= 45 and support_n >= 2:
		out.append("spaetberufen")
	if actor.genres.has("action") or action_n >= 2:
		out.append("action_prestige")
	if family_low <= -25.0 or float(c.dna.familie) <= -20.0:
		out.append("skandal_respekt")
	if support_n >= 3:
		out.append("ensemble_star")
	return out

func declare_narrative(cid: int, type_s: String) -> String:
	var c = client(cid)
	if c == null or not NARRATIVE_TYPES.has(type_s):
		return "This story cannot be declared."
	if not c.get("narrative", {}).is_empty() and str(c.narrative.get("status", "aktiv")) == "aktiv":
		return "A narrative is already running for %s." % client_name(c)
	if not narrative_candidate_types(c).has(type_s):
		return "The career so far does not support this narrative yet."
	var cost := roundi(7500.0 * Util.infl(state.year))
	if float(state.agency.cash) < float(cost):
		return "The PR campaign costs %s — too much for the till right now." % Util.fmt_money(cost)
	book(-float(cost), "pr_recht", "Career narrative: %s" % client_name(c))
	c.narrative = {"type":type_s, "startedMi":mi(), "progress":0.0, "status":"aktiv"}
	press_event("Careers", "Chapter 1: %s — %s begins" % [client_name(c), NARRATIVE_TYPES[type_s].label])
	return "The press kit carries one clear headline: “%s”. Matching roles pay into the story twice." % NARRATIVE_TYPES[type_s].label

func narrative_role_match(c: Dictionary, prod: Dictionary, role: Dictionary) -> bool:
	var narrative: Dictionary = c.get("narrative", {})
	if narrative.is_empty() or str(narrative.get("status", "")) != "aktiv":
		return false
	var lead := str(role.get("type", "support")) == "lead"
	var prestige := int(prod.get("prestige", 0))
	var genre := str(prod.get("genre", ""))
	match str(narrative.type):
		"kinderstar_ernst": return lead and prestige >= 2 and genre in ["drama", "thriller", "crime"]
		"comeback": return lead and (prestige >= 2 or genre in ["drama", "thriller"])
		"spaetberufen": return lead
		"action_prestige": return lead and prestige >= 2 and genre == "drama"
		"skandal_respekt": return prestige >= 2 and genre in ["drama", "adventure", "western"]
		"ensemble_star": return lead
	return false

func narrative_multiplier(c: Dictionary, prod: Dictionary, role: Dictionary) -> float:
	return 2.0 if narrative_role_match(c, prod, role) else 1.0

func advance_narrative_on_release(c: Dictionary, prod: Dictionary, role: Dictionary) -> void:
	var narrative: Dictionary = c.get("narrative", {})
	if narrative.is_empty() or str(narrative.get("status", "")) != "aktiv":
		return
	var info: Dictionary = NARRATIVE_TYPES.get(str(narrative.type), {})
	if narrative_role_match(c, prod, role):
		narrative.progress = minf(100.0, float(narrative.progress) + (60.0 if str(role.type) == "lead" else 35.0))
		press_event("Careers", "Chapter %d: %s continues “%s” with “%s”" % [2 + int(float(narrative.progress) / 55.0), client_name(c), info.get("label", "a new story"), prod.title])
		if float(narrative.progress) >= 100.0:
			narrative.status = "abgeschlossen"
			c.fame = clampf(float(c.fame) + 8.0, 5.0, 100.0)
			state.agency.rep = clampi(int(state.agency.rep) + 5, 0, 100)
			press_event("Cover story", "%s completes “%s” — Hollywood sees a career with new eyes" % [client_name(c), info.get("label", "the transformation")])
			log_msg("Career narrative completed: %s — %s." % [client_name(c), info.get("label", "a fresh start")], "history")
	else:
		narrative.progress = maxf(0.0, float(narrative.progress) - 25.0)
		press_event("Press mockery", "Chapters out of order? %s drains the momentum of their own PR story with “%s”" % [client_name(c), prod.title])

func studio_style(studio_id: String) -> String:
	for s in Data.STUDIOS:
		if s.id == studio_id:
			return s.style
	return "commercial"

# =====================================================================
# Spielzustand
# =====================================================================
func new_game(agency_name: String, start_year: int, backstory_id: String = "") -> void:
	state = {
		"agency": {"name": agency_name, "cash": 0.0, "rep": 15, "debtMonths": 0},
		"year": start_year, "month": 1, "week": 1, "startYear": start_year,
		"saveVersion": 2, "backstory": backstory_id,
		"favors": [], "debts": [],
		"ledger": [], "ledgerMonthly": [],
		"clients": [], "castings": [], "productions": [], "released": [], "log": [],
		"rumors": [], "newspaper": [], "pressFeed": [],
		"rivals": [], "powerFigures": [], "identity": {}, "identityLastTop": [],
		"instinct": 20, "predictions": [], "history_pairs": {},
		"audition": null, "directors": {},
		"planner": {"player": _empty_week(), "clients": {}}, "scoutBonus": 0,
		"plannerMonthCounts": {},
		"coverage": {"current": null, "history": []}, "coverageQueue": 0,
		"studioRel": {}, "market": 1.0, "marketHistory": [], "usedHistory": [],
		"eventCd": {}, "followups": [], "usedTitles": [], "quests": [],
		"strikeMonths": 0, "strikeExempt": false,
		"nextId": 1, "over": false,
		"player": Persona.default_player(),
		"contacts": [], "contactAP": Persona.AP_PER_WEEK, "promises": [],
	}
	for key in IDENTITY_KEYS:
		state.identity[key] = 0.0
	state["attributes"] = {}
	for key in Data.ATTRIBUTES:
		state.attributes[key] = Balance.ATTR_BASE
	_init_rivals(start_year)
	Persona.init_contacts()
	Mogul.init_state()
	Network.init_state()
	Dialogs.init_state()
	Staff.init_state()
	for s in Data.STUDIOS:
		state.studioRel[s.id] = Util.rndi(20, 45)
	# Startkapital: Basis × Inflation × optionaler Era-Faktor (data/eras/core.json,
	# "startCapitalMult") — die Frühzeit braucht mehr Runway, bis kleine Klienten
	# tragende Gagen erreichen (Balance-Chunk 19).
	var capital_mult := 1.0
	for era_def in Data.ERAS:
		if int(era_def.year) == start_year:
			capital_mult = float(era_def.get("startCapitalMult", 1.0))
	book(float(roundi(Balance.START_CAPITAL * Util.infl(start_year) * capital_mult)), "sonstiges", "Opening capital — office opening on Sunset Boulevard")
	Persona.book(roundf(2500.0 * Util.infl(start_year)), "Savings from the years before")
	# Ein alter Bekannter aus den Anfangsjahren erinnert sich.
	grant_favor("galaInvite", favor_contact_for("galaInvite"))
	log_msg("%s opens its offices on Sunset Boulevard. Time to make careers." % agency_name, "history")
	_apply_backstory_start()
	spawn_castings(Util.rndi(2, 3))

# ---------- Backstory (wählbare Vorgeschichte der Spielfigur) ----------
func has_backstory(id_s: String) -> bool:
	return state != null and str(state.get("backstory", "")) == id_s

func backstory_def() -> Dictionary:
	if state == null:
		return {}
	var id_s := str(state.get("backstory", ""))
	if id_s == "":
		return {}
	for b in Data.BACKSTORIES:
		if str(b.id) == id_s:
			return b
	return {}

# Numerischer Trait-/Schwächen-Wert der aktiven Backstory (Summe aus beiden).
func backstory_mod(key: String, def_val: float = 0.0) -> float:
	var b := backstory_def()
	if b.is_empty():
		return def_val
	var t: Dictionary = b.get("trait", {}).get("effects", {})
	var w: Dictionary = b.get("weakness", {}).get("effects", {})
	if not t.has(key) and not w.has(key):
		return def_val
	return float(t.get(key, 0.0)) + float(w.get(key, 0.0))

# Wie viele Klienten die Agentur seriös betreuen kann. Noch KEIN hartes Limit —
# Durchsetzung kommt mit dem Personal-System in einer späteren Iteration.
func client_capacity() -> int:
	var b := backstory_def()
	return 6 + int(b.get("client_capacity_mod", 0))

func _apply_backstory_start() -> void:
	var b := backstory_def()
	if b.is_empty():
		return
	var start: Dictionary = b.get("start", {})
	if float(start.get("cash_add", 0)) != 0.0:
		book(roundf(float(start.cash_add) * Util.infl(state.startYear)), "sonstiges", "Backstory: %s" % str(b.name))
	state.agency.rep = clampi(int(state.agency.rep) + int(start.get("rep_add", 0)), 0, 100)
	state.instinct = clampi(int(state.instinct) + int(start.get("instinct_add", 0)), 5, 100)
	# RPG-Attribute (Chunk 15): die Vorgeschichte seedet die Stärken
	for attr_key in start.get("attributes", {}):
		attr_gain(str(attr_key), float(start.attributes[attr_key]))
	for kind_s in start.get("favors", []):
		grant_favor(str(kind_s), favor_contact_for(str(kind_s)), true)
	# Biografischer Start (Feature 41): frühere Tätigkeiten bringen
	# Fähigkeiten und ein anfängliches Netzwerk mit.
	for field in start.get("skills_xp", {}):
		Mogul.grant_xp(str(field), float(start.skills_xp[field]), "Backstory: %s" % str(b.name))
	for ctype in start.get("contacts_extra", []):
		if Data.CONTACT_PERSONS.has(str(ctype)):
			var cname := str(Util.pick(Data.CONTACT_PERSONS[str(ctype)]))
			if not state.contacts.any(func(ct): return str(ct.name) == cname):
				var new_ct: Dictionary = Persona._add_contact(str(ctype), cname)
				Network.adjust(new_ct, {"liking": 10.0, "trust": 8.0}, false)
				Persona._memory(new_ct, "Knows you from your years before the agency.")
	var by_style: Dictionary = start.get("studio_rel_style", {})
	var rel_all := int(start.get("studio_rel_all", 0))
	for s in Data.STUDIOS:
		var add := rel_all + int(by_style.get(str(s.style), 0))
		if add != 0 and state.studioRel.has(s.id):
			state.studioRel[s.id] = clampi(int(state.studioRel[s.id]) + add, 0, 100)
	log_msg("Backstory: %s — %s" % [str(b.name), str(b.get("desc", ""))], "history")

func next_id() -> int:
	state.nextId = int(state.nextId) + 1
	return int(state.nextId) - 1

func log_msg(text: String, type: String = "info") -> void:
	state.log.push_front({"y": state.year, "m": state.month, "text": text, "type": type})
	if state.log.size() > 300:
		state.log.pop_back()
	# Jede Krise nagt auch am Manager persönlich.
	if type == "bad":
		Persona.on_bad_news()
	# Karrieregedächtnis (Feature 10): historische Momente bleiben für immer
	if type == "history":
		Network.memoir(text)

func press_event(cat: String, text_s: String) -> void:
	if state == null:
		return
	state.pressFeed.append({"cat": cat, "text": text_s})
	while state.pressFeed.size() > 30:
		state.pressFeed.pop_front()

func identity_total() -> float:
	var total := 0.0
	for key in IDENTITY_KEYS:
		total += float(state.identity.get(key, 0.0))
	return total

func identity_top_labels() -> Array:
	if state == null or identity_total() <= 0.0:
		return []
	var keys: Array = IDENTITY_KEYS.duplicate()
	keys.sort_custom(func(a, b): return float(state.identity.get(a, 0.0)) > float(state.identity.get(b, 0.0)))
	var out: Array = []
	for key in keys.slice(0, 2):
		if float(state.identity.get(key, 0.0)) > 0.0:
			out.append(str(IDENTITY_LABELS[key]))
	return out

func identity_strength(key: String) -> float:
	var total := identity_total()
	if total <= 0.0:
		return 0.0
	var avg := total / float(IDENTITY_KEYS.size())
	return clampf((float(state.identity.get(key, 0.0)) - avg) / maxf(4.0, avg + 4.0), -1.0, 2.0)

func record_identity(key: String, amount: float = 1.0) -> void:
	if not IDENTITY_KEYS.has(key) or amount <= 0.0:
		return
	var before: Array = identity_top_labels()
	state.identity[key] = float(state.identity.get(key, 0.0)) + amount
	var after: Array = identity_top_labels()
	if after != before and identity_total() >= 3.0:
		state.identityLastTop = after.duplicate()
		press_event("Agencies", "%s wears a new label: %s" % [state.agency.name, " & ".join(after)])

func _rival_names(year: int) -> Array:
	if year < 1940:
		return ["Continental Artists Bureau", "Majestic Players Office", "Selznick & Rowe", "Pacific Star Exchange"]
	if year < 1970:
		return ["Avalon Artists", "Gold Coast Agency", "Monarch Talent", "Sterling Representation"]
	if year < 2000:
		return ["Apex Artists", "Canyon Talent Group", "TriStar Representation", "Westwood Creative"]
	return ["Velocity Entertainment", "Northstar Talent", "Mosaic Artists Group", "Summit Creative Partners"]

func _init_rivals(year: int) -> void:
	var names := _rival_names(year)
	var styles := ["aggressiv", "nachwuchs", "studiotreu", "prestige"]
	var studios := active_studios()
	for i in styles.size():
		state.rivals.append({"id":"rival_%d" % i, "name":names[i], "style":styles[i], "clients":[], "grudge":0.0, "rel":0.0,
			"studioId":str(studios[i % studios.size()].id) if studios.size() else ""})

func date_str() -> String:
	return "Week %d · %s %d" % [int(state.get("week", 1)), MONTHS[int(state.month) - 1], int(state.year)]

func mi() -> int:
	return int(state.year) * 12 + int(state.month) - 1

# Wochenindex (4 Wochen pro Monat)
func wi() -> int:
	return mi() * 4 + int(state.get("week", 1)) - 1

func mi_str(m) -> String:
	return "%s %d" % [MONTHS[int(m) % 12], int(m) / 12]

# ---------- Talentpool & Klienten ----------
func active_studios() -> Array:
	var y = state.year
	return Data.STUDIOS.filter(func(s): return s.from <= y and s.to >= y)

func is_client(actor_id: String) -> bool:
	for c in state.clients:
		if c.aid == actor_id:
			return true
	return false

func rival_for_actor(actor_id: String) -> Variant:
	for rival in state.get("rivals", []):
		if rival.get("clients", []).has(actor_id):
			return rival
	return null

func is_rival_client(actor_id: String) -> bool:
	return rival_for_actor(actor_id) != null

func pool_actors() -> Array:
	var y = state.year
	var out = Data.ACTORS.filter(func(a):
		return a.debut <= y and (a.death == null or a.death > y) and Util.age_of(a, y) <= 85 and not is_client(a.id))
	out.sort_custom(func(a, b): return Util.fame_at(a, y) > Util.fame_at(b, y))
	return out

func available_actors() -> Array:
	var y = state.year
	var out = Data.ACTORS.filter(func(a):
		return a.debut <= y and (a.death == null or a.death > y) and Util.age_of(a, y) <= 85 and not is_client(a.id) and not is_rival_client(a.id))
	out.sort_custom(func(a, b): return Util.fame_at(a, y) > Util.fame_at(b, y))
	return out

func client(cid) -> Variant:
	for c in state.clients:
		if int(c.id) == int(cid):
			return c
	return null

func client_name(c: Dictionary) -> String:
	return actor_by_id[c.aid].name

func rival_by_id(rival_id: String) -> Variant:
	for rival in state.get("rivals", []):
		if str(rival.id) == rival_id:
			return rival
	return null

func pick_poach_rival() -> Variant:
	if state.get("rivals", []).is_empty():
		return null
	var sorted: Array = state.rivals.duplicate()
	sorted.sort_custom(func(a, b):
		var av := float(a.grudge) + (25.0 if str(a.style) == "aggressiv" else 0.0)
		var bv := float(b.grudge) + (25.0 if str(b.style) == "aggressiv" else 0.0)
		return av > bv)
	return sorted[0]

func rival_poach_client(rival_id: String, c: Dictionary) -> void:
	var rival = rival_by_id(rival_id)
	if rival == null or c == null:
		return
	var actor_id := str(c.aid)
	var actor_name := client_name(c)
	state.clients.erase(c)
	if not rival.clients.has(actor_id):
		rival.clients.append(actor_id)
	rival.grudge = clampf(float(rival.grudge) + 20.0, 0.0, 100.0)
	rival.rel = clampf(float(rival.rel) - 15.0, -100.0, 100.0)
	press_event("Client moves", "%s leaves %s for %s" % [actor_name, state.agency.name, rival.name])

func _rival_candidate(rival: Dictionary) -> Variant:
	var pool := available_actors()
	if pool.is_empty():
		return null
	match str(rival.style):
		"nachwuchs":
			var young: Array = pool.filter(func(a): return Util.age_of(a, state.year) <= 28)
			if young.size():
				young.sort_custom(func(a, b): return float(a.talent) > float(b.talent))
				return young[0]
		"prestige":
			var artists: Array = pool.filter(func(a): return float(a.talent) >= 82.0)
			if artists.size():
				artists.sort_custom(func(a, b): return float(a.talent) > float(b.talent))
				return artists[0]
		"aggressiv":
			return pool[0]
		"studiotreu":
			var reliable: Array = pool.filter(func(a): return float(Util.attrs(a).discipline) >= 60.0)
			if reliable.size():
				return reliable[0]
	return pool[0]

func _rival_coop_event(rival: Dictionary) -> Variant:
	var c = random_client(func(x): return is_free(x))
	if c == null:
		return null
	var rid := str(rival.id)
	var cid := int(c.id)
	var rival_name := str(rival.name)
	return {"title":"A call from %s" % rival_name,
		"text":"[i]“You don't have to like each other to build a good picture together.”[/i]\n\n%s offers a package cooperation: your client %s gets a role, the rival house fills out the rest of the cast." % [rival_name, client_name(c)],
		"choices":[
			{"label":"Package it together", "fn":func():
				var cl = client(cid)
				var rv = rival_by_id(rid)
				if cl == null or rv == null:
					return "The opportunity has passed."
				var result = quick_production(cl, {"prestige":2 if str(rv.style) == "prestige" else 1})
				rv.grudge = maxf(0.0, float(rv.grudge) - 12.0)
				rv.rel = clampf(float(rv.rel) + 14.0, -100.0, 100.0)
				press_event("Agencies", "%s and %s package “%s” together" % [state.agency.name, rv.name, result.title])
				return "Two address books, one contract: “%s” goes into production." % result.title},
			{"label":"Decline politely", "fn":func(): return "You leave the door open. In Hollywood, tomorrow is another month."},
		]}

func tick_rivals(events: Array = [], force: bool = false) -> void:
	var cooperation_added := false
	for rival in state.get("rivals", []):
		for actor_id in rival.clients.duplicate():
			var actor: Dictionary = actor_by_id.get(str(actor_id), {})
			if actor.is_empty() or (actor.death != null and float(actor.death) <= float(state.year)):
				rival.clients.erase(actor_id)
		var sign_chance := 0.07 if str(rival.style) == "nachwuchs" else 0.035
		if force or Util.chance(sign_chance):
			var actor = _rival_candidate(rival)
			if actor != null:
				rival.clients.append(str(actor.id))
				press_event("Rival deals", "%s signs %s" % [rival.name, actor.name])
				log_msg("Competition: %s signs %s." % [rival.name, actor.name], "info")
		if float(rival.grudge) >= 60.0 and state.clients.size() and (force or Util.chance(0.18)):
			var target: Dictionary = Util.pick(state.clients)
			var rumor := Scandal.add_rumor(int(target.id), "%s is sowing doubts about the reliability of %s in the studio corridors." % [rival.name, client_name(target)], false, "skandal", ["Studios", "Assistants"], 14.0, true, "", 34.0)
			rumor["sourceRival"] = str(rival.id)
			press_event("Agencies", "Ice age between %s and %s: studio corridors become a battlefield" % [state.agency.name, rival.name])
		# Aktives Abwerbe-Duell (statt stillem Grudge): unzufriedene Klienten
		# bekommen ein konkretes Gegenangebot auf den Tisch gelegt.
		if state.clients.size() and (force or Util.chance(0.04 + float(rival.grudge) / 500.0)):
			var poach_cands: Array = state.clients.filter(func(pc):
				return float(pc.loyalty) < 55.0 or float(pc.mood) < 45.0)
			if poach_cands.size():
				events.append(_rival_poach_event(rival, Util.pick(poach_cands)))
		if not force and not cooperation_added and float(rival.grudge) <= 12.0 and float(rival.rel) >= 20.0 and Util.chance(0.04):
			var coop = _rival_coop_event(rival)
			if coop != null:
				events.append(coop)
				cooperation_added = true

# Marktanteils-Ranking: Star-Power aller Agenturen (Summe Klienten-Ruhm),
# Spieler eingeschlossen — die Konkurrenz wird als Rangliste sichtbar.
func agency_ranking() -> Array:
	var out: Array = []
	var own := 0.0
	for c in state.clients:
		own += float(c.fame)
	out.append({"name": str(state.agency.name), "score": own, "isPlayer": true})
	for rival in state.get("rivals", []):
		var score := 0.0
		for aid in rival.clients:
			var actor: Dictionary = actor_by_id.get(str(aid), {})
			if not actor.is_empty():
				score += float(Util.fame_at(actor, state.year))
		out.append({"name": str(rival.name), "score": score, "isPlayer": false})
	out.sort_custom(func(a, b): return float(a.score) > float(b.score))
	return out


# Abwerbe-Duell: Der Rivale legt ein konkretes Angebot auf den Tisch —
# mitbieten, an die gemeinsame Geschichte appellieren oder ziehen lassen.
func _rival_poach_event(rival: Dictionary, c: Dictionary) -> Dictionary:
	var rid := str(rival.id)
	var rival_name := str(rival.name)
	var cid := int(c.id)
	var bonus := roundi(Util.ask_fee(float(c.fame), state.year) * 0.06)
	var appeal_p := clampf(0.30 + float(c.loyalty) / 200.0 + float(c.trust) / 250.0 + float(attr("menschenkenntnis")) / 400.0, 0.1, 0.9)
	return {"title": "Poaching attempt: %s" % client_name(c),
		"text": "[i]“Half the commission, twice the attention.”[/i]\n\n%s has made %s a concrete offer — and your client is listening. Loyalty %d, mood %d: this is not a bluff." % [rival_name, client_name(c), roundi(float(c.loyalty)), roundi(float(c.mood))],
		"choices": [
			{"label": "Match the terms (signing bonus %s)" % Util.fmt_money(bonus), "fn": func():
				var cl = client(cid)
				var rv = rival_by_id(rid)
				if cl == null:
					return "The moment has passed."
				if float(state.agency.cash) < float(bonus):
					return "The till cannot cover the bonus — and everyone at the table knows it."
				book(-float(bonus), "bonus", "Counter-offer: %s stays" % client_name(cl))
				cl.loyalty = clampf(float(cl.loyalty) + 10.0, 0.0, 100.0)
				change_trust(cl, 4.0)
				if rv != null:
					rv.grudge = clampf(float(rv.grudge) + 12.0, 0.0, 100.0)
				attr_gain("verhandlung", 0.3)
				press_event("Agencies", "%s outbids %s — %s stays" % [state.agency.name, rival_name, client_name(cl)])
				return "Money talks loudest when it arrives first. %s signs the amendment — and %s crosses a name off a list." % [client_name(cl), rival_name]},
			{"label": "[👁 %d %%] Appeal to everything you built together" % roundi(appeal_p * 100.0), "fn": func():
				var cl = client(cid)
				var rv = rival_by_id(rid)
				if cl == null:
					return "The moment has passed."
				if Util.chance(appeal_p):
					attr_gain("menschenkenntnis", 0.4)
					cl.loyalty = clampf(float(cl.loyalty) + 6.0, 0.0, 100.0)
					cl.mood = clampf(float(cl.mood) + 4.0, 0.0, 100.0)
					return "No numbers, just history: the first casting, the first premiere, the promise you kept. %s stays." % client_name(cl)
				attr_gain("menschenkenntnis", 0.15)
				_client_leaves_to_rival(cl, rv)
				return "The words are right, the timing is not. %s signs across town — politely, which somehow makes it worse." % client_name(cl)},
			{"label": "Let them go", "fn": func():
				var cl = client(cid)
				var rv = rival_by_id(rid)
				if cl == null:
					return "The moment has passed."
				_client_leaves_to_rival(cl, rv)
				state.agency.rep = clampi(int(state.agency.rep) - 2, 0, 100)
				return "Some fights cost more than the prize. The roster is shorter — and the town takes note."},
		]}


func _client_leaves_to_rival(c: Dictionary, rival) -> void:
	state.clients.erase(c)
	if rival != null:
		rival.clients.append(str(c.aid))
		press_event("Client moves", "%s leaves %s for %s" % [client_name(c), state.agency.name, str(rival.name)])
	log_msg("%s leaves the agency." % client_name(c), "bad")


func rival_casting_block(studio_id: String) -> float:
	for rival in state.get("rivals", []):
		if str(rival.style) == "studiotreu" and str(rival.get("studioId", "")) == studio_id and rival.clients.size():
			return clampf(8.0 + float(rival.grudge) / 12.0 - maxf(0.0, float(rival.rel)) / 20.0, 4.0, 16.0)
	return 0.0

func power_figure_for_aid(actor_id: String) -> Variant:
	for figure in state.get("powerFigures", []):
		if str(figure.aid) == actor_id:
			return figure
	return null

func power_figure_candidates() -> Array:
	return state.clients.filter(func(c):
		var actor: Dictionary = actor_by_id[c.aid]
		return Util.age_of(actor, state.year) >= 45 and (int(c.get("awards", 0)) >= 1 or float(c.fame) >= 80.0) and power_figure_for_aid(str(c.aid)) == null)

func become_power_figure(cid: int, role_s: String, keep_close: bool = false, force_independent: bool = false) -> String:
	var c = client(cid)
	if c == null or role_s not in ["director", "producer"]:
		return "The opportunity has already moved on."
	if power_figure_for_aid(str(c.aid)) != null:
		return "%s has already taken this step." % client_name(c)
	var actor_name := client_name(c)
	var fractured := force_independent or (not keep_close and (float(c.loyalty) < 30.0 or float(c.trust) < 30.0))
	var figure := {"id":next_id(), "aid":str(c.aid), "name":actor_name, "role":role_s, "startedMi":mi(), "agencyFriendly":not fractured, "rivalId":"", "credits":0}
	state.powerFigures.append(figure)
	c.flags["powerFigure"] = role_s
	var role_label := "directing" if role_s == "director" else "producing"
	if fractured:
		var rival_id := "power_%s_%d" % [str(c.aid), int(figure.id)]
		var studio_id := str(active_studios()[0].id) if active_studios().size() else ""
		var new_rival := {"id":rival_id, "name":"%s %s" % [actor_name, "Pictures" if role_s == "producer" else "Artists"], "style":"prestige", "clients":[], "grudge":65.0, "rel":-40.0, "studioId":studio_id, "foundedBy":str(c.aid)}
		state.rivals.append(new_rival)
		figure.rivalId = rival_id
		state.clients.erase(c)
		press_event("Cover story", "%s trades the screen for %s — and founds %s" % [actor_name, role_label, new_rival.name])
		log_msg("Client turns competitor: %s founds %s." % [actor_name, new_rival.name], "history")
		return "%s moves into %s and opens a house of their own. A fractured relationship has become a new rival." % [actor_name, role_label]
	change_trust(c, 8.0)
	c.loyalty = clampf(float(c.loyalty) + 8.0, 0.0, 100.0)
	press_event("Cover story", "%s moves into %s — %s stays close through the power shift" % [actor_name, role_label, state.agency.name])
	log_msg("Power shift: %s now works in %s and stays close to the house." % [actor_name, role_label], "history")
	return "%s moves into %s. At future castings, your agency remains the first address." % [actor_name, role_label]

func assign_power_figure_to_casting(casting: Dictionary, force: bool = false) -> void:
	if state.get("powerFigures", []).is_empty() or (not force and not Util.chance(0.35)):
		return
	var available: Array = state.powerFigures.filter(func(p):
		var actor: Dictionary = actor_by_id.get(str(p.aid), {})
		return not actor.is_empty() and (actor.death == null or float(actor.death) > float(state.year)))
	if available.is_empty():
		return
	var figure: Dictionary = Util.pick(available)
	var key := "director" if str(figure.role) == "director" else "producer"
	casting[key] = {"figureId":int(figure.id), "aid":str(figure.aid), "name":str(figure.name), "agencyFriendly":bool(figure.agencyFriendly), "rivalId":str(figure.rivalId)}
	if bool(figure.agencyFriendly):
		casting["agencyBoost"] = float(casting.get("agencyBoost", 0.0)) + 8.0
	elif str(figure.rivalId) != "":
		casting["powerRivalBlock"] = 8.0

func random_client(filter: Callable = Callable()) -> Variant:
	var list = state.clients if not filter.is_valid() else state.clients.filter(filter)
	return Util.pick(list) if list.size() else null

# ---------- Vertrauen, Geheimnisse & Gerüchte ----------
func change_trust(c: Dictionary, delta: float) -> void:
	# Backstory-Trait: manche gewinnen Vertrauen schneller
	if delta > 0.0:
		delta *= backstory_mod("trust_gain_mult", 1.0)
	var cap: float = clampf(float(c.get("trustCap", 100.0)), 0.0, 100.0)
	c["trust"] = clampf(float(c.get("trust", 30.0)) + delta, 0.0, cap)
# ---------- Geheimnisse & Gerüchte: siehe Autoload Scandal.gd ----------

func is_free(c: Dictionary) -> bool:
	return int(c.busyUntil) <= mi()

func eff_talent(c: Dictionary) -> float:
	return clampf(actor_by_id[c.aid].talent + c.get("talentBonus", 0.0) - (5.0 if c.flags.get("typecast", false) else 0.0), 5.0, 100.0)

func perk_costs() -> float:
	var f := Util.infl(state.year)
	var sum := 0.0
	for c in state.clients:
		for p in c.perks:
			sum += PERKS[p].cost * f
	return sum

# Fixkosten-Basis von Anzeige UND Monatsabschluss (Werte: Balance.gd).
func office_base_cost() -> int:
	var era_mult := Balance.OFFICE_EARLY_ERA_MULT if int(state.year) < Balance.OFFICE_EARLY_ERA_UNTIL else 1.0
	return roundi((Balance.OFFICE_BASE + state.clients.size() * Balance.OFFICE_PER_CLIENT) * Util.infl(state.year) * era_mult)

func overhead() -> int:
	return roundi(office_base_cost() + perk_costs())

# =====================================================================
# Finanzbuchhaltung (Ledger)
# =====================================================================
# ZENTRAL: Jede Geldbewegung läuft hier durch. Ändert die Kasse UND
# schreibt einen Ledger-Eintrag {mi, amount, cat, text}.
func book(amount: float, cat: String, text: String) -> void:
	state.agency.cash = float(state.agency.cash) + amount
	state.ledger.append({"mi": mi(), "amount": amount, "cat": cat, "text": text})
	while state.ledger.size() > LEDGER_MAX:
		state.ledger.pop_front()

# Monatsabschluss: Einzelbuchungen eines Monats zu einem Aggregat
# verdichten, damit die Historie kompakt bleibt.
func _close_ledger_month(month_mi: int) -> void:
	for m in state.ledgerMonthly:
		if int(m.mi) == month_mi:
			return
	state.ledgerMonthly.append(live_month(month_mi))
	state.ledgerMonthly.sort_custom(func(a, b): return int(a.mi) < int(b.mi))
	while state.ledgerMonthly.size() > LEDGER_MONTHS_MAX:
		state.ledgerMonthly.pop_front()

# Live-Aggregat aus den rohen Einzelbuchungen (für den laufenden Monat).
func live_month(month_mi: int) -> Dictionary:
	var inc := 0.0
	var exp := 0.0
	var by_cat := {}
	for e in state.ledger:
		if int(e.mi) != month_mi:
			continue
		var amt: float = e.amount
		if amt >= 0:
			inc += amt
		else:
			exp -= amt
		by_cat[e.cat] = by_cat.get(e.cat, 0.0) + amt
	return {"mi": month_mi, "income": inc, "expenses": exp, "byCat": by_cat}

# Durchschnittliche monatliche Ausgaben der letzten n abgeschlossenen Monate.
func avg_burn(n: int = 6) -> float:
	var months: Array = state.ledgerMonthly.slice(maxi(0, state.ledgerMonthly.size() - n))
	if months.is_empty():
		return float(overhead())
	var sum := 0.0
	for m in months:
		sum += float(m.expenses)
	return sum / months.size()

# Monate bis zur Zahlungsunfähigkeit bei aktuellem Burn (-1 = kein Burn).
func months_to_broke() -> float:
	var burn := avg_burn(6)
	if burn <= 0.0:
		return -1.0
	return float(state.agency.cash) / burn

# Größte Einnahmekategorie der letzten n Monate (inkl. laufendem Monat).
func top_income_cat(n: int = 12) -> String:
	var sums := {}
	var months: Array = state.ledgerMonthly.slice(maxi(0, state.ledgerMonthly.size() - n))
	for m in months:
		for cat in m.byCat:
			if float(m.byCat[cat]) > 0.0:
				sums[cat] = sums.get(cat, 0.0) + float(m.byCat[cat])
	var live := live_month(mi())
	for cat in live.byCat:
		if float(live.byCat[cat]) > 0.0:
			sums[cat] = sums.get(cat, 0.0) + float(live.byCat[cat])
	var best := ""
	var best_v := 0.0
	for cat in sums:
		if float(sums[cat]) > best_v:
			best_v = float(sums[cat])
			best = str(cat)
	return best

# =====================================================================
# Gefallen & Schulden
# =====================================================================
# Schnittstelle für andere Features (z. B. Gerüchte): verbraucht den
# ältesten passenden Gefallen. true = eingelöst, false = keiner vorhanden.
func consume_favor(kind: String) -> bool:
	var best = null
	for f in state.favors:
		if str(f.kind) == kind and (best == null or int(f.gainedMi) < int(best.gainedMi)):
			best = f
	if best == null:
		return false
	state.favors.erase(best)
	log_msg("Favor called in: %s (%s)." % [FAVOR_KINDS[kind].name, best["from"].get("name", "?")], "info")
	# Gefallen sind Verpflichtungen, keine Münzen (Feature 31): wer
	# einfordert, kühlt die Beziehung — und schuldet manchmal bald selbst.
	_favor_reciprocity(best)
	return true

# Ältesten Gefallen beliebiger Art verbrauchen.
func consume_any_favor() -> bool:
	if state.favors.is_empty():
		return false
	var best = state.favors[0]
	for f in state.favors:
		if int(f.gainedMi) < int(best.gainedMi):
			best = f
	state.favors.erase(best)
	log_msg("Favor called in: %s (%s)." % [FAVOR_KINDS[str(best.kind)].name, best["from"].get("name", "?")], "info")
	_favor_reciprocity(best)
	return true


# Feature 31: Eingeforderte Gefallen sind erfüllte Verpflichtungen — die
# Beziehung kühlt einen Hauch ab, und manchmal steht bald ein Gegenwunsch
# im Raum. Nichts in dieser Stadt ist umsonst.
func _favor_reciprocity(fav: Dictionary) -> void:
	Persona.touch_contact_person(fav["from"], -2.0, "You called in the favor. Fair — and noted.")
	if Util.chance(0.25):
		owe_favor(str(Util.pick(FAVOR_KINDS.keys())), fav["from"])
		log_msg("Nothing in this town is free: %s will remember this the next time THEY need something." % fav["from"].get("name", "?"), "info")

func has_favor(kind: String) -> bool:
	for f in state.favors:
		if str(f.kind) == kind:
			return true
	return false

# Eine benannte Person, die zum Gefallen passt.
func favor_contact_for(kind: String, studio_id: String = "") -> Dictionary:
	var type := "produzent"
	match kind:
		"suppressStory": type = Util.pick(["kolumnist", "journalist"])
		"scriptAccess": type = "regisseur"
		"extraAudition": type = Util.pick(["produzent", "studio"])
		"billing": type = "produzent"
		"galaInvite": type = Util.pick(["studio", "produzent"])
	if type == "studio":
		var sid := studio_id
		if sid == "":
			sid = str(Util.pick(active_studios()).id)
		return {"type": "studio", "name": str(_studio(sid).name), "studioId": sid}
	return {"type": type, "name": str(Util.pick(Data.CONTACT_PERSONS[type]))}

# Jemand schuldet DIR einen Gefallen.
func grant_favor(kind: String, from: Dictionary = {}, silent: bool = false) -> Dictionary:
	var person: Dictionary = from if not from.is_empty() else favor_contact_for(kind)
	var exp := -1
	if Util.chance(0.8):
		exp = mi() + Util.rndi(24, 36)
	var fav := {"id": next_id(), "kind": kind, "from": person, "gainedMi": mi(), "expiresMi": exp, "note": str(FAVOR_KINDS[kind].desc)}
	state.favors.append(fav)
	attr_gain("netzwerk", 0.3)
	Persona.touch_contact_person(person, 2.0)
	# Soziales Kapital (Feature 13): wer dir etwas schuldet, ist Hebel
	Network.bump_dependence(str(person.get("name", "")), 6.0)
	if not silent:
		log_msg("%s now owes you a favor: %s." % [person.get("name", "?"), FAVOR_KINDS[kind].name], "deal")
	return fav

# DU schuldest jemandem einen Gefallen.
func owe_favor(kind: String, from: Dictionary = {}) -> Dictionary:
	var person: Dictionary = from if not from.is_empty() else favor_contact_for(kind)
	var debt := {"id": next_id(), "kind": kind, "from": person, "gainedMi": mi(), "expiresMi": -1, "note": str(FAVOR_KINDS[kind].desc)}
	state.debts.append(debt)
	Persona.touch_contact_person(person, 1.0, "Helped you out — you are in their debt.")
	log_msg("You are in %s's debt (%s)." % [person.get("name", "?"), FAVOR_KINDS[kind].name], "bad")
	return debt

func remove_debt(debt_id) -> void:
	for d in state.debts.duplicate():
		if int(d.id) == int(debt_id):
			state.debts.erase(d)

# Gefallen an ein Studio weitergeben statt selbst zu nutzen → Beziehung +.
func pass_any_favor_to_studio(studio_id: String) -> bool:
	if not consume_any_favor():
		return false
	state.studioRel[studio_id] = clampi(int(state.studioRel.get(studio_id, 40)) + 7, 0, 100)
	log_msg("You pass a favor along to %s — the relationship deepens." % _studio(studio_id).name, "deal")
	return true

# extraAudition: hebt eine Rollen-Absage für einen Klienten auf.
func use_extra_audition(role: Dictionary, client_id) -> bool:
	var found := false
	for i in range(role.rejected.size() - 1, -1, -1):
		if int(role.rejected[i]) == int(client_id):
			found = true
			role.rejected.remove_at(i)
	if not found:
		return false
	if not consume_favor("extraAudition"):
		role.rejected.append(int(client_id))
		return false
	return true

# scriptAccess: deterministische Schätzung der versteckten Qualitätsbasis
# (Prestige + Script-Roll, wie in release_film). Instinkt reduziert das
# Rauschen der Einschätzung — geübte Agenten lesen Drehbücher genauer.
func script_insight(casting: Dictionary) -> int:
	var base := 35 + int(casting.prestige) * 8 + (Util.hashs(str(casting.id) + "scr") % 21)
	var noise := (Util.hashs(str(casting.id) + "noi") % 13) - 6
	var err := roundi(float(noise) * (1.0 - float(state.get("instinct", 20)) / 100.0))
	# Vertragswissen (Feature 6): das Klausel-Radar liest Drehbücher fast exakt
	if Mogul.has_ability("clause_radar"):
		err = roundi(float(err) * 0.4)
	return clampi(base + err, 5, 100)

# Verfall: abgelaufene Gefallen im Monatstakt entfernen.
func _expire_favors() -> void:
	for f in state.favors.duplicate():
		if int(f.expiresMi) >= 0 and mi() > int(f.expiresMi):
			state.favors.erase(f)
			log_msg("Expired: %s is no longer willing to talk (%s)." % [f["from"].get("name", "?"), FAVOR_KINDS.get(str(f.kind), {}).get("name", str(f.kind))], "info")


# =====================================================================
# Verhandlung v2: verdeckte Forderungen & Gegenvorschläge
# =====================================================================
func actor_profile(actor: Dictionary, fame: float) -> Dictionary:
	var money: float = 20.0 + actor.ego * 0.5 + (15.0 if fame > 70 else 0.0)
	var prestige: float = actor.talent * 0.7
	var security: float = clampf(85.0 - fame, 5.0, 60.0) + (15.0 if Util.age_of(actor, state.year) > 50 else 0.0)
	var sum := money + prestige + security
	var top := "money"
	if prestige >= money and prestige >= security:
		top = "prestige"
	elif security > money and security > prestige:
		top = "security"
	return {"money": money / sum, "prestige": prestige / sum, "security": security / sum, "top": top}

func actor_demands(actor: Dictionary, fame: float, ask: float, profile: Dictionary) -> Dictionary:
	var perks_by_trait := {"money": ["travel", "assistant"], "prestige": ["script", "coach"], "security": ["pr", "assistant"]}
	var traits := ["money", "prestige", "security"]
	traits.sort_custom(func(a, b): return profile[a] > profile[b])
	var wanted: Array = [Util.pick(perks_by_trait[traits[0]])]
	var second = Util.pick(perks_by_trait[traits[1]])
	if not wanted.has(second) and Util.chance(0.7):
		wanted.append(second)
	var promise = null
	if profile.top == "prestige" and fame < 75 and Util.chance(0.5):
		promise = "prestige"
	if profile.top == "security" and Util.chance(0.5):
		promise = "lead12"
	if actor.talent > 88 and actor.ego > 75 and Util.chance(0.4):
		promise = "oscar"
	var years := 5
	if profile.top == "security":
		years = 7
	elif profile.top == "money":
		years = 3
	return {
		"commission": clampi(roundi(16.0 - fame / 10.0 - actor.ego / 20.0), 5, 14),
		"bonus": roundi(ask * (0.04 + actor.ego / 500.0 + profile.money * 0.12)),
		"years": years, "perks": wanted, "promise": promise,
	}

func start_negotiation(actor_id: String) -> Dictionary:
	var actor: Dictionary = actor_by_id[actor_id]
	var fame := Util.fame_at(actor, state.year)
	var req := required_rep(fame)
	var owner = rival_for_actor(actor_id)
	var poach_req := req + (10 if owner != null else 0)
	if state.agency.rep < poach_req:
		# Stale-Schutz: eine gescheiterte Anbahnung darf keine alte Verhandlung
		# zurücklassen — sonst signt ein folgender sign_client den Falschen.
		nego = null
		return {"locked": true, "actor": actor, "fame": fame, "reqRep": poach_req, "rivalName": str(owner.name) if owner != null else ""}
	var ask := Util.ask_fee(fame, state.year)
	var profile := actor_profile(actor, fame)
	nego = {
		"actor": actor, "fame": fame, "ask": ask, "profile": profile,
		"demands": actor_demands(actor, fame, ask, profile),
		"round": 1, "maxRounds": 4, "counter": null, "done": false, "locked": false,
		"rivalId": str(owner.id) if owner != null else "",
	}
	return nego

func identity_offer_modifier(actor: Dictionary) -> float:
	if float(actor.talent) >= 88.0:
		return (identity_strength("kuenstlerisch") + identity_strength("klientenorientiert")) * 4.5
	return (identity_strength("kommerziell") + identity_strength("studiotreu")) * 2.5

func evaluate_offer(offer: Dictionary) -> float:
	var p: Dictionary = nego.profile
	var d: Dictionary = nego.demands
	var rep: float = state.agency.rep
	var trust: float = 0.35 + rep / 140.0
	var bonus_factor: float = clampf(offer.bonus / (nego.ask * 0.12), 0.0, 1.3)
	var money_raw: float = (18.0 - offer.commission) * 3.5 + bonus_factor * 50.0
	var promise_raw := 0.0
	if offer.promise == "lead12":
		promise_raw = 38.0 * (p.security * 0.6 + p.prestige * 0.4) * 3.0
	elif offer.promise == "prestige":
		promise_raw = 38.0 * p.prestige * 3.0
	elif offer.promise == "oscar":
		promise_raw = 48.0 * p.prestige * 3.0
	if d.promise != null and offer.promise == d.promise:
		promise_raw += 10.0
	var perks_score := 0.0
	for pk in offer.perks:
		perks_score += 13.0 if d.perks.has(pk) else 4.0
	var years_score: float = -absf(offer.years - d.years) * 2.5
	var standing: float = (rep - nego.fame * 0.55) * 0.9
	# Klauseln wirken je nach Star-Profil: Künstler wollen Kreativ-Veto,
	# Sicherheitsorientierte Eskalatoren, Kommerzielle Gewinnbeteiligung.
	var clause_score := 0.0
	for cl in offer.get("clauses", []):
		match str(cl):
			"creativeApproval": clause_score += 9.0 * p.prestige * 3.0 - (4.0 if p.top == "money" else 0.0)
			"escalator": clause_score += 8.0 * p.security * 2.5
			"profitShare": clause_score += 7.0 * p.money * 2.0 - (6.0 if p.top == "security" else 0.0)
			"endorsement": clause_score += 5.0 * p.money * 2.0
			"likenessRights": clause_score += 4.0
			"sequelOption": clause_score -= 8.0 * p.prestige * 2.0
			"moralClause": clause_score -= 7.0
	return money_raw * p.money * 2.6 + promise_raw * trust + perks_score + years_score + standing + clause_score + identity_offer_modifier(nego.actor) - (nego.round - 1) * 3.0 + backstory_mod("nego_bonus", 0.0)

func mood_label(score: float) -> Array:
	if score >= 65.0: return ["thrilled", "pos"]
	if score >= 50.0: return ["interested", ""]
	if score >= 34.0: return ["weighing it", ""]
	return ["dismissive", "neg"]

func negotiation_hint() -> String:
	var hints := {
		"money": ["“Pretty words don't pay for a villa in Bel Air, my friend.”", "“Let's talk numbers. Everything else is small talk.”"],
		"prestige": ["“I want roles people still talk about in thirty years.”", "“Money spoils. Art endures. What are you offering me artistically?”"],
		"security": ["“I need to know I'll still be working next year. Can you guarantee that?”", "“Don't promise me anything you can't keep.”"],
	}
	return "%s: %s" % [nego.actor.name, Util.pick(hints[nego.profile.top])]

func build_counter(offer: Dictionary) -> Variant:
	if nego == null:
		return null
	var d: Dictionary = nego.demands
	var perks: Array = offer.perks.duplicate()
	for pk in d.perks:
		if not perks.has(pk):
			perks.append(pk)
	var counter := {
		"commission": mini(int(offer.commission), int(d.commission)),
		"bonus": maxi(int(offer.bonus), roundi(d.bonus * 0.85 / 1000.0) * 1000),
		"years": d.years, "perks": perks,
		"promise": offer.promise if offer.promise != null else d.promise,
	}
	var parts: Array = []
	if counter.commission < offer.commission:
		parts.append("%d%% commission — not a point more" % counter.commission)
	if counter.bonus > offer.bonus:
		parts.append("%s signing money up front" % Util.fmt_money(counter.bonus))
	if counter.years != offer.years:
		parts.append("a %d-year term" % counter.years)
	var new_perks = counter.perks.filter(func(pk): return not offer.perks.has(pk))
	if new_perks.size():
		parts.append(", ".join(new_perks.map(func(pk): return PERKS[pk].name)))
	if counter.promise != null and counter.promise != offer.promise:
		parts.append("your word on %s" % PROMISES[counter.promise].label)
	if parts.is_empty():
		return null
	counter["text"] = "“My offer: %s. Then I'll sign today.”" % ", ".join(parts)
	return counter

func sign_client(terms: Dictionary) -> Dictionary:
	if nego == null:
		return {"accepted": false}
	if terms.bonus > state.agency.cash:
		return {"broke": true}
	if int(terms.bonus) > 0:
		book(-float(terms.bonus), "bonus", "Signing-Bonus: %s" % nego.actor.name)
	var actor: Dictionary = nego.actor
	var c := {
		"id": next_id(), "aid": actor.id, "fame": float(nego.fame), "heat": 0.0,
		"loyalty": float(Util.rndi(45, 60) + (6 if terms.bonus > 0 else 0)), "mood": 60.0, "exhaustion": 0.0,
		"weightKg": float(Util.body_of(actor).weight), "weightTrend": 0.0,
		"commission": int(terms.commission), "perks": terms.get("perks", []),
		"years": int(terms.years), "contractEnd": mi() + int(terms.years) * 12,
		"promises": [], "busyUntil": 0, "films": [], "flags": {}, "talentBonus": 0.0,
		"campaign": 0.0, "awards": 0,
		"dna": CareerDNA.initial_dna(actor),
		"signedAt": mi(),
		"trust": float(Util.rndi(28, 34)), "trustCap": 100.0, "secrets": [], "secretThresholds": [],
		"narrative": {}, "fameHistory": [], "dnaHistory": [],
		"clauses": [], "exclusiveStudio": "",
	}
	c.fameHistory.append({"mi":mi(), "v":float(c.fame)})
	c.dnaHistory.append({"mi":mi(), "romantik":float(c.dna.romantik), "popular":float(c.dna.popular), "verlass":float(c.dna.verlass), "unikat":float(c.dna.unikat), "familie":float(c.dna.familie)})
	if terms.get("promise") != null:
		c.promises.append({"type": terms.promise, "label": PROMISES[terms.promise].label, "due": mi() + int(PROMISES[terms.promise].months), "fulfilled": false, "broken": false})
	# Vertragsklauseln (Feature 8): era-verfügbar gefiltert auf den Klienten übernehmen
	for cl in terms.get("clauses", []):
		if clause_available(str(cl)) and not c.clauses.has(str(cl)):
			c.clauses.append(str(cl))
	state.clients.append(c)
	# Instinkt-Prognose (Feature 6b): Signing eines Noch-nicht-Stars anbieten
	if int(nego.fame) < 40:
		state["pendingStarPrediction"] = int(c.id)
	var rival_id := str(nego.get("rivalId", ""))
	if rival_id != "":
		for rival in state.rivals:
			if str(rival.id) == rival_id:
				rival.clients.erase(str(actor.id))
				rival.grudge = clampf(float(rival.grudge) + 25.0, 0.0, 100.0)
				press_event("Agencies", "%s snatches %s away from %s" % [state.agency.name, actor.name, rival.name])
				break
	else:
		press_event("Client moves", "%s signs with %s" % [actor.name, state.agency.name])
	state.agency.rep = clampi(int(state.agency.rep) + roundi(nego.fame / 22.0), 0, 100)
	attr_gain("verhandlung", 0.5)
	Mogul.grant_xp("negotiation", 3.0, "Signed a client")
	Mogul.grant_xp("people", 1.0, "Signed a client")
	Network.memoir("%s signs with the agency — %d years, %d%% commission." % [actor.name, int(terms.years), int(terms.commission)], [str(actor.name)])
	log_msg("%s signs for %d years (%d%% commission%s%s)." % [actor.name, terms.years, terms.commission,
		(", bonus " + Util.fmt_money(terms.bonus)) if terms.bonus > 0 else "",
		", with a promise" if terms.get("promise") != null else ""], "deal")
	nego.done = true
	return {"accepted": true, "client": c}

func make_offer(offer: Dictionary) -> Dictionary:
	# Menschenkenntnis (Feature 6): wer Bluffs liest, erlebt weniger Launen-Rauschen
	var noise := 3.0 if Mogul.has_ability("cold_read") else 9.0
	var score := evaluate_offer(offer) + Util.rndf(-noise, noise)
	if score >= 58.0:
		return sign_client(offer)
	Mogul.grant_xp("negotiation", 1.0, "A rejected offer teaches")
	Mogul.grant_xp("people", 0.5, "Read the room, badly")
	nego.round = int(nego.round) + 1
	nego.counter = build_counter(offer) if score >= 34.0 else null
	if nego.round > nego.maxRounds:
		nego.done = true
		log_msg("%s declines for good." % nego.actor.name, "bad")
		return {"accepted": false, "final": true, "hint": negotiation_hint()}
	return {"accepted": false, "final": false, "hint": negotiation_hint(), "counter": nego.counter}

func accept_counter() -> Dictionary:
	return sign_client(nego.counter)

# =====================================================================
# Castings & Studio-Verhandlung
# =====================================================================
func genre_weights() -> Dictionary:
	var y = state.year
	var w := {"drama":20.0,"comedy":16.0,"romance":12.0,"thriller":10.0,"crime":10.0,"adventure":8.0,"action":6.0,"horror":5.0}
	w["western"] = 12.0 if y < 1975 else 1.0
	w["musical"] = 10.0 if y < 1970 else 2.0
	w["scifi"] = 1.0 if y < 1950 else (5.0 if y < 1977 else 12.0)
	if y >= 1980:
		w["action"] = 16.0
		w["romance"] = 8.0
	return w

func pick_genre() -> String:
	var w := genre_weights()
	var total := 0.0
	for k in w:
		total += w[k]
	var r := randf() * total
	for k in w:
		r -= w[k]
		if r <= 0:
			return k
	return "drama"

func make_title(genre: String) -> String:
	var t: Dictionary = Data.TITLES[genre]
	return "%s %s" % [Util.pick(t.a), Util.pick(t.b)]

func project_title(genre: String) -> String:
	var y = state.year
	var used: Array = state.usedTitles
	var cand = Data.REAL_TITLES.filter(func(t): return absf(t.y - y) <= 4 and t.g.has(genre) and not used.has(t.t))
	if cand.size() and Util.chance(0.8):
		var t = Util.pick(cand)
		used.append(t.t)
		return t.t
	return make_title(genre)

func spawn_castings(count: int) -> void:
	for i in count:
		var cs := _make_casting()
		# Chancen aus dem Netzwerk (Feature 20): ein Teil der Projekte wird
		# nie öffentlich ausgeschrieben — nur ein guter Kontakt bringt sie dir.
		if i > 0 and Util.chance(0.45):
			cs["hidden"] = true
			cs["netSource"] = Util.pick(["produzent", "regisseur", "studio"])
		state.castings.append(cs)

# Einzelnes Casting erzeugen (auch von der Coverage genutzt — die hält es
# einen Monat verdeckt, bevor es regulär auf dem Markt erscheint).
func _make_casting() -> Dictionary:
	var y = state.year
	var studio = Util.pick(active_studios())
	var genre := pick_genre()
	var prestige := Util.rndi(1, 3) if studio.style != "commercial" else Util.rndi(0, 2)
	if genre == "drama" and Util.chance(0.4):
		prestige = mini(3, prestige + 1)
	var roles: Array = []
	var lead_gender = "m" if Util.chance(0.5) else "f"
	roles.append(_mk_role("lead", lead_gender, prestige, y))
	if Util.chance(0.6):
		roles.append(_mk_role("lead", "f" if lead_gender == "m" else "m", prestige, y))
	roles.append(_mk_role("support", "m" if Util.chance(0.5) else "f", prestige, y))
	if Util.chance(0.4):
		roles.append(_mk_role("support", "m" if Util.chance(0.5) else "f", prestige, y))
	var fee_sum := 0.0
	for r in roles:
		fee_sum += r.fee
	var casting := {
		"id": next_id(), "studioId": studio.id, "title": project_title(genre), "genre": genre,
		"prestige": prestige,
		"budget": roundi(fee_sum * Util.rndf(3.0, 4.5) + 400000.0 * Util.infl(y) * Util.rndf(0.6, 1.4) * (1.0 + prestige * 0.3)),
		"deadline": Util.rndi(8, 12), "roles": roles, "qualityMod": 0.0,
	}
	# Seltene offene Einladung auch für eine Nebenrolle.
	casting["auditionSupport"] = Util.chance(0.12)
	casting["dreamPair"] = Util.chance(0.08)
	assign_power_figure_to_casting(casting)
	return casting

func _mk_role(type: String, gender: String, prestige: int, y: float) -> Dictionary:
	var min_fame := Util.rndi(25, 55 + prestige * 10) if type == "lead" else Util.rndi(10, 35)
	var age_min := Util.rndi(18, 45)
	return {
		"type": type, "gender": gender, "minFame": min_fame,
		"ageMin": age_min, "ageMax": age_min + Util.rndi(12, 30),
		"fee": roundi(Util.ask_fee(min_fame + 12, y) * (1.0 if type == "lead" else 0.35)),
		"filled": null, "rejected": [],
	}

func fit_score(casting: Dictionary, role: Dictionary, c: Dictionary) -> int:
	var actor: Dictionary = actor_by_id[c.aid]
	var y = state.year
	var age := Util.age_of(actor, y)
	var fit := 30.0
	if actor.genres.has(casting.genre):
		fit += 22.0 + (5.0 if c.perks.has("script") else 0.0)
	fit += (Util.attrs(actor).charisma - 50.0) / 15.0
	fit += clampf((c.fame - role.minFame) * 0.7, -25.0, 18.0)
	fit += c.heat * 2.0
	fit += float(state.studioRel[casting.studioId]) / 6.0
	fit += float(casting.get("agencyBoost", 0.0))
	fit -= float(casting.get("powerRivalBlock", 0.0))
	fit -= maxf(0.0, (c.exhaustion - 50.0) / 2.5)
	# Erweiterungspunkt: Körpergewicht wirkt bewusst noch nicht auf die Besetzung.
	# Karriere-DNA: passt das öffentliche Bild zur Rolle?
	fit += CareerDNA.dna_fit(c, casting.genre, studio_style(casting.studioId))
	var style := studio_style(casting.studioId)
	if style == "prestige" or style == "indie":
		fit += (identity_strength("kuenstlerisch") + identity_strength("klientenorientiert")) * (4.5 if eff_talent(c) >= 88.0 else 2.5)
	else:
		fit += (identity_strength("studiotreu") + identity_strength("kommerziell")) * 3.5
	fit -= rival_casting_block(str(casting.studioId))
	fit -= Scandal.rumor_fit_penalty(c)
	# Tonfilm-Umbruch: Studios casten 1928–1934 keine fragilen Stimmen
	if voice_at_risk(c):
		fit -= Balance.VOICE_FIT_MALUS
	# Power-Couple: Studios lieben es, das Traumpaar gemeinsam zu plakatieren
	for pr_role in casting.roles:
		if pr_role.filled != null and pr_role.filled.get("clientId") != null:
			var partner = client(pr_role.filled.clientId)
			if partner != null and str(c.flags.get("coupleWith", "")) == str(partner.aid):
				fit += Balance.PAIR_COUPLE_FIT
				break
	# Weekly Planner: „Vorbereitung“ gibt dem nächsten Pitch einen einmaligen Bonus
	if float(c.flags.get("prepFit", 0.0)) > 0.0:
		fit += float(c.flags.prepFit)
	# Fernseh-Ära: TV-Gesichter verlieren bei Prestige-Kino an Standing (Feature 14)
	if int(state.year) >= 1948 and int(state.year) <= 1965 and c.flags.get("tvIncome") != null and int(c.flags.tvIncome.months) > 0 and int(casting.prestige) >= 2:
		fit -= 5.0
	# Studiosystem-Ära: Exklusivklienten sind beim eigenen Studio stärker (Feature 14)
	if str(c.get("exclusiveStudio", "")) != "" and str(c.exclusiveStudio) == str(casting.studioId):
		fit += 6.0
	if age < role.ageMin:
		fit -= (role.ageMin - age) * 2.5
	if age > role.ageMax:
		fit -= (age - role.ageMax) * 2.5
	return clampi(roundi(fit), 2, 97)

func eligible_clients(casting: Dictionary, role: Dictionary) -> Array:
	var out: Array = []
	for c in state.clients:
		var a: Dictionary = actor_by_id[c.aid]
		if a.g != role.gender or not is_free(c):
			continue
		# Studiosystem: Exklusivklienten dürfen nur für ihr Studio arbeiten
		if str(c.get("exclusiveStudio", "")) != "" and str(c.exclusiveStudio) != str(casting.studioId):
			continue
		var taken := false
		var feud_block := false
		for r in casting.roles:
			if r.filled != null and r.filled.get("clientId") != null:
				if int(r.filled.clientId) == int(c.id):
					taken = true
				# Feud im Roster: die beiden lassen sich nicht zusammen besetzen
				var other = client(r.filled.clientId)
				if other != null and (str(c.flags.get("feudWith", "")) == str(other.aid) or str(other.flags.get("feudWith", "")) == str(c.aid)):
					feud_block = true
		if taken or feud_block:
			continue
		var fit := fit_score(casting, role, c)
		# Drehbuch-Mitsprache (Perk) und Kreativ-Veto (Klausel) lehnen schlechte Rollen ab
		if (c.perks.has("script") or c.get("clauses", []).has("creativeApproval")) and fit < 35:
			continue
		out.append({"c": c, "fit": fit, "estFee": role_fee_for(casting, role, c),
			"dna": roundi(CareerDNA.dna_fit(c, casting.genre, studio_style(casting.studioId)))})
	out.sort_custom(func(x, y2): return x.fit > y2.fit)
	return out

func role_fee_for(_cs: Dictionary, role: Dictionary, c: Dictionary) -> int:
	var ask: float = Util.ask_fee(c.fame, state.year) * (1.0 if role.type == "lead" else 0.35) * (1.0 + int(c.get("awards", 0)) * 0.08)
	# Gagen-Eskalator-Klausel: jede weitere Zusammenarbeit wird teurer
	if c.get("clauses", []).has("escalator"):
		ask *= 1.15
	return roundi(clampf(ask, role.fee * 0.6, role.fee * 2.2))

func submit_pitch(casting_id, role_idx: int, client_id) -> Dictionary:
	var casting = _casting(casting_id)
	var role: Dictionary = casting.roles[role_idx]
	var c = client(client_id)
	var fit := fit_score(casting, role, c)
	var p: float = clampf(fit / 100.0 + 0.08, 0.05, 0.95)
	# Gagen-Eskalator: Studios zögern bei teuren Wiederbesetzungen
	if c.get("clauses", []).has("escalator"):
		p = clampf(p - 0.06, 0.05, 0.95)
	# Hinterzimmer-Absprachen (Feature 8): Boni, goldene Zusagen — und Wortbruch
	var backroom_mods: Dictionary = Mogul.pitch_mods(casting)
	p = clampf(p + float(backroom_mods.get("bonus", 0.0)), 0.05, 0.98)
	# Glaubwürdigkeit (Feature 13): ein respektierter Studio-Kontakt öffnet Ohren
	p = clampf(p + Network.pitch_bonus(casting), 0.05, 0.98)
	if bool(backroom_mods.get("golden", false)):
		p = 1.0
	# Planner-„Vorbereitung“ ist einmalig — jetzt wird sie verbraucht
	if c.flags.has("prepFit"):
		c.flags.erase("prepFit")
	if Util.chance(p):
		pitch_ctx = {"casting": casting, "roleIdx": role_idx, "role": role, "client": c, "fee": role_fee_for(casting, role, c), "haggled": false}
		# Alternativen für die Instinkt-Prognose „Wer passt besser?“ merken (Feature 6c)
		var alts: Array = []
		for e in eligible_clients(casting, role):
			if int(e.c.id) != int(client_id):
				alts.append(int(e.c.id))
		pitch_ctx["alts"] = alts.slice(0, 2)
		if needs_table(casting, role):
			pitch_ctx["table"] = true
		return {"success": true, "fee": pitch_ctx.fee}
	role.rejected.append(int(client_id))
	state.studioRel[casting.studioId] = clampi(int(state.studioRel[casting.studioId]) - 1, 0, 100)
	Mogul.grant_xp("talent", 1.0, "A rejection teaches too")
	return {"success": false}

func _casting(cid) -> Variant:
	for cs in state.castings:
		if int(cs.id) == int(cid):
			return cs
	return null

func close_deal(fee: float, extra_log: String = "", clauses: Array = [], billing: int = 1) -> void:
	var casting: Dictionary = pitch_ctx.casting
	var role: Dictionary = pitch_ctx.role
	var c: Dictionary = pitch_ctx.client
	# Gewinnbeteiligung drückt die Fixgage (Feature 8) — Kleingedrucktes-Profis
	# formulieren die Klausel selbst und geben weniger Fixgage ab (Feature 6)
	if clauses.has("profitShare"):
		fee = roundi(fee * (0.88 if Mogul.has_ability("fine_print") else 0.8))
	role.filled = {"clientId": int(c.id), "fee": roundi(fee), "billing": billing}
	if clauses.size():
		role.filled["clauses"] = clauses.duplicate()
	c.busyUntil = mi() + ceili(float(casting.deadline) / 4.0)
	# Studiosystem-Ära: erste Zusammenarbeit bindet den Klienten exklusiv (Feature 14)
	if int(state.year) < 1948 and str(c.get("exclusiveStudio", "")) == "":
		c["exclusiveStudio"] = str(casting.studioId)
		log_msg("%s is now bound exclusively to %s — better fees there, no castings anywhere else." % [client_name(c), _studio(str(casting.studioId)).name], "history")
	log_msg("Deal: %s plays %s in “%s” for %s. Commission: %s.%s" % [client_name(c),
		"the lead" if role.type == "lead" else "a supporting role", casting.title,
		Util.fmt_money(fee), Util.fmt_money(fee * c.commission / 100.0), extra_log], "deal")
	check_promises_on_deal(c, casting, role)
	press_event("Casting", "%s takes %s in “%s” for %s" % [client_name(c), "the lead" if role.type == "lead" else "a supporting role", casting.title, _studio(str(casting.studioId)).name])
	if int(casting.prestige) >= 2:
		record_identity("kuenstlerisch", 0.35)
	elif studio_style(str(casting.studioId)) == "commercial":
		record_identity("kommerziell", 0.35)
	c.mood = clampf(c.mood + 8.0, 0.0, 100.0)
	if Util.chance(0.18):
		var kind_s: String = Util.pick(["extraAudition", "scriptAccess", "billing"])
		grant_favor(kind_s, favor_contact_for(kind_s, str(casting.studioId)))
	Mogul.grant_xp("negotiation", 2.0, "Closed a deal")
	if clauses.size():
		Mogul.grant_xp("contracts", 1.0, "Negotiated clauses")
	# Interessenkonflikt (Feature 7): eigener Klient in einem selbst finanzierten Film
	Mogul.on_deal_closed(casting)
	pitch_ctx = null

func accept_offer() -> void:
	close_deal(pitch_ctx.fee, "", pitch_ctx.get("offerClauses", []))

func haggle() -> Dictionary:
	var rel: float = state.studioRel[pitch_ctx.casting.studioId]
	var surplus: float = pitch_ctx.client.fame - pitch_ctx.role.minFame
	var p: float = clampf(0.35 + surplus / 120.0 + pitch_ctx.client.heat / 50.0 + rel / 250.0 + int(pitch_ctx.client.get("awards", 0)) * 0.06, 0.1, 0.88)
	# Verhandlungs-Fähigkeiten (Feature 6): der Closer trifft öfter
	if Mogul.has_ability("closer"):
		p = clampf(p + 0.07, 0.1, 0.92)
	pitch_ctx.haggled = true
	if Util.chance(p):
		# Spezialisierung (Feature 42): der Meisterverhandler holt mehr heraus
		pitch_ctx.fee = roundi(pitch_ctx.fee * (Balance.HAGGLE_MASTER_MULT if Mogul.has_ability("master_negotiator") else Balance.HAGGLE_MULT))
		attr_gain("verhandlung", 0.4)
		return {"success": true, "fee": pitch_ctx.fee}
	Mogul.grant_xp("negotiation", 1.0, "A failed haggle teaches")
	# „Second pass“: wer weiß, wann Schluss ist, sprengt selten den Deal
	if Util.chance(0.2 if Mogul.has_ability("second_pass") else 0.45):
		state.studioRel[pitch_ctx.casting.studioId] = clampi(int(rel) - 6, 0, 100)
		log_msg("Overplayed the hand: “%s” — the studio walks away from the talks with %s." % [pitch_ctx.casting.title, client_name(pitch_ctx.client)], "bad")
		pitch_ctx = null
		return {"success": false, "lost": true}
	return {"success": false, "lost": false, "fee": pitch_ctx.fee}

func package_options() -> Array:
	if pitch_ctx == null or state.agency.rep < 25:
		return []
	var out: Array = []
	var casting: Dictionary = pitch_ctx.casting
	for idx in casting.roles.size():
		var r: Dictionary = casting.roles[idx]
		if r.type == "support" and r.filled == null and idx != int(pitch_ctx.roleIdx):
			for e in eligible_clients(casting, r):
				if int(e.c.id) != int(pitch_ctx.client.id):
					var entry = e.duplicate()
					entry["roleIdx"] = idx
					entry["role"] = r
					out.append(entry)
	out.sort_custom(func(x, y2): return x.fit > y2.fit)
	return out.slice(0, 6)

func try_package(support_role_idx: int, second_client_id) -> Dictionary:
	var casting: Dictionary = pitch_ctx.casting
	var role2: Dictionary = casting.roles[support_role_idx]
	var c2 = client(second_client_id)
	var rel: float = state.studioRel[casting.studioId]
	var p: float = clampf(0.4 + state.agency.rep / 180.0 + fit_score(casting, role2, c2) / 300.0, 0.15, 0.9)
	if Util.chance(p):
		var fee1 := roundi(pitch_ctx.fee * Balance.PACKAGE_FEE_MULT)
		var fee2 := roundi(role_fee_for(casting, role2, c2) * Balance.PACKAGE_FEE_MULT)
		close_deal(fee1, " (package deal)")
		role2.filled = {"clientId": int(c2.id), "fee": fee2}
		c2.busyUntil = mi() + ceili(float(casting.deadline) / 4.0)
		c2.mood = clampf(c2.mood + 8.0, 0.0, 100.0)
		check_promises_on_deal(c2, casting, role2)
		attr_gain("verhandlung", 0.4)
		log_msg("Package deal sealed: %s also takes a supporting role in “%s” for %s." % [client_name(c2), casting.title, Util.fmt_money(fee2)], "deal")
		state.agency.rep = clampi(int(state.agency.rep) + 2, 0, 100)
		grant_favor("extraAudition", favor_contact_for("extraAudition", str(casting.studioId)))
		if Util.chance(0.4):
			var kind2: String = Util.pick(["billing", "scriptAccess"])
			grant_favor(kind2, favor_contact_for(kind2, str(casting.studioId)))
		return {"success": true}
	state.studioRel[casting.studioId] = clampi(int(rel) - 4, 0, 100)
	return {"success": false}

# Versprechen werden UNMITTELBAR bei der Unterschrift geprüft — egal ob der
# Deal über ein Casting, einen Package-Deal oder einen Sofort-Deal zustande kam.
func check_promises_on_deal(c: Dictionary, casting: Dictionary, role: Dictionary) -> void:
	for pr in c.promises:
		if pr.fulfilled or pr.get("broken", false):
			continue
		if pr.type == "lead12" and role.type == "lead":
			fulfill_promise(c, pr)
		if pr.type == "prestige" and int(casting.prestige) >= 2:
			fulfill_promise(c, pr)
	# Karrierebrett: jede Deal-Art (Casting, Package, Sofort-Deal) läuft hier
	# hindurch — die geplante Rollenfolge wird an derselben Stelle abgeglichen.
	check_board_on_deal(c, casting, role)

func fulfill_promise(c: Dictionary, pr: Dictionary) -> void:
	pr.fulfilled = true
	c.loyalty = clampf(c.loyalty + Balance.PROMISE_KEPT_LOYALTY, 0.0, 100.0)
	change_trust(c, Balance.PROMISE_KEPT_TRUST)
	c.mood = clampf(c.mood + Balance.PROMISE_KEPT_MOOD, 0.0, 100.0)
	state.agency.rep = clampi(int(state.agency.rep) + Balance.PROMISE_KEPT_REP, 0, 100)
	log_msg("Promise kept: %s — %s. Loyalty rises sharply." % [client_name(c), pr.label], "deal")

# ---------- Comeback: das späte Karriere-Kunststück ----------
# Ein Star nach dem Zenit bekommt EIN gezieltes Prestige-Projekt samt
# Kampagne. Zündet es, ist er zurück im Gespräch — scheitert es, ist
# die Geschichte auserzählt (ein Versuch pro Klient).
func comeback_possible(c: Dictionary) -> bool:
	var actor: Dictionary = actor_by_id.get(str(c.get("aid", "")), {})
	if actor.is_empty() or not is_free(c):
		return false
	if c.flags.get("comebackDone", false) or c.flags.get("comebackActive", false):
		return false
	if float(state.year) <= float(actor.peak) or Util.age_of(actor, state.year) > 78:
		return false
	return float(c.fame) < minf(55.0, float(actor.peakFame) * 0.6)

func comeback_cost() -> int:
	return roundi(Balance.COMEBACK_CAMPAIGN_COST * Util.infl(state.year))

func launch_comeback(cid) -> String:
	var c = client(cid)
	if c == null or not comeback_possible(c):
		return "The moment for this has passed."
	var cost := comeback_cost()
	if float(state.agency.cash) < float(cost):
		return "A comeback needs a campaign — and the till cannot cover %s." % Util.fmt_money(cost)
	book(-float(cost), "pr_recht", "Comeback campaign: %s" % client_name(c))
	var res: Dictionary = quick_production(c, {"prestige": 3, "qualityMod": 6.0})
	res.prod["comeback"] = true
	c.flags["comebackActive"] = true
	record_identity("klientenorientiert", 1.0)
	press_event("Careers", "One more picture: %s stakes everything on the return of %s" % [state.agency.name, client_name(c)])
	log_msg("Comeback project: “%s” — everything rides on this one." % str(res.prod.title), "history")
	return "The town loves nothing more than a second act. “%s” goes into production — with a campaign to match." % str(res.prod.title)

func quick_production(c: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var actor: Dictionary = actor_by_id[c.aid]
	var genre: String = opts.get("genre", Util.pick(actor.genres) if Util.chance(0.7) else pick_genre())
	var studio: Dictionary = opts.get("studio", Util.pick(active_studios()))
	var role_type: String = opts.get("roleType", "lead")
	var fee := roundi(Util.ask_fee(c.fame, state.year) * (1.0 if role_type == "lead" else 0.35) * opts.get("feeMult", 1.0))
	# Streaming-Ära (2015+): kürzere Produktionszeiten (Feature 14)
	var months := Util.rndi(3, 5) if int(state.year) >= 2015 else Util.rndi(4, 6)
	var prod := {
		"id": next_id(), "studioId": studio.id, "title": project_title(genre), "genre": genre,
		"prestige": opts.get("prestige", Util.rndi(1, 2)),
		"budget": roundi(fee * Util.rndf(3.0, 4.5) + 300000.0 * Util.infl(state.year)),
		"weeksLeft": months * 4, "qualityMod": opts.get("qualityMod", 0.0),
		"roles": [{"type": role_type, "gender": actor.g, "minFame": 30, "ageMin": 18, "ageMax": 99, "fee": fee, "filled": {"clientId": int(c.id), "fee": fee, "billing": 1}, "rejected": []}],
	}
	_init_production_uncertainty(prod)
	state.productions.append(prod)
	var income := roundi(fee * c.commission / 100.0)
	book(float(income), "provision", "Commission, instant deal: %s (“%s”)" % [client_name(c), prod.title])
	c.busyUntil = mi() + months
	# Studiosystem-Ära: Exklusivbindung auch bei Sofort-Deals (Feature 14)
	if int(state.year) < 1948 and str(c.get("exclusiveStudio", "")) == "":
		c["exclusiveStudio"] = str(studio.id)
		log_msg("%s is now bound exclusively to %s — better fees there, no castings anywhere else." % [client_name(c), studio.name], "history")
	change_trust(c, 1.5)
	# Auch Sofort-Deals zählen unmittelbar für Versprechen (Hauptrolle/Prestige)
	check_promises_on_deal(c, prod, prod.roles[0])
	press_event("Casting", "%s signs for %s in “%s” (%s)" % [client_name(c), "the lead" if role_type == "lead" else "a supporting role", prod.title, studio.name])
	if int(prod.prestige) >= 2:
		record_identity("kuenstlerisch", 0.35)
	elif studio_style(str(prod.studioId)) == "commercial":
		record_identity("kommerziell", 0.35)
	log_msg("Instant deal: %s in “%s” (%s) — %s fee, %s commission." % [client_name(c), prod.title, studio.name, Util.fmt_money(fee), Util.fmt_money(income)], "deal")
	return {"fee": fee, "income": income, "title": prod.title, "studioName": studio.name, "prod": prod}

# =====================================================================
# Monatswechsel
# =====================================================================
# Kompatibilitäts-Helfer (Tests/Hooks): simuliert Wochen bis zum Monatswechsel.
func end_month() -> Array:
	var events: Array = []
	var m := int(state.month)
	var guard := 0
	while int(state.month) == m and not state.over and guard < 5:
		events.append_array(end_week())
		guard += 1
	return events

# ---------- Wochen-Zug ----------
func end_week() -> Array:
	if state.over:
		return []
	var events: Array = []
	var strike: bool = int(state.strikeMonths) > 0

	# Spielfigur: Arbeitslast der Woche wirkt auf Energie & Stress
	Persona.tick_week()
	Mogul.tick_week()
	# Die Post der Woche: Briefe/E-Mails werden zugestellt, Liegengebliebenes verfällt
	Dialogs.tick_week()
	# Bedeutungsstaffelung (Feature 24): die Routine der Woche wird zu EINER Zeile
	Dialogs.flush_digest()

	# Wochenplaner: die geplante Woche wirkt VOR den Ereignissen
	_apply_planner(events)

	# Castings → Produktionen (Deadline in Wochen)
	if not strike:
		for casting in state.castings.duplicate():
			casting.deadline = int(casting.deadline) - 1
			if int(casting.deadline) <= 0:
				start_production(casting, events)
				state.castings.erase(casting)

	# Produktionen → Release (Restzeit in Wochen)
	if not strike or state.strikeExempt:
		for prod in state.productions.duplicate():
			ensure_prod_fields(prod)
			prod.weeksLeft = int(prod.weeksLeft) - 1
			if int(prod.weeksLeft) <= 0:
				events.append(release_film(prod))
				state.productions.erase(prod)

	# Follow-ups (Ketten): fällige Folge-Ereignisse (due bleibt im Monatsindex)
	for fu in state.followups.duplicate():
		if mi() >= int(fu.due):
			state.followups.erase(fu)
			var ev = EvEngine.build_by_id(str(fu.event), fu.get("ctx", {})) if str(fu.get("type", "")) == "json" else Ev.build_followup(fu)
			if ev != null:
				events.append(ev)

	maybe_fire_event(events)

	# Mitarbeiter (Features 33–36): Vorschläge, autonome Arbeit, Eskalationen
	Staff.tick_week(events)

	# Assistant: the weekly decision note (delegation, Feature 4)
	var brief: Dictionary = Persona.assistant_briefing()
	if not brief.is_empty():
		events.append(brief)

	if int(state.get("week", 1)) >= 4:
		state.week = 1
		_month_close(events)
	else:
		state.week = int(state.get("week", 1)) + 1
	# Neue Woche, neue Kontaktzeit
	state.contactAP = Persona.ap_per_week()
	save_game()
	return events

# ---------- Monatsabschluss (läuft nach der 4. Woche) ----------
func _month_close(events: Array) -> void:
	var strike: bool = int(state.strikeMonths) > 0
	# Fixkosten des abgelaufenen Monats buchen und die Buchhaltung
	# des Monats abschließen (Aggregat in ledgerMonthly).
	# Wochenplaner: ≥3 „Bücher prüfen“-Slots im Monat senken die Bürokosten um 10 %
	var base_cost := roundi(office_base_cost() * backstory_mod("office_cost_mult", 1.0))
	if int(state.get("plannerMonthCounts", {}).get("buecher", 0)) >= 3:
		base_cost = roundi(base_cost * Balance.OFFICE_BOOKS_MULT)
		attr_gain("geschaeftssinn", 0.3)
	state["plannerMonthCounts"] = {}
	var perk_cost := roundi(perk_costs())
	book(-float(base_cost), "buero", "Office, staff & fixed costs")
	if perk_cost > 0:
		book(-float(perk_cost), "perks", "Client perks (%d clients)" % state.clients.size())
	# Spielfigur: Gehalt, Lebensstil, Zustand & Karriere — vor dem
	# Ledger-Abschluss, damit die Buchungen im ablaufenden Monat landen.
	Persona.tick_month(events)
	# Empire-Cluster (Features 5–9): Immobilien-Unterhalt, Börse, Beteiligungen,
	# Hinterzimmer-Fristen & Endgame — ebenfalls vor dem Ledger-Abschluss.
	Mogul.tick_month(events)
	# Netzwerk-Cluster (Features 10–15): Kapital zahlt aus, Ärger kühlt ab
	Network.tick_month()
	# Mitarbeiter: Löhne, Lernen, Loyalität & Abwerbung (Features 32–36)
	Staff.tick_month(events)
	# RPG-Attribut Geschäftssinn (Chunk 15): schwarze Monatszahlen schulen
	var closing_month := live_month(mi())
	if float(closing_month.income) > float(closing_month.expenses):
		attr_gain("geschaeftssinn", 0.3)
	_close_ledger_month(mi())
	state.month = int(state.month) + 1
	if state.month > 12:
		state.month = 1
		state.year = int(state.year) + 1
	Jukebox.set_era(int(state.year))

	# Historische Ereignisse
	for h in Data.HISTORY:
		var key := "%d-%d" % [int(h.year), int(h.month)]
		if int(h.year) == int(state.year) and int(h.month) == int(state.month) and not state.usedHistory.has(key):
			state.usedHistory.append(key)
			state.market = h.market
			log_msg(h.text, "history")
			events.append({"title": "Headline", "text": "[i]%s[/i]" % h.text, "choices": [{"label": "Continue"}]})
			if h.get("effect") == "talkies":
				for c in state.clients:
					if actor_by_id[c.aid].debut <= 1924:
						c.fame = clampf(c.fame - 12.0, 5.0, 100.0)
						c.mood -= 15.0
						log_msg("%s struggles with the talkies — the fame is crumbling." % client_name(c), "bad")
			# Paramount-Urteil (Mai 1948): Exklusivverträge der Studiosystem-Ära enden (Feature 14)
			if int(h.year) == 1948 and int(h.month) == 5:
				var freed := 0
				for c in state.clients:
					if str(c.get("exclusiveStudio", "")) != "":
						c["exclusiveStudio"] = ""
						c.loyalty = clampf(c.loyalty + 4.0, 0.0, 100.0)
						freed += 1
				if freed > 0:
					log_msg("The Paramount decree dissolves %d exclusive contracts — a wave of renegotiations rolls through Hollywood." % freed, "history")
	state.market += (1.0 - state.market) * 0.06
	state.marketHistory.append(roundi(state.market * 100.0))
	if state.marketHistory.size() > 24:
		state.marketHistory.pop_front()

	# Streik (Countdown monatlich; blockiert die Wochen-Ticks über strikeMonths > 0)
	if strike:
		state.strikeMonths = int(state.strikeMonths) - 1
		log_msg("The strike paralyzes Hollywood%s." % (" — your productions keep running under an exemption" if state.strikeExempt else ""), "bad")
		if int(state.strikeMonths) == 0:
			log_msg("The strike is over. The studios are ramping production back up.", "history")
			state.strikeExempt = false

	# Monatliche, unzuverlässige Set-Signale (Feature 13)
	if not strike:
		_tick_signals(events)

	if not strike:
		spawn_castings(Util.rndi(1, 2) + (1 if state.agency.rep >= 50 else 0))
		while state.castings.size() > 10:
			state.castings.pop_front()

	# Script Coverage: Blatt verfällt, verdecktes Casting wird sichtbar,
	# ggf. neues Blatt auf den Schreibtisch (neue Blätter nur ohne Streik)
	_tick_coverage(events, strike)

	tick_clients(events)
	_tick_roster_pairs(events)
	Scandal.tick_rumors(events)
	tick_rivals(events)
	# Karrierebretter: veraltete Plan-Slots verfallen lautlos
	_tick_boards()
	# Instinkt-Prognosen (Feature 6): fällige Wetten auflösen
	tick_predictions(events)

	if int(state.month) == 2:
		var aw = awards_ceremony()
		if aw != null:
			events.append(aw)

	_expire_favors()
	if state.agency.cash < 0:
		state.agency.debtMonths = int(state.agency.debtMonths) + 1
		log_msg("The agency is insolvent (%d/%d months). The banks are getting nervous." % [int(state.agency.debtMonths), Balance.INSOLVENCY_MONTHS], "bad")
		if int(state.agency.debtMonths) >= Balance.INSOLVENCY_MONTHS:
			state.over = true
			events.append({"title": "Game Over", "text": "Three months in the red — the creditors take over. %s closes its doors for good.\n\nAchieved: %d clients, reputation %d, %d brokered films." % [state.agency.name, state.clients.size(), int(state.agency.rep), state.released.size()], "choices": [{"label": "New game", "action": "restart"}]})
	else:
		state.agency.debtMonths = 0
	Newspaper.build_newspaper()

# Feuert wöchentlich — die Chancen sind so gewählt, dass die Monatsfrequenz
# der alten Werte (0,45 bzw. 0,8 pro Monat) erhalten bleibt: 1−(1−p)⁴.
func maybe_fire_event(events: Array) -> void:
	var candidates: Array = []
	for e in Ev.all_events() + EvEngine.all_events():
		if int(state.eventCd.get(e.id, 0)) > mi():
			continue
		var w: float = e.weight.call()
		if w > 0:
			candidates.append({"e": e, "w": w})
	if candidates.is_empty():
		return
	var seasonal := false
	var total := 0.0
	for x in candidates:
		total += x.w
		if x.w >= 3.0:
			seasonal = true
	if not Util.chance(0.33 if seasonal else 0.14):
		return
	var r := randf() * total
	var chosen: Dictionary = candidates[0]
	for x in candidates:
		r -= x.w
		if r <= 0:
			chosen = x
			break
	state.eventCd[chosen.e.id] = mi() + int(chosen.e.get("cd", 9))
	var ev = chosen.e.build.call()
	if ev != null:
		events.append(ev)

func tick_clients(events: Array) -> void:
	for c in state.clients.duplicate():
		var actor: Dictionary = actor_by_id[c.aid]
		if actor.death != null and state.year >= actor.death:
			log_msg("Hollywood mourns: %s has died (%d–%d)." % [actor.name, int(actor.birth), int(actor.death)], "history")
			state.clients.erase(c)
			continue
		var busy := not is_free(c)
		var disc: float = Util.attrs(actor).discipline
		# Kleine monatliche Schritte; große Sprünge kommen aus Entscheidungen.
		_tick_client_weight(c, actor, disc)
		var trust_growth := 0.28 + minf(0.28, c.perks.size() * 0.07) + (0.10 if busy else 0.0)
		change_trust(c, trust_growth)
		if busy:
			c.exhaustion = clampf(c.exhaustion + (3.0 if c.perks.has("assistant") else 6.0) + (2.0 if disc < 40 else (-1.0 if disc > 75 else 0.0)), 0.0, 100.0)
		else:
			c.exhaustion = clampf(c.exhaustion - (11.0 if c.perks.has("travel") else 8.0), 0.0, 100.0)
		if c.exhaustion > 75:
			c.mood = clampf(c.mood - 4.0, 0.0, 100.0)
		if c.perks.has("pr"):
			c.mood = clampf(c.mood + 1.0, 0.0, 100.0)
		if c.perks.has("travel"):
			c.mood = clampf(c.mood + 2.0, 0.0, 100.0)
		if c.perks.has("assistant"):
			c.loyalty = clampf(c.loyalty + 1.0, 0.0, 100.0)
		if c.perks.has("coach"):
			c.talentBonus = minf(10.0, c.get("talentBonus", 0.0) + 0.15)
		# TV-Vertrag
		var tv = c.flags.get("tvIncome")
		if tv != null and int(tv.months) > 0:
			book(float(tv.monthly), "tv", "TV contract: %s" % client_name(c))
			tv.months = int(tv.months) - 1
			c.fame = clampf(c.fame - 0.3, 5.0, 100.0)
			# Fernseh-Ära: TV wertet das Kino-Image ab (Feature 14)
			if int(state.year) >= 1948 and int(state.year) <= 1965:
				c.dna.popular = clampf(c.dna.popular + 0.4, -100.0, 100.0)
				c.dna.unikat = clampf(c.dna.unikat - 0.4, -100.0, 100.0)
		# Werbevertrag-Klausel (Feature 8): regelmäßiges Einkommen, Image +, Laune −
		if c.get("clauses", []).has("endorsement"):
			var ad_income := roundi((900.0 + float(c.fame) * 30.0) * Util.infl(state.year) * float(c.commission) / 100.0)
			book(float(ad_income), "sonstiges", "Endorsement deal: %s" % client_name(c))
			c.mood = clampf(c.mood - 1.0, 0.0, 100.0)
			c.dna.familie = clampf(c.dna.familie + 0.4, -100.0, 100.0)
		# Tonfilm-Umbruch: fragile Stimmen verlieren in der Übergangszeit
		# monatlich Ruhm, bis Training oder Nische die Karriere sichern.
		if voice_at_risk(c):
			c.fame = maxf(c.fame - Balance.VOICE_FAME_DRIFT, 5.0)
			if not c.flags.get("voiceNoted", false):
				c.flags["voiceNoted"] = true
				log_msg("The microphones are merciless: whispers about %s's voice make the rounds." % client_name(c), "bad")
		# Karriere-DNA verblasst langsam Richtung Neutral, wenn nichts nachkommt
		if not busy:
			CareerDNA.decay(c)
		if not busy:
			c.heat = clampf(c.heat - 1.0, -10.0, 10.0)
			c.fame = maxf(maxf(c.fame - 0.4, Util.fame_at(actor, state.year) * 0.6), 5.0)
			c.mood = clampf(c.mood - 2.0, 0.0, 100.0)
			if c.mood < 35:
				c.loyalty = clampf(c.loyalty - 2.0, 0.0, 100.0)
		else:
			c.mood = clampf(c.mood + 1.0, 0.0, 100.0)
		# Eine nachweisbar skrupellose Hauskultur erleichtert schmutzige Tricks,
		# lässt aber das Vertrauen aller Klienten langsam erodieren.
		var ruthless := identity_strength("skrupellos")
		if ruthless > 0.25:
			change_trust(c, -0.18 * ruthless)
		snapshot_client(c)
		# Versprechen
		for pr in c.promises:
			if not pr.fulfilled and not pr.get("broken", false) and mi() > int(pr.due):
				pr.broken = true
				c.loyalty = clampf(c.loyalty - Balance.PROMISE_BROKEN_LOYALTY, 0.0, 100.0)
				change_trust(c, -Balance.PROMISE_BROKEN_TRUST)
				c.mood = clampf(c.mood - Balance.PROMISE_BROKEN_MOOD, 0.0, 100.0)
				state.agency.rep = clampi(int(state.agency.rep) - Balance.PROMISE_BROKEN_REP, 0, 100)
				log_msg("Promise broken: %s waited in vain for %s." % [actor.name, pr.label], "bad")
				events.append({"title": "A broken promise", "text": "[i]“You gave me your word. In this town an agent's word is everything — or so I thought.”[/i]\n\n%s is deeply disappointed. Loyalty plummets, your reputation suffers." % actor.name, "choices": [{"label": "Understood"}]})
		# Vertragsende
		Scandal.maybe_reveal_secret(c, events)
		if mi() >= int(c.contractEnd):
			if c.loyalty >= 65:
				c.contractEnd = mi() + int(c.years) * 12
				change_trust(c, 4.0)
				log_msg("%s renews the contract for %d years without hesitation." % [actor.name, int(c.years)], "deal")
			else:
				var cid: int = int(c.id)
				events.append({"title": "Contract expiring",
					"text": "The contract with %s is ending. Loyalty (%d/100) is not enough for an automatic renewal." % [actor.name, roundi(c.loyalty)],
					"choices": [
						{"label": "Concession: commission −2 points", "fn": func():
							var cl = client(cid)
							if cl == null:
								return "Too late."
							cl.commission = maxi(5, int(cl.commission) - 2)
							cl.contractEnd = mi() + int(cl.years) * 12
							cl.loyalty = clampf(cl.loyalty + 10.0, 0.0, 100.0)
							return "%s stays — at %d%% commission." % [actor.name, int(cl.commission)]},
						{"label": "Let them go", "fn": func():
							var cl = client(cid)
							if cl != null:
								state.clients.erase(cl)
							log_msg("%s leaves the agency at the end of the contract — on good terms." % actor.name, "info")
							return "You part ways professionally. No ugly headlines."},
					]})
				c.contractEnd = mi() + 2
		# Kündigung
		if c.loyalty < 20 and Util.chance(0.4):
			state.clients.erase(c)
			state.agency.rep = clampi(int(state.agency.rep) - 3, 0, 100)
			log_msg("%s leaves the agency. “My lawyers will be in touch.”" % actor.name, "bad")
			events.append({"title": "Client lost", "text": "%s has terminated the contract and is moving to the competition." % actor.name, "choices": [{"label": "Continue"}]})
			continue
		if Util.age_of(actor, state.year) > 85:
			state.clients.erase(c)
			log_msg("%s retires from the business at %d." % [actor.name, Util.age_of(actor, state.year)], "info")

# ---------- Produktion & Box-Office ----------
func start_production(casting: Dictionary, events: Array = []) -> void:
	var y = state.year
	for role in casting.roles:
		if role.filled != null:
			continue
		var rival_candidates: Array = []
		for rival in state.get("rivals", []):
			for actor_id in rival.clients:
				var rival_actor: Dictionary = actor_by_id.get(str(actor_id), {})
				if not rival_actor.is_empty() and rival_actor.g == role.gender and Util.fame_at(rival_actor, y) >= role.minFame * 0.6 and Util.age_of(rival_actor, y) >= role.ageMin - 6 and Util.age_of(rival_actor, y) <= role.ageMax + 8:
					rival_candidates.append({"actor":rival_actor, "rival":rival})
		if rival_candidates.size() and Util.chance(0.68):
			var rc: Dictionary = Util.pick(rival_candidates)
			var ra: Dictionary = rc.actor
			role.filled = {"npc":true, "name":ra.name, "talent":ra.talent, "fame":Util.fame_at(ra, y), "actorId":ra.id, "rivalId":rc.rival.id}
			press_event("Casting", "%s pushes %s through in “%s”" % [rc.rival.name, ra.name, casting.title])
			continue
		var candidates = available_actors().filter(func(a):
			return a.g == role.gender and Util.fame_at(a, y) >= role.minFame * 0.6 and Util.age_of(a, y) >= role.ageMin - 6 and Util.age_of(a, y) <= role.ageMax + 8)
		if candidates.size() and Util.chance(0.7):
			var a = Util.pick(candidates.slice(0, 8))
			role.filled = {"npc": true, "name": a.name, "talent": a.talent, "fame": Util.fame_at(a, y)}
		else:
			var first = Util.pick(Data.NPC_FIRST_M) if role.gender == "m" else Util.pick(Data.NPC_FIRST_F)
			role.filled = {"npc": true, "name": "%s %s" % [first, Util.pick(Data.NPC_LAST)], "talent": Util.rndi(35, 70), "fame": Util.rndi(10, maxi(12, int(role.minFame)))}
	# Streaming-Ära: kürzere Produktionszeiten (Feature 14, Werte: Balance.gd)
	var months := Util.rndi(Balance.PROD_MONTHS_MIN_MODERN, Balance.PROD_MONTHS_MAX_MODERN) if int(state.year) >= Balance.PROD_MODERN_YEAR else Util.rndi(Balance.PROD_MONTHS_MIN, Balance.PROD_MONTHS_MAX)
	var income := 0.0
	for role in casting.roles:
		if role.filled.get("clientId") != null:
			var c = client(role.filled.clientId)
			if c != null:
				income += role.filled.fee * c.commission / 100.0
				c.busyUntil = mi() + months
				change_trust(c, 1.25)
	if income > 0:
		book(float(roundi(income)), "provision", "Commissions, shooting start “%s”" % casting.title)
		log_msg("Shooting starts on “%s” — commissions worth %s come in." % [casting.title, Util.fmt_money(income)], "deal")
	var prod = casting.duplicate(true)
	# WICHTIG: Rollen-Referenzen behalten? Produktion arbeitet auf Kopie — Klienten-IDs bleiben gültig.
	prod["weeksLeft"] = months * 4
	_init_production_uncertainty(prod)
	state.productions.append(prod)
	# Instinkt-Prognose (Feature 6a): „Wird das ein Hit?“ beim Drehbeginn anbieten
	for role in casting.roles:
		if role.filled.get("clientId") != null:
			var c2 = client(role.filled.clientId)
			if c2 != null:
				events.append(hit_prediction_event(prod, c2))
				break

func release_film(prod: Dictionary) -> Dictionary:
	# Skript-Basis deterministisch (wie script_insight): 35 + Prestige*8 + Roll 0..20
	var script: float = 35.0 + int(prod.prestige) * 8.0 + float(Util.hashs(str(prod.id) + "scr") % 21)
	if prod.has("director"):
		script += 4.0
	if prod.has("producer"):
		script += 2.0
	var talents: Array = []
	var fit_bonus := 0.0
	for r in prod.roles:
		var c = client(r.filled.get("clientId")) if r.filled.get("clientId") != null else null
		talents.append(eff_talent(c) if c != null else r.filled.get("talent", 50.0))
		if c != null and actor_by_id[c.aid].genres.has(prod.genre):
			fit_bonus += 2.5
	var cast_q := 0.0
	for t in talents:
		cast_q += t
	cast_q /= talents.size()
	# Beziehungschemie (Feature 12): Leinwandchemie der Leads ±8, Regie-Chemie ±3
	var chem_q := lead_chem_quality(prod) + director_chem_quality(prod)
	var quality := clampi(roundi(script * 0.45 + cast_q * 0.5 + fit_bonus + prod.get("qualityMod", 0.0) + chem_q + Util.rndf(-5.0, 5.0)), 5, 100)
	var star_power := 0.0
	var lead_n := 0
	for r in prod.roles:
		if r.type != "lead":
			continue
		lead_n += 1
		var c = client(r.filled.get("clientId")) if r.filled.get("clientId") != null else null
		star_power += (c.fame * 0.75 + Util.attrs(actor_by_id[c.aid]).presence * 0.25) if c != null else r.filled.get("fame", 25.0)
	star_power /= maxi(1, lead_n)
	var revenue := roundi(prod.budget * (0.25 + quality / 45.0 + star_power / 70.0) * state.market * Util.rndf(0.55, 1.75))
	var ratio: float = float(revenue) / prod.budget
	var verdict := "Flop" if ratio < 1.0 else ("Solid success" if ratio < 2.0 else ("Hit" if ratio < 3.2 else "Blockbuster"))
	# Coverage-Prognose „Rolle wird geschnitten“: der Schnitt-Wurf fällt beim
	# Release, die Wahrscheinlichkeit hängt am verdeckten Rollengrößen-Flag.
	for pr in state.get("predictions", []):
		if pr.get("resolved", false) or str(pr.get("type", "")) != "coverage":
			continue
		if str(pr.subject.get("cat", "")) != "schnitt":
			continue
		if int(pr.subject.get("castingId", -1)) != int(prod.id):
			continue
		var ridx := clampi(int(pr.subject.get("roleIdx", 0)), 0, prod.roles.size() - 1)
		if _coverage_cut_roll(prod, prod.roles[ridx]):
			prod.roles[ridx]["_coverageCut"] = true
	var affected: Array = []
	var fame_deltas := {}
	for r in prod.roles:
		var c = client(r.filled.get("clientId")) if r.filled.get("clientId") != null else null
		if c == null:
			continue
		var mult := 1.0 if r.type == "lead" else 0.5
		var narrative_mult := narrative_multiplier(c, prod, r)
		var delta: float = clampf(((quality - 55.0) / 8.0 + (ratio - 1.6) * 2.5) * mult, -8.0, 10.0)
		delta = clampf(delta * narrative_mult, -12.0, 18.0)
		# Billing aus der Mehrparteien-Verhandlung (Feature 9): erste Nennung zählt
		var billing := int(r.filled.get("billing", 1))
		if billing >= 2:
			delta = clampf(delta * 0.8, -12.0, 18.0)
			c.mood = clampf(c.mood - 4.0, 0.0, 100.0)
		else:
			delta = clampf(delta * 1.05, -12.0, 18.0)
		# Coverage bestätigt: die Rolle fällt der Schere zum Opfer
		if bool(r.get("_coverageCut", false)):
			delta = clampf(delta * 0.25, -12.0, 18.0)
			c.mood = clampf(c.mood - 6.0, 0.0, 100.0)
			press_event("Reviews", "The scissors of %s: %s falls victim to the final cut of “%s”" % [_studio(str(prod.studioId)).name, client_name(c), prod.title])
		fame_deltas[int(c.id)] = delta
		# Gefallen "billing": prominente Platzierung im Vorspann bringt Extra-Ruhm.
		if c.flags.get("billingBoost", false):
			c.flags.erase("billingBoost")
			delta = clampf(delta + 3.0, -8.0, 10.0)
			log_msg("Top billing: %s shines in the opening credits of “%s”." % [client_name(c), prod.title], "deal")
		c.fame = clampf(c.fame + delta, 5.0, 100.0)
		c.heat = clampf(c.heat + delta * 0.7, -10.0, 10.0)
		c.loyalty = clampf(c.loyalty + (3.0 if delta > 0 else -2.0), 0.0, 100.0)
		# Comeback-Projekt: Alles-oder-nichts, über den normalen Delta hinaus
		if bool(prod.get("comeback", false)) and r.type == "lead":
			c.flags.erase("comebackActive")
			c.flags["comebackDone"] = true
			if ratio >= Balance.COMEBACK_SUCCESS_RATIO or quality >= Balance.COMEBACK_SUCCESS_QUALITY:
				c.fame = clampf(c.fame + Balance.COMEBACK_SUCCESS_FAME, 5.0, 100.0)
				c.heat = clampf(c.heat + 5.0, -10.0, 10.0)
				c.dna.unikat = clampf(c.dna.unikat + 6.0, -100.0, 100.0)
				press_event("Careers", "The comeback of the year: %s returns in “%s”" % [client_name(c), prod.title])
				log_msg("The second act works: %s is back in the conversation." % client_name(c), "history")
			else:
				c.fame = clampf(c.fame - 3.0, 5.0, 100.0)
				c.mood = clampf(c.mood - 12.0, 0.0, 100.0)
				c.loyalty = clampf(c.loyalty - 6.0, 0.0, 100.0)
				press_event("Careers", "The comeback that wasn't: “%s” cannot revive %s" % [prod.title, client_name(c)])
		c.films.push_front({"title": prod.title, "year": int(state.year), "verdict": verdict, "quality": quality, "lead": r.type == "lead", "genre":prod.genre, "prestige":int(prod.prestige), "ratio":ratio, "fameDelta":delta})
		if c.films.size() > 12:
			c.films.pop_back()
		# Karriere-DNA: jede Rolle prägt das öffentliche Bild
		# (boardMult: erfüllter Karrierebrett-Plan prägt ×1,5 ein)
		CareerDNA.imprint_dna(c, prod.genre, mult * narrative_mult * float(r.filled.get("boardMult", 1.0)), int(prod.prestige), ratio)
		advance_narrative_on_release(c, prod, r)
		if delta >= 5.0:
			press_event("New stars", "%s jumps %d fame points with “%s”" % [client_name(c), roundi(delta), prod.title])
		snapshot_client(c)
		affected.append("%s (%s%d fame)" % [client_name(c), "+" if delta >= 0 else "", roundi(delta)])
	# Gewinnbeteiligung (Feature 8): Anteil am Überschuss ab ratio 2 — über book()
	for r in prod.roles:
		if r.filled == null or r.filled.get("clientId") == null:
			continue
		var c3 = client(r.filled.clientId)
		if c3 == null:
			continue
		var rclauses: Array = r.filled.get("clauses", [])
		if rclauses.has("profitShare") and ratio > 2.0:
			var share := roundi(float(prod.budget) * (ratio - 2.0) * 0.08 * float(c3.commission) / 100.0)
			if share > 0:
				book(float(share), "provision", "Profit share: %s (“%s”)" % [client_name(c3), prod.title])
		# Sequel-Option (Feature 8): Blockbuster aktiviert die Alt-Gagen-Falle
		if rclauses.has("sequelOption") and ratio >= 3.0:
			c3.flags["sequelDue"] = {"title": prod.title, "fee": int(r.filled.get("fee", 0)), "studioId": str(prod.studioId)}
	# Empire-Cluster: Film-Beteiligungen auszahlen, Studio-Aktien reagieren,
	# Interessenkonflikte können auffliegen (Feature 7)
	Mogul.on_release(prod, revenue, ratio, quality)
	# Gemeinsame Historie der Beteiligten pflegt die persönliche Chemie (Feature 12)
	var lead_keys := _prod_people_keys(prod, true)
	for i in lead_keys.size():
		for j in range(i + 1, lead_keys.size()):
			note_pair_history(lead_keys[i], lead_keys[j], 2 if ratio >= 2.0 else -1, ratio, str(prod.title))
	# Instinkt-Prognosen auflösen (Feature 6): Hit-Wette, „Wer passt besser?“
	# und die Coverage-Marker aus dem Lektorats-Blatt
	_resolve_release_predictions(prod, ratio, fame_deltas, quality)
	# Produktions-Signale im Rückblick (Feature 13): Haben die Meldungen gestimmt?
	var sigs: Array = prod.get("signals", [])
	if sigs.size():
		var pos_n := 0
		for sg in sigs:
			if bool(sg.get("pos", false)):
				pos_n += 1
		var predicted_good := pos_n * 2 >= sigs.size()
		var actually_good := ratio >= 1.6
		if predicted_good == actually_good:
			log_msg("In hindsight: the set signals from “%s” told the truth." % prod.title, "info")
		else:
			log_msg("In hindsight: the set signals from “%s” deceived — set talk stays set talk." % prod.title, "info")
	# Heimvideo (Feature 14, 1980+): Flops können nachträglich Geld einspielen
	if int(state.year) >= 1980 and ratio < 1.0 and fame_deltas.size():
		state.followups.append({"type": "homevideo", "title": prod.title, "studioId": str(prod.studioId), "budget": int(prod.budget), "due": mi() + Util.rndi(6, 18)})
	if affected.size():
		state.agency.rep = clampi(int(state.agency.rep) + (2 if ratio >= 2.0 else (-1 if ratio < 1.0 else 0)), 0, 100)
	state.studioRel[prod.studioId] = clampi(int(state.studioRel[prod.studioId]) + (5 if ratio >= 2.0 else (-3 if ratio < 1.0 else 1)), 0, 100)
	state.released.push_front({"title": prod.title, "genre": prod.genre, "year": int(state.year), "releaseMi":mi(), "studioId": prod.studioId, "quality": quality, "revenue": revenue, "budget": prod.budget, "ratio": ratio, "verdict": verdict, "prestige": int(prod.prestige), "roles": prod.roles})
	var studio_name: String = _studio(prod.studioId).name
	for key in ["director", "producer"]:
		if prod.has(key):
			var figure = null
			for candidate in state.get("powerFigures", []):
				if int(candidate.id) == int(prod[key].figureId):
					figure = candidate
					break
			if figure != null:
				figure.credits = int(figure.credits) + 1
	log_msg("Premiere “%s” (%s): %s — %s box office at quality %d." % [prod.title, studio_name, verdict, Util.fmt_money(revenue), quality], "bad" if ratio < 1.0 else "deal")
	return {"title": "Premiere: “%s”" % prod.title,
		"text": "%s · %s · Quality %d/100\n\nBox office: %s (budget %s) — %s%s" % [studio_name, Data.GENRES[prod.genre].label, quality, Util.fmt_money(revenue), Util.fmt_money(prod.budget), verdict, ("\n\nYour clients: " + ", ".join(affected)) if affected.size() else ""],
		"choices": [{"label": "Continue"}]}

func _studio(sid: String) -> Dictionary:
	for s in Data.STUDIOS:
		if s.id == sid:
			return s
	return {"name": "?"}

# ---------- Awards ----------
# „For Your Consideration“: In der Award-Saison (Nov–Jan) lässt sich die
# Academy-Wertung eines Klienten mit Kampagnenbudget anschieben — das
# c.campaign-Feld fließt in die Performance-Wertung der Zeremonie ein.
func fyc_season() -> bool:
	return int(state.month) in [11, 12, 1]

# Das „Klassenjahr“, das die nächste Zeremonie ehrt.
func fyc_class_year() -> int:
	return int(state.year) if int(state.month) >= 11 else int(state.year) - 1

func fyc_eligible(c: Dictionary) -> bool:
	if not fyc_season():
		return false
	for f in state.released:
		if int(f.year) != fyc_class_year():
			continue
		for r in f.get("roles", []):
			if str(r.get("type", "")) == "lead" and r.get("filled") != null and r.filled.get("clientId") != null and int(r.filled.clientId) == int(c.id):
				return true
	return false

func fyc_campaign(cid, big: bool) -> String:
	var c = client(cid)
	if c == null or not fyc_eligible(c):
		return "The Academy's attention has a season — and this is not it."
	if float(c.get("campaign", 0.0)) >= Balance.FYC_CAP:
		return "Every trade paper already carries the name. More money would only look desperate."
	var cost := roundi((Balance.FYC_BIG_COST if big else Balance.FYC_SMALL_COST) * Util.infl(state.year))
	if float(state.agency.cash) < float(cost):
		return "The campaign would cost %s — the till cannot cover it." % Util.fmt_money(cost)
	book(-float(cost), "pr_recht", "FYC campaign: %s" % client_name(c))
	c.campaign = minf(float(c.get("campaign", 0.0)) + (Balance.FYC_BIG_BOOST if big else Balance.FYC_SMALL_BOOST), Balance.FYC_CAP)
	attr_gain("geschaeftssinn", 0.2)
	if big:
		record_identity("kommerziell", 0.5)
		press_event("Awards", "For your consideration: the town cannot open a paper without reading the name %s" % client_name(c))
		return "Trade ads, screenings, dinners with the right voters. The name is everywhere now — exactly where it needs to be."
	return "A tasteful spread in the trades, twice a week. The right people notice — quietly."

func awards_ceremony() -> Variant:
	var pool = state.released.filter(func(f): return int(f.year) == int(state.year) - 1)
	if pool.is_empty():
		return null
	var sorted = pool.duplicate()
	sorted.sort_custom(func(a, b): return a.quality > b.quality)
	var noms = sorted.slice(0, 3)
	var winner: Dictionary = noms[0]
	press_event("Awards", "Awards season: “%s” tops the class of %d" % [winner.title, int(state.year) - 1])
	var text := "The Academy honors the films of %d.\n\nBest Picture: “%s”" % [int(state.year) - 1, winner.title]
	var perfs: Array = []
	for f in noms:
		for r in f.roles:
			if r.type != "lead":
				continue
			var c = client(r.filled.get("clientId")) if r.filled.get("clientId") != null else null
			var nm: String = client_name(c) if c != null else r.filled.get("name", "?")
			var talent: float = eff_talent(c) if c != null else r.filled.get("talent", 50.0)
			perfs.append({"c": c, "name": nm, "score": talent * 0.5 + f.quality * 0.4 + (c.get("campaign", 0.0) if c != null else 0.0) + Util.rndf(0.0, 15.0), "film": f.title})
	perfs.sort_custom(func(a, b): return a.score > b.score)
	if perfs.size():
		var best: Dictionary = perfs[0]
		text += "\nBest performance: %s (“%s”)" % [best.name, best.film]
		if best.c != null:
			best.c.fame = clampf(best.c.fame + 8.0, 5.0, 100.0)
			best.c.heat = clampf(best.c.heat + 5.0, -10.0, 10.0)
			best.c.loyalty = clampf(best.c.loyalty + 12.0, 0.0, 100.0)
			best.c.awards = int(best.c.get("awards", 0)) + 1
			best.c.dna.unikat = clampf(best.c.dna.unikat + 8.0, -100.0, 100.0)
			state.agency.rep = clampi(int(state.agency.rep) + 6, 0, 100)
			text += "\n\nYour client wins! Reputation +6, fame +8 — and lasting bargaining power."
			log_msg("%s wins the Academy Award — brokered by %s!" % [best.name, state.agency.name], "history")
			press_event("Awards", "%s wins for “%s” — a triumph for %s" % [best.name, best.film, state.agency.name])
		for p in perfs.slice(0, 3):
			if p.c != null:
				for pr in p.c.promises:
					if not pr.fulfilled and not pr.get("broken", false) and pr.type == "oscar":
						fulfill_promise(p.c, pr)
				if p.c != perfs[0].c:
					p.c.fame = clampf(p.c.fame + 4.0, 5.0, 100.0)
	for c in state.clients:
		c.campaign = 0.0
	return {"title": "Awards season %d" % int(state.year), "text": text, "choices": [{"label": "Applause!"}]}

# ---------- Speichern / Laden ----------
const SAVE_PATH := "user://hm_save.json"
const SAVE_BACKUP_PATH := "user://hm_save.bak.json"
const SAVE_VERSION := 2

# Grund des letzten Ladefehlers — die UI zeigt ihn statt still zu scheitern.
var load_error := ""

func save_game() -> void:
	if state == null:
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(state))
	f.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Nicht ladbare Saves werden nie überschrieben, sondern vorher weggesichert.
func _backup_save() -> void:
	var src = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if src == null:
		return
	var dst = FileAccess.open(SAVE_BACKUP_PATH, FileAccess.WRITE)
	dst.store_string(src.get_as_text())
	dst.close()
	src.close()

func load_game() -> bool:
	load_error = ""
	if not has_save():
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null or not (parsed is Dictionary):
		_backup_save()
		load_error = "The save file could not be read (corrupt data). A copy was kept as hm_save.bak.json — the game will not overwrite it."
		push_warning(load_error)
		return false
	if int(parsed.get("saveVersion", 1)) > SAVE_VERSION:
		_backup_save()
		load_error = "This save comes from a newer game version (v%d, this build reads up to v%d). A copy was kept as hm_save.bak.json." % [int(parsed.saveVersion), SAVE_VERSION]
		push_warning(load_error)
		return false
	state = parsed
	_migrate_save()
	_apply_save_defaults()
	return true

# Versionskette: pro Versionssprung ein Schritt, bis SAVE_VERSION erreicht ist.
# Neue Sprünge unten als eigenen match-Zweig ergänzen (SAVE_VERSION mit anheben).
func _migrate_save() -> void:
	while int(state.get("saveVersion", 1)) < SAVE_VERSION:
		match int(state.get("saveVersion", 1)):
			1:
				_migrate_v1_to_v2()
			_:
				state["saveVersion"] = SAVE_VERSION

# v1 → v2: Umstellung auf den Wochenrhythmus.
func _migrate_v1_to_v2() -> void:
	state["week"] = 1
	for prod in state.get("productions", []):
		prod["weeksLeft"] = int(prod.get("monthsLeft", 4)) * 4
		prod.erase("monthsLeft")
	for cs in state.get("castings", []):
		cs["deadline"] = int(cs.get("deadline", 2)) * 4
	# Alte 4-Slot-Planung verwerfen — ensure_planner baut die 21-Slot-Woche auf.
	state["planner"] = {"player": [], "clients": {}}
	state["saveVersion"] = 2

# Versionsunabhängig: fehlende Felder älterer Stände defensiv mit Defaults füllen.
func _apply_save_defaults() -> void:
	if not state.has("week"):
		state["week"] = 1
	if not state.has("backstory"):
		state["backstory"] = ""
	if not state.has("plannerMonthCounts"):
		state["plannerMonthCounts"] = {}
	# Migration: neue rein JSON-basierte Felder für ältere Stände nachrüsten.
	if not state.has("rumors"):
		state["rumors"] = []
	if not state.has("favors"):
		state["favors"] = []
	if not state.has("debts"):
		state["debts"] = []
	if not state.has("ledger"):
		state["ledger"] = []
	if not state.has("ledgerMonthly"):
		state["ledgerMonthly"] = []
	if not state.has("newspaper"):
		state["newspaper"] = []
	if not state.has("pressFeed"):
		state["pressFeed"] = []
	if not state.has("rivals"):
		state["rivals"] = []
	if state.rivals.is_empty():
		_init_rivals(int(state.year))
	if not state.has("identity"):
		state["identity"] = {}
	for identity_key in IDENTITY_KEYS:
		if not state.identity.has(identity_key):
			state.identity[identity_key] = 0.0
	if not state.has("identityLastTop"):
		state["identityLastTop"] = []
	# Migration Quest-Journal (Chunk 17)
	if not state.has("quests") or not (state.quests is Array):
		state["quests"] = []
	# Migration RPG-Attribute (Chunk 15): fehlende Werte mit Basis nachrüsten
	if not state.has("attributes") or not (state.attributes is Dictionary):
		state["attributes"] = {}
	for attr_key in Data.ATTRIBUTES:
		if not state.attributes.has(attr_key):
			state.attributes[attr_key] = Balance.ATTR_BASE
	if not state.has("powerFigures"):
		state["powerFigures"] = []
	# Migration Spielfigur-Cluster
	Persona.ensure_player()
	Persona.ensure_contacts()
	# Migration Empire-Cluster (Features 5–9: Estate, Skills, Invest, Backroom, Endgame)
	Mogul.ensure_all()
	# Migration Netzwerk-Cluster (Features 10–15: Memoir, Dimensionen, Gatekeeper)
	Network.ensure_network()
	# Migration Korrespondenz (Dialogsystem & Posteingang)
	Dialogs.ensure_inbox()
	# Migration Mitarbeiter & Delegation (Features 32–36)
	Staff.ensure_staff()
	# Migration Simulations- & Verhandlungs-Cluster
	if not state.has("instinct"):
		state["instinct"] = 20
	if not state.has("predictions"):
		state["predictions"] = []
	if not state.has("history_pairs"):
		state["history_pairs"] = {}
	if not state.has("audition"):
		state["audition"] = null
	if not state.has("directors") or not (state.directors is Dictionary):
		state["directors"] = {}
	if not state.has("scoutBonus"):
		state["scoutBonus"] = 0
	if not state.has("planner"):
		state["planner"] = {"player": _empty_week(), "clients": {}}
	if not state.planner.has("player"):
		state.planner["player"] = _empty_week()
	if not state.planner.has("clients"):
		state.planner["clients"] = {}
	# Migration Bewertungs-Cluster (Coverage & Karrierebretter)
	if not state.has("coverage") or not (state.coverage is Dictionary):
		state["coverage"] = {"current": null, "history": []}
	if not state.coverage.has("current"):
		state.coverage["current"] = null
	if not state.coverage.has("history"):
		state.coverage["history"] = []
	if not state.has("coverageQueue"):
		state["coverageQueue"] = 0
	# Migration: alter Netzwerk-Wert wird in konkrete Gefallen umgewandelt
	# (pro 15 Punkte ein Gefallen), das Feld danach entfernt.
	if state.has("network"):
		var nw := int(state.network)
		var cnt := nw / 15
		for i in cnt:
			var kind_s: String = Util.pick(["extraAudition", "suppressStory", "scriptAccess", "billing", "galaInvite"])
			grant_favor(kind_s, favor_contact_for(kind_s), true)
		state.erase("network")
		if cnt > 0:
			log_msg("Old acquaintances from the early days get in touch: %d open favors await you." % cnt, "history")
	for c in state.clients:
		if not c.has("dna"):
			c["dna"] = CareerDNA.initial_dna(actor_by_id[c.aid])
		if not c.has("weightKg"):
			c["weightKg"] = client_base_weight(c)
		else:
			c["weightKg"] = clamp_client_weight(c, float(c.weightKg))
		if not c.has("weightTrend"):
			c["weightTrend"] = 0.0
		if not c.has("clauses"):
			c["clauses"] = []
		if not c.has("exclusiveStudio"):
			c["exclusiveStudio"] = ""
		if not c.has("trust"):
			c["trust"] = 30.0
		if not c.has("trustCap"):
			c["trustCap"] = 100.0
		if not c.has("secrets"):
			c["secrets"] = []
		if not c.has("secretThresholds"):
			c["secretThresholds"] = []
		if not c.has("narrative"):
			c["narrative"] = {}
		if not c.has("fameHistory"):
			c["fameHistory"] = [{"mi":mi(), "v":float(c.fame)}]
		if not c.has("dnaHistory"):
			c["dnaHistory"] = [{"mi":mi(), "romantik":float(c.dna.romantik), "popular":float(c.dna.popular), "verlass":float(c.dna.verlass), "unikat":float(c.dna.unikat), "familie":float(c.dna.familie)}]
		# Migration: Karrierebrett (3 Plan-Slots pro Klient)
		if not c.has("careerBoard") or not (c.careerBoard is Dictionary):
			c["careerBoard"] = {"slots": [], "startedMi": mi(), "completed": 0}
		if not c.careerBoard.has("slots"):
			c.careerBoard["slots"] = []
		if not c.careerBoard.has("startedMi"):
			c.careerBoard["startedMi"] = mi()
		for slot in c.careerBoard.slots:
			if not slot.has("filledMi"):
				slot["filledMi"] = -1
			if not slot.has("createdMi"):
				slot["createdMi"] = int(c.careerBoard.startedMi)
	var carrier_migration := {"Schauspieler": "Actors", "Assistenten": "Assistants", "Journalisten": "Journalists", "Regisseure": "Directors", "Partygäste": "Party guests"}
	var verdict_migration := {"Achtbarer Erfolg": "Solid success"}
	for f2 in state.released:
		if verdict_migration.has(str(f2.get("verdict", ""))):
			f2.verdict = verdict_migration[str(f2.verdict)]
	for c2 in state.clients:
		for f2 in c2.get("films", []):
			if verdict_migration.has(str(f2.get("verdict", ""))):
				f2.verdict = verdict_migration[str(f2.verdict)]
	for rumor in state.rumors:
		var holders_new: Array = []
		for h in rumor.get("holders", []):
			holders_new.append(carrier_migration.get(str(h), str(h)))
		rumor.holders = holders_new
		if not rumor.has("impactApplied"):
			rumor["impactApplied"] = false
		if not rumor.has("sourceSecret"):
			rumor["sourceSecret"] = ""
		if not rumor.has("industryBelief"):
			rumor["industryBelief"] = float(rumor.get("belief", 0.0))
		if not rumor.has("industryImpactApplied"):
			rumor["industryImpactApplied"] = false
	for rival in state.rivals:
		if not rival.has("clients"):
			rival["clients"] = []
		if not rival.has("grudge"):
			rival["grudge"] = 0.0
		if not rival.has("rel"):
			rival["rel"] = 0.0
		if not rival.has("studioId"):
			var studios := active_studios()
			rival["studioId"] = str(studios[0].id) if studios.size() else ""
	for figure in state.powerFigures:
		if not figure.has("agencyFriendly"):
			figure["agencyFriendly"] = true
		if not figure.has("rivalId"):
			figure["rivalId"] = ""
		if not figure.has("credits"):
			figure["credits"] = 0


# =====================================================================
# Simulations- & Verhandlungs-Cluster
# (Instinkt-Prognosen · Vertragsklauseln · Mehrparteien-Verhandlung ·
#  Beziehungschemie · Produktionssignale · Weekly Planner · Epochen-Regeln)
# =====================================================================

var table = null

# ---------- Feature 8: Vertragsklauseln ----------
# Klauseln erzeugen keine Zahlenboni, sondern zukünftige Ereignisse.
const CLAUSES = {
	"sequelOption": {"name": "Sequel option", "desc": "The studio may demand sequels at the old fee — risky after a hit"},
	"escalator": {"name": "Fee escalator", "desc": "+15% fee with every new role — studios hesitate to re-cast"},
	"creativeApproval": {"name": "Creative veto", "desc": "Client declines roles with fit < 35 (like script approval)"},
	"moralClause": {"name": "Morality clause", "desc": "On a scandal (rumor at 60+ credibility) the studio may cancel penalty-free"},
	"profitShare": {"name": "Profit participation", "desc": "Fixed fee −20%, in exchange a share of the surplus above twice the budget"},
	"likenessRights": {"name": "Likeness rights", "desc": "A digital likeness of the client — a battleground from 2015 on"},
	"endorsement": {"name": "Endorsement deal", "desc": "Monthly extra income, family image +, mood −"},
}

func clause_available(clause_id: String) -> bool:
	if clause_id == "likenessRights":
		return state != null and int(state.year) >= 1995
	return CLAUSES.has(clause_id)

func clause_label(clause_id: String) -> String:
	return str(CLAUSES.get(clause_id, {}).get("name", clause_id))

# ---------- Feature 6: Instinkt & Prognosen ----------
# state.instinct wächst NUR durch richtige Spieler-Prognosen.
func add_prediction(type_s: String, subject, guess, due_mi: int, note_s: String = "") -> Dictionary:
	var pr := {"id": next_id(), "type": type_s, "subject": subject, "guess": guess,
		"dueMi": due_mi, "resolved": false, "correct": false, "note": note_s, "madeMi": mi()}
	state.predictions.append(pr)
	log_msg("Prediction noted: %s" % note_s, "info")
	return pr

# (a) Drehbeginn: „Wird das ein Hit (ratio ≥ 2)?“
func hit_prediction_event(prod: Dictionary, c: Dictionary) -> Dictionary:
	var pid := int(prod.id)
	var title_s := str(prod.title)
	var name_s := client_name(c)
	return {"title": "Gut check: “%s”" % title_s,
		"text": "[i]“On the first day of shooting everyone pretends to know what this will become. Nobody knows.”[/i]\n\n“%s” with %s goes into production. Your call: will the film be a hit (box office ≥ 2× budget)?\n\nCorrect predictions sharpen your instinct (%d/100). Staying silent costs nothing." % [title_s, name_s, int(state.get("instinct", 20))],
		"choices": [
			{"label": "Yes, this will be a hit", "fn": func():
				add_prediction("hit", pid, true, mi() + 30, "“%s” will be a hit" % title_s)
				return "Noted. At the premiere we'll see whether your gut was right."},
			{"label": "No, more likely a flop", "fn": func():
				add_prediction("hit", pid, false, mi() + 30, "“%s” will not be a hit" % title_s)
				return "Noted. At the premiere we'll see whether your gut was right."},
			{"label": "No call", "fn": func(): return "You keep your cards close — not every premiere needs a bet."},
		]}

# (b) Signing unter Ruhm 40: „Zukünftiger Star (Ruhm 70 in 8 Jahren)?“
func star_prediction_event(c: Dictionary) -> Dictionary:
	var cid := int(c.id)
	var name_s := client_name(c)
	return {"title": "Gut check: %s" % name_s,
		"text": "[i]“That one might become something — or not.”[/i]\n\nYou signed %s at fame %d. Your call: does %s reach fame 70 within 8 years?\n\nCorrect predictions sharpen your instinct (%d/100). Staying silent costs nothing." % [name_s, roundi(c.fame), name_s, int(state.get("instinct", 20))],
		"choices": [
			{"label": "Yes, a future star", "fn": func():
				add_prediction("star", cid, true, mi() + 96, "%s reaches fame 70" % name_s)
				return "Noted. In eight years at the latest, we'll know."},
			{"label": "No, probably not", "fn": func():
				add_prediction("star", cid, false, mi() + 96, "%s stays below fame 70" % name_s)
				return "Noted. In eight years at the latest, we'll know."},
			{"label": "No call", "fn": func(): return "You keep your cards close."},
		]}

func pop_pending_star_prediction() -> Variant:
	if not state.has("pendingStarPrediction"):
		return null
	var cid = state.pendingStarPrediction
	state.erase("pendingStarPrediction")
	var c = client(cid)
	return star_prediction_event(c) if c != null else null

# (c) Casting mit 2+ passenden Klienten: „Wer passt besser?“
func note_betterfit_prediction(chosen_c: Dictionary, alt_c: Dictionary, casting_id: int) -> void:
	add_prediction("betterfit",
		{"prodId": casting_id, "chosen": int(chosen_c.id), "other": int(alt_c.id), "otherFame": float(alt_c.fame)},
		true, mi() + 30, "%s fits better than %s" % [client_name(chosen_c), client_name(alt_c)])

func _resolve_prediction(pr: Dictionary, correct: bool, label: String) -> void:
	pr["resolved"] = true
	pr["correct"] = correct
	if correct:
		state.instinct = clampi(int(state.instinct) + 3, 0, 100)
		attr_gain("menschenkenntnis", 0.5)
		state.agency.rep = clampi(int(state.agency.rep) + 1, 0, 100)
		log_msg("Prediction confirmed: %s — instinct +3, reputation +1." % label, "deal")
	else:
		state.instinct = maxi(5, int(state.instinct) - 1)
		log_msg("Prediction missed: %s — instinct −1." % label, "info")

# Auflösung beim Release (Hit-Wette, „Wer passt besser?“, Coverage-Marker)
func _resolve_release_predictions(prod: Dictionary, ratio: float, fame_deltas: Dictionary, quality: int = -1) -> void:
	for pr in state.get("predictions", []):
		if pr.get("resolved", false):
			continue
		if str(pr.type) == "hit" and int(pr.subject) == int(prod.id):
			_resolve_prediction(pr, (ratio >= 2.0) == bool(pr.guess), "“%s” (%s)" % [prod.title, "hit" if ratio >= 2.0 else "no hit"])
		elif str(pr.type) == "betterfit" and int(pr.subject.get("prodId", -1)) == int(prod.id):
			var chosen_delta := float(fame_deltas.get(int(pr.subject.get("chosen", -1)), 0.0))
			var other_c = client(pr.subject.get("other", -1))
			var other_delta := (float(other_c.fame) - float(pr.subject.get("otherFame", 0.0))) if other_c != null else -99.0
			_resolve_prediction(pr, (chosen_delta >= other_delta) == bool(pr.guess), str(pr.get("note", "casting prediction")))
		elif str(pr.type) == "coverage" and int(pr.subject.get("castingId", -1)) == int(prod.id):
			_resolve_coverage_prediction(pr, prod, ratio, quality)

# Monatstakt: Star-Prognosen verfallen nach 8 Jahren; Sicherheits-Verfall ohne Strafe
func tick_predictions(_events: Array) -> void:
	for pr in state.get("predictions", []):
		if pr.get("resolved", false):
			continue
		match str(pr.type):
			"star":
				if mi() >= int(pr.dueMi):
					var c = client(pr.subject)
					var fame_now := float(c.fame) if c != null else 0.0
					_resolve_prediction(pr, (fame_now >= 70.0) == bool(pr.guess), str(pr.get("note", "star prediction")))
			"hit", "betterfit", "coverage":
				if mi() >= int(pr.dueMi) + 12:
					pr["resolved"] = true

# Instinkt-Wirkung: engere Noten-Spannweite im Talentpool (9 → bis 4)
func pool_spread() -> float:
	var base := 9.0 - float(state.get("instinct", 20)) / 100.0 * 5.0
	base -= float(state.get("scoutBonus", 0))
	# Spezialisierung (Feature 42): der Meister-Scout schätzt fast exakt
	if Mogul.has_ability("master_scout"):
		base -= 2.0
	return clampf(base, 2.0, 9.0)

# Bauchgefühl-Hinweis bei hohem Instinkt (ab 55) — oder mit trainiertem Bauch (Feature 6)
func gut_feeling(casting: Dictionary) -> String:
	var trained := Mogul.has_ability("gut_plus")
	if int(state.get("instinct", 20)) < (40 if trained else 55):
		return ""
	var base := 35 + int(casting.prestige) * 8 + (Util.hashs(str(casting.id) + "scr") % 21)
	var precise := " (script feels like a %d/100)" % base if trained else ""
	if base >= 62:
		return "🧠 Your gut says: hit material.%s" % precise
	if base <= 48:
		return "🧠 Your gut says: smells like a flop.%s" % precise
	return "🧠 Your gut says: could go either way.%s" % precise

# ---------- Feature 12: Beziehungschemie ----------
# Paarweise, deterministisch aus Util.hashs() + gespeicherte gemeinsame Historie.
func pair_key(a_key: String, b_key: String) -> String:
	return "%s|%s" % [a_key, b_key] if a_key < b_key else "%s|%s" % [b_key, a_key]

# ---------- Roster-Beziehungen: Power-Couples & Feuds ----------
# Monatlich: Paare im eigenen Roster mit starker persönlicher Chemie und
# gemeinsamer Filmhistorie werden zum Thema — im Guten wie im Schlechten.
func _tick_roster_pairs(events: Array) -> void:
	for i in state.clients.size():
		for j in range(i + 1, state.clients.size()):
			var c1: Dictionary = state.clients[i]
			var c2: Dictionary = state.clients[j]
			var seen_key := "pairSeen_" + str(c2.aid)
			if c1.flags.get(seen_key, false):
				continue
			var chem := chemistry(str(c1.aid), str(c2.aid))
			var films_together := int(state.history_pairs.get(pair_key(str(c1.aid), str(c2.aid)), {}).get("n", 0))
			if int(chem.personal) >= Balance.PAIR_COUPLE_CHEM and films_together >= Balance.PAIR_COUPLE_FILMS:
				c1.flags[seen_key] = true
				events.append(_couple_event(c1, c2))
			elif int(chem.personal) <= Balance.PAIR_FEUD_CHEM and films_together >= 1:
				c1.flags[seen_key] = true
				c1.flags["feudWith"] = str(c2.aid)
				c2.flags["feudWith"] = str(c1.aid)
				c1.mood = clampf(float(c1.mood) - 6.0, 0.0, 100.0)
				c2.mood = clampf(float(c2.mood) - 6.0, 0.0, 100.0)
				press_event("Blind item", "Which two stars of the same agency can no longer stand in the same room?")
				log_msg("Feud in the house: %s and %s refuse to be cast together." % [client_name(c1), client_name(c2)], "bad")
				events.append({"title": "Bad blood", "text": "It started with a borrowed dressing room and ended with thrown scripts: [b]%s[/b] and [b]%s[/b] are done with each other. From now on, neither accepts a picture the other is in." % [client_name(c1), client_name(c2)], "choices": [{"label": "Noted"}]})


func _couple_event(c1: Dictionary, c2: Dictionary) -> Dictionary:
	var cid1 := int(c1.id)
	var cid2 := int(c2.id)
	return {"title": "More than chemistry",
		"text": "The set photographers saw it first, the maître d' confirmed it: [b]%s[/b] and [b]%s[/b] are inseparable. The question is not whether the town finds out — only who tells the story." % [client_name(c1), client_name(c2)],
		"choices": [
			{"label": "Announce Hollywood's newest royal couple", "fn": func():
				var a = client(cid1)
				var b = client(cid2)
				if a == null or b == null:
					return "The moment has passed."
				for cl in [a, b]:
					cl.flags["coupleWith"] = str((b if cl == a else a).aid)
					cl.heat = clampf(float(cl.heat) + 2.0, -10.0, 10.0)
					cl.fame = clampf(float(cl.fame) + 1.5, 5.0, 100.0)
					cl.dna.romantik = clampf(float(cl.dna.romantik) + 4.0, -100.0, 100.0)
					cl.dna.familie = clampf(float(cl.dna.familie) + 3.0, -100.0, 100.0)
				press_event("Cover story", "%s and %s — Hollywood's new royal couple" % [client_name(a), client_name(b)])
				return "Two careers, one headline. The fan mail doubles overnight — studios already ask for a picture with both names above the title."},
			{"label": "Guard their privacy", "fn": func():
				record_identity("diskret", 0.5)
				return "Some things in this town stay yours only as long as nobody prints them. You make sure nobody prints this."},
		]}


func chemistry(a_key: String, b_key: String) -> Dictionary:
	var k := pair_key(a_key, b_key)
	var screen := (Util.hashs(k + "scr") % 21) - 10
	var personal := (Util.hashs(k + "per") % 21) - 10
	var hist: Dictionary = state.get("history_pairs", {}).get(k, {})
	personal = clampi(personal + int(hist.get("p", 0)), -10, 10)
	return {"screen": screen, "personal": personal}

func note_pair_history(a_key: String, b_key: String, personal_delta: int, success: float = -1.0, title_s: String = "") -> void:
	var k := pair_key(a_key, b_key)
	var hist: Dictionary = state.history_pairs.get(k, {"n": 0, "p": 0})
	hist["n"] = int(hist.get("n", 0)) + 1
	hist["p"] = clampi(int(hist.get("p", 0)) + personal_delta, -8, 8)
	if success >= 0.0:
		hist["successSum"] = float(hist.get("successSum", 0.0)) + success
		hist["lastSuccess"] = success
	if title_s != "":
		hist["lastTitle"] = title_s
	state.history_pairs[k] = hist
	while state.history_pairs.size() > 120:
		state.history_pairs.erase(state.history_pairs.keys()[0])

func _person_key_for_role(r: Dictionary) -> String:
	if r.filled == null:
		return ""
	if r.filled.get("clientId") != null:
		var c = client(r.filled.clientId)
		return str(c.aid) if c != null else ""
	return "npc:" + str(r.filled.get("name", "?"))

func _director_key(prod_or_casting: Dictionary) -> String:
	if prod_or_casting.has("director"):
		var d = prod_or_casting.director
		if d is Dictionary:
			return "dir:" + str(d.get("name", "?"))
		return "dir:" + str(d)
	return "dir:" + str(Data.CONTACT_PERSONS.regisseur[Util.hashs(str(prod_or_casting.get("title", prod_or_casting.get("id", 0)))) % Data.CONTACT_PERSONS.regisseur.size()])

func _director_name_for(casting: Dictionary) -> String:
	var k := _director_key(casting)
	return k.substr(4)

func _prod_people_keys(prod: Dictionary, leads_only: bool) -> Array:
	var keys: Array = []
	for r in prod.roles:
		if leads_only and str(r.type) != "lead":
			continue
		var k := _person_key_for_role(r)
		if k != "" and not keys.has(k):
			keys.append(k)
	var dir_key := _director_key(prod)
	if dir_key != "" and not keys.has(dir_key):
		keys.append(dir_key)
	return keys

# =====================================================================
# Bühnen-Cluster: Das entscheidende Vorsprechen · Der Chemistry Read
# =====================================================================

func audition_available(casting: Dictionary, role: Dictionary) -> bool:
	if role == null or role.get("filled") != null:
		return false
	return (str(role.get("type", "")) == "lead" and int(casting.get("prestige", 0)) >= 2) \
		or (str(role.get("type", "")) == "support" and bool(casting.get("auditionSupport", false)))

func audition_choice_label(casting: Dictionary, dim: String, value: String) -> String:
	if dim == "scene":
		var genre_s := str(Data.GENRES.get(str(casting.get("genre", "drama")), {}).get("label", "film"))
		return {
			"speech": "the big %s speech" % genre_s,
			"quiet": "the quiet moment",
			"confrontation": "the confrontation",
		}.get(value, value)
	return str(AUDITION_LABELS.get(dim, {}).get(value, value))

func audition_profile(director_name: String, prod_title: String) -> Dictionary:
	var profile := {}
	var seed_s := director_name + prod_title
	for dim in AUDITION_DIMS:
		var values: Array = AUDITION_OPTIONS[dim]
		profile[dim] = str(values[Util.hashs(seed_s + ":" + dim) % values.size()])
	return profile

func audition_competition(casting: Dictionary, role: Dictionary) -> Array:
	var out: Array = []
	for rival in state.get("rivals", []):
		for aid in rival.get("clients", []):
			var actor: Dictionary = actor_by_id.get(str(aid), {})
			if actor.is_empty() or str(actor.get("g", "")) != str(role.get("gender", "")):
				continue
			var age := Util.age_of(actor, state.year)
			if age < int(role.get("ageMin", 18)) - 6 or age > int(role.get("ageMax", 99)) + 8:
				continue
			var image_c := {"dna": CareerDNA.initial_dna(actor)}
			out.append({"name":str(actor.name), "aid":str(actor.id), "agency":str(rival.name),
				"image":CareerDNA.dna_label(image_c), "talent":float(actor.talent), "fame":float(Util.fame_at(actor, state.year))})
	out.sort_custom(func(a, b): return Util.hashs(str(a.aid) + str(casting.title)) < Util.hashs(str(b.aid) + str(casting.title)))
	if out.is_empty():
		var fallback: Array = available_actors().filter(func(a): return str(a.g) == str(role.get("gender", "")))
		if fallback.size():
			var actor: Dictionary = fallback[Util.hashs(str(casting.title) + "competition") % mini(8, fallback.size())]
			out.append({"name":str(actor.name), "aid":str(actor.id), "agency":"Studio favorite",
				"image":CareerDNA.dna_label({"dna":CareerDNA.initial_dna(actor)}), "talent":float(actor.talent), "fame":float(Util.fame_at(actor, state.year))})
	return out.slice(0, 2)

func _audition_reveal(source_s: String) -> Variant:
	if state.get("audition") == null:
		return null
	var aud: Dictionary = state.audition
	var casting = _casting(aud.castingId)
	if casting == null:
		return null
	var director_name := _director_name_for(casting)
	var profile := audition_profile(director_name, str(casting.title))
	var used: Array = aud.get("revealed", []).map(func(h): return str(h.get("dim", "")))
	var start := Util.hashs(str(casting.title) + source_s + str(aud.clientId)) % AUDITION_DIMS.size()
	for offset in AUDITION_DIMS.size():
		var dim: String = str(AUDITION_DIMS[(start + offset) % AUDITION_DIMS.size()])
		if used.has(dim):
			continue
		var hint := {"dim":dim, "value":str(profile[dim]), "source":source_s}
		aud.revealed.append(hint)
		return hint
	return null

func begin_audition(casting_id: int, role_idx: int, client_id: int) -> Dictionary:
	var casting = _casting(casting_id)
	var c = client(client_id)
	if casting == null or c == null or role_idx < 0 or role_idx >= casting.roles.size():
		return {"ok":false, "msg":"This audition is no longer available."}
	var role: Dictionary = casting.roles[role_idx]
	if not audition_available(casting, role) or not is_free(c):
		return {"ok":false, "msg":"This audition is no longer available."}
	var eligible := eligible_clients(casting, role).any(func(e): return int(e.c.id) == client_id)
	if not eligible:
		return {"ok":false, "msg":"The client does not match the advertised role."}
	state.audition = {"castingId":casting_id, "roleIdx":role_idx, "clientId":client_id,
		"step":0, "choices":{}, "revealed":[]}
	var director_name := _director_name_for(casting)
	var dir_chem := chemistry("dir:" + director_name, str(c.aid))
	if int(dir_chem.personal) > 3:
		_audition_reveal("chemistry")
	if int(state.get("instinct", 20)) >= 60:
		_audition_reveal("instinct")
	return {"ok":true, "director":director_name, "competition":audition_competition(casting, role),
		"prepLimit":audition_preparation_limit(c), "archive":director_archive_hint(director_name)}

func audition_preparation_limit(c: Dictionary) -> int:
	ensure_planner()
	var slots: Array = state.planner.clients.get(str(int(c.id)), [])
	var planned := slots.any(func(s): return s != null and str(s.get("a", "")) == "vorbereitung")
	return 3 if planned or float(c.flags.get("prepFit", 0.0)) > 0.0 else 2

func audition_begin_choices() -> void:
	if state.get("audition") != null:
		state.audition.step = 1

func audition_reveal_script() -> Variant:
	if state.get("audition") == null or not consume_favor("scriptAccess"):
		return null
	return _audition_reveal("script")

func audition_choose(dim: String, value: String, prepared: bool) -> Dictionary:
	if state.get("audition") == null:
		return {"ok":false}
	var aud: Dictionary = state.audition
	var step := int(aud.get("step", 0))
	if step < 1 or step > AUDITION_DIMS.size() or str(AUDITION_DIMS[step - 1]) != dim:
		return {"ok":false}
	if not AUDITION_OPTIONS.get(dim, []).has(value):
		return {"ok":false}
	var c = client(aud.clientId)
	if c == null:
		return {"ok":false}
	var prepared_n := 0
	for choice in aud.choices.values():
		if bool(choice.get("prepared", false)):
			prepared_n += 1
	if prepared and prepared_n >= audition_preparation_limit(c):
		return {"ok":false, "msg":"All preparation slots are taken."}
	aud.choices[dim] = {"value":value, "prepared":prepared}
	aud.step = step + 1
	return {"ok":true, "done":int(aud.step) > AUDITION_DIMS.size()}

func director_archive_hint(director_name: String) -> String:
	var memory: Dictionary = state.get("directors", {}).get(director_name, {})
	var liked: Array = memory.get("liked", [])
	if liked.is_empty():
		return ""
	var first := str(liked[0]).split(":")
	if first.size() != 2:
		return ""
	return "🗞 Newspaper archive: on an earlier film it was noted that %s preferred %s." % [director_name,
		audition_choice_label({"genre":"drama"}, str(first[0]), str(first[1]))]

func audition_hint_text(casting: Dictionary, hint: Dictionary) -> String:
	var source_s := {"script":"Script access", "chemistry":"Director chemistry", "instinct":"Gut feeling"}.get(str(hint.get("source", "")), "Hint")
	return "%s: %s leans toward “%s” for %s." % [source_s, _director_name_for(casting),
		audition_choice_label(casting, str(hint.dim), str(hint.value)),
		{"scene":"the scene", "interpretation":"the interpretation", "appearance":"the appearance", "emphasis":"the emphasis"}.get(str(hint.dim), str(hint.dim))]

func _remember_director(director_name: String, profile: Dictionary) -> void:
	var liked: Array = []
	for dim in AUDITION_DIMS:
		liked.append("%s:%s" % [dim, str(profile[dim])])
	state.directors[director_name] = {"liked":liked, "lastSeen":mi()}

func audition_support_options(casting: Dictionary, c: Dictionary) -> Array:
	var out: Array = []
	var actor: Dictionary = actor_by_id[c.aid]
	for i in casting.roles.size():
		var role: Dictionary = casting.roles[i]
		if str(role.type) != "support" or role.filled != null or str(role.gender) != str(actor.g):
			continue
		out.append({"roleIdx":i, "fee":role_fee_for(casting, role, c)})
	return out

func resolve_audition(forced_outcome: String = "") -> Dictionary:
	if state.get("audition") == null:
		return {"ok":false, "msg":"No audition in progress."}
	var aud: Dictionary = state.audition
	var casting = _casting(aud.castingId)
	var c = client(aud.clientId)
	if casting == null or c == null or aud.choices.size() < AUDITION_DIMS.size():
		return {"ok":false, "msg":"The audition is incomplete."}
	var role: Dictionary = casting.roles[int(aud.roleIdx)]
	var director_name := _director_name_for(casting)
	var profile := audition_profile(director_name, str(casting.title))
	var matches := 0
	var prepared_n := 0
	var performance := 0.0
	for dim in AUDITION_DIMS:
		var choice: Dictionary = aud.choices[dim]
		var matched := str(choice.value) == str(profile[dim])
		if matched:
			matches += 1
		if bool(choice.prepared):
			prepared_n += 1
			performance += 18.0 if matched else 6.0
		else:
			var roll := float(Util.hashs("%s:%s:%s:%s" % [casting.title, c.aid, dim, choice.value]) % 11) - 5.0
			performance += (13.0 if matched else 3.0) + roll
	var setback := 0.0
	var setbacks: Dictionary = c.flags.get("auditionSetbacks", {})
	if setbacks.has(director_name):
		setback = float(setbacks[director_name])
		setbacks.erase(director_name)
		if setbacks.is_empty():
			c.flags.erase("auditionSetbacks")
		else:
			c.flags["auditionSetbacks"] = setbacks
	var own_score := performance + eff_talent(c) * 0.32 + CareerDNA.dna_fit(c, str(casting.genre), studio_style(str(casting.studioId))) * 0.65 \
		+ fit_score(casting, role, c) * 0.12 - setback
	var rivals := audition_competition(casting, role)
	var competition_score := 72.0
	for rival in rivals:
		competition_score = maxf(competition_score, 35.0 + float(rival.talent) * 0.38 + float(rival.fame) * 0.18 \
			+ float(Util.hashs(str(casting.title) + str(rival.aid) + "aud") % 17))
	var margin := own_score - competition_score
	var outcome := "win" if margin >= 0.0 else ("narrow" if margin >= -12.0 else "clear")
	if forced_outcome in ["win", "narrow", "clear"]:
		outcome = forced_outcome
	_remember_director(director_name, profile)
	var result := {"ok":true, "outcome":outcome, "margin":margin, "score":own_score,
		"competitionScore":competition_score, "matches":matches, "prepared":prepared_n,
		"director":director_name, "title":str(casting.title), "castingId":int(casting.id),
		"clientId":int(c.id), "roleIdx":int(aud.roleIdx), "profile":profile}
	if outcome == "win":
		pitch_ctx = {"casting":casting, "roleIdx":int(aud.roleIdx), "role":role, "client":c,
			"fee":roundi(role_fee_for(casting, role, c) * 1.10), "haggled":true, "alts":[]}
		close_deal(float(pitch_ctx.fee), " (audition: +10%)")
		note_pair_history("dir:" + director_name, str(c.aid), 2)
		if narrative_role_match(c, casting, role):
			c.narrative.progress = minf(100.0, float(c.narrative.get("progress", 0.0)) + 10.0)
			press_event("Careers", "%s wins the key role for the running career narrative" % client_name(c))
		press_event("Casting", "Who got the dream role? %s convinces %s in “%s”" % [client_name(c), director_name, casting.title])
		result["fee"] = int(role.filled.fee)
	elif outcome == "narrow":
		var fallbacks := audition_support_options(casting, c)
		result["fallbacks"] = fallbacks
		if fallbacks.is_empty():
			grant_favor("extraAudition", {"type":"studio", "name":str(_studio(str(casting.studioId)).name), "studioId":str(casting.studioId)})
			result["favor"] = true
		press_event("Casting", "Photo finish on “%s”: %s misses the dream role by a hair" % [casting.title, client_name(c)])
	else:
		if not c.flags.has("auditionSetbacks"):
			c.flags["auditionSetbacks"] = {}
		c.flags.auditionSetbacks[director_name] = 4.0
		result["setback"] = 4
		press_event("Casting", "Who got the dream role? On “%s” the competition prevails" % casting.title)
	state.audition = null
	return result

func audition_support_fallback(casting_id: int, client_id: int, role_idx: int) -> Dictionary:
	var casting = _casting(casting_id)
	var c = client(client_id)
	if casting == null or c == null or role_idx < 0 or role_idx >= casting.roles.size():
		return {"ok":false}
	var role: Dictionary = casting.roles[role_idx]
	if str(role.type) != "support" or role.filled != null:
		return {"ok":false}
	pitch_ctx = {"casting":casting, "roleIdx":role_idx, "role":role, "client":c,
		"fee":role_fee_for(casting, role, c), "haggled":true, "alts":[]}
	close_deal(float(pitch_ctx.fee), " (consolation prize after the audition)")
	return {"ok":true}

# ---------- Chemistry Read ----------
func _chem_role_indices(casting: Dictionary) -> Array:
	var leads: Array = []
	var other: Array = []
	for i in casting.roles.size():
		var role: Dictionary = casting.roles[i]
		if role.filled != null:
			continue
		if str(role.type) == "lead":
			leads.append(i)
		else:
			other.append(i)
	if leads.size() >= 2:
		return leads.slice(0, 2)
	if bool(casting.get("dreamPair", false)) and leads.size() == 1 and other.size():
		return [leads[0], other[0]]
	return []

func chem_read_available(casting: Dictionary) -> bool:
	var indices := _chem_role_indices(casting)
	return indices.size() == 2 and chem_read_candidate_pairs(int(casting.id)).size() >= 2

func _chem_pair_from_clients(_cs: Dictionary, role_indices: Array, a: Dictionary, b: Dictionary) -> Dictionary:
	return {"key":"%d|%d" % [int(a.c.id), int(b.c.id)], "npc":false,
		"aClientId":int(a.c.id), "bClientId":int(b.c.id),
		"aName":client_name(a.c), "bName":client_name(b.c),
		"aKey":str(a.c.aid), "bKey":str(b.c.aid),
		"aTalent":eff_talent(a.c), "bTalent":eff_talent(b.c),
		"aFit":float(a.fit), "bFit":float(b.fit), "roleIndices":role_indices.duplicate()}

func chem_read_candidate_pairs(casting_id: int) -> Array:
	var casting = _casting(casting_id)
	if casting == null:
		return []
	var indices := _chem_role_indices(casting)
	if indices.size() != 2:
		return []
	var left := eligible_clients(casting, casting.roles[int(indices[0])])
	var right := eligible_clients(casting, casting.roles[int(indices[1])])
	var out: Array = []
	for a in left:
		for b in right:
			if int(a.c.id) == int(b.c.id):
				continue
			out.append(_chem_pair_from_clients(casting, indices, a, b))
	out.sort_custom(func(a, b): return float(a.aFit) + float(a.bFit) > float(b.aFit) + float(b.bFit))
	return out.slice(0, 8)

func _chem_npc(casting: Dictionary, role: Dictionary) -> Dictionary:
	var pool: Array = available_actors().filter(func(a): return str(a.g) == str(role.gender))
	if pool.size():
		var actor: Dictionary = pool[Util.hashs(str(casting.title) + str(role.gender) + "chem_npc") % mini(8, pool.size())]
		return {"name":str(actor.name), "key":"npc:" + str(actor.name), "talent":float(actor.talent),
			"fame":float(Util.fame_at(actor, state.year))}
	var name_s := "%s %s" % [Util.pick(Data.NPC_FIRST_M) if str(role.gender) == "m" else Util.pick(Data.NPC_FIRST_F), Util.pick(Data.NPC_LAST)]
	return {"name":name_s, "key":"npc:" + name_s, "talent":55.0, "fame":25.0}

func chem_read_studio_pair(casting_id: int) -> Dictionary:
	var casting = _casting(casting_id)
	if casting == null:
		return {}
	var indices := _chem_role_indices(casting)
	if indices.size() != 2:
		return {}
	var own_left := eligible_clients(casting, casting.roles[int(indices[0])])
	var own_right := eligible_clients(casting, casting.roles[int(indices[1])])
	var own_on_left := own_left.size() > 0 and (own_right.is_empty() or Util.hashs(str(casting.title) + "studio_side") % 2 == 0)
	if own_on_left:
		var own: Dictionary = own_left[0]
		var npc := _chem_npc(casting, casting.roles[int(indices[1])])
		return {"key":"studio|%d|%s" % [int(own.c.id), str(npc.key)], "npc":true,
			"aClientId":int(own.c.id), "bClientId":null, "aName":client_name(own.c), "bName":str(npc.name),
			"aKey":str(own.c.aid), "bKey":str(npc.key), "aTalent":eff_talent(own.c), "bTalent":float(npc.talent),
			"aFit":float(own.fit), "bFit":52.0, "roleIndices":indices.duplicate(), "studioSuggestion":true}
	if own_right.size():
		var own2: Dictionary = own_right[0]
		var npc2 := _chem_npc(casting, casting.roles[int(indices[0])])
		return {"key":"studio|%s|%d" % [str(npc2.key), int(own2.c.id)], "npc":true,
			"aClientId":null, "bClientId":int(own2.c.id), "aName":str(npc2.name), "bName":client_name(own2.c),
			"aKey":str(npc2.key), "bKey":str(own2.c.aid), "aTalent":float(npc2.talent), "bTalent":eff_talent(own2.c),
			"aFit":52.0, "bFit":float(own2.fit), "roleIndices":indices.duplicate(), "studioSuggestion":true}
	return {}

func chemistry_signal(screen_value: int, with_noise: bool = true, seed_s: String = "") -> Dictionary:
	var true_sign := signi(screen_value)
	var shown_sign := true_sign
	var reliable := true
	if with_noise and true_sign != 0:
		reliable = Util.hashs(seed_s + "signal") % 100 < 75
		if not reliable:
			shown_sign = -true_sign
	var lines := {
		1: ["They finish each other's sentences without losing the rhythm.", "One glance is enough, and both find the same beat."],
		-1: ["One avoids the other's gaze; every pause feels a touch too long.", "The bodies keep their distance, even when the text demands closeness."],
		0: ["Professional and clean — but still without that spark you can't rehearse.", "The scene lands, but the air between them stays neutral."],
	}
	var choices: Array = lines[shown_sign]
	return {"text":str(choices[Util.hashs(seed_s + "prose") % choices.size()]), "sign":shown_sign, "reliable":reliable}

func chem_read_score(casting: Dictionary, pair: Dictionary, scene_s: String) -> float:
	var chem := chemistry(str(pair.aKey), str(pair.bKey))
	var screen := float(chem.screen)
	var personal := float(chem.personal)
	var scene_score := 0.0
	match scene_s:
		"love": scene_score = screen * 3.0 + personal * 0.6
		"conflict": scene_score = screen * 1.8 + maxf(0.0, -personal) * 1.5 + maxf(0.0, personal) * 0.35
		"comedy": scene_score = screen * 1.8 + personal * 1.5
	var individual := (float(pair.aTalent) + float(pair.bTalent)) * 0.18 + (float(pair.aFit) + float(pair.bFit)) * 0.12
	var roll := float(Util.hashs(str(casting.title) + str(pair.key) + scene_s + "chem_read") % 11) - 5.0
	return individual + scene_score + roll

func _chem_history_text(pair: Dictionary) -> String:
	var hist: Dictionary = state.history_pairs.get(pair_key(str(pair.aKey), str(pair.bKey)), {})
	var n := int(hist.get("n", 0))
	if n <= 0:
		return "No shared film in the archive yet."
	var avg := float(hist.get("successSum", 0.0)) / maxf(1.0, float(n))
	var verdict := "successful back then" if avg >= 2.0 else ("mixed back then" if avg >= 1.0 else "no box-office spark back then")
	return "%d shared production%s · %s%s" % [n, "s" if n != 1 else "", verdict,
		(" (most recently “%s”)" % str(hist.lastTitle)) if str(hist.get("lastTitle", "")) != "" else ""]

func _chem_personal_hint(pair: Dictionary) -> String:
	var subjects: Array = []
	for cid in [pair.get("aClientId"), pair.get("bClientId")]:
		if cid == null:
			continue
		var c = client(cid)
		if c != null:
			subjects.append(int(c.id))
			subjects.append(str(c.aid))
	var known: bool = state.get("rumors", []).any(func(r): return bool(r.get("knownToPlayer", false)) and subjects.has(r.get("subject")))
	if not known:
		return "The rumor network has no solid whisper about the two of them yet."
	var personal := int(chemistry(str(pair.aKey), str(pair.bKey)).personal)
	if personal >= 3:
		return "Assistants say the two kept talking even after the take."
	if personal <= -3:
		return "Word from the dressing rooms is that off camera, doors slammed a little too loudly."
	return "The rumors contradict each other — closeness and distance are evenly matched."

func begin_chem_read(casting_id: int, selected_keys: Array, scene_s: String) -> Dictionary:
	var casting = _casting(casting_id)
	if casting == null or not CHEM_READ_SCENES.has(scene_s) or selected_keys.size() != 2:
		return {"ok":false}
	var all_pairs := chem_read_candidate_pairs(casting_id)
	var selected: Array = []
	for pair in all_pairs:
		if selected_keys.has(str(pair.key)):
			selected.append(pair)
	if selected.size() != 2:
		return {"ok":false}
	var studio_pair := chem_read_studio_pair(casting_id)
	if not studio_pair.is_empty():
		selected.append(studio_pair)
	for pair in selected:
		pair["score"] = chem_read_score(casting, pair, scene_s)
		pair["signal"] = chemistry_signal(int(chemistry(str(pair.aKey), str(pair.bKey)).screen), true,
			str(casting.title) + str(pair.key) + scene_s)
		pair["historyText"] = _chem_history_text(pair)
		pair["personalHint"] = _chem_personal_hint(pair)
	chem_read = {"castingId":casting_id, "scene":scene_s, "pairs":selected}
	return {"ok":true, "scene":scene_s, "pairs":selected}

func _chem_fill_client(casting: Dictionary, role_idx: int, cid, bonus: float, extra_s: String) -> bool:
	if cid == null:
		return false
	var c = client(cid)
	if c == null:
		return false
	var role: Dictionary = casting.roles[role_idx]
	pitch_ctx = {"casting":casting, "roleIdx":role_idx, "role":role, "client":c,
		"fee":roundi(role_fee_for(casting, role, c) * bonus), "haggled":true, "alts":[]}
	close_deal(float(pitch_ctx.fee), extra_s)
	return true

func _chem_fill_npc(casting: Dictionary, role_idx: int, pair: Dictionary, side: String) -> void:
	var role: Dictionary = casting.roles[role_idx]
	var name_s := str(pair.get(side + "Name", "Studio favorite"))
	var talent := float(pair.get(side + "Talent", 55.0))
	role.filled = {"npc":true, "name":name_s, "talent":talent, "fame":roundi(talent * 0.65)}

func resolve_chem_read(chosen_key: String) -> Dictionary:
	if chem_read == null:
		return {"ok":false}
	var casting = _casting(chem_read.castingId)
	if casting == null:
		return {"ok":false}
	var pairs: Array = chem_read.pairs
	var ranked := pairs.duplicate()
	ranked.sort_custom(func(a, b): return float(a.score) > float(b.score))
	var chosen = null
	for pair in pairs:
		if str(pair.key) == chosen_key:
			chosen = pair
			break
	if chosen == null:
		return {"ok":false}
	var rank := ranked.find(chosen)
	var outcome := "best" if rank == 0 else ("worst" if rank == ranked.size() - 1 else "middle")
	var indices: Array = chosen.roleIndices
	var own_retained := false
	if outcome in ["best", "middle"]:
		var bonus := 1.12 if outcome == "best" else 1.0
		if chosen.aClientId != null:
			own_retained = _chem_fill_client(casting, int(indices[0]), chosen.aClientId, bonus, " (chemistry package%s)" % (": +12%" if outcome == "best" else "")) or own_retained
		else:
			_chem_fill_npc(casting, int(indices[0]), chosen, "a")
		if chosen.bClientId != null:
			own_retained = _chem_fill_client(casting, int(indices[1]), chosen.bClientId, bonus, " (chemistry package%s)" % (": +12%" if outcome == "best" else "")) or own_retained
		else:
			_chem_fill_npc(casting, int(indices[1]), chosen, "b")
		if outcome == "best":
			if not casting.has("signals"):
				casting["signals"] = []
			casting.signals.append({"t":"The chemistry is right", "pos":true, "mi":mi()})
	else:
		# Rückweg: Der stärkere eigene Name bleibt; nur die andere Rolle geht ans Studio.
		var keep_a := chosen.aClientId != null and (chosen.bClientId == null or float(chosen.aFit) >= float(chosen.bFit))
		if keep_a:
			own_retained = _chem_fill_client(casting, int(indices[0]), chosen.aClientId, 1.0, " (chemistry read: studio casts the partner role)")
			var replacement_b := _chem_npc(casting, casting.roles[int(indices[1])])
			var repl_pair_b := {"bName":replacement_b.name, "bTalent":replacement_b.talent}
			_chem_fill_npc(casting, int(indices[1]), repl_pair_b, "b")
		else:
			own_retained = _chem_fill_client(casting, int(indices[1]), chosen.bClientId, 1.0, " (chemistry read: studio casts the partner role)")
			var replacement_a := _chem_npc(casting, casting.roles[int(indices[0])])
			var repl_pair_a := {"aName":replacement_a.name, "aTalent":replacement_a.talent}
			_chem_fill_npc(casting, int(indices[0]), repl_pair_a, "a")
	var hist_delta := 1 if outcome == "best" else (0 if outcome == "middle" else -1)
	note_pair_history(str(chosen.aKey), str(chosen.bKey), hist_delta, 2.0 if outcome == "best" else (1.2 if outcome == "middle" else 0.6), str(casting.title))
	var names_s := "%s & %s" % [str(chosen.aName), str(chosen.bName)]
	press_event("Casting", "Chemistry read on “%s”: %s — %s" % [casting.title, names_s,
		"a dream pairing" if outcome == "best" else ("a solid cast" if outcome == "middle" else "the studio swaps out a name")])
	var result := {"ok":true, "outcome":outcome, "rank":rank, "pair":chosen,
		"ownRetained":own_retained, "castingId":int(casting.id)}
	chem_read = null
	return result

# Leinwandchemie der Leads fließt in die Qualität (±8)
func lead_chem_quality(prod: Dictionary) -> float:
	var keys := _prod_people_keys(prod, true).filter(func(k): return not str(k).begins_with("dir:"))
	var sum := 0.0
	var n := 0
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			sum += float(chemistry(str(keys[i]), str(keys[j])).screen)
			n += 1
	if n == 0:
		return 0.0
	return (sum / n) * 0.8

# Regisseur-Klient-Chemie (persönlich) wirkt auf die Qualität (±3)
func director_chem_quality(prod: Dictionary) -> float:
	var dk := _director_key(prod)
	var sum := 0.0
	var n := 0
	for r in prod.roles:
		var k := _person_key_for_role(r)
		if k == "" or k.begins_with("npc:"):
			continue
		sum += float(chemistry(dk, k).personal)
		n += 1
	if n == 0:
		return 0.0
	return (sum / n) * 0.3

# ---------- Feature 9: Mehrparteien-Verhandlung ----------
# Bei großen Hauptrollen sitzen Studio, Regisseur, Klient und ggf. ein
# zweiter Star am Tisch. Zufriedenheits-Scores, Vetos, begrenzte Punkte.
func needs_table(casting: Dictionary, role: Dictionary) -> bool:
	return str(role.type) == "lead" and (int(casting.prestige) >= 2 or float(casting.budget) >= float(role.fee) * 10.0)

func start_table() -> Dictionary:
	var casting: Dictionary = pitch_ctx.casting
	var role: Dictionary = pitch_ctx.role
	var c: Dictionary = pitch_ctx.client
	var dir_name := _director_name_for(casting)
	var chem_dir := chemistry("dir:" + dir_name, str(c.aid))
	var dna_v := CareerDNA.dna_fit(c, casting.genre, studio_style(str(casting.studioId)))
	table = {
		"castingId": int(casting.id), "roleIdx": int(pitch_ctx.roleIdx), "clientId": int(c.id),
		"fee": int(pitch_ctx.fee), "billing": 1, "clauses": [], "points": 3,
		"favorUsed": false, "chemUsed": false, "done": false,
		"parties": {
			"studio": {"name": _studio(str(casting.studioId)).name, "sat": 55.0, "veto": 20.0, "demand": "wants to push the fee down"},
			"director": {"name": dir_name, "sat": clampf(45.0 + float(chem_dir.personal) * 2.0 + dna_v, 5.0, 90.0), "veto": 25.0, "demand": "has a casting idea of their own"},
			"client": {"name": client_name(c), "sat": clampf(48.0 + float(actor_by_id[c.aid].ego) * 0.1, 5.0, 90.0), "veto": 20.0, "demand": "wants first billing & clauses"},
		},
	}
	# Bereits besetzter anderer Star will die erste Nennung
	for r in casting.roles:
		if str(r.type) == "lead" and r != role and r.filled != null:
			var sname := ""
			if r.filled.get("clientId") != null:
				var oc = client(r.filled.clientId)
				if oc != null:
					sname = client_name(oc)
			else:
				sname = str(r.filled.get("name", ""))
			if sname != "":
				table.parties["star"] = {"name": sname, "sat": 42.0, "veto": 25.0, "demand": "wants first billing in the credits"}
	return table

func _sat(party: String, delta: float) -> void:
	if not table.parties.has(party):
		return
	table.parties[party]["sat"] = clampf(float(table.parties[party].sat) + delta, 0.0, 100.0)

func table_concede(action: String, target: String = "") -> Dictionary:
	if table == null or table.get("done", false):
		return {"ok": false, "msg": "No negotiation table."}
	if action == "use_favor":
		if bool(table.favorUsed):
			return {"ok": false, "msg": "The favor has already been used."}
		if state.favors.is_empty():
			return {"ok": false, "msg": "No favor available."}
	elif action == "chem_argument":
		if bool(table.chemUsed):
			return {"ok": false, "msg": "The argument is spent."}
	elif int(table.points) < 1:
		return {"ok": false, "msg": "No concessions left."}
	match action:
		"fee_down":
			table.fee = roundi(float(table.fee) * 0.9)
			_sat("studio", 18.0)
			_sat("client", -12.0)
		"fee_up":
			table.fee = roundi(float(table.fee) * 1.1)
			_sat("client", 15.0)
			_sat("studio", -15.0)
		"billing_first":
			table.billing = 1
			_sat("client", 12.0)
			_sat("star", -22.0)
		"billing_second":
			table.billing = 2
			_sat("star", 20.0)
			_sat("client", -10.0)
		"clause":
			if target == "" or table.clauses.has(target):
				return {"ok": false, "msg": "This clause is already on the table."}
			table.clauses.append(target)
			_sat("client", 10.0)
			_sat("studio", -8.0)
		"use_favor":
			consume_any_favor()
			table["favorUsed"] = true
			_sat(target, 20.0)
		"chem_argument":
			table["chemUsed"] = true
			var c = client(table.clientId)
			var casting = _casting(table.castingId)
			if c != null and casting != null:
				var ch := chemistry("dir:" + str(table.parties.director.name), str(c.aid))
				var dv := CareerDNA.dna_fit(c, casting.genre, studio_style(str(casting.studioId)))
				_sat("director", 25.0 if (int(ch.personal) >= 0 or dv >= 3.0) else 5.0)
	if ["fee_down", "fee_up", "billing_first", "billing_second", "clause"].has(action):
		table["points"] = int(table.points) - 1
	return {"ok": true}

# Abschluss nur, wenn keine Partei unter ihrer Veto-Schwelle ist.
func close_table() -> Dictionary:
	if table == null:
		return {"success": false, "msg": "No negotiation table."}
	var veto_party := ""
	for pk in table.parties:
		if float(table.parties[pk].sat) < float(table.parties[pk].veto):
			veto_party = pk
			break
	if veto_party == "":
		var casting = _casting(table.castingId)
		if casting == null:
			table.done = true
			return {"success": false, "msg": "The project is no longer current."}
		close_deal(float(table.fee), " (multi-party deal)", table.clauses, int(table.billing))
		table.done = true
		return {"success": true}
	table.done = true
	# Rückwege: Nebenrolle, anderer Klient oder Rückzug ohne Zusatzschaden
	var fallbacks: Array = []
	var casting2 = _casting(table.castingId)
	if casting2 != null:
		for i in casting2.roles.size():
			var r: Dictionary = casting2.roles[i]
			if str(r.type) == "support" and r.filled == null:
				fallbacks.append({"kind": "support", "roleIdx": i})
		fallbacks.append({"kind": "other"})
	fallbacks.append({"kind": "withdraw"})
	return {"success": false, "veto": veto_party, "fallbacks": fallbacks}

# Trostpreis: dieselbe Klient:in in einer Nebenrolle (kein Zusatzschaden)
func table_support_fallback(role_idx: int) -> Dictionary:
	var casting = _casting(table.castingId)
	if casting == null or role_idx >= casting.roles.size():
		return {"ok": false}
	var role: Dictionary = casting.roles[role_idx]
	var c = client(table.clientId)
	if c == null:
		return {"ok": false}
	pitch_ctx = {"casting": casting, "roleIdx": role_idx, "role": role, "client": c, "fee": role_fee_for(casting, role, c), "haggled": true, "alts": []}
	close_deal(float(pitch_ctx.fee), " (consolation prize: supporting role)", [], 1)
	return {"ok": true}

func table_withdraw() -> void:
	pitch_ctx = null

# ---------- Feature 13: Produktionssignale ----------
const SIGNAL_GOOD = ["Glowing set reports", "Test screening surprises on the upside", "The chemistry on set is right", "Dailies thrill the studio"]
const SIGNAL_BAD = ["Bad dailies", "Budget overrun", "Rumors of reshoots", "Tension on set"]

# Versteckte Qualitätsbasis + Signal-Container anlegen
func _init_production_uncertainty(prod: Dictionary) -> void:
	var script_base := 35.0 + int(prod.prestige) * 8.0 + float(Util.hashs(str(prod.id) + "scr") % 21)
	var tq := script_base * 0.45
	var tn := 0.0
	var nn := 0
	for role in prod.roles:
		if role.filled == null:
			continue
		var cc = client(role.filled.get("clientId")) if role.filled.get("clientId") != null else null
		tn += eff_talent(cc) if cc != null else float(role.filled.get("talent", 50.0))
		nn += 1
	if nn > 0:
		tq += (tn / nn) * 0.5
	prod["trueQ"] = tq + float(prod.get("qualityMod", 0.0))
	if not prod.has("signals"):
		prod["signals"] = []
	if not prod.has("reactions"):
		prod["reactions"] = {}

func ensure_prod_fields(prod: Dictionary) -> void:
	# Wochen-Migration: alte Produktionen zählten in Monaten
	if not prod.has("weeksLeft"):
		prod["weeksLeft"] = int(prod.get("monthsLeft", 4)) * 4
		prod.erase("monthsLeft")
	if not prod.has("signals"):
		prod["signals"] = []
	if not prod.has("reactions"):
		prod["reactions"] = {}
	if not prod.has("trueQ"):
		prod["trueQ"] = 50.0

# Monatliche, UNZUVERLÄSSIGE Signale aus laufenden Produktionen
func _tick_signals(_events: Array, force: bool = false) -> void:
	var accuracy := 0.7 + float(state.get("instinct", 20)) / 500.0
	for prod in state.productions:
		ensure_prod_fields(prod)
		var has_client := false
		for r in prod.roles:
			if r.filled != null and r.filled.get("clientId") != null and client(r.filled.clientId) != null:
				has_client = true
		if not has_client:
			continue
		# Schlechte persönliche Chemie erhöht Set-Reibung (Feature 12)
		var keys := _prod_people_keys(prod, false)
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				if int(chemistry(str(keys[i]), str(keys[j])).personal) <= -5 and Util.chance(0.22):
					prod.qualityMod = float(prod.get("qualityMod", 0.0)) - 1.0
					for r2 in prod.roles:
						if r2.filled != null and r2.filled.get("clientId") != null:
							var cc2 = client(r2.filled.clientId)
							if cc2 != null:
								cc2.exhaustion = clampf(cc2.exhaustion + 6.0, 0.0, 100.0)
					log_msg("Tension on the set of “%s” — the shoot suffers from personal animosities." % prod.title, "bad")
		if not force and not Util.chance(0.75):
			continue
		var good_actual := float(prod.trueQ) >= 55.0
		var positive := good_actual == Util.chance(accuracy)
		prod.signals.append({"t": str(Util.pick(SIGNAL_GOOD if positive else SIGNAL_BAD)), "pos": positive, "mi": mi()})
		while prod.signals.size() > 4:
			prod.signals.pop_front()

func _production(pid) -> Variant:
	for prod in state.productions:
		if int(prod.id) == int(pid):
			return prod
	return null

func latest_signal_pos(prod: Dictionary) -> bool:
	ensure_prod_fields(prod)
	if prod.signals.is_empty():
		return true
	return bool(prod.signals[prod.signals.size() - 1].get("pos", true))

# Reaktion 1: Nachverhandeln (bei guten Signalen) — 1× pro Film
func prod_renegotiate(prod_id: int) -> String:
	var prod = _production(prod_id)
	if prod == null:
		return "This production no longer exists."
	ensure_prod_fields(prod)
	if bool(prod.reactions.get("reneg", false)):
		return "Already renegotiated — a second time would burst the frame."
	prod.reactions["reneg"] = true
	var p := 0.55 + float(state.studioRel[prod.studioId]) / 300.0
	if Util.chance(p):
		var gained := 0
		for r in prod.roles:
			if r.filled != null and r.filled.get("clientId") != null:
				var c = client(r.filled.clientId)
				if c != null:
					var extra := roundi(float(r.filled.get("fee", 0)) * 0.2 * float(c.commission) / 100.0)
					r.filled["fee"] = roundi(float(r.filled.get("fee", 0)) * 1.2)
					gained += extra
		if gained > 0:
			book(float(gained), "provision", "Renegotiation on good set signals (“%s”)" % prod.title)
		return "The studio gives in: +20%% fee on the running contracts (%s right away). Hit rumors want to be rewarded." % Util.fmt_money(gained)
	state.studioRel[prod.studioId] = clampi(int(state.studioRel[prod.studioId]) - 5, 0, 100)
	return "The studio blocks: “The contract stands.” The relationship cools noticeably."

# Reaktion 2: Klienten rausziehen (bei schlechten Signalen) — 1× pro Film
func prod_pull_client(prod_id: int) -> String:
	var prod = _production(prod_id)
	if prod == null:
		return "This production no longer exists."
	ensure_prod_fields(prod)
	if bool(prod.reactions.get("pull", false)):
		return "Already done — a second pull-out would destroy the film."
	var target = null
	var target_role = null
	for r in prod.roles:
		if r.filled != null and r.filled.get("clientId") != null:
			var cc = client(r.filled.clientId)
			if cc != null:
				target = cc
				target_role = r
				break
	if target == null:
		return "None of your own clients on board."
	prod.reactions["pull"] = true
	var sev := roundi(float(target_role.filled.get("fee", 0)) * 0.3)
	book(-float(sev), "abfindung", "Contract exit: %s (“%s”)" % [client_name(target), prod.title])
	target.busyUntil = mi()
	target.exhaustion = clampf(target.exhaustion - 20.0, 0.0, 100.0)
	state.studioRel[prod.studioId] = clampi(int(state.studioRel[prod.studioId]) - 8, 0, 100)
	target_role.filled = {"npc": true, "name": "Replacement cast", "talent": 55, "fame": 30}
	log_msg("%s exits “%s” — severance %s, the studio is annoyed." % [client_name(target), prod.title, Util.fmt_money(sev)], "bad")
	return "%s is out. Severance %s paid, the fame stays untouched — but %s will remember this." % [client_name(target), Util.fmt_money(sev), _studio(str(prod.studioId)).name]

# Reaktion 3: Beteiligung fordern (Wette auf Erfolg) — 1× pro Film
func prod_demand_share(prod_id: int) -> String:
	var prod = _production(prod_id)
	if prod == null:
		return "This production no longer exists."
	ensure_prod_fields(prod)
	if bool(prod.reactions.get("share", false)):
		return "The participation is already negotiated."
	prod.reactions["share"] = true
	var changed := false
	for r in prod.roles:
		if r.filled != null and r.filled.get("clientId") != null:
			var cl = client(r.filled.clientId)
			if cl != null:
				var cls: Array = r.filled.get("clauses", [])
				if not cls.has("profitShare"):
					cls.append("profitShare")
				r.filled["clauses"] = cls
				r.filled["fee"] = roundi(float(r.filled.get("fee", 0)) * 0.7)
				changed = true
	if not changed:
		return "None of your own clients on board."
	state.studioRel[prod.studioId] = clampi(int(state.studioRel[prod.studioId]) - 3, 0, 100)
	return "A bet on success: 30% of the fee moves into profit participation. If the film is a hit, the till rings twice."

# ---------- Weekly Planner ----------
# 7 Tage × 3 Tagesabschnitte (Vormittag/Nachmittag/Abend) = 21 Slots pro Woche.
# Flaches Array, Index = tag * 3 + abschnitt. Aufgelöst wird wöchentlich in
# end_week(); danach beginnt die Planung der neuen Woche leer.
const PLANNER_SLOTS := 21
const PLANNER_PARTS := ["Morning", "Afternoon", "Evening"]
const PLANNER_DAYS := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

const PLANNER_CLIENT = {
	"erholung": {"name": "Rest", "icon": "🌴", "desc": "Exhaustion −0.6 per slot"},
	"pr": {"name": "PR appointment", "icon": "📸", "desc": "Heat +0.08 per slot, small costs"},
	"training": {"name": "Training", "icon": "🎭", "desc": "Talent grows slowly"},
	"gala": {"name": "Gala", "icon": "🥂", "desc": "Evenings only: chance of favors & contacts"},
	"vorbereitung": {"name": "Preparation", "icon": "📖", "desc": "Next pitch: fit +8 (from 3 slots/week)"},
}
const PLANNER_PLAYER = {
	"scouting": {"name": "Scouting", "icon": "🔭", "desc": "Talent pool assessment gets sharper"},
	"dinner": {"name": "Studio dinner", "icon": "🍽", "desc": "Relations +0.2 per slot with the chosen studio"},
	"pflege": {"name": "Client care", "icon": "🤝", "desc": "Trust +0.15 per slot with the chosen client"},
	"presse": {"name": "Press work", "icon": "🗞", "desc": "Early rumor detection (from 2 slots/week)"},
	"buecher": {"name": "Check the books", "icon": "🧾", "desc": "Office costs −10% (from 3 slots/month)"},
	"weiterbildung": {"name": "Training", "icon": "📚", "desc": "From 3 slots/week your weakest attribute grows"},
}


func _empty_week() -> Array:
	var out: Array = []
	out.resize(PLANNER_SLOTS)
	return out

func ensure_planner() -> void:
	if not state.has("planner"):
		state["planner"] = {"player": _empty_week(), "clients": {}}
	if not state.planner.has("player"):
		state.planner["player"] = _empty_week()
	if not state.planner.has("clients"):
		state.planner["clients"] = {}
	while state.planner.player.size() < PLANNER_SLOTS:
		state.planner.player.append(null)
	if not state.has("plannerMonthCounts"):
		state["plannerMonthCounts"] = {}
	var clients: Dictionary = state.planner.clients
	for c in state.clients:
		var key := str(int(c.id))
		if not clients.has(key):
			clients[key] = _empty_week()
		while clients[key].size() < PLANNER_SLOTS:
			clients[key].append(null)
	for key in clients.keys().duplicate():
		if client(key) == null:
			clients.erase(key)

func planner_slot_set(who: String, cid: int, day: int, part: int, action, target = null) -> void:
	ensure_planner()
	var idx := clampi(day * 3 + part, 0, PLANNER_SLOTS - 1)
	var slot = null
	if action != null:
		slot = {"a": str(action)}
		if target != null:
			slot["t"] = str(target)
	if who == "player":
		state.planner.player[idx] = slot
	else:
		var key := str(cid)
		if not state.planner.clients.has(key):
			state.planner.clients[key] = _empty_week()
		state.planner.clients[key][idx] = slot

# Bequemlichkeit: eine Aktion in alle (oder alle leeren) Slots eines Tracks legen
func planner_fill(who: String, cid: int, action, target = null, only_empty: bool = true) -> void:
	ensure_planner()
	var track: Array = state.planner.player if who == "player" else state.planner.clients.get(str(cid), _empty_week())
	for idx in PLANNER_SLOTS:
		if only_empty and track[idx] != null:
			continue
		var day := int(idx / 3.0)
		var part := idx % 3
		if action != null and who != "player" and str(action) == "gala" and part != 2:
			continue  # Galas finden abends statt
		planner_slot_set(who, cid, day, part, action, target)

# Wöchentliche Auswertung in end_week() VOR den Ereignissen.
# Effekte sind pro Slot skaliert (÷21 gegenüber den alten Monats-Slots),
# damit ein voll geplanter Monat ≈ dem alten 4-Slot-Monat entspricht.
func _apply_planner(_events: Array) -> void:
	ensure_planner()
	var counts: Dictionary = state.get("plannerMonthCounts", {})
	var scouting := 0
	var presse := 0
	var weiterbildung := 0
	var dinner_slots: Dictionary = {}
	var pflege_slots: Dictionary = {}
	for s in state.planner.player:
		if s == null:
			continue
		var a := str(s.get("a", ""))
		counts[a] = int(counts.get(a, 0)) + 1
		match a:
			"scouting":
				scouting += 1
			"weiterbildung":
				weiterbildung += 1
			"dinner":
				var sid := str(s.get("t", ""))
				if sid != "":
					dinner_slots[sid] = int(dinner_slots.get(sid, 0)) + 1
			"pflege":
				var pcid := str(s.get("t", ""))
				if pcid != "":
					pflege_slots[pcid] = int(pflege_slots.get(pcid, 0)) + 1
			"presse":
				presse += 1
			"buecher":
				pass  # zählt über plannerMonthCounts in den Monatsabschluss
	# ~5 Scouting-Slots wirken wie früher eine ganze Scouting-Woche
	state["scoutBonus"] = clampi(roundi(scouting / 5.0), 0, 4)
	for sid in dinner_slots:
		if state.studioRel.has(sid):
			var delta := roundi(0.2 * float(dinner_slots[sid]) * backstory_mod("dinner_mult", 1.0))
			if delta > 0:
				state.studioRel[sid] = clampi(int(state.studioRel[sid]) + delta, 0, 100)
				log_msg("Studio dinner: the relationship with %s deepens (+%d)." % [_studio(str(sid)).name, delta], "deal")
	for pcid in pflege_slots:
		var pc = client(pcid)
		if pc != null:
			change_trust(pc, 0.15 * float(pflege_slots[pcid]))
	if presse >= maxi(1, 2 - int(backstory_mod("presse_slot_bonus", 0.0))):
		_planner_presse()
	# Weiterbildung (Chunk 15): ab 3 Slots wächst das schwächste Attribut —
	# kein gezieltes Pumpen, der Manager arbeitet an seiner Schwäche.
	if weiterbildung >= 3 and state.has("attributes") and not state.attributes.is_empty():
		var weakest := ""
		for attr_key in state.attributes:
			if weakest == "" or float(state.attributes[attr_key]) < float(state.attributes[weakest]):
				weakest = str(attr_key)
		attr_gain(weakest, 0.3)
	state["plannerMonthCounts"] = counts
	# Klienten-Wochen auswerten
	for c in state.clients:
		if not is_free(c):
			continue  # Dreh-Wochen sind automatisch belegt
		var slots: Array = state.planner.clients.get(str(int(c.id)), _empty_week())
		var week_counts: Dictionary = {}
		for s in slots:
			# Default-Autoplanung: Erholung bei Erschöpfung > 50, sonst PR
			var action := "erholung" if float(c.exhaustion) > 50.0 else "pr"
			if s != null:
				action = str(s.get("a", action))
			week_counts[action] = int(week_counts.get(action, 0)) + 1
		_planner_client_week(c, week_counts)
	# Die neue Woche beginnt mit leerem Plan
	state.planner.player = _empty_week()
	for key in state.planner.clients:
		state.planner.clients[key] = _empty_week()

func _planner_client_week(c: Dictionary, counts: Dictionary) -> void:
	var base_weight := client_base_weight(c)
	var weight_start := float(c.get("weightKg", base_weight))
	var weight_next := weight_start
	var n_erh := int(counts.get("erholung", 0))
	if n_erh > 0:
		c.exhaustion = clampf(c.exhaustion - 0.6 * n_erh, 0.0, 100.0)
	var n_pr := int(counts.get("pr", 0))
	if n_pr > 0:
		c.heat = clampf(c.heat + 0.08 * n_pr, -10.0, 10.0)
		book(-float(roundi(20.0 * n_pr * Util.infl(state.year))), "pr_recht", "PR appointments: %s" % client_name(c))
	var n_tr := int(counts.get("training", 0))
	if n_tr > 0:
		c.talentBonus = minf(10.0, float(c.get("talentBonus", 0.0)) + 0.015 * n_tr)
		weight_next = move_toward(weight_next, base_weight, 0.05 * n_tr)
	var n_gala := int(counts.get("gala", 0))
	if n_gala > 0:
		var gala_dir := -1.0 if weight_next < base_weight else 1.0
		weight_next += gala_dir * 0.02 * n_gala
		book(-float(roundi(60.0 * n_gala * Util.infl(state.year))), "events", "Gala evenings: %s" % client_name(c))
		# Höchstens ein Gefallen pro Woche — Galas sind kein Bauernhof
		if Util.chance(1.0 - pow(0.95, float(n_gala))):
			var kind_s: String = Util.pick(["galaInvite", "extraAudition", "billing"])
			grant_favor(kind_s, favor_contact_for(kind_s))
		else:
			c.heat = clampf(c.heat + 0.05 * n_gala, -10.0, 10.0)
	var n_vor := int(counts.get("vorbereitung", 0))
	if n_vor > 0:
		var fit := 8.0 * minf(1.0, float(n_vor) / 3.0)
		c.flags["prepFit"] = maxf(float(c.flags.get("prepFit", 0.0)), fit)
	if not is_equal_approx(weight_next, weight_start):
		change_client_weight(c, weight_next - weight_start)

func _planner_presse() -> void:
	# Gerücht-Früherkennung: das jüngste unbekannte Gerücht kommt auf den Tisch
	for rumor in state.get("rumors", []):
		if not rumor.get("knownToPlayer", false):
			rumor["knownToPlayer"] = true
			log_msg("Press work: your people hear early what is circulating about %s." % Scandal.rumor_subject_name(rumor), "info")
			return
	# Nichts Neues: das stärkste bekannte Gerücht verliert etwas Zugkraft
	var worst = null
	for rumor in state.get("rumors", []):
		if worst == null or float(rumor.belief) > float(worst.belief):
			worst = rumor
	if worst != null:
		worst.belief = maxf(0.0, float(worst.belief) - 5.0)


# =====================================================================
# Bewertungs-Cluster
# (Script Coverage · Das perfekte Rollen-Karrierebrett)
# =====================================================================

# ---------- Feature C: Script Coverage ----------
# Einmal im Monat (≈60 %, mindestens einmal pro Quartal) legt das Lektorat
# ein Coverage-Blatt auf den Schreibtisch: eine verdichtete Einschätzung zu
# einem Casting, das erst NÄCHSTEN Monat sichtbar ausgeschrieben wird.
# Der Spieler setzt wenige Marker (Prognosen) auf Aussagen des Blattes.

const COVERAGE_CATS = {
	"sicher":        {"name": "Safe role", "icon": "🛡", "desc": "The film won't flop: box office ≥ budget and quality ≥ 45."},
	"prestige":      {"name": "Prestige chance", "icon": "🎩", "desc": "Quality ≥ 62 — the critics will take notice. Marker grants +5 fit at the pitch."},
	"schwach":       {"name": "Weak script", "icon": "📉", "desc": "The box office stays below the budget (ratio < 1)."},
	"sleeper":       {"name": "Possible sleeper hit", "icon": "🌟", "desc": "A hit (≥ 2× budget) even though the script looks weak."},
	"schnitt":       {"name": "Danger: role gets cut", "icon": "✂", "desc": "The marked role falls victim to the final cut."},
	"problematisch": {"name": "Troubled production", "icon": "🌪", "desc": "Set friction and bad signals prevail."},
}

func _tick_coverage(_events: Array, strike: bool = false) -> void:
	if not state.has("coverage") or not (state.coverage is Dictionary):
		state["coverage"] = {"current": null, "history": []}
	# 1. Das aktuelle Blatt verfällt zum Monatsende → ins Archiv
	var cur = state.coverage.get("current")
	if cur != null and mi() >= int(cur.get("dueMi", 0)):
		_archive_coverage(cur)
		state.coverage["current"] = null
	# 2. Das verdeckte Coverage-Casting des Vormonats wird regulär sichtbar
	for cs in state.castings:
		if bool(cs.get("hidden", false)):
			cs["hidden"] = false
	if strike:
		return
	# 3. Neues Blatt? ~60 % pro Monat, garantiert mindestens einmal pro Quartal
	state["coverageQueue"] = int(state.get("coverageQueue", 0)) + 1
	if state.coverage.get("current") == null and (Util.chance(0.6) or int(state.coverageQueue) >= 3):
		_issue_coverage()

func _issue_coverage() -> void:
	state["coverageQueue"] = 0
	var casting := _make_casting()
	casting["hidden"] = true
	state.castings.append(casting)
	var role_idx := _coverage_role_idx(casting)
	var sheet := {
		"id": next_id(),
		"castingRef": int(casting.id),
		"title": str(casting.title), "genre": str(casting.genre),
		"studioId": str(casting.studioId), "prestige": int(casting.prestige),
		"logline": _coverage_logline(casting),
		"statements": _coverage_statements(casting, role_idx),
		"roleIdx": role_idx,
		"markersMax": 3 if int(state.get("instinct", 20)) >= 60 else 2,
		"createdMi": mi(), "dueMi": mi() + 1,
	}
	state.coverage["current"] = sheet
	log_msg("Coverage on your desk: “%s” (%s) — assessment until the end of the month, %d markers." % [sheet.title, _studio(str(casting.studioId)).name, int(sheet.markersMax)], "info")

# Referenzierte Rolle bestimmen (bevorzugt eine Nebenrolle) und das verdeckte
# Rollengrößen-Flag würfeln: klein geschriebene Parts landen eher im Schnitt.
func _coverage_role_idx(casting: Dictionary) -> int:
	var idx := 0
	for i in casting.roles.size():
		if str(casting.roles[i].type) == "support":
			idx = i
			break
	var role: Dictionary = casting.roles[idx]
	var risk := 0.15
	if str(role.type) == "support":
		risk += 0.2
	if int(role.minFame) <= 18:
		risk += 0.15
	role["cutRisk"] = Util.chance(risk)
	return idx

func _coverage_logline(casting: Dictionary) -> String:
	var studio: Dictionary = _studio(str(casting.studioId))
	var genre_label: String = Data.GENRES[str(casting.genre)].label
	var style_phrase := {"prestige": "with clear awards ambitions", "indie": "with modest risk and a big heart", "commercial": "built for the broad audience"}.get(str(studio.get("style", "commercial")), "built for the broad audience")
	var y := int(state.year)
	if y < 1970:
		return "LOGLINE: “%s” — a %s from the house of %s, %s." % [casting.title, genre_label, studio.name, style_phrase]
	if y >= 2010:
		return "Quick take: “%s” is the new %s from %s — %s, and everyone is already talking about it." % [casting.title, genre_label, studio.name, style_phrase]
	return "Logline: “%s” — a %s from %s, %s." % [casting.title, genre_label, studio.name, style_phrase]

# 4–6 kurze Aussagen: echte Indikatoren (Skriptbasis, Budget vs. Genre,
# Regie-Historie, geplante Klauseln, Rollengröße) plus Rauschen.
# Zuverlässigkeit ~70 %, steigt mit Instinkt (wie script_insight).
func _coverage_statements(casting: Dictionary, role_idx: int) -> Array:
	var rel := 0.7 + float(state.get("instinct", 20)) / 1000.0
	var pool: Array = []
	# 1. Verdeckte Skriptbasis (dieselbe Formel wie script_insight / release_film)
	var script_base := 35 + int(casting.prestige) * 8 + (Util.hashs(str(casting.id) + "scr") % 21)
	var script_band := 1  # 0 schwach, 1 mittel, 2 stark
	if script_base <= 47:
		script_band = 0
	elif script_base >= 60:
		script_band = 2
	pool.append(_band_statement("scriptQ", script_band, [
		"The script stumbles from act two on — the story department sets it aside skeptically.",
		"Solid craftsmanship without big surprises, page after page.",
		"The script bears the signature of an awards contender — structure, dialogue, everything lands.",
	], rel))
	# 2. Budget vs. Genre-Anspruch
	var fee_sum := 0.0
	for r in casting.roles:
		fee_sum += float(r.fee)
	var typical := fee_sum * 3.75 + 400000.0 * Util.infl(state.year) * (1.0 + int(casting.prestige) * 0.3)
	var budget_band := 1
	if float(casting.budget) > typical * 1.15:
		budget_band = 2
	elif float(casting.budget) < typical * 0.75:
		budget_band = 0
	pool.append(_band_statement("budget", budget_band, [
		"The budget looks tightly calculated — even by the genre's standards.",
		"The budget sits within the expected range for a project like this.",
		"The budget is unusually high for this genre — the studio is betting everything on one card.",
	], rel))
	# 3. Regie-Historie (deterministisch aus dem Namen abgeleitet)
	var dir_name := _director_name_for(casting)
	var track := Util.hashs("track:" + dir_name) % 100
	var dir_band := 1
	if track <= 40:
		dir_band = 0
	elif track >= 55:
		dir_band = 2
	pool.append(_band_statement("regie", dir_band, [
		"%s has delivered two flops in a row — internally, doubts are voiced." % dir_name,
		"On %s, studio leadership keeps its cards close." % dir_name,
		"%s is coming off a success — the studio lets things run." % dir_name,
	], rel))
	# 4. Geplante Klauseln: Hardliner-Flag des Studios
	var hardliner := Util.hashs(str(casting.id) + "hard") % 100 < 35
	pool.append(_bool_statement("klauseln", hardliner,
		"The studio internally insists on far-reaching options — sequel clauses and morality paragraphs are ready.",
		"The studio is traditionally relaxed about contract language.", rel))
	# 5. Rollengröße der referenzierten Rolle
	var role: Dictionary = casting.roles[role_idx]
	pool.append(_bool_statement("rollengroesse", bool(role.get("cutRisk", false)),
		"The role reads thin — the studio's first cut lists already mention it.",
		"The role is firmly anchored in the plot — no editor will shake it loose.", rel))
	# Mischen und auf 4–5 kürzen (mindestens 4, mit Füller auffüllen)
	pool.shuffle()
	var out: Array = pool.slice(0, mini(5, maxi(4, pool.size())))
	while out.size() < 4:
		out.append({"text": "Schedule pressure: the studio wants to hold the release date at any cost.", "truthKey": "fueller", "truth": true, "marked": ""})
	return out

# Band-Aussage (0/1/2). Mit Wahrscheinlichkeit rel stimmt die Behauptung,
# sonst wird eine andere Band-Behauptung gezeigt (Rauschen).
func _band_statement(key: String, band: int, texts: Array, rel: float) -> Dictionary:
	var shown := band
	if not Util.chance(rel):
		var others := [0, 1, 2]
		others.erase(band)
		shown = int(Util.pick(others))
	return {"text": str(texts[shown]), "truthKey": key, "truth": shown == band, "marked": ""}

func _bool_statement(key: String, fact: bool, true_text: String, false_text: String, rel: float) -> Dictionary:
	var shown := fact
	if not Util.chance(rel):
		shown = not fact
	return {"text": true_text if shown else false_text, "truthKey": key, "truth": shown == fact, "marked": ""}

# Marker setzen: eine Aussage einer Kategorie zuordnen → Prognose.
func coverage_mark(stmt_idx: int, cat: String) -> String:
	var cur = state.coverage.get("current") if state.has("coverage") else null
	if cur == null:
		return "No coverage sheet on the desk."
	if not COVERAGE_CATS.has(cat):
		return "Unknown category."
	var stmts: Array = cur.get("statements", [])
	if stmt_idx < 0 or stmt_idx >= stmts.size():
		return "That statement does not exist."
	var st: Dictionary = stmts[stmt_idx]
	if str(st.get("marked", "")) != "":
		return "This statement is already marked — ink dries fast."
	var used := 0
	for s in stmts:
		if str(s.get("marked", "")) != "":
			used += 1
	if used >= int(cur.get("markersMax", 2)):
		return "No markers left — only a few clear bets per sheet."
	st["marked"] = cat
	var cs = _casting(cur.get("castingRef", -1))
	var due := mi() + (ceili(float(cs.deadline) / 4.0) if cs != null else 2) + 7
	add_prediction("coverage",
		{"castingId": int(cur.get("castingRef", -1)), "cat": cat, "roleIdx": int(cur.get("roleIdx", 0)), "sheetId": int(cur.get("id", 0))},
		true, due, "Coverage “%s”: %s" % [str(cur.get("title", "?")), COVERAGE_CATS[cat].name])
	# Prestigechance: Die Überzeugung des Lektorats trägt durch den Pitch (+5 Passung)
	if cat == "prestige" and cs != null:
		cs["agencyBoost"] = float(cs.get("agencyBoost", 0.0)) + 5.0
	return "Marker set: %s. It resolves when “%s” hits the theaters." % [COVERAGE_CATS[cat].name, str(cur.get("title", "?"))]

# Der Schnitt-Wurf beim Release — Wahrscheinlichkeit hängt am Rollengrößen-Flag.
func _coverage_cut_roll(_prod: Dictionary, role: Dictionary) -> bool:
	return Util.chance(0.75 if bool(role.get("cutRisk", false)) else 0.12)

func _resolve_coverage_prediction(pr: Dictionary, prod: Dictionary, ratio: float, quality: int) -> void:
	var cat := str(pr.subject.get("cat", ""))
	var q := quality if quality >= 0 else 50
	var script_base := 35.0 + int(prod.prestige) * 8.0 + float(Util.hashs(str(prod.id) + "scr") % 21)
	var pos := 0
	var neg := 0
	for sg in prod.get("signals", []):
		if bool(sg.get("pos", false)):
			pos += 1
		else:
			neg += 1
	var troubled := float(prod.get("qualityMod", 0.0)) < 0.0 or neg > pos
	var ok := false
	match cat:
		"sicher":
			ok = ratio >= 1.0 and q >= 45
		"prestige":
			ok = q >= 62
		"schwach":
			ok = ratio < 1.0
		"sleeper":
			ok = ratio >= 2.0 and script_base < 62.0
		"schnitt":
			var ridx := clampi(int(pr.subject.get("roleIdx", 0)), 0, maxi(0, prod.roles.size() - 1))
			ok = prod.roles.size() > 0 and bool(prod.roles[ridx].get("_coverageCut", false))
		"problematisch":
			ok = troubled
	_resolve_prediction(pr, ok, "Coverage “%s”: %s" % [str(prod.get("title", "?")), COVERAGE_CATS.get(cat, {}).get("name", cat)])

# Abgelaufenes Blatt ins Archiv (max. 8) — inkl. der Wahrheit hinter den Aussagen.
func _archive_coverage(cur: Dictionary) -> void:
	var hist: Array = state.coverage.get("history", [])
	var stmts: Array = []
	for st in cur.get("statements", []):
		stmts.append({"text": str(st.get("text", "")), "truthKey": str(st.get("truthKey", "")),
			"truth": bool(st.get("truth", false)), "marked": str(st.get("marked", ""))})
	hist.push_front({
		"id": int(cur.get("id", 0)), "title": str(cur.get("title", "")),
		"genre": str(cur.get("genre", "")), "studioId": str(cur.get("studioId", "")),
		"mi": int(cur.get("createdMi", mi())), "castingRef": int(cur.get("castingRef", -1)),
		"roleIdx": int(cur.get("roleIdx", 0)), "statements": stmts,
	})
	while hist.size() > 8:
		hist.pop_back()
	state.coverage["history"] = hist

# Trefferquote aller Coverage-Prognosen (für Karte & Archiv).
func coverage_stats() -> Dictionary:
	var done := 0
	var hits := 0
	var open_n := 0
	for pr in state.get("predictions", []):
		if str(pr.get("type", "")) != "coverage":
			continue
		if pr.get("resolved", false):
			done += 1
			if pr.get("correct", false):
				hits += 1
		else:
			open_n += 1
	return {"done": done, "hits": hits, "open": open_n}


# ---------- Feature D: Das perfekte Rollen-Karrierebrett ----------
# Drei Plan-Slots pro Klient: Genre + Rollentyp + Prestige-Stufe als Absicht,
# kein konkreter Film. Die Folge prägt die DNA-Trajektorie — Kontrast bringt
# den Transformations-Bonus, Wiederholung den Typecasting-Sog.

const BOARD_SLOTS := 3
const BOARD_PRESTIGE_TIERS := {1: "Commercial (★)", 2: "Ambitious (★★)", 3: "Prestige (★★★)"}

func ensure_board(c: Dictionary) -> void:
	if not c.has("careerBoard") or not (c.careerBoard is Dictionary):
		c["careerBoard"] = {"slots": [], "startedMi": mi(), "completed": 0}
	if not c.careerBoard.has("slots"):
		c.careerBoard["slots"] = []
	if not c.careerBoard.has("startedMi"):
		c.careerBoard["startedMi"] = mi()
	for slot in c.careerBoard.slots:
		if not slot.has("filledMi"):
			slot["filledMi"] = -1
		if not slot.has("createdMi"):
			slot["createdMi"] = int(c.careerBoard.startedMi)

func board_slot_label(slot: Dictionary) -> String:
	var genre_label: String = Data.GENRES.get(str(slot.get("genre", "drama")), {}).get("label", str(slot.get("genre", "?")))
	var type_label := "Lead" if str(slot.get("roleType", "lead")) == "lead" else "Supporting role"
	var tier_label: String = BOARD_PRESTIGE_TIERS.get(clampi(int(slot.get("prestige", 1)), 1, 3), "★")
	return "%s · %s · %s" % [genre_label, type_label, tier_label]

func board_slot_add(cid: int, genre: String, role_type: String, prestige: int) -> String:
	var c = client(cid)
	if c == null:
		return "This client is no longer with the house."
	if not Data.GENRES.has(genre):
		return "Unknown genre."
	if not ["lead", "support"].has(role_type):
		return "Unknown role type."
	ensure_board(c)
	var board: Dictionary = c.careerBoard
	if board.slots.size() >= BOARD_SLOTS:
		return "The board is full — three plans at once is plenty in this town."
	prestige = clampi(prestige, 1, 3)
	var slot := {"genre": genre, "roleType": role_type, "prestige": prestige, "createdMi": mi(), "filledMi": -1, "filledTitle": ""}
	board.slots.append(slot)
	log_msg("Career board: %s plans %s." % [client_name(c), board_slot_label(slot)], "info")
	return "Slot %d planned: %s" % [board.slots.size(), board_slot_label(slot)]

func board_slot_remove(cid: int, idx: int) -> void:
	var c = client(cid)
	if c == null:
		return
	ensure_board(c)
	if idx >= 0 and idx < c.careerBoard.slots.size():
		c.careerBoard.slots.remove_at(idx)

# Index des nächsten offenen Slots (−1 = Brett leer oder komplett erfüllt)
func board_next_open(c: Dictionary) -> int:
	ensure_board(c)
	for i in c.careerBoard.slots.size():
		if int(c.careerBoard.slots[i].get("filledMi", -1)) < 0:
			return i
	return -1

func _prestige_bucket(p: int) -> int:
	return clampi(p, 1, 3)

# Erfüllungs-Abgleich bei JEDEM Deal (über check_promises_on_deal erreicht).
# Match: Genre stimmt ODER Kombination aus Rollentyp + Prestige-Stufe stimmt.
# Kein Match: kein Abzug, kein Ärger — Pläne ändern sich in Hollywood.
func check_board_on_deal(c: Dictionary, prod: Dictionary, role: Dictionary) -> void:
	ensure_board(c)
	var idx := board_next_open(c)
	if idx < 0:
		return
	var slot: Dictionary = c.careerBoard.slots[idx]
	var genre := str(prod.get("genre", ""))
	var role_type := str(role.get("type", "support"))
	var prestige := int(prod.get("prestige", 0))
	var match_genre := str(slot.get("genre", "")) == genre
	var match_combo := str(slot.get("roleType", "")) == role_type and _prestige_bucket(int(slot.get("prestige", 1))) == _prestige_bucket(prestige)
	if not (match_genre or match_combo):
		log_msg("Career board: “%s” does not fit %s's plan — the slot stays open, no drama." % [str(prod.get("title", "?")), client_name(c)], "info")
		return
	slot["filledMi"] = mi()
	slot["filledTitle"] = str(prod.get("title", ""))
	if role.get("filled") != null:
		role.filled["boardMult"] = 1.5
	c.heat = clampf(float(c.heat) + 1.0, -10.0, 10.0)
	log_msg("Career board: slot %d fulfilled — %s follows the plan (%s). The role imprints ×1.5 at release." % [idx + 1, client_name(c), board_slot_label(slot)], "deal")
	var ana := board_analysis(c)
	if ana.repetitive:
		# Typecasting-Sog: kurzfristig schneller Ruhm, aber das Bild erstarrt
		c.fame = clampf(float(c.fame) + 1.5, 5.0, 100.0)
		c.dna.unikat = clampf(float(c.dna.unikat) - 3.0, -100.0, 100.0)
		if idx >= 2:
			c.flags["typecastRisk"] = true
			log_msg("Typecasting risk: three identical role profiles in a row — the image of %s hardens into a stencil." % client_name(c), "bad")
	if board_next_open(c) < 0:
		_board_complete(c, ana)

# Analyse der geplanten Folge inkl. schreibgeschützter DNA-Projektion.
func board_analysis(c: Dictionary) -> Dictionary:
	ensure_board(c)
	var genres: Array = []
	var lead_n := 0
	for slot in c.careerBoard.slots:
		var g := str(slot.get("genre", ""))
		if not genres.has(g):
			genres.append(g)
		if str(slot.get("roleType", "lead")) == "lead":
			lead_n += 1
	var planned := int(c.careerBoard.slots.size())
	var ana := {
		"planned": planned,
		"distinct": genres.size(),
		"leadN": lead_n,
		"contrasting": planned == BOARD_SLOTS and genres.size() == BOARD_SLOTS,
		"repetitive": planned == BOARD_SLOTS and genres.size() == 1,
		"projected": _board_project_dna(c),
	}
	return ana

# DNA-Trajektorie: imprint_dna-Formeln read-only auf einer Kopie simuliert
# (Board-Match ×1,5, ratio-neutral — eine ehrliche Mittelwert-Projektion).
func _board_project_dna(c: Dictionary) -> Dictionary:
	var proj := {}
	for ax in CareerDNA.DNA_AXES:
		proj[ax.key] = float(c.dna[ax.key])
	var genres: Array = []
	for slot in c.careerBoard.slots:
		var m := (1.0 if str(slot.get("roleType", "lead")) == "lead" else 0.5) * 1.5
		var vec: Dictionary = CareerDNA.GENRE_DNA.get(str(slot.get("genre", "")), {})
		for k in vec:
			proj[k] = clampf(float(proj[k]) + float(vec[k]) * m, -100.0, 100.0)
		if int(slot.get("prestige", 1)) >= 2:
			proj.unikat = clampf(float(proj.unikat) + 3.0 * m, -100.0, 100.0)
			proj.popular = clampf(float(proj.popular) - 2.0 * m, -100.0, 100.0)
		var g := str(slot.get("genre", ""))
		if not genres.has(g):
			genres.append(g)
	if c.careerBoard.slots.size() == BOARD_SLOTS:
		if genres.size() == 1:
			proj.unikat = clampf(float(proj.unikat) - 9.0, -100.0, 100.0)  # 3 × Typecasting-Drift
		elif genres.size() == BOARD_SLOTS:
			proj.unikat = clampf(float(proj.unikat) + 6.0, -100.0, 100.0)  # Transformations-Bonus
	return proj

func _board_complete(c: Dictionary, ana: Dictionary) -> void:
	c.fame = clampf(float(c.fame) + 4.0, 5.0, 100.0)
	press_event("Careers", "The reinvention of the %s: %s completes their own three-project plan — and Hollywood marvels" % [CareerDNA.dna_label(c), client_name(c)])
	log_msg("Career board complete: %s — fame +4 and a cover story about the reinvention." % client_name(c), "history")
	if ana.contrasting:
		# Transformations-Bonus: die Presse feiert die Vielseitigkeit
		c.dna.unikat = clampf(float(c.dna.unikat) + 6.0, -100.0, 100.0)
		press_event("Careers", "Shape-shifter %s: three genres, three direct hits — versatility becomes the trademark" % client_name(c))
	# Integration statt Konkurrenz: aktives Narrativ profitiert, wenn es passt
	var nar: Dictionary = c.get("narrative", {})
	if not nar.is_empty() and str(nar.get("status", "")) == "aktiv" and _board_narrative_compatible(c):
		nar["progress"] = minf(100.0, float(nar.get("progress", 0.0)) + 30.0)
		press_event("Careers", "%s's three-project plan also carries the bigger story a step further" % client_name(c))
		_narrative_maybe_complete(c)
	c.careerBoard["slots"] = []
	c.careerBoard["startedMi"] = mi()
	c.careerBoard["completed"] = int(c.careerBoard.get("completed", 0)) + 1

func _board_narrative_compatible(c: Dictionary) -> bool:
	for slot in c.careerBoard.slots:
		if int(slot.get("filledMi", -1)) < 0:
			continue
		if narrative_role_match(c, {"genre": str(slot.get("genre", "")), "prestige": int(slot.get("prestige", 1))}, {"type": str(slot.get("roleType", "lead"))}):
			return true
	return false

# Abschluss-Block eines Narrativs (gleiche Wirkung wie advance_narrative_on_release).
func _narrative_maybe_complete(c: Dictionary) -> void:
	var nar: Dictionary = c.get("narrative", {})
	if nar.is_empty() or str(nar.get("status", "")) != "aktiv":
		return
	if float(nar.get("progress", 0.0)) < 100.0:
		return
	var info: Dictionary = NARRATIVE_TYPES.get(str(nar.get("type", "")), {})
	nar["status"] = "abgeschlossen"
	c.fame = clampf(float(c.fame) + 8.0, 5.0, 100.0)
	state.agency.rep = clampi(int(state.agency.rep) + 5, 0, 100)
	press_event("Cover story", "%s completes “%s” — Hollywood sees a career with new eyes" % [client_name(c), info.get("label", "the transformation")])
	log_msg("Career narrative completed: %s — %s." % [client_name(c), info.get("label", "a fresh start")], "history")

# Rollenprofil-Vorschläge, die ein aktives Narrativ nahelegt (Ein-Klick-Übernahme).
func board_suggestions(c: Dictionary) -> Array:
	var actor: Dictionary = actor_by_id[c.aid]
	var home := str(actor.genres[0]) if actor.genres.size() else "drama"
	var nar: Dictionary = c.get("narrative", {})
	match str(nar.get("type", "")):
		"kinderstar_ernst":
			return [["drama", "lead", 3], ["thriller", "lead", 2], ["crime", "support", 2]]
		"comeback":
			return [["drama", "lead", 3], ["thriller", "lead", 2], ["comedy", "support", 1]]
		"spaetberufen":
			return [["drama", "lead", 2], [home, "lead", 2], ["crime", "lead", 3]]
		"action_prestige":
			return [["drama", "lead", 3], ["thriller", "lead", 2], ["action", "support", 2]]
		"skandal_respekt":
			return [["drama", "support", 2], ["adventure", "lead", 2], ["western", "support", 2]]
		"ensemble_star":
			return [["drama", "lead", 3], [home, "lead", 2], ["comedy", "lead", 1]]
	# Ohne Narrativ: Kontrast zum Heimatgenre als ehrlicher Default
	var contra := "drama" if home in ["comedy", "action", "musical"] else "comedy"
	return [[home, "lead", 2], [contra, "lead", 2], ["thriller", "support", 2]]

func board_adopt_suggestion(cid: int) -> String:
	var c = client(cid)
	if c == null:
		return "This client is no longer with the house."
	ensure_board(c)
	var kept: Array = []
	for slot in c.careerBoard.slots:
		if int(slot.get("filledMi", -1)) >= 0:
			kept.append(slot)
	c.careerBoard["slots"] = kept
	var sug := board_suggestions(c)
	var i := 0
	while c.careerBoard.slots.size() < BOARD_SLOTS and i < sug.size():
		c.careerBoard.slots.append({"genre": str(sug[i][0]), "roleType": str(sug[i][1]), "prestige": int(sug[i][2]),
			"createdMi": mi(), "filledMi": -1, "filledTitle": ""})
		i += 1
	log_msg("Career board: %s adopts the recommended role sequence." % client_name(c), "info")
	return "Three tailor-made slots adopted — now only the matching deals are missing."

# Verfall: offene Slots, die älter als 30 Monate sind, verfallen still (Log, keine Strafe).
func _tick_boards() -> void:
	for c in state.clients:
		ensure_board(c)
		var board: Dictionary = c.careerBoard
		for slot in board.slots.duplicate():
			if int(slot.get("filledMi", -1)) < 0 and mi() - int(slot.get("createdMi", mi())) > 30:
				board.slots.erase(slot)
				log_msg("Career board: one of %s's plan slots quietly expires — plans change in this town." % client_name(c), "info")
