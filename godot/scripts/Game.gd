extends Node
# =====================================================================
# Hollywood Manager (Godot) — Spiellogik
# Port der Web-Version plus neues Feature: Karriere-DNA.
# state ist ein reines JSON-Dictionary (Save/Load via user://).
# =====================================================================

const MONTHS_DE = ["Januar","Februar","März","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"]

const PERKS = {
	"pr":        {"de":"PR-Betreuung",          "cost":1500, "desc":"Mildert Skandale und Leaks, Laune +1/Monat"},
	"travel":    {"de":"Erste-Klasse-Komfort",  "cost":1200, "desc":"Laune +2/Monat, Erholung geht schneller"},
	"script":    {"de":"Drehbuch-Mitsprache",   "cost":0,    "desc":"Klient lehnt Rollen mit Passung < 35 ab, +5 Passung bei Genre-Treffern"},
	"coach":     {"de":"Privat-Coach",          "cost":1800, "desc":"Talent wächst langsam (bis +10)"},
	"assistant": {"de":"Persönliche Assistenz", "cost":800,  "desc":"Halbiert Erschöpfung am Set, Loyalität +1/Monat"},
}

const PROMISES = {
	"lead12":   {"label":"Hauptrolle innerhalb von 12 Monaten",           "months":12},
	"prestige": {"label":"ein Prestige-Projekt innerhalb von 18 Monaten", "months":18},
	"oscar":    {"label":"eine Oscar-Nominierung innerhalb von 24 Monaten","months":24},
}

const CONTRACT_YEARS = [2, 3, 5, 7]

const GRADE_BANDS = [[92,"A+"],[85,"A"],[80,"A−"],[75,"B+"],[70,"B"],[65,"B−"],[60,"C+"],[55,"C"],[50,"C−"],[45,"D+"],[40,"D"],[35,"D−"],[0,"F"]]

# ---------------------------------------------------------------------
# Karriere-DNA: fünf bipolare Image-Achsen (-100 … +100, 0 = ungeprägt).
# Rollen prägen das öffentliche Bild; das Casting gleicht Rollenbild und
# Karriere-DNA ab — Typecasting entsteht organisch.
# ---------------------------------------------------------------------
const DNA_AXES = [
	{"key":"romantik","pos":"Romantisch","neg":"Bedrohlich"},
	{"key":"popular", "pos":"Populär","neg":"Elitär"},
	{"key":"verlass", "pos":"Zuverlässig","neg":"Unberechenbar"},
	{"key":"unikat",  "pos":"Einzigartig","neg":"Austauschbar"},
	{"key":"familie", "pos":"Familientauglich","neg":"Kontrovers"},
]

const SECRET_TYPES := {
	"beziehung": {"label":"Heimliche Beziehung", "topic":"affäre", "prep":"Diskrete Termine und eine glaubwürdige Erklärung vorbereiten"},
	"gesundheit": {"label":"Gesundheitliches Problem", "topic":"gesundheit", "prep":"Behandlung und Drehpausen diskret koordinieren"},
	"wechselabsicht": {"label":"Wechselabsicht", "topic":"wechsel", "prep":"Vertrag und Karriereplan frühzeitig nachbessern"},
	"schwangerschaft": {"label":"Schwangerschaft", "topic":"gesundheit", "prep":"Eine planbare Auszeit mit den Studios abstimmen"},
	"sucht": {"label":"Suchtproblematik", "topic":"skandal", "prep":"Vor dem Zusammenbruch eine diskrete Klinik organisieren"},
	"politik": {"label":"Politische Aktivitäten", "topic":"politik", "prep":"Anwälte, Auslandskontakte und eine öffentliche Linie vorbereiten"},
	"setkonflikt": {"label":"Konflikt am Set", "topic":"skandal", "prep":"Eine vertrauliche Vermittlung mit der Produktion ansetzen"},
}

# Reichweite wird als monatliche Weitergabechance gelesen. Zuverlässigkeit
# beeinflusst, wie stark ein Gerücht beim Weitertragen an Glauben gewinnt.
const RUMOR_CARRIERS := {
	"Schauspieler": {"reliability":0.68, "reach":0.18, "industry":0.55, "public":0.55, "interest":["affäre","wechsel","skandal"]},
	"Assistenten": {"reliability":0.82, "reach":0.12, "industry":1.00, "public":0.25, "interest":["gesundheit","affäre","wechsel","politik","skandal"]},
	"Journalisten": {"reliability":0.58, "reach":0.34, "industry":0.20, "public":1.15, "interest":["affäre","skandal","gesundheit","politik"]},
	"Regisseure": {"reliability":0.76, "reach":0.16, "industry":1.10, "public":0.20, "interest":["gesundheit","wechsel","skandal"]},
	"Studios": {"reliability":0.84, "reach":0.22, "industry":1.25, "public":0.10, "interest":["wechsel","gesundheit","politik","skandal"]},
	"Partygäste": {"reliability":0.38, "reach":0.28, "industry":0.10, "public":1.05, "interest":["affäre","skandal"]},
}

# ---------------------------------------------------------------------
# Gefallen & Schulden: konkrete Marker statt abstraktem Netzwerk-Wert.
# state.favors[] / state.debts[] = {id, kind, from: {type, name, studioId?},
#   gainedMi, expiresMi (-1 = kein Verfall), note}
# ---------------------------------------------------------------------
const FAVOR_KINDS = {
	"extraAudition": {"de": "Zusätzliches Vorsprechen", "desc": "Ein abgelehnter Klient darf erneut für eine Rolle pitchen"},
	"suppressStory": {"de": "Story unterdrücken", "desc": "Entschärft ein Skandal-, Leak- oder Foto-Ereignis"},
	"scriptAccess": {"de": "Drehbuch-Einsicht", "desc": "Enthüllt die versteckte Qualitätsbasis eines Castings vor dem Pitch"},
	"billing": {"de": "Platzierung im Vorspann", "desc": "+Ruhm für einen Klienten beim nächsten Release"},
	"galaInvite": {"de": "Exklusive Einladung", "desc": "Eine Gala, die neue Kontakte oder einen Sofort-Deal bringen kann"},
}

const FAVOR_CONTACTS = {
	"kolumnist": ["Kolumnistin R. Hopper", "Klatschkolumnist L. Parson", "Kolumnist S. Skolsky"],
	"journalist": ["Reporter E. Crane", "Journalistin P. Lane", "Boulevard-Reporter W. Falk"],
	"regisseur": ["Regisseur V. Malone", "Regisseurin D. Whitfield", "Regisseur R. Kessler"],
	"produzent": ["Produzent H. Barrow", "Produzentin G. Mercer", "Produzent M. Quinn"],
}

# ---------------------------------------------------------------------
# Finanzbuchhaltung: jede Geldbewegung läuft über book() ins Ledger.
# ---------------------------------------------------------------------
const LEDGER_CATS = {
	"provision": "Provisionen",
	"bonus": "Signing- & Loyalitäts-Boni",
	"buero": "Büro & Fixkosten",
	"perks": "Klienten-Perks",
	"pr_recht": "PR, Anwälte & Kampagnen",
	"events": "Ereignisse",
	"tv": "Fernsehen",
	"investition": "Investitionen",
	"abfindung": "Abfindungen",
	"sonstiges": "Sonstiges",
}

const LEDGER_MAX := 600
const LEDGER_MONTHS_MAX := 240

# Was eine Rolle dieses Genres dem öffentlichen Bild einprägt (pro Film, Hauptrolle ×1).
const GENRE_DNA = {
	"romance":  {"romantik":8.0,  "familie":3.0,  "popular":2.0},
	"comedy":   {"popular":6.0,   "familie":5.0},
	"musical":  {"familie":6.0,   "popular":4.0,  "romantik":2.0},
	"drama":    {"popular":-3.0,  "unikat":4.0},
	"western":  {"romantik":-3.0, "verlass":4.0,  "popular":3.0},
	"action":   {"romantik":-4.0, "popular":5.0,  "familie":-1.0},
	"thriller": {"romantik":-5.0, "unikat":2.0,   "familie":-2.0},
	"horror":   {"romantik":-7.0, "familie":-5.0, "unikat":3.0},
	"crime":    {"romantik":-6.0, "familie":-4.0, "unikat":2.0},
	"scifi":    {"popular":4.0,   "unikat":3.0},
	"adventure":{"popular":5.0,   "familie":3.0},
}

const IDENTITY_KEYS := ["klientenorientiert", "studiotreu", "skrupellos", "diskret", "kuenstlerisch", "kommerziell"]
const IDENTITY_LABELS := {
	"klientenorientiert": "klientenorientiert", "studiotreu": "studiotreu",
	"skrupellos": "skrupellos", "diskret": "diskret",
	"kuenstlerisch": "künstlerisch", "kommerziell": "kommerziell",
}

const NARRATIVE_TYPES := {
	"kinderstar_ernst": {"label":"Vom Kinderstar zum Charakterfach", "desc":"Eine erwachsene Prestige-Rolle sprengt das niedliche Jugendimage."},
	"comeback": {"label":"Das große Comeback", "desc":"Nach einem Ruhmestief schreibt ein starker neuer Erfolg Kapitel zwei."},
	"spaetberufen": {"label":"Endlich im Mittelpunkt", "desc":"Viele Nebenrollen münden spät in die erste große Hauptrolle."},
	"action_prestige": {"label":"Vom Actionstar zum Prestige", "desc":"Kassenerfolge werden gegen eine anspruchsvolle Hauptrolle eingetauscht."},
	"skandal_respekt": {"label":"Vom Skandal zum Respekt", "desc":"Ein kontroverses Image wird durch verlässliche Arbeit neu erzählt."},
	"ensemble_star": {"label":"Aus der zweiten Reihe zum Star", "desc":"Ein bewährtes Ensemble-Gesicht beansprucht endlich die Leinwandmitte."},
}

const RIVAL_STYLE_INFO := {
	"aggressiv": {"label":"Aggressiv", "icon":"🦈"},
	"nachwuchs": {"label":"Nachwuchs", "icon":"🌱"},
	"studiotreu": {"label":"Studiotreu", "icon":"🏛"},
	"prestige": {"label":"Prestige", "icon":"🎩"},
}

var state = null
var nego = null
var pitch_ctx = null
var actor_by_id: Dictionary = {}
var _attr_cache: Dictionary = {}

func _ready() -> void:
	randomize()
	for a in Data.ACTORS:
		actor_by_id[a.id] = a

# ---------- Zufall & Helfer ----------
func pick(arr: Array):
	return arr[randi() % arr.size()]

func chance(p: float) -> bool:
	return randf() < p

func rndf(a: float, b: float) -> float:
	return randf_range(a, b)

func rndi(a: int, b: int) -> int:
	return randi_range(a, b)

func hashs(s: String) -> int:
	var h := 5381
	for ch in s.to_utf8_buffer():
		h = int((h * 33 + ch) % 4294967296)
	return h

# ---------- Ökonomie & Karriere-Mathematik ----------
func infl(year: float) -> float:
	return pow(1.03, year - 1925.0)

func fame_at(actor: Dictionary, year: float) -> int:
	if year < actor.debut:
		return 0
	var rise: float = maxf(3.0, (actor.peak - actor.debut) / 2.2)
	var fall := 14.0
	var d: float = year - actor.peak
	var s: float = rise if d < 0 else fall
	var f: float = actor.peakFame * exp(-0.5 * (d / s) * (d / s))
	return clampi(roundi(f), 5, 100)

func age_of(actor: Dictionary, year: float) -> int:
	return int(year - actor.birth)

func ask_fee(fame: float, year: float) -> float:
	return maxf(infl(year) * 900000.0 * pow(fame / 100.0, 2.6), 5000.0 * infl(year))

func required_rep(fame: float) -> int:
	return 0 if fame <= 45 else roundi((fame - 45.0) * 1.1)

func grade(v: float) -> String:
	for band in GRADE_BANDS:
		if v >= band[0]:
			return band[1]
	return "F"

func grade_range(v: float, spread: float, seed_s: String) -> String:
	var jitter: float = float(hashs(seed_s) % 9) - 4.0
	var center: float = clampf(v + jitter, 3.0, 100.0)
	var lo := grade(clampf(center - spread, 0.0, 100.0))
	var hi := grade(clampf(center + spread, 0.0, 100.0))
	return lo if lo == hi else "%s – %s" % [lo, hi]

func fmt_money(v: float) -> String:
	var sign := "-" if v < 0 else ""
	v = absf(v)
	if v >= 1e9:
		return "%s%s Mrd. $" % [sign, _de_num(v / 1e9)]
	if v >= 1e6:
		return "%s%s Mio. $" % [sign, _de_num(v / 1e6)]
	if v >= 1e4:
		return "%s%d Tsd. $" % [sign, roundi(v / 1000.0)]
	return "%s%d $" % [sign, roundi(v)]

func _de_num(x: float) -> String:
	return str(snappedf(x, 0.01)).replace(".", ",")

# ---------- Verdeckte Attribute (deterministisch) ----------
func attrs(actor: Dictionary) -> Dictionary:
	if not _attr_cache.has(actor.id):
		_attr_cache[actor.id] = {
			"charisma": clampi(roundi(30.0 + (hashs(str(actor.id) + "cha") % 100) * 0.5 + (actor.peakFame - 60.0) * 0.4), 5, 98),
			"discipline": clampi(roundi(95.0 - actor.ego * 0.55 - (hashs(str(actor.id) + "dis") % 100) * 0.25), 5, 95),
			"presence": clampi(roundi(actor.talent * 0.35 + actor.peakFame * 0.4 + (hashs(str(actor.id) + "pre") % 100) * 0.25 - 5.0), 5, 98),
		}
	return _attr_cache[actor.id]

# ---------- Karriere-DNA ----------
func initial_dna(actor: Dictionary) -> Dictionary:
	# Ausgangsbild aus den angestammten Genres plus deterministisches Rauschen
	var dna := {}
	for ax in DNA_AXES:
		dna[ax.key] = 0.0
	for g in actor.genres:
		var vec: Dictionary = GENRE_DNA.get(g, {})
		for k in vec:
			dna[k] = clampf(dna[k] + vec[k] * 3.0, -45.0, 45.0)
	for ax in DNA_AXES:
		dna[ax.key] = clampf(dna[ax.key] + float(hashs(str(actor.id) + ax.key) % 21) - 10.0, -55.0, 55.0)
	return dna

func imprint_dna(c: Dictionary, genre: String, mult: float, prestige: int, ratio: float) -> void:
	var vec: Dictionary = GENRE_DNA.get(genre, {})
	for k in vec:
		c.dna[k] = clampf(c.dna[k] + vec[k] * mult, -100.0, 100.0)
	if prestige >= 2:
		c.dna.unikat = clampf(c.dna.unikat + 3.0 * mult, -100.0, 100.0)
		c.dna.popular = clampf(c.dna.popular - 2.0 * mult, -100.0, 100.0)
	if ratio >= 3.0:
		c.dna.popular = clampf(c.dna.popular + 4.0 * mult, -100.0, 100.0)
	if ratio < 1.0:
		c.dna.verlass = clampf(c.dna.verlass - 2.0 * mult, -100.0, 100.0)

# Wie gut passt das öffentliche Bild zu einer Rolle dieses Genres?
# Rückgabe ca. -25 … +25, fließt in die Casting-Passung ein.
func dna_fit(c: Dictionary, genre: String, studio_style: String) -> float:
	var vec: Dictionary = GENRE_DNA.get(genre, {})
	var s := 0.0
	for k in vec:
		s += (vec[k] / 8.0) * (c.dna[k] / 100.0) * 14.0
	s += c.dna.unikat / 30.0
	s += (-c.dna.popular if studio_style == "prestige" else c.dna.popular) / 25.0
	return s

func dna_label(c: Dictionary) -> String:
	# Prägnanteste Achse als Kurz-Etikett („Der Bedrohliche")
	var best_key := ""
	var best_val := 0.0
	for ax in DNA_AXES:
		if absf(c.dna[ax.key]) > absf(best_val):
			best_val = c.dna[ax.key]
			best_key = ax.key
	if absf(best_val) < 25.0:
		return "Unbeschriebenes Blatt"
	for ax in DNA_AXES:
		if ax.key == best_key:
			return ax.pos if best_val > 0 else ax.neg
	return ""

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
	var age := age_of(actor, state.year)
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
		return "Diese Geschichte lässt sich nicht ausrufen."
	if not c.get("narrative", {}).is_empty() and str(c.narrative.get("status", "aktiv")) == "aktiv":
		return "Für %s läuft bereits ein Narrativ." % client_name(c)
	if not narrative_candidate_types(c).has(type_s):
		return "Die bisherige Karriere trägt dieses Narrativ noch nicht."
	var cost := roundi(7500.0 * infl(state.year))
	if float(state.agency.cash) < float(cost):
		return "Die PR-Kampagne kostet %s — zu viel für die aktuelle Kasse." % fmt_money(cost)
	book(-float(cost), "pr_recht", "Karrierenarrativ: %s" % client_name(c))
	c.narrative = {"type":type_s, "startedMi":mi(), "progress":0.0, "status":"aktiv"}
	press_event("Karrieren", "Kapitel 1: %s — %s beginnt" % [client_name(c), NARRATIVE_TYPES[type_s].label])
	return "Die Pressemappe trägt eine klare Überschrift: „%s“. Passende Rollen zahlen doppelt auf die Geschichte ein." % NARRATIVE_TYPES[type_s].label

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
		press_event("Karrieren", "Kapitel %d: %s setzt „%s“ mit „%s“ fort" % [2 + int(float(narrative.progress) / 55.0), client_name(c), info.get("label", "eine neue Geschichte"), prod.title])
		if float(narrative.progress) >= 100.0:
			narrative.status = "abgeschlossen"
			c.fame = clampf(float(c.fame) + 8.0, 5.0, 100.0)
			state.agency.rep = clampi(int(state.agency.rep) + 5, 0, 100)
			press_event("Titelstory", "%s vollendet „%s“ — Hollywood sieht eine Karriere mit neuen Augen" % [client_name(c), info.get("label", "die Verwandlung")])
			log_msg("Karrierenarrativ abgeschlossen: %s — %s." % [client_name(c), info.get("label", "Neuanfang")], "history")
	else:
		narrative.progress = maxf(0.0, float(narrative.progress) - 25.0)
		press_event("Presse-Spott", "Kapitel vertauscht? %s nimmt mit „%s“ der eigenen PR-Erzählung den Schwung" % [client_name(c), prod.title])

func studio_style(studio_id: String) -> String:
	for s in Data.STUDIOS:
		if s.id == studio_id:
			return s.style
	return "commercial"

# =====================================================================
# Spielzustand
# =====================================================================
func new_game(agency_name: String, start_year: int) -> void:
	state = {
		"agency": {"name": agency_name, "cash": 0.0, "rep": 15, "debtMonths": 0},
		"year": start_year, "month": 1, "startYear": start_year,
		"favors": [], "debts": [],
		"ledger": [], "ledgerMonthly": [],
		"clients": [], "castings": [], "productions": [], "released": [], "log": [],
		"rumors": [], "newspaper": [], "pressFeed": [],
		"rivals": [], "identity": {}, "identityLastTop": [],
		"studioRel": {}, "market": 1.0, "marketHistory": [], "usedHistory": [],
		"eventCd": {}, "followups": [], "usedTitles": [],
		"strikeMonths": 0, "strikeExempt": false,
		"nextId": 1, "over": false,
	}
	for key in IDENTITY_KEYS:
		state.identity[key] = 0.0
	_init_rivals(start_year)
	for s in Data.STUDIOS:
		state.studioRel[s.id] = rndi(20, 45)
	book(float(roundi(120000.0 * infl(start_year))), "sonstiges", "Eröffnungskapital — Büroeröffnung am Sunset Boulevard")
	# Ein alter Bekannter aus den Anfangsjahren erinnert sich.
	grant_favor("galaInvite", favor_contact_for("galaInvite"))
	log_msg("%s öffnet ihre Büros am Sunset Boulevard. Zeit, Karrieren zu machen." % agency_name, "history")
	spawn_castings(rndi(2, 3))

func next_id() -> int:
	state.nextId = int(state.nextId) + 1
	return int(state.nextId) - 1

func log_msg(text: String, type: String = "info") -> void:
	state.log.push_front({"y": state.year, "m": state.month, "text": text, "type": type})
	if state.log.size() > 300:
		state.log.pop_back()

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
		press_event("Agenturen", "%s trägt ein neues Etikett: %s" % [state.agency.name, " & ".join(after)])

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
	return "%s %d" % [MONTHS_DE[int(state.month) - 1], int(state.year)]

func mi() -> int:
	return int(state.year) * 12 + int(state.month) - 1

func mi_str(m) -> String:
	return "%s %d" % [MONTHS_DE[int(m) % 12], int(m) / 12]

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
		return a.debut <= y and (a.death == null or a.death > y) and age_of(a, y) <= 85 and not is_client(a.id))
	out.sort_custom(func(a, b): return fame_at(a, y) > fame_at(b, y))
	return out

func available_actors() -> Array:
	var y = state.year
	var out = Data.ACTORS.filter(func(a):
		return a.debut <= y and (a.death == null or a.death > y) and age_of(a, y) <= 85 and not is_client(a.id) and not is_rival_client(a.id))
	out.sort_custom(func(a, b): return fame_at(a, y) > fame_at(b, y))
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
	press_event("Klientenwechsel", "%s wechselt von %s zu %s" % [actor_name, state.agency.name, rival.name])

func _rival_candidate(rival: Dictionary) -> Variant:
	var pool := available_actors()
	if pool.is_empty():
		return null
	match str(rival.style):
		"nachwuchs":
			var young: Array = pool.filter(func(a): return age_of(a, state.year) <= 28)
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
			var reliable: Array = pool.filter(func(a): return float(attrs(a).discipline) >= 60.0)
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
	return {"title":"Ein Anruf von %s" % rival_name,
		"text":"[i]„Man muss sich nicht mögen, um gemeinsam einen guten Film zu bauen.“[/i]\n\n%s bietet eine Package-Kooperation an: Dein Klient %s erhält eine Rolle, das rivalisierende Haus ergänzt den übrigen Cast." % [rival_name, client_name(c)],
		"choices":[
			{"label":"Gemeinsam packagen", "fn":func():
				var cl = client(cid)
				var rv = rival_by_id(rid)
				if cl == null or rv == null:
					return "Die Gelegenheit ist verstrichen."
				var result = quick_production(cl, {"prestige":2 if str(rv.style) == "prestige" else 1})
				rv.grudge = maxf(0.0, float(rv.grudge) - 12.0)
				rv.rel = clampf(float(rv.rel) + 14.0, -100.0, 100.0)
				press_event("Agenturen", "%s und %s schnüren gemeinsam „%s“" % [state.agency.name, rv.name, result.title])
				return "Zwei Adressbücher, ein Vertrag: „%s“ geht in Produktion." % result.title},
			{"label":"Höflich ablehnen", "fn":func(): return "Man lässt die Tür offen. In Hollywood ist morgen ein anderer Monat."},
		]}

func tick_rivals(events: Array = [], force: bool = false) -> void:
	var cooperation_added := false
	for rival in state.get("rivals", []):
		for actor_id in rival.clients.duplicate():
			var actor: Dictionary = actor_by_id.get(str(actor_id), {})
			if actor.is_empty() or (actor.death != null and float(actor.death) <= float(state.year)):
				rival.clients.erase(actor_id)
		var sign_chance := 0.07 if str(rival.style) == "nachwuchs" else 0.035
		if force or chance(sign_chance):
			var actor = _rival_candidate(rival)
			if actor != null:
				rival.clients.append(str(actor.id))
				press_event("Rivalen-Deals", "%s nimmt %s unter Vertrag" % [rival.name, actor.name])
				log_msg("Konkurrenz: %s verpflichtet %s." % [rival.name, actor.name], "info")
		if float(rival.grudge) >= 60.0 and state.clients.size() and (force or chance(0.18)):
			var target: Dictionary = pick(state.clients)
			var rumor := add_rumor(int(target.id), "%s lässt in Studiokorridoren Zweifel an der Zuverlässigkeit von %s säen." % [rival.name, client_name(target)], false, "skandal", ["Studios", "Assistenten"], 14.0, true, "", 34.0)
			rumor["sourceRival"] = str(rival.id)
			press_event("Agenturen", "Eiszeit zwischen %s und %s: Studiokorridore werden zum Schlachtfeld" % [state.agency.name, rival.name])
		if not force and not cooperation_added and float(rival.grudge) <= 12.0 and float(rival.rel) >= 20.0 and chance(0.04):
			var coop = _rival_coop_event(rival)
			if coop != null:
				events.append(coop)
				cooperation_added = true

func rival_casting_block(studio_id: String) -> float:
	for rival in state.get("rivals", []):
		if str(rival.style) == "studiotreu" and str(rival.get("studioId", "")) == studio_id and rival.clients.size():
			return clampf(8.0 + float(rival.grudge) / 12.0 - maxf(0.0, float(rival.rel)) / 20.0, 4.0, 16.0)
	return 0.0

func random_client(filter: Callable = Callable()) -> Variant:
	var list = state.clients if not filter.is_valid() else state.clients.filter(filter)
	return pick(list) if list.size() else null

# ---------- Vertrauen, Geheimnisse & Gerüchte ----------
func change_trust(c: Dictionary, delta: float) -> void:
	var cap: float = clampf(float(c.get("trustCap", 100.0)), 0.0, 100.0)
	c["trust"] = clampf(float(c.get("trust", 30.0)) + delta, 0.0, cap)

func secret_of(c: Dictionary, type_s: String) -> Variant:
	for secret in c.get("secrets", []):
		if str(secret.get("type", "")) == type_s:
			return secret
	return null

func has_mitigated_secret(c: Dictionary, type_s: String) -> bool:
	var secret = secret_of(c, type_s)
	return secret != null and str(secret.get("status", "geheim")) == "entschärft"

func _secret_text(type_s: String, name_s: String) -> String:
	var lines := {
		"beziehung": "[i]„Es gibt jemanden. Wenn die Kolumnisten das erfahren, wird aus Liebe eine Schlagzeile.“[/i]",
		"gesundheit": "[i]„Die Ärzte sagen, ich muss kürzertreten. Das Studio darf es noch nicht wissen.“[/i]",
		"wechselabsicht": "[i]„Eine andere Agentur ruft an. Ich habe nicht zugesagt – aber ich denke darüber nach.“[/i]",
		"schwangerschaft": "[i]„Ich bin schwanger. Ich will weiterarbeiten, nur nicht auf Kosten von uns beiden.“[/i]",
		"sucht": "[i]„Ich schaffe die Nächte nicht mehr allein. Wenn niemand hilft, endet das vor laufender Kamera.“[/i]",
		"politik": "[i]„Ich war bei Treffen, über die man in Washington besser nicht spricht.“[/i]",
		"setkonflikt": "[i]„Noch einen Drehtag mit diesem Regisseur – und einer von uns geht.“[/i]",
	}
	return "%s\n\n%s vertraut dir ein persönliches Geheimnis an. Frühes Wissen gibt dir die Chance, die Krise vorzubereiten." % [lines.get(type_s, "[i]„Das bleibt zwischen uns.“[/i]"), name_s]

func reveal_secret(c: Dictionary, type_s: String = "", severity: int = 0) -> Variant:
	if type_s == "":
		var possible: Array = SECRET_TYPES.keys().filter(func(candidate): return secret_of(c, str(candidate)) == null)
		if actor_by_id[c.aid].g != "f":
			possible.erase("schwangerschaft")
		if possible.is_empty():
			return null
		if int(state.year) >= 1947 and int(state.year) <= 1956 and possible.has("politik"):
			possible.append_array(["politik", "politik"])
		type_s = str(pick(possible))
	if not SECRET_TYPES.has(type_s) or secret_of(c, type_s) != null:
		return null
	var sev: int = clampi(severity if severity > 0 else rndi(1, 3), 1, 3)
	var secret := {"type":type_s, "severity":sev, "knownSince":mi(), "status":"geheim"}
	c.secrets.append(secret)
	var cid: int = int(c.id)
	var prep_cost: int = roundi((1800.0 + sev * 1700.0) * infl(state.year))
	return {"title":"Unter vier Augen: %s" % SECRET_TYPES[type_s].label,
		"text":_secret_text(type_s, client_name(c)),
		"choices":[
			{"label":"Vorbereiten: %s (%s)" % [SECRET_TYPES[type_s].prep, fmt_money(prep_cost)], "fn":func(): return prepare_secret(cid, type_s, prep_cost)},
			{"label":"Zuhören und Vertraulichkeit zusichern", "fn":func():
				var cl = client(cid)
				if cl == null: return "Das Gespräch kommt zu spät."
				change_trust(cl, 3.0)
				return "Du versprichst nichts außer Diskretion. %s weiß, dass dieses Büro ein sicherer Ort ist. (Vertrauen +3)" % client_name(cl)},
			{"label":"An die Presse verkaufen", "fn":func(): return sell_secret(cid, type_s)},
		]}

func prepare_secret(cid: int, type_s: String, cost: int = -1) -> String:
	var c = client(cid)
	if c == null:
		return "Der Klient ist nicht mehr bei der Agentur."
	var secret = secret_of(c, type_s)
	if secret == null:
		return "Darauf kannst du dich ohne gesicherte Informationen nicht vorbereiten."
	var actual_cost: int = cost if cost >= 0 else roundi((1800.0 + int(secret.severity) * 1700.0) * infl(state.year))
	if float(state.agency.cash) < actual_cost:
		return "Die diskrete Vorbereitung würde %s kosten. Dafür reicht die Kasse noch nicht – das Geheimnis bleibt geschützt." % fmt_money(actual_cost)
	book(-float(actual_cost), "pr_recht", "Diskrete Vorbereitung: %s (%s)" % [SECRET_TYPES[type_s].label, client_name(c)])
	secret.status = "entschärft"
	record_identity("diskret", 1.0)
	record_identity("klientenorientiert", 0.5)
	change_trust(c, 9.0)
	c.loyalty = clampf(float(c.loyalty) + 5.0, 0.0, 100.0)
	match type_s:
		"sucht", "gesundheit":
			c.exhaustion = clampf(float(c.exhaustion) - 35.0, 0.0, 100.0)
			c.mood = clampf(float(c.mood) + 6.0, 0.0, 100.0)
		"schwangerschaft":
			c.flags["plannedLeave"] = mi() + 3
		"wechselabsicht":
			c.flags["poachPreparedUntil"] = mi() + 18
		"politik":
			c.flags["blacklistPreparedUntil"] = mi() + 24
		"setkonflikt":
			c.flags["setMediation"] = true
	log_msg("%s bereitet das Geheimnis von %s diskret vor." % [state.agency.name, client_name(c)], "deal")
	return "Anwälte, Ärzte und Kalender arbeiten lautlos im Hintergrund. Die spätere Krise wird deutlich milder. (Vertrauen +9)"

func maybe_reveal_secret(c: Dictionary, events: Array, force: bool = false) -> bool:
	var used: Array = c.get("secretThresholds", [])
	for threshold in [45, 60, 75]:
		if float(c.get("trust", 30.0)) < threshold or used.has(threshold):
			continue
		var p: float = 0.18 + float(threshold - 45) / 150.0
		if force or chance(p):
			used.append(threshold)
			c.secretThresholds = used
			var ev = reveal_secret(c)
			if ev != null:
				events.append(ev)
				return true
	return false

func add_rumor(subject, text_s: String, truth: bool, topic: String, holders: Array = [], belief: float = 10.0, known: bool = false, source_secret: String = "", industry_belief: float = -1.0) -> Dictionary:
	var industry_start := belief if industry_belief < 0.0 else industry_belief
	var rumor := {"id":next_id(), "subject":subject, "text":text_s, "truth":truth, "topic":topic,
		"holders":holders.duplicate(), "belief":clampf(belief, 0.0, 100.0), "industryBelief":clampf(industry_start, 0.0, 100.0),
		"knownToPlayer":known, "age":0, "impactApplied":false, "industryImpactApplied":false, "sourceSecret":source_secret}
	state.rumors.append(rumor)
	return rumor

func rumor_by_id(rid: int) -> Variant:
	for rumor in state.get("rumors", []):
		if int(rumor.id) == rid:
			return rumor
	return null

func rumor_subject_client(rumor: Dictionary) -> Variant:
	var direct = client(rumor.subject) if (rumor.subject is int or rumor.subject is float) else null
	if direct != null:
		return direct
	for c in state.clients:
		if str(c.aid) == str(rumor.subject):
			return c
	return null

func rumor_subject_name(rumor: Dictionary) -> String:
	if str(rumor.subject) == "agency":
		return str(state.agency.name)
	var c = rumor_subject_client(rumor)
	if c != null:
		return client_name(c)
	if actor_by_id.has(str(rumor.subject)):
		return str(actor_by_id[str(rumor.subject)].name)
	return "Unbekannt"

func player_knows_rumor_truth(rumor: Dictionary) -> bool:
	if str(rumor.get("sourceSecret", "")) == "":
		return false
	var c = rumor_subject_client(rumor)
	return c != null and secret_of(c, str(rumor.sourceSecret)) != null

func _leak_secret(c: Dictionary, secret: Dictionary, known: bool = false, initial_belief: float = 16.0) -> Dictionary:
	secret["leaked"] = true
	var info: Dictionary = SECRET_TYPES[str(secret.type)]
	var text_s := "In der Stadt heißt es, bei %s gehe es um: %s." % [client_name(c), str(info.label).to_lower()]
	return add_rumor(int(c.id), text_s, true, str(info.topic), ["Assistenten"], initial_belief, known, str(secret.type))

func sell_secret(cid: int, type_s: String) -> String:
	var c = client(cid)
	if c == null:
		return "Daraus wird keine Geschichte mehr."
	var secret = secret_of(c, type_s)
	if secret == null or str(secret.status) == "publik":
		return "Diese Geschichte ist nicht mehr exklusiv."
	var payment: int = roundi((7000.0 + int(secret.severity) * 9000.0 + float(c.fame) * 300.0) * infl(state.year))
	book(float(payment), "pr_recht", "Exklusivgeschichte an die Presse verkauft (%s)" % client_name(c))
	record_identity("skrupellos", 3.0)
	secret.status = "publik"
	c.trustCap = 20.0
	c.trust = 0.0
	c.loyalty = clampf(float(c.loyalty) - 45.0, 0.0, 100.0)
	for other in state.clients:
		if int(other.id) != cid:
			other.heat = clampf(float(other.heat) + 1.5, -10.0, 10.0)
	var rumor := _leak_secret(c, secret, true, 46.0)
	rumor["soldByAgency"] = true
	log_msg("Eine intime Geschichte über %s landet in der Presse." % client_name(c), "bad")
	var ending := ""
	if chance(0.65):
		state.clients.erase(c)
		ending = " %s kündigt noch am selben Abend." % client_name(c)
	return "Die Kolumne zahlt %s. Das Vertrauen ist zerstört und dauerhaft gedeckelt.%s" % [fmt_money(payment), ending]

func _apply_rumor_impact(rumor: Dictionary) -> void:
	# Öffentliche Wirkung: Ruhm und Image. Die Branchenwirkung bleibt separat
	# und wird beim Casting über rumor_fit_penalty() gelesen.
	rumor.impactApplied = true
	var c = rumor_subject_client(rumor)
	if c != null:
		var severity: float = 3.0 + float(rumor.belief) / 30.0
		c.fame = clampf(float(c.fame) - severity, 5.0, 100.0)
		c.mood = clampf(float(c.mood) - 9.0, 0.0, 100.0)
		c.dna.familie = clampf(float(c.dna.familie) - 7.0, -100.0, 100.0)
		c.dna.verlass = clampf(float(c.dna.verlass) - 5.0, -100.0, 100.0)
		if str(rumor.get("sourceSecret", "")) != "":
			var secret = secret_of(c, str(rumor.sourceSecret))
			if secret != null:
				secret.status = "publik"
	if str(rumor.get("sourceSecret", "")) != "":
		for cl in state.clients:
			change_trust(cl, -7.0)
		log_msg("Das Gerücht wird zur Schlagzeile. In der Agentur fragt sich jeder, wer geredet hat.", "bad")
	else:
		log_msg("Ein Gerücht über %s gilt in Hollywood plötzlich als Tatsache." % rumor_subject_name(rumor), "bad")

func _apply_industry_rumor_impact(rumor: Dictionary) -> void:
	rumor.industryImpactApplied = true
	log_msg("Die Branche behandelt das Gerücht über %s nun als interne Wahrheit — auch ohne Schlagzeile." % rumor_subject_name(rumor), "bad")

func tick_rumors(events: Array = [], force_spread: bool = false) -> void:
	# Wahre Geheimnisse können unbemerkt aus dem Büro sickern.
	for c in state.clients:
		for secret in c.get("secrets", []):
			if str(secret.status) != "publik" and not secret.get("leaked", false) and (force_spread or chance(0.025)):
				_leak_secret(c, secret)
	# Gelegentliche Erfindungen bevorzugen bekannte Namen.
	if not force_spread and state.clients.size() and chance(0.035):
		var stars: Array = state.clients.duplicate()
		stars.sort_custom(func(a, b): return float(a.fame) > float(b.fame))
		var target: Dictionary = pick(stars.slice(0, mini(3, stars.size())))
		var topic: String = str(pick(["affäre", "skandal", "wechsel", "gesundheit"]))
		add_rumor(int(target.id), "Auf einer Party wird behauptet, bei %s bahne sich etwas an – Belege hat niemand." % client_name(target), false, topic, ["Partygäste"], 12.0)

	for rumor in state.rumors.duplicate():
		rumor.age = int(rumor.age) + 1
		var topic_s: String = str(rumor.topic)
		var candidates: Array = []
		for carrier in RUMOR_CARRIERS:
			var spec: Dictionary = RUMOR_CARRIERS[carrier]
			if not rumor.holders.has(carrier) and spec.interest.has(topic_s):
				candidates.append(carrier)
		if candidates.size():
			var max_reach := 0.0
			for holder in rumor.holders:
				max_reach = maxf(max_reach, float(RUMOR_CARRIERS.get(holder, {}).get("reach", 0.1)))
			if force_spread or chance(max_reach):
				rumor.holders.append(str(pick(candidates)))
		var public_momentum := 0.0
		var industry_momentum := 0.0
		for holder in rumor.holders:
			var spec: Dictionary = RUMOR_CARRIERS.get(holder, {"reach":0.1, "reliability":0.5})
			var base: float = float(spec.reach) * (5.0 + float(spec.reliability) * 8.0)
			public_momentum += base * float(spec.get("public", 0.5))
			industry_momentum += base * float(spec.get("industry", 0.5))
		if rumor.get("impactApplied", false):
			rumor.belief = maxf(0.0, float(rumor.belief) - 5.0)
		else:
			rumor.belief = clampf(float(rumor.belief) + public_momentum, 0.0, 100.0)
		if rumor.get("industryImpactApplied", false):
			rumor.industryBelief = maxf(0.0, float(rumor.industryBelief) - 3.0)
		else:
			rumor.industryBelief = clampf(float(rumor.industryBelief) + industry_momentum, 0.0, 100.0)
		if not rumor.knownToPlayer:
			var contact_bonus: float = minf(0.2, state.favors.size() * 0.025)
			for rel in state.studioRel.values():
				contact_bonus += float(rel) / maxf(1.0, state.studioRel.size() * 700.0)
			if (rumor.holders.has("Assistenten") and chance(0.45 + contact_bonus)) or chance(contact_bonus * 0.35):
				rumor.knownToPlayer = true
				events.append({"title":"Ein Flüstern im Vorzimmer", "text":"[i]„Noch ist es nur Gerede – aber Sie sollten wissen, was man über %s erzählt.“[/i]\n\n%s" % [rumor_subject_name(rumor), rumor.text], "choices":[{"label":"Zum Gerüchte-Dossier"}]})
		if float(rumor.belief) >= 60.0 and not rumor.get("impactApplied", false):
			_apply_rumor_impact(rumor)
		if float(rumor.industryBelief) >= 60.0 and not rumor.get("industryImpactApplied", false):
			_apply_industry_rumor_impact(rumor)
		if int(rumor.age) > 6 and maxf(float(rumor.belief), float(rumor.industryBelief)) < 8.0:
			state.rumors.erase(rumor)

func rumor_fit_penalty(c: Dictionary) -> float:
	var penalty := 0.0
	for rumor in state.get("rumors", []):
		if rumor_subject_client(rumor) != c:
			continue
		var industry := float(rumor.get("industryBelief", rumor.get("belief", 0.0)))
		if industry >= 60.0:
			penalty = maxf(penalty, 12.0)
		elif industry >= 40.0:
			penalty = maxf(penalty, 6.0)
	return penalty

func deny_rumor(rid: int) -> String:
	var rumor = rumor_by_id(rid)
	if rumor == null:
		return "Das Gerücht ist bereits versiegt."
	if bool(rumor.truth) and chance(0.45):
		rumor.belief = clampf(float(rumor.belief) + 28.0, 0.0, 100.0)
		var c = rumor_subject_client(rumor)
		if c != null:
			c.mood = clampf(float(c.mood) - 8.0, 0.0, 100.0)
		return "Das Dementi zerfällt unter Nachfragen. Nun wirkt die Geschichte doppelt glaubwürdig."
	rumor.belief = maxf(0.0, float(rumor.belief) - (24.0 if not bool(rumor.truth) else 10.0))
	return "Die Erklärung sitzt. Für den Moment verliert das Gerücht an Zugkraft."

func suppress_rumor(rid: int) -> String:
	var rumor = rumor_by_id(rid)
	if rumor == null:
		return "Die Geschichte ist bereits verschwunden."
	var used_favor := false
	if has_method("consume_favor"):
		used_favor = bool(call("consume_favor", "suppressStory"))
	var cost: int = roundi(12000.0 * infl(state.year))
	if not used_favor:
		if float(state.agency.cash) < cost:
			return "Kein passender Gefallen – und die verlangten %s fehlen in der Kasse." % fmt_money(cost)
		book(-float(cost), "pr_recht", "Gerücht unterdrückt: %s" % rumor_subject_name(rumor))
	record_identity("diskret", 1.5)
	rumor.belief = maxf(0.0, float(rumor.belief) - 38.0)
	rumor.holders = rumor.holders.filter(func(h): return str(h) not in ["Journalisten", "Partygäste"])
	if rumor.holders.is_empty():
		rumor.holders = ["Assistenten"]
	return "Ein Anruf, eine Gegengefälligkeit, eine geschlossene Schublade. Die Story verliert fast ihre gesamte Reichweite."

func studio_talk_rumor(rid: int) -> String:
	var rumor = rumor_by_id(rid)
	if rumor == null:
		return "In den Studios erinnert sich niemand mehr an die Geschichte."
	var paid_with_favor := consume_any_favor()
	var cost := roundi(9000.0 * infl(state.year))
	if not paid_with_favor:
		if float(state.agency.cash) < float(cost):
			return "Für diskrete Studiogespräche fehlen ein Gefallen oder %s." % fmt_money(cost)
		book(-float(cost), "pr_recht", "Diskrete Studiogespräche: %s" % rumor_subject_name(rumor))
	rumor.industryBelief = maxf(0.0, float(rumor.get("industryBelief", 0.0)) - 34.0)
	rumor.holders = rumor.holders.filter(func(h): return str(h) not in ["Studios", "Regisseure"])
	if rumor.holders.is_empty():
		rumor.holders = ["Assistenten"]
	record_identity("diskret", 1.0)
	record_identity("studiotreu", 0.5)
	return "Hinter verschlossenen Türen werden Fakten, Garantien und alte Schulden sortiert. Die Branche wird deutlich skeptischer gegenüber dem Gerücht."

func counter_rumor(rid: int) -> String:
	var rumor = rumor_by_id(rid)
	if rumor == null:
		return "Dafür ist es zu spät."
	var cost: int = roundi(5000.0 * infl(state.year))
	if float(state.agency.cash) < cost:
		return "Die Kampagne würde %s kosten. Die Kasse gibt das nicht her." % fmt_money(cost)
	book(-float(cost), "pr_recht", "Gegengerücht-Kampagne: %s" % rumor_subject_name(rumor))
	rumor.belief = maxf(0.0, float(rumor.belief) - 20.0)
	if chance(0.12):
		for c in state.clients:
			change_trust(c, -2.0)
		return "Das Gegengerücht wirkt – doch ein Reporter erkennt deine Handschrift. Das Vertrauen im Haus bekommt einen Kratzer."
	return "Eine interessantere Geschichte übernimmt die Cocktailpartys. Dieses Gerücht rutscht aus dem Rampenlicht."

func wait_out_rumor(rid: int) -> String:
	var rumor = rumor_by_id(rid)
	if rumor == null:
		return "Das Gerücht ist schon vergessen."
	rumor["waitingOut"] = true
	return "Keine Pressekonferenz, kein Futter. Du setzt darauf, dass Hollywood morgen eine neue Obsession findet."

func rumor_targets() -> Array:
	var targets: Array = pool_actors().filter(func(a): return not is_client(str(a.id)))
	targets.sort_custom(func(a, b):
		var ar := 1 if is_rival_client(str(a.id)) else 0
		var br := 1 if is_rival_client(str(b.id)) else 0
		return ar > br if ar != br else fame_at(a, state.year) > fame_at(b, state.year))
	return targets

func launch_rumor(actor_id: String, topic: String = "skandal") -> String:
	if not actor_by_id.has(actor_id) or is_client(actor_id):
		return "Das Ziel taugt nicht für diese Kampagne."
	var actor: Dictionary = actor_by_id[actor_id]
	var owner = rival_for_actor(actor_id)
	var text_s := "In den Vorzimmern heißt es, bei %s gebe es eine Geschichte, die noch niemand drucken will." % actor.name
	var rumor := add_rumor(actor_id, text_s, false, topic, ["Assistenten", "Partygäste"], 14.0, true, "", 20.0)
	rumor["launchedByAgency"] = true
	record_identity("skrupellos", 2.0)
	var exposure: float = clampf(0.34 - identity_strength("skrupellos") * 0.10, 0.12, 0.45)
	if chance(exposure):
		rumor["agencyExposed"] = true
		state.agency.rep = clampi(int(state.agency.rep) - 5, 0, 100)
		for c in state.clients:
			change_trust(c, -5.0)
		record_identity("skrupellos", 2.0)
		if owner != null:
			owner.grudge = clampf(float(owner.grudge) + 18.0, 0.0, 100.0)
		press_event("Skandal", "Schmutzkampagne enttarnt: Spuren führen zu %s" % state.agency.name)
		return "Das Gerücht läuft — doch ein Assistent erkennt deine Handschrift. Ruf und Klientenvertrauen leiden."
	return "Ein Nebensatz hier, eine anonyme Notiz dort. Das Gerücht ist im Netz, und vorerst kennt niemand den Urheber."

func is_free(c: Dictionary) -> bool:
	return int(c.busyUntil) <= mi()

func eff_talent(c: Dictionary) -> float:
	return clampf(actor_by_id[c.aid].talent + c.get("talentBonus", 0.0) - (5.0 if c.flags.get("typecast", false) else 0.0), 5.0, 100.0)

func perk_costs() -> float:
	var f := infl(state.year)
	var sum := 0.0
	for c in state.clients:
		for p in c.perks:
			sum += PERKS[p].cost * f
	return sum

func overhead() -> int:
	return roundi((2200.0 + state.clients.size() * 600.0) * infl(state.year) + perk_costs())

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
	log_msg("Gefallen eingelöst: %s (%s)." % [FAVOR_KINDS[kind].de, best["from"].get("name", "?")], "info")
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
	log_msg("Gefallen eingelöst: %s (%s)." % [FAVOR_KINDS[str(best.kind)].de, best["from"].get("name", "?")], "info")
	return true

func has_favor(kind: String) -> bool:
	for f in state.favors:
		if str(f.kind) == kind:
			return true
	return false

# Eine benannte Person, die zum Gefallen passt.
func favor_contact_for(kind: String, studio_id: String = "") -> Dictionary:
	var type := "produzent"
	match kind:
		"suppressStory": type = pick(["kolumnist", "journalist"])
		"scriptAccess": type = "regisseur"
		"extraAudition": type = pick(["produzent", "studio"])
		"billing": type = "produzent"
		"galaInvite": type = pick(["studio", "produzent"])
	if type == "studio":
		var sid := studio_id
		if sid == "":
			sid = str(pick(active_studios()).id)
		return {"type": "studio", "name": str(_studio(sid).name), "studioId": sid}
	return {"type": type, "name": str(pick(FAVOR_CONTACTS[type]))}

# Jemand schuldet DIR einen Gefallen.
func grant_favor(kind: String, from: Dictionary = {}, silent: bool = false) -> Dictionary:
	var person: Dictionary = from if not from.is_empty() else favor_contact_for(kind)
	var exp := -1
	if chance(0.8):
		exp = mi() + rndi(24, 36)
	var fav := {"id": next_id(), "kind": kind, "from": person, "gainedMi": mi(), "expiresMi": exp, "note": str(FAVOR_KINDS[kind].desc)}
	state.favors.append(fav)
	if not silent:
		log_msg("%s schuldet dir jetzt einen Gefallen: %s." % [person.get("name", "?"), FAVOR_KINDS[kind].de], "deal")
	return fav

# DU schuldest jemandem einen Gefallen.
func owe_favor(kind: String, from: Dictionary = {}) -> Dictionary:
	var person: Dictionary = from if not from.is_empty() else favor_contact_for(kind)
	var debt := {"id": next_id(), "kind": kind, "from": person, "gainedMi": mi(), "expiresMi": -1, "note": str(FAVOR_KINDS[kind].desc)}
	state.debts.append(debt)
	log_msg("Du stehst bei %s in der Schuld (%s)." % [person.get("name", "?"), FAVOR_KINDS[kind].de], "bad")
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
	log_msg("Du lässt einen Gefallen %s zukommen — die Beziehung vertieft sich." % _studio(studio_id).name, "deal")
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
# (Prestige + Script-Roll, wie in release_film).
func script_insight(casting: Dictionary) -> int:
	return 35 + int(casting.prestige) * 8 + (hashs(str(casting.id) + "scr") % 21)

# Verfall: abgelaufene Gefallen im Monatstakt entfernen.
func _expire_favors() -> void:
	for f in state.favors.duplicate():
		if int(f.expiresMi) >= 0 and mi() > int(f.expiresMi):
			state.favors.erase(f)
			log_msg("Verjährt: %s lässt nicht mehr mit sich reden (%s)." % [f["from"].get("name", "?"), FAVOR_KINDS.get(str(f.kind), {}).get("de", str(f.kind))], "info")


# =====================================================================
# Verhandlung v2: verdeckte Forderungen & Gegenvorschläge
# =====================================================================
func actor_profile(actor: Dictionary, fame: float) -> Dictionary:
	var money: float = 20.0 + actor.ego * 0.5 + (15.0 if fame > 70 else 0.0)
	var prestige: float = actor.talent * 0.7
	var security: float = clampf(85.0 - fame, 5.0, 60.0) + (15.0 if age_of(actor, state.year) > 50 else 0.0)
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
	var wanted: Array = [pick(perks_by_trait[traits[0]])]
	var second = pick(perks_by_trait[traits[1]])
	if not wanted.has(second) and chance(0.7):
		wanted.append(second)
	var promise = null
	if profile.top == "prestige" and fame < 75 and chance(0.5):
		promise = "prestige"
	if profile.top == "security" and chance(0.5):
		promise = "lead12"
	if actor.talent > 88 and actor.ego > 75 and chance(0.4):
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
	var fame := fame_at(actor, state.year)
	var req := required_rep(fame)
	var owner = rival_for_actor(actor_id)
	var poach_req := req + (10 if owner != null else 0)
	if state.agency.rep < poach_req:
		return {"locked": true, "actor": actor, "fame": fame, "reqRep": poach_req, "rivalName": str(owner.name) if owner != null else ""}
	var ask := ask_fee(fame, state.year)
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
	return money_raw * p.money * 2.6 + promise_raw * trust + perks_score + years_score + standing + identity_offer_modifier(nego.actor) - (nego.round - 1) * 3.0

func mood_label(score: float) -> Array:
	if score >= 65.0: return ["begeistert", "pos"]
	if score >= 50.0: return ["interessiert", ""]
	if score >= 34.0: return ["abwägend", ""]
	return ["ablehnend", "neg"]

func negotiation_hint() -> String:
	var hints := {
		"money": ["„Schöne Worte zahlen keine Villa in Bel Air, mein Freund.“", "„Reden wir über Zahlen. Alles andere ist Smalltalk.“"],
		"prestige": ["„Ich will Rollen, über die man in dreißig Jahren noch spricht.“", "„Geld verdirbt. Kunst bleibt. Was bieten Sie mir künstlerisch?“"],
		"security": ["„Ich muss wissen, dass ich nächstes Jahr noch arbeite. Können Sie das garantieren?“", "„Versprechen Sie mir nichts, was Sie nicht halten können.“"],
	}
	return "%s: %s" % [nego.actor.name, pick(hints[nego.profile.top])]

func build_counter(offer: Dictionary) -> Variant:
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
		parts.append("%d %% Provision — keinen Punkt mehr" % counter.commission)
	if counter.bonus > offer.bonus:
		parts.append("%s Handgeld im Voraus" % fmt_money(counter.bonus))
	if counter.years != offer.years:
		parts.append("%d Jahre Laufzeit" % counter.years)
	var new_perks = counter.perks.filter(func(pk): return not offer.perks.has(pk))
	if new_perks.size():
		parts.append(", ".join(new_perks.map(func(pk): return PERKS[pk].de)))
	if counter.promise != null and counter.promise != offer.promise:
		parts.append("Ihr Wort auf %s" % PROMISES[counter.promise].label)
	if parts.is_empty():
		return null
	counter["text"] = "„Mein Angebot: %s. Dann unterschreibe ich heute noch.“" % ", ".join(parts)
	return counter

func sign_client(terms: Dictionary) -> Dictionary:
	if terms.bonus > state.agency.cash:
		return {"broke": true}
	if int(terms.bonus) > 0:
		book(-float(terms.bonus), "bonus", "Signing-Bonus: %s" % nego.actor.name)
	var actor: Dictionary = nego.actor
	var c := {
		"id": next_id(), "aid": actor.id, "fame": float(nego.fame), "heat": 0.0,
		"loyalty": float(rndi(45, 60) + (6 if terms.bonus > 0 else 0)), "mood": 60.0, "exhaustion": 0.0,
		"commission": int(terms.commission), "perks": terms.get("perks", []),
		"years": int(terms.years), "contractEnd": mi() + int(terms.years) * 12,
		"promises": [], "busyUntil": 0, "films": [], "flags": {}, "talentBonus": 0.0,
		"campaign": 0.0, "awards": 0,
		"dna": initial_dna(actor),
		"signedAt": mi(),
		"trust": float(rndi(28, 34)), "trustCap": 100.0, "secrets": [], "secretThresholds": [],
		"narrative": {}, "fameHistory": [], "dnaHistory": [],
	}
	c.fameHistory.append({"mi":mi(), "v":float(c.fame)})
	c.dnaHistory.append({"mi":mi(), "romantik":float(c.dna.romantik), "popular":float(c.dna.popular), "verlass":float(c.dna.verlass), "unikat":float(c.dna.unikat), "familie":float(c.dna.familie)})
	if terms.get("promise") != null:
		c.promises.append({"type": terms.promise, "label": PROMISES[terms.promise].label, "due": mi() + int(PROMISES[terms.promise].months), "fulfilled": false, "broken": false})
	state.clients.append(c)
	var rival_id := str(nego.get("rivalId", ""))
	if rival_id != "":
		for rival in state.rivals:
			if str(rival.id) == rival_id:
				rival.clients.erase(str(actor.id))
				rival.grudge = clampf(float(rival.grudge) + 25.0, 0.0, 100.0)
				press_event("Agenturen", "%s entreißt %s dem Haus %s" % [state.agency.name, actor.name, rival.name])
				break
	else:
		press_event("Klientenwechsel", "%s unterschreibt bei %s" % [actor.name, state.agency.name])
	state.agency.rep = clampi(int(state.agency.rep) + roundi(nego.fame / 22.0), 0, 100)
	log_msg("%s unterschreibt für %d Jahre (%d %% Provision%s%s)." % [actor.name, terms.years, terms.commission,
		(", Bonus " + fmt_money(terms.bonus)) if terms.bonus > 0 else "",
		", mit Versprechen" if terms.get("promise") != null else ""], "deal")
	nego.done = true
	return {"accepted": true, "client": c}

func make_offer(offer: Dictionary) -> Dictionary:
	var score := evaluate_offer(offer) + rndf(-9.0, 9.0)
	if score >= 58.0:
		return sign_client(offer)
	nego.round = int(nego.round) + 1
	nego.counter = build_counter(offer) if score >= 34.0 else null
	if nego.round > nego.maxRounds:
		nego.done = true
		log_msg("%s lehnt endgültig ab." % nego.actor.name, "bad")
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
	return "%s %s" % [pick(t.a), pick(t.b)]

func project_title(genre: String) -> String:
	var y = state.year
	var used: Array = state.usedTitles
	var cand = Data.REAL_TITLES.filter(func(t): return absf(t.y - y) <= 4 and t.g.has(genre) and not used.has(t.t))
	if cand.size() and chance(0.8):
		var t = pick(cand)
		used.append(t.t)
		return t.t
	return make_title(genre)

func spawn_castings(count: int) -> void:
	var y = state.year
	for i in count:
		var studio = pick(active_studios())
		var genre := pick_genre()
		var prestige := rndi(1, 3) if studio.style != "commercial" else rndi(0, 2)
		if genre == "drama" and chance(0.4):
			prestige = mini(3, prestige + 1)
		var roles: Array = []
		var lead_gender = "m" if chance(0.5) else "f"
		roles.append(_mk_role("lead", lead_gender, prestige, y))
		if chance(0.6):
			roles.append(_mk_role("lead", "f" if lead_gender == "m" else "m", prestige, y))
		roles.append(_mk_role("support", "m" if chance(0.5) else "f", prestige, y))
		if chance(0.4):
			roles.append(_mk_role("support", "m" if chance(0.5) else "f", prestige, y))
		var fee_sum := 0.0
		for r in roles:
			fee_sum += r.fee
		state.castings.append({
			"id": next_id(), "studioId": studio.id, "title": project_title(genre), "genre": genre,
			"prestige": prestige,
			"budget": roundi(fee_sum * rndf(3.0, 4.5) + 400000.0 * infl(y) * rndf(0.6, 1.4) * (1.0 + prestige * 0.3)),
			"deadline": rndi(2, 3), "roles": roles, "qualityMod": 0.0,
		})

func _mk_role(type: String, gender: String, prestige: int, y: float) -> Dictionary:
	var min_fame := rndi(25, 55 + prestige * 10) if type == "lead" else rndi(10, 35)
	var age_min := rndi(18, 45)
	return {
		"type": type, "gender": gender, "minFame": min_fame,
		"ageMin": age_min, "ageMax": age_min + rndi(12, 30),
		"fee": roundi(ask_fee(min_fame + 12, y) * (1.0 if type == "lead" else 0.35)),
		"filled": null, "rejected": [],
	}

func fit_score(casting: Dictionary, role: Dictionary, c: Dictionary) -> int:
	var actor: Dictionary = actor_by_id[c.aid]
	var y = state.year
	var age := age_of(actor, y)
	var fit := 30.0
	if actor.genres.has(casting.genre):
		fit += 22.0 + (5.0 if c.perks.has("script") else 0.0)
	fit += (attrs(actor).charisma - 50.0) / 15.0
	fit += clampf((c.fame - role.minFame) * 0.7, -25.0, 18.0)
	fit += c.heat * 2.0
	fit += float(state.studioRel[casting.studioId]) / 6.0
	fit -= maxf(0.0, (c.exhaustion - 50.0) / 2.5)
	# Karriere-DNA: passt das öffentliche Bild zur Rolle?
	fit += dna_fit(c, casting.genre, studio_style(casting.studioId))
	var style := studio_style(casting.studioId)
	if style == "prestige" or style == "indie":
		fit += (identity_strength("kuenstlerisch") + identity_strength("klientenorientiert")) * (4.5 if eff_talent(c) >= 88.0 else 2.5)
	else:
		fit += (identity_strength("studiotreu") + identity_strength("kommerziell")) * 3.5
	fit -= rival_casting_block(str(casting.studioId))
	fit -= rumor_fit_penalty(c)
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
		var taken := false
		for r in casting.roles:
			if r.filled != null and r.filled.get("clientId") != null and int(r.filled.clientId) == int(c.id):
				taken = true
		if taken:
			continue
		var fit := fit_score(casting, role, c)
		if c.perks.has("script") and fit < 35:
			continue
		out.append({"c": c, "fit": fit, "estFee": role_fee_for(casting, role, c),
			"dna": roundi(dna_fit(c, casting.genre, studio_style(casting.studioId)))})
	out.sort_custom(func(x, y2): return x.fit > y2.fit)
	return out

func role_fee_for(casting: Dictionary, role: Dictionary, c: Dictionary) -> int:
	var ask: float = ask_fee(c.fame, state.year) * (1.0 if role.type == "lead" else 0.35) * (1.0 + int(c.get("awards", 0)) * 0.08)
	return roundi(clampf(ask, role.fee * 0.6, role.fee * 2.2))

func submit_pitch(casting_id, role_idx: int, client_id) -> Dictionary:
	var casting = _casting(casting_id)
	var role: Dictionary = casting.roles[role_idx]
	var c = client(client_id)
	var fit := fit_score(casting, role, c)
	var p: float = clampf(fit / 100.0 + 0.08, 0.05, 0.95)
	if chance(p):
		pitch_ctx = {"casting": casting, "roleIdx": role_idx, "role": role, "client": c, "fee": role_fee_for(casting, role, c), "haggled": false}
		return {"success": true, "fee": pitch_ctx.fee}
	role.rejected.append(int(client_id))
	state.studioRel[casting.studioId] = clampi(int(state.studioRel[casting.studioId]) - 1, 0, 100)
	return {"success": false}

func _casting(cid) -> Variant:
	for cs in state.castings:
		if int(cs.id) == int(cid):
			return cs
	return null

func close_deal(fee: float, extra_log: String = "") -> void:
	var casting: Dictionary = pitch_ctx.casting
	var role: Dictionary = pitch_ctx.role
	var c: Dictionary = pitch_ctx.client
	role.filled = {"clientId": int(c.id), "fee": roundi(fee)}
	c.busyUntil = mi() + int(casting.deadline)
	log_msg("Deal: %s spielt %s in „%s“ für %s. Provision: %s.%s" % [client_name(c),
		"die Hauptrolle" if role.type == "lead" else "eine Nebenrolle", casting.title,
		fmt_money(fee), fmt_money(fee * c.commission / 100.0), extra_log], "deal")
	check_promises_on_deal(c, casting, role)
	press_event("Casting", "%s übernimmt %s in „%s“ für %s" % [client_name(c), "die Hauptrolle" if role.type == "lead" else "eine Nebenrolle", casting.title, _studio(str(casting.studioId)).name])
	if int(casting.prestige) >= 2:
		record_identity("kuenstlerisch", 0.35)
	elif studio_style(str(casting.studioId)) == "commercial":
		record_identity("kommerziell", 0.35)
	c.mood = clampf(c.mood + 8.0, 0.0, 100.0)
	if chance(0.18):
		var kind_s: String = pick(["extraAudition", "scriptAccess", "billing"])
		grant_favor(kind_s, favor_contact_for(kind_s, str(casting.studioId)))
	pitch_ctx = null

func accept_offer() -> void:
	close_deal(pitch_ctx.fee)

func haggle() -> Dictionary:
	var rel: float = state.studioRel[pitch_ctx.casting.studioId]
	var surplus: float = pitch_ctx.client.fame - pitch_ctx.role.minFame
	var p: float = clampf(0.35 + surplus / 120.0 + pitch_ctx.client.heat / 50.0 + rel / 250.0 + int(pitch_ctx.client.get("awards", 0)) * 0.06, 0.1, 0.88)
	pitch_ctx.haggled = true
	if chance(p):
		pitch_ctx.fee = roundi(pitch_ctx.fee * 1.25)
		return {"success": true, "fee": pitch_ctx.fee}
	if chance(0.45):
		state.studioRel[pitch_ctx.casting.studioId] = clampi(int(rel) - 6, 0, 100)
		log_msg("Zu hoch gepokert: „%s“ — das Studio bricht die Verhandlung mit %s ab." % [pitch_ctx.casting.title, client_name(pitch_ctx.client)], "bad")
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
	if chance(p):
		var fee1 := roundi(pitch_ctx.fee * 1.12)
		var fee2 := roundi(role_fee_for(casting, role2, c2) * 1.12)
		close_deal(fee1, " (Package-Deal)")
		role2.filled = {"clientId": int(c2.id), "fee": fee2}
		c2.busyUntil = mi() + int(casting.deadline)
		c2.mood = clampf(c2.mood + 8.0, 0.0, 100.0)
		check_promises_on_deal(c2, casting, role2)
		log_msg("Package-Deal perfekt: %s übernimmt zusätzlich eine Nebenrolle in „%s“ für %s." % [client_name(c2), casting.title, fmt_money(fee2)], "deal")
		state.agency.rep = clampi(int(state.agency.rep) + 2, 0, 100)
		grant_favor("extraAudition", favor_contact_for("extraAudition", str(casting.studioId)))
		if chance(0.4):
			var kind2: String = pick(["billing", "scriptAccess"])
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

func fulfill_promise(c: Dictionary, pr: Dictionary) -> void:
	pr.fulfilled = true
	c.loyalty = clampf(c.loyalty + 18.0, 0.0, 100.0)
	change_trust(c, 14.0)
	c.mood = clampf(c.mood + 10.0, 0.0, 100.0)
	state.agency.rep = clampi(int(state.agency.rep) + 3, 0, 100)
	log_msg("Versprechen gehalten: %s — %s. Loyalität steigt deutlich." % [client_name(c), pr.label], "deal")

func quick_production(c: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var actor: Dictionary = actor_by_id[c.aid]
	var genre: String = opts.get("genre", pick(actor.genres) if chance(0.7) else pick_genre())
	var studio: Dictionary = opts.get("studio", pick(active_studios()))
	var role_type: String = opts.get("roleType", "lead")
	var fee := roundi(ask_fee(c.fame, state.year) * (1.0 if role_type == "lead" else 0.35) * opts.get("feeMult", 1.0))
	var months := rndi(4, 6)
	var prod := {
		"id": next_id(), "studioId": studio.id, "title": project_title(genre), "genre": genre,
		"prestige": opts.get("prestige", rndi(1, 2)),
		"budget": roundi(fee * rndf(3.0, 4.5) + 300000.0 * infl(state.year)),
		"monthsLeft": months, "qualityMod": opts.get("qualityMod", 0.0),
		"roles": [{"type": role_type, "gender": actor.g, "minFame": 30, "ageMin": 18, "ageMax": 99, "fee": fee, "filled": {"clientId": int(c.id), "fee": fee}, "rejected": []}],
	}
	state.productions.append(prod)
	var income := roundi(fee * c.commission / 100.0)
	book(float(income), "provision", "Provision Sofort-Deal: %s („%s“)" % [client_name(c), prod.title])
	c.busyUntil = mi() + months
	change_trust(c, 1.5)
	# Auch Sofort-Deals zählen unmittelbar für Versprechen (Hauptrolle/Prestige)
	check_promises_on_deal(c, prod, prod.roles[0])
	press_event("Casting", "%s unterschreibt für die %s in „%s“ (%s)" % [client_name(c), "Hauptrolle" if role_type == "lead" else "Nebenrolle", prod.title, studio.name])
	if int(prod.prestige) >= 2:
		record_identity("kuenstlerisch", 0.35)
	elif studio_style(str(prod.studioId)) == "commercial":
		record_identity("kommerziell", 0.35)
	log_msg("Sofort-Deal: %s in „%s“ (%s) — %s Gage, %s Provision." % [client_name(c), prod.title, studio.name, fmt_money(fee), fmt_money(income)], "deal")
	return {"fee": fee, "income": income, "title": prod.title, "studioName": studio.name, "prod": prod}

# =====================================================================
# Monatswechsel
# =====================================================================
func end_month() -> Array:
	if state.over:
		return []
	var events: Array = []
	# Fixkosten des abgelaufenen Monats buchen und die Buchhaltung
	# des Monats abschließen (Aggregat in ledgerMonthly).
	var base_cost := roundi((2200.0 + state.clients.size() * 600.0) * infl(state.year))
	var perk_cost := roundi(perk_costs())
	book(-float(base_cost), "buero", "Büro, Personal & Fixkosten")
	if perk_cost > 0:
		book(-float(perk_cost), "perks", "Klienten-Perks (%d Klienten)" % state.clients.size())
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
			events.append({"title": "Schlagzeile", "text": "[i]%s[/i]" % h.text, "choices": [{"label": "Weiter"}]})
			if h.get("effect") == "talkies":
				for c in state.clients:
					if actor_by_id[c.aid].debut <= 1924:
						c.fame = clampf(c.fame - 12.0, 5.0, 100.0)
						c.mood -= 15.0
						log_msg("%s kämpft mit dem Tonfilm — der Ruhm bröckelt." % client_name(c), "bad")
	state.market += (1.0 - state.market) * 0.06
	state.marketHistory.append(roundi(state.market * 100.0))
	if state.marketHistory.size() > 24:
		state.marketHistory.pop_front()

	# Streik
	var strike: bool = int(state.strikeMonths) > 0
	if strike:
		state.strikeMonths = int(state.strikeMonths) - 1
		log_msg("Der Streik legt Hollywood lahm%s." % (" — deine Produktionen laufen per Ausnahme weiter" if state.strikeExempt else ""), "bad")
		if int(state.strikeMonths) == 0:
			log_msg("Der Streik ist beendet. Die Studios fahren die Produktion wieder hoch.", "history")
			state.strikeExempt = false

	# Castings → Produktionen
	if not strike:
		for casting in state.castings.duplicate():
			casting.deadline = int(casting.deadline) - 1
			if int(casting.deadline) <= 0:
				start_production(casting)
				state.castings.erase(casting)

	# Produktionen → Release
	if not strike or state.strikeExempt:
		for prod in state.productions.duplicate():
			prod.monthsLeft = int(prod.monthsLeft) - 1
			if int(prod.monthsLeft) <= 0:
				events.append(release_film(prod))
				state.productions.erase(prod)

	if not strike:
		spawn_castings(rndi(1, 2) + (1 if state.agency.rep >= 50 else 0))
		while state.castings.size() > 10:
			state.castings.pop_front()

	tick_clients(events)
	tick_rumors(events)
	tick_rivals(events)

	# Follow-ups
	for fu in state.followups.duplicate():
		if mi() >= int(fu.due):
			state.followups.erase(fu)
			var ev = Ev.build_followup(fu)
			if ev != null:
				events.append(ev)

	if int(state.month) == 2:
		var aw = awards_ceremony()
		if aw != null:
			events.append(aw)

	maybe_fire_event(events)

	_expire_favors()
	if state.agency.cash < 0:
		state.agency.debtMonths = int(state.agency.debtMonths) + 1
		log_msg("Die Agentur ist zahlungsunfähig (%d/3 Monate). Die Banken werden nervös." % int(state.agency.debtMonths), "bad")
		if int(state.agency.debtMonths) >= 3:
			state.over = true
			events.append({"title": "Game Over", "text": "Drei Monate in den roten Zahlen — die Gläubiger übernehmen. %s schließt für immer die Türen.\n\nErreicht: %d Klienten, Ruf %d, %d vermittelte Filme." % [state.agency.name, state.clients.size(), int(state.agency.rep), state.released.size()], "choices": [{"label": "Neues Spiel", "action": "restart"}]})
	else:
		state.agency.debtMonths = 0
	Newspaper.build_newspaper()
	save_game()
	return events

func maybe_fire_event(events: Array) -> void:
	var candidates: Array = []
	for e in Ev.all_events():
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
	if not chance(0.8 if seasonal else 0.45):
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
			log_msg("Hollywood trauert: %s ist verstorben (%d–%d)." % [actor.name, int(actor.birth), int(actor.death)], "history")
			state.clients.erase(c)
			continue
		var busy := not is_free(c)
		var disc: float = attrs(actor).discipline
		# Kleine monatliche Schritte; große Sprünge kommen aus Entscheidungen.
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
			book(float(tv.monthly), "tv", "TV-Vertrag: %s" % client_name(c))
			tv.months = int(tv.months) - 1
			c.fame = clampf(c.fame - 0.3, 5.0, 100.0)
		# Karriere-DNA verblasst langsam Richtung Neutral, wenn nichts nachkommt
		if not busy:
			for ax in DNA_AXES:
				c.dna[ax.key] = move_toward(c.dna[ax.key], 0.0, 0.4)
		if not busy:
			c.heat = clampf(c.heat - 1.0, -10.0, 10.0)
			c.fame = maxf(maxf(c.fame - 0.4, fame_at(actor, state.year) * 0.6), 5.0)
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
				c.loyalty = clampf(c.loyalty - 35.0, 0.0, 100.0)
				change_trust(c, -24.0)
				c.mood = clampf(c.mood - 20.0, 0.0, 100.0)
				state.agency.rep = clampi(int(state.agency.rep) - 5, 0, 100)
				log_msg("Versprechen gebrochen: %s wartete vergeblich auf %s." % [actor.name, pr.label], "bad")
				events.append({"title": "Ein gebrochenes Versprechen", "text": "[i]„Sie hatten mir Ihr Wort gegeben. In dieser Stadt ist das Wort eines Agenten alles — dachte ich.“[/i]\n\n%s ist tief enttäuscht. Loyalität stürzt ab, dein Ruf leidet." % actor.name, "choices": [{"label": "Verstanden"}]})
		# Vertragsende
		maybe_reveal_secret(c, events)
		if mi() >= int(c.contractEnd):
			if c.loyalty >= 65:
				c.contractEnd = mi() + int(c.years) * 12
				change_trust(c, 4.0)
				log_msg("%s verlängert den Vertrag ohne Zögern um %d Jahre." % [actor.name, int(c.years)], "deal")
			else:
				var cid: int = int(c.id)
				events.append({"title": "Vertrag läuft aus",
					"text": "Der Vertrag mit %s endet. Die Loyalität (%d/100) reicht nicht für eine automatische Verlängerung." % [actor.name, roundi(c.loyalty)],
					"choices": [
						{"label": "Zugeständnis: Provision −2 Punkte", "fn": func():
							var cl = client(cid)
							if cl == null:
								return "Zu spät."
							cl.commission = maxi(5, int(cl.commission) - 2)
							cl.contractEnd = mi() + int(cl.years) * 12
							cl.loyalty = clampf(cl.loyalty + 10.0, 0.0, 100.0)
							return "%s bleibt — zu %d %% Provision." % [actor.name, int(cl.commission)]},
						{"label": "Ziehen lassen", "fn": func():
							var cl = client(cid)
							if cl != null:
								state.clients.erase(cl)
							log_msg("%s verlässt die Agentur nach Vertragsende — im Guten." % actor.name, "info")
							return "Man trennt sich professionell. Keine bösen Schlagzeilen."},
					]})
				c.contractEnd = mi() + 2
		# Kündigung
		if c.loyalty < 20 and chance(0.4):
			state.clients.erase(c)
			state.agency.rep = clampi(int(state.agency.rep) - 3, 0, 100)
			log_msg("%s verlässt die Agentur. „Meine Anwälte melden sich.“" % actor.name, "bad")
			events.append({"title": "Klient verloren", "text": "%s hat den Vertrag gekündigt und wechselt zur Konkurrenz." % actor.name, "choices": [{"label": "Weiter"}]})
			continue
		if age_of(actor, state.year) > 85:
			state.clients.erase(c)
			log_msg("%s zieht sich mit %d Jahren aus dem Geschäft zurück." % [actor.name, age_of(actor, state.year)], "info")

# ---------- Produktion & Box-Office ----------
func start_production(casting: Dictionary) -> void:
	var y = state.year
	for role in casting.roles:
		if role.filled != null:
			continue
		var rival_candidates: Array = []
		for rival in state.get("rivals", []):
			for actor_id in rival.clients:
				var rival_actor: Dictionary = actor_by_id.get(str(actor_id), {})
				if not rival_actor.is_empty() and rival_actor.g == role.gender and fame_at(rival_actor, y) >= role.minFame * 0.6 and age_of(rival_actor, y) >= role.ageMin - 6 and age_of(rival_actor, y) <= role.ageMax + 8:
					rival_candidates.append({"actor":rival_actor, "rival":rival})
		if rival_candidates.size() and chance(0.68):
			var rc: Dictionary = pick(rival_candidates)
			var ra: Dictionary = rc.actor
			role.filled = {"npc":true, "name":ra.name, "talent":ra.talent, "fame":fame_at(ra, y), "actorId":ra.id, "rivalId":rc.rival.id}
			press_event("Casting", "%s setzt %s in „%s“ durch" % [rc.rival.name, ra.name, casting.title])
			continue
		var candidates = available_actors().filter(func(a):
			return a.g == role.gender and fame_at(a, y) >= role.minFame * 0.6 and age_of(a, y) >= role.ageMin - 6 and age_of(a, y) <= role.ageMax + 8)
		if candidates.size() and chance(0.7):
			var a = pick(candidates.slice(0, 8))
			role.filled = {"npc": true, "name": a.name, "talent": a.talent, "fame": fame_at(a, y)}
		else:
			var first = pick(Data.NPC_FIRST_M) if role.gender == "m" else pick(Data.NPC_FIRST_F)
			role.filled = {"npc": true, "name": "%s %s" % [first, pick(Data.NPC_LAST)], "talent": rndi(35, 70), "fame": rndi(10, maxi(12, int(role.minFame)))}
	var months := rndi(4, 7)
	var income := 0.0
	for role in casting.roles:
		if role.filled.get("clientId") != null:
			var c = client(role.filled.clientId)
			if c != null:
				income += role.filled.fee * c.commission / 100.0
				c.busyUntil = mi() + months
				change_trust(c, 1.25)
	if income > 0:
		book(float(roundi(income)), "provision", "Provisionen Drehbeginn „%s“" % casting.title)
		log_msg("Drehbeginn „%s“ — Provisionen über %s gehen ein." % [casting.title, fmt_money(income)], "deal")
	var prod = casting.duplicate(true)
	# WICHTIG: Rollen-Referenzen behalten? Produktion arbeitet auf Kopie — Klienten-IDs bleiben gültig.
	prod["monthsLeft"] = months
	state.productions.append(prod)

func release_film(prod: Dictionary) -> Dictionary:
	var script: float = 35.0 + int(prod.prestige) * 8.0 + rndf(0.0, 20.0)
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
	var quality := clampi(roundi(script * 0.45 + cast_q * 0.5 + fit_bonus + prod.get("qualityMod", 0.0) + rndf(-5.0, 5.0)), 5, 100)
	var star_power := 0.0
	var lead_n := 0
	for r in prod.roles:
		if r.type != "lead":
			continue
		lead_n += 1
		var c = client(r.filled.get("clientId")) if r.filled.get("clientId") != null else null
		star_power += (c.fame * 0.75 + attrs(actor_by_id[c.aid]).presence * 0.25) if c != null else r.filled.get("fame", 25.0)
	star_power /= maxi(1, lead_n)
	var revenue := roundi(prod.budget * (0.25 + quality / 45.0 + star_power / 70.0) * state.market * rndf(0.55, 1.75))
	var ratio: float = float(revenue) / prod.budget
	var verdict := "Flop" if ratio < 1.0 else ("Achtbarer Erfolg" if ratio < 2.0 else ("Hit" if ratio < 3.2 else "Blockbuster"))
	var affected: Array = []
	for r in prod.roles:
		var c = client(r.filled.get("clientId")) if r.filled.get("clientId") != null else null
		if c == null:
			continue
		var mult := 1.0 if r.type == "lead" else 0.5
		var narrative_mult := narrative_multiplier(c, prod, r)
		var delta: float = clampf(((quality - 55.0) / 8.0 + (ratio - 1.6) * 2.5) * mult, -8.0, 10.0)
		delta = clampf(delta * narrative_mult, -12.0, 18.0)
		# Gefallen "billing": prominente Platzierung im Vorspann bringt Extra-Ruhm.
		if c.flags.get("billingBoost", false):
			c.flags.erase("billingBoost")
			delta = clampf(delta + 3.0, -8.0, 10.0)
			log_msg("Top-Billing: %s glänzt im Vorspann von „%s“." % [client_name(c), prod.title], "deal")
		c.fame = clampf(c.fame + delta, 5.0, 100.0)
		c.heat = clampf(c.heat + delta * 0.7, -10.0, 10.0)
		c.loyalty = clampf(c.loyalty + (3.0 if delta > 0 else -2.0), 0.0, 100.0)
		c.films.push_front({"title": prod.title, "year": int(state.year), "verdict": verdict, "quality": quality, "lead": r.type == "lead", "genre":prod.genre, "prestige":int(prod.prestige), "ratio":ratio, "fameDelta":delta})
		if c.films.size() > 12:
			c.films.pop_back()
		# Karriere-DNA: jede Rolle prägt das öffentliche Bild
		imprint_dna(c, prod.genre, mult * narrative_mult, int(prod.prestige), ratio)
		advance_narrative_on_release(c, prod, r)
		if delta >= 5.0:
			press_event("Neue Stars", "%s springt mit „%s“ um %d Ruhmpunkte nach vorn" % [client_name(c), prod.title, roundi(delta)])
		snapshot_client(c)
		affected.append("%s (%s%d Ruhm)" % [client_name(c), "+" if delta >= 0 else "", roundi(delta)])
	if affected.size():
		state.agency.rep = clampi(int(state.agency.rep) + (2 if ratio >= 2.0 else (-1 if ratio < 1.0 else 0)), 0, 100)
	state.studioRel[prod.studioId] = clampi(int(state.studioRel[prod.studioId]) + (5 if ratio >= 2.0 else (-3 if ratio < 1.0 else 1)), 0, 100)
	state.released.push_front({"title": prod.title, "genre": prod.genre, "year": int(state.year), "releaseMi":mi(), "studioId": prod.studioId, "quality": quality, "revenue": revenue, "budget": prod.budget, "ratio": ratio, "verdict": verdict, "prestige": int(prod.prestige), "roles": prod.roles})
	var studio_name: String = _studio(prod.studioId).name
	log_msg("Premiere „%s“ (%s): %s — %s Einspielergebnis bei Qualität %d." % [prod.title, studio_name, verdict, fmt_money(revenue), quality], "bad" if ratio < 1.0 else "deal")
	return {"title": "Premiere: „%s“" % prod.title,
		"text": "%s · %s · Qualität %d/100\n\nEinspielergebnis: %s (Budget %s) — %s%s" % [studio_name, Data.GENRES[prod.genre].de, quality, fmt_money(revenue), fmt_money(prod.budget), verdict, ("\n\nDeine Klienten: " + ", ".join(affected)) if affected.size() else ""],
		"choices": [{"label": "Weiter"}]}

func _studio(sid: String) -> Dictionary:
	for s in Data.STUDIOS:
		if s.id == sid:
			return s
	return {"name": "?"}

# ---------- Awards ----------
func awards_ceremony() -> Variant:
	var pool = state.released.filter(func(f): return int(f.year) == int(state.year) - 1)
	if pool.is_empty():
		return null
	var sorted = pool.duplicate()
	sorted.sort_custom(func(a, b): return a.quality > b.quality)
	var noms = sorted.slice(0, 3)
	var winner: Dictionary = noms[0]
	press_event("Awards", "Award-Saison: „%s“ führt die Bestenliste des Jahrgangs %d an" % [winner.title, int(state.year) - 1])
	var text := "Die Academy ehrt die Filme des Jahres %d.\n\nBester Film: „%s“" % [int(state.year) - 1, winner.title]
	var perfs: Array = []
	for f in noms:
		for r in f.roles:
			if r.type != "lead":
				continue
			var c = client(r.filled.get("clientId")) if r.filled.get("clientId") != null else null
			var nm: String = client_name(c) if c != null else r.filled.get("name", "?")
			var talent: float = eff_talent(c) if c != null else r.filled.get("talent", 50.0)
			perfs.append({"c": c, "name": nm, "score": talent * 0.5 + f.quality * 0.4 + (c.get("campaign", 0.0) if c != null else 0.0) + rndf(0.0, 15.0), "film": f.title})
	perfs.sort_custom(func(a, b): return a.score > b.score)
	if perfs.size():
		var best: Dictionary = perfs[0]
		text += "\nBeste darstellerische Leistung: %s („%s“)" % [best.name, best.film]
		if best.c != null:
			best.c.fame = clampf(best.c.fame + 8.0, 5.0, 100.0)
			best.c.heat = clampf(best.c.heat + 5.0, -10.0, 10.0)
			best.c.loyalty = clampf(best.c.loyalty + 12.0, 0.0, 100.0)
			best.c.awards = int(best.c.get("awards", 0)) + 1
			best.c.dna.unikat = clampf(best.c.dna.unikat + 8.0, -100.0, 100.0)
			state.agency.rep = clampi(int(state.agency.rep) + 6, 0, 100)
			text += "\n\nDein Klient gewinnt! Ruf +6, Ruhm +8 — und dauerhaft mehr Verhandlungsmacht."
			log_msg("%s gewinnt den Academy Award — vermittelt von %s!" % [best.name, state.agency.name], "history")
			press_event("Awards", "%s gewinnt für „%s“ — Triumph für %s" % [best.name, best.film, state.agency.name])
		for p in perfs.slice(0, 3):
			if p.c != null:
				for pr in p.c.promises:
					if not pr.fulfilled and not pr.get("broken", false) and pr.type == "oscar":
						fulfill_promise(p.c, pr)
				if p.c != perfs[0].c:
					p.c.fame = clampf(p.c.fame + 4.0, 5.0, 100.0)
	for c in state.clients:
		c.campaign = 0.0
	return {"title": "Award-Saison %d" % int(state.year), "text": text, "choices": [{"label": "Applaus!"}]}

# ---------- Speichern / Laden ----------
const SAVE_PATH := "user://hm_save.json"

func save_game() -> void:
	if state == null:
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(state))
	f.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> bool:
	if not has_save():
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null:
		return false
	state = parsed
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
	# Migration: alter Netzwerk-Wert wird in konkrete Gefallen umgewandelt
	# (pro 15 Punkte ein Gefallen), das Feld danach entfernt.
	if state.has("network"):
		var nw := int(state.network)
		var cnt := nw / 15
		for i in cnt:
			var kind_s: String = pick(["extraAudition", "suppressStory", "scriptAccess", "billing", "galaInvite"])
			grant_favor(kind_s, favor_contact_for(kind_s), true)
		state.erase("network")
		if cnt > 0:
			log_msg("Alte Bekannte aus der Anfangszeit melden sich: %d offene Gefallen warten auf dich." % cnt, "history")
	for c in state.clients:
		if not c.has("dna"):
			c["dna"] = initial_dna(actor_by_id[c.aid])
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
	for rumor in state.rumors:
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
	return true
