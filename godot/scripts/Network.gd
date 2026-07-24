extends Node
# =====================================================================
# Hollywood Manager — Networking as a core system (Features 10–15).
# Covers: the savable career memoir (decisions & relationships stay
# traceable for decades), the unified contact web (circles & personal
# links between everyone who matters), multi-dimensional relationships
# (trust/liking/respect/closeness/dependence/irritation instead of one
# number), social capital (access, information, referrals, credibility,
# markers), gatekeepers in front of the important people, and personal
# introductions through mutual acquaintances.
# Data-driven: roles, circles, VIP types and notable persons come from
# data/contacts/*.json and can be extended via user://data/ mods.
# =====================================================================

const DIMS := ["trust", "liking", "respect", "closeness", "dependence", "irritation"]
const FACTS_MAX := 10
const OCCASIONS_MAX := 3
# Contact upkeep (Feature 16): occasions that keep relationships alive.
const OCCASION_KINDS := {
	"birthday": {"name": "Birthday", "icon": "🎂", "act": "Send congratulations & a small gift", "cost": 25.0, "ap": 0},
	"premiere": {"name": "Premiere week", "icon": "🎬", "act": "Send flowers and a handwritten note", "cost": 35.0, "ap": 0},
	"crisis": {"name": "A rough patch", "icon": "🤝", "act": "Offer personal help", "cost": 60.0, "ap": 1},
	"callback": {"name": "Asked you to call back", "icon": "📞", "act": "Return the call", "cost": 0.0, "ap": 1},
}
# Dynamic NPC careers (Feature 22): today's reporter is tomorrow's press baron.
const CAREER_STEPS := {"journalist": "kolumnist", "kolumnist": "verleger", "produzent": "studio", "regisseur": "produzent", "anwalt": "financier"}
const DIM_INFO := {
	"trust": {"name": "Trust", "icon": "🤝"},
	"liking": {"name": "Liking", "icon": "💛"},
	"respect": {"name": "Respect", "icon": "🎩"},
	"closeness": {"name": "Closeness", "icon": "🫂"},
	"dependence": {"name": "They owe you", "icon": "🪝"},
	"irritation": {"name": "Irritation", "icon": "💢"},
}
const LINK_KINDS := {"freund": "friends", "familie": "family", "geschaeft": "business", "club": "club circle"}
const MEMOIR_MAX := 400
const GATE_BLOCK_REL := 45.0
const MARKER_COST := 25.0


func _st() -> Dictionary:
	return Game.state


# =====================================================================
# State setup & migration
# =====================================================================
func init_state() -> void:
	var st := _st()
	st["memoirs"] = []
	st["occasions"] = []
	for ct in st.contacts:
		seed_contact(ct)
	_weave_links()


# Migration: retrofit dims, circles, gates, links and the memoir.
func ensure_network() -> void:
	var st := _st()
	if st == null:
		return
	if not st.has("memoirs") or not (st.memoirs is Array):
		st["memoirs"] = []
	if not st.has("occasions") or not (st.occasions is Array):
		st["occasions"] = []
	if st.has("contacts"):
		for ct in st.contacts:
			seed_contact(ct)
		_weave_links()


# One number becomes six: existing rel seeds the dimensions so old
# relationships keep roughly their standing.
func seed_contact(ct: Dictionary) -> void:
	if not ct.has("dims") or not (ct.dims is Dictionary):
		var r := float(ct.get("rel", 25.0))
		ct["dims"] = {"trust": r, "liking": r, "closeness": r * 0.9,
			"respect": r * 0.7 + 10.0, "dependence": 10.0, "irritation": 0.0}
	for d in DIMS:
		if not ct.dims.has(d):
			ct.dims[d] = 0.0
	if not ct.has("circles"):
		ct["circles"] = Data.CONTACT_CIRCLES.get(str(ct.type), []).duplicate()
	if not ct.has("links"):
		ct["links"] = []
	if not ct.has("metMi"):
		ct["metMi"] = Game.mi()
	if not ct.has("vip"):
		ct["vip"] = Data.CONTACT_VIP_TYPES.has(str(ct.type))
	if bool(ct.vip) and not ct.has("gate"):
		var kind := "Secretary"
		match str(ct.type):
			"financier": kind = "Attorney"
			"verleger": kind = "Assistant"
		var first: String = Game.pick(Data.NPC_FIRST_F if Game.chance(0.7) else Data.NPC_FIRST_M)
		ct["gate"] = {"name": "%s %s %s" % [kind, first, Game.pick(Data.NPC_LAST)], "rel": float(Game.rndi(10, 30))}
	if not ct.has("gateWeek"):
		ct["gateWeek"] = -99
	if not ct.has("markerMi"):
		ct["markerMi"] = -99
	if not ct.has("facts"):
		ct["facts"] = []
	if not ct.has("infoMi"):
		ct["infoMi"] = -99
	ct.rel = derived_rel(ct)


# The unified web: everyone who matters is connected to someone —
# friendships, family, business, club circles.
func _weave_links() -> void:
	var st := _st()
	for ct in st.contacts:
		if not (ct.links is Array):
			ct["links"] = []
		if ct.links.size() > 0 or st.contacts.size() < 2:
			continue
		var others: Array = st.contacts.filter(func(o): return str(o.name) != str(ct.name))
		others.shuffle()
		for other in others.slice(0, Game.rndi(1, 2)):
			if ct.links.any(func(l): return str(l.to) == str(other.name)):
				continue
			var kind: String = Game.pick(["freund", "geschaeft", "club", "geschaeft", "freund", "familie"])
			ct.links.append({"to": str(other.name), "kind": kind})
			if not (other.links is Array):
				other["links"] = []
			if not other.links.any(func(l): return str(l.to) == str(ct.name)):
				other.links.append({"to": str(ct.name), "kind": kind})


func contact_by_name(cname: String) -> Dictionary:
	for ct in _st().contacts:
		if str(ct.name) == cname:
			return ct
	return {}


# =====================================================================
# Feature 12 — Multi-dimensional relationships
# =====================================================================
func dim(ct: Dictionary, d: String) -> float:
	if not ct.has("dims"):
		seed_contact(ct)
	return float(ct.dims.get(d, 0.0))


# The composite the rest of the game reads as "rel": warmth carries,
# irritation poisons everything.
func derived_rel(ct: Dictionary) -> float:
	if not ct.has("dims"):
		return float(ct.get("rel", 25.0))
	var d: Dictionary = ct.dims
	return clampf(float(d.liking) * 0.35 + float(d.trust) * 0.25 + float(d.closeness) * 0.15
		+ float(d.respect) * 0.15 + float(d.dependence) * 0.10 - float(d.irritation) * 0.6, 0.0, 100.0)


# Central mutation point: applies deltas, refreshes the composite and
# lets liking ripple through the web (friends hear how you treat people).
func adjust(ct: Dictionary, deltas: Dictionary, spill: bool = true) -> void:
	if ct.is_empty():
		return
	if not ct.has("dims"):
		seed_contact(ct)
	for d in deltas:
		if ct.dims.has(d):
			ct.dims[d] = clampf(float(ct.dims[d]) + float(deltas[d]), 0.0, 100.0)
	ct.rel = derived_rel(ct)
	if not spill:
		return
	var ripple := float(deltas.get("liking", 0.0)) - float(deltas.get("irritation", 0.0)) * 0.5
	if absf(ripple) >= 3.0:
		for link in ct.get("links", []):
			var other := contact_by_name(str(link.to))
			if not other.is_empty():
				adjust(other, {"liking": ripple * 0.25}, false)


# How each channel translates into dimensions (Feature 2 meets 12):
# dinners build closeness and trust, letters respect, gifts liking.
const CHANNEL_PROFILE := {
	"call": {"liking": 0.7, "closeness": 0.3},
	"meet": {"liking": 0.35, "closeness": 0.4, "trust": 0.25},
	"note": {"respect": 0.6, "liking": 0.4},
	"gift": {"liking": 0.8, "closeness": 0.2},
	"aide": {"respect": 0.6, "liking": 0.4},
	"club": {"closeness": 0.45, "trust": 0.3, "liking": 0.25},
}


func apply_channel(ct: Dictionary, key: String, gain: float) -> void:
	if gain < 0.0:
		adjust(ct, {"liking": gain, "irritation": -gain * 1.5})
		return
	var profile: Dictionary = CHANNEL_PROFILE.get(key, {"liking": 1.0})
	var deltas := {}
	for d in profile:
		deltas[d] = gain * 1.6 * float(profile[d])
	adjust(ct, deltas)


# Favor traffic and similar nudges from other systems.
func touch(ct: Dictionary, delta: float) -> void:
	adjust(ct, {"liking": delta * 0.6, "trust": delta * 0.4}, false)


# Someone owes you — that is leverage, not affection.
func bump_dependence(person_name: String, amount: float) -> void:
	var ct := contact_by_name(person_name)
	if not ct.is_empty():
		adjust(ct, {"dependence": amount}, false)


# =====================================================================
# Feature 14 — Gatekeepers: the small people decide who gets through
# =====================================================================
func is_vip(ct: Dictionary) -> bool:
	return bool(ct.get("vip", false))


func gate_of(ct: Dictionary) -> Dictionary:
	return ct.get("gate", {})


# A VIP takes meetings only if the anteroom likes you — or you are
# already close enough that no anteroom dares stop you.
func gate_blocks(ct: Dictionary) -> bool:
	if not is_vip(ct) or gate_of(ct).is_empty():
		return false
	return float(gate_of(ct).rel) < GATE_BLOCK_REL and dim(ct, "closeness") < 50.0


func charm_cost() -> float:
	return roundf(15.0 * Game.infl(_st().year))


# Flowers, theatre tickets, remembering a birthday: cheap, weekly, and
# it pays off for years.
func charm_gate(cid) -> Dictionary:
	var ct := Persona.contact_by_id(cid)
	if ct.is_empty() or gate_of(ct).is_empty():
		return {"ok": false, "text": "No anteroom to charm."}
	if int(ct.get("gateWeek", -99)) == Game.wi():
		return {"ok": false, "text": "You have already been kind to the anteroom this week."}
	if float(_st().player.cash) < charm_cost():
		return {"ok": false, "text": "Privately short on cash."}
	Persona.book(-charm_cost(), "Flowers & courtesies: %s" % str(gate_of(ct).name))
	ct.gateWeek = Game.wi()
	var gate: Dictionary = gate_of(ct)
	gate.rel = clampf(float(gate.rel) + float(Game.rndi(7, 13)), 0.0, 100.0)
	Mogul.grant_xp("networking", 1.0, "Was kind to the small people")
	Persona._memory(ct, "Your kindness to %s did not go unnoticed." % str(gate.name))
	if float(gate.rel) >= GATE_BLOCK_REL:
		return {"ok": true, "text": "%s smiles when your name comes up now (%d/100). The door to %s stands open." % [str(gate.name), roundi(float(gate.rel)), str(ct.name)]}
	return {"ok": true, "text": "Flowers for %s (%d/100). A few more gestures and your calls get through." % [str(gate.name), roundi(float(gate.rel))]}


# Loyal anterooms leak: schedules, moods, the occasional whisper.
func _tick_gates_month() -> void:
	for ct in _st().contacts:
		var gate := gate_of(ct)
		if gate.is_empty() or float(gate.rel) < 70.0 or not Game.chance(0.25):
			continue
		if Game.chance(0.5):
			var tip_line: String = Mogul.maybe_market_tip(ct)
			if tip_line != "":
				Game.log_msg("%s slips you a word in passing: something is moving at %s's desk." % [str(gate.name), str(ct.name)], "info")
				continue
		for rumor in _st().rumors:
			if not bool(rumor.knownToPlayer):
				rumor.knownToPlayer = true
				Game.log_msg("%s mentions, sotto voce, a story making the rounds — you'd never have heard it otherwise." % str(gate.name), "info")
				break


# =====================================================================
# Feature 15 — Introductions: new doors open through mutual friends
# =====================================================================
func notables_unmet() -> Array:
	var st := _st()
	return Data.CONTACT_NOTABLES.filter(func(n): return not st.contacts.any(func(ct): return str(ct.name) == str(n.name)))


func circles_of_type(type_s: String) -> Array:
	return Data.CONTACT_CIRCLES.get(type_s, [])


# Who can vouch for you: shares a circle with the target and actually
# likes AND trusts you — nobody risks their name for less.
func introducers_for(notable: Dictionary) -> Array:
	var target_circles := circles_of_type(str(notable.type))
	var out: Array = []
	for ct in _st().contacts:
		if not ct.get("circles", []).any(func(c): return target_circles.has(str(c))):
			continue
		if dim(ct, "liking") >= 55.0 and dim(ct, "trust") >= 45.0:
			out.append(ct)
	return out


func introduce_blocked_reason(notable_name: String) -> String:
	if Persona.is_away():
		return "You are not in Los Angeles"
	if int(_st().contactAP) < 1:
		return "No contact time left this week"
	for n in notables_unmet():
		if str(n.name) == notable_name:
			return "" if not introducers_for(n).is_empty() else "Nobody in your book can credibly vouch for you"
	return "Already in your circle"


func introduce(notable_name: String, introducer_cid) -> Dictionary:
	var reason := introduce_blocked_reason(notable_name)
	if reason != "":
		return {"ok": false, "text": reason}
	var st := _st()
	var notable := {}
	for n in notables_unmet():
		if str(n.name) == notable_name:
			notable = n
	var intro := Persona.contact_by_id(introducer_cid)
	if notable.is_empty() or intro.is_empty():
		return {"ok": false, "text": "This introduction cannot be arranged."}
	st.contactAP = int(st.contactAP) - 1
	var ct := Persona._add_contact(str(notable.type), str(notable.name))
	seed_contact(ct)
	# A credible referral opens the door warmer than any cold call could.
	ct.dims.liking = 30.0 + dim(intro, "liking") * 0.2
	ct.dims.trust = 25.0 + dim(intro, "trust") * 0.15
	ct.dims.respect = 20.0 + float(_st().player.indRep) * 0.2
	ct.rel = derived_rel(ct)
	ct.links.append({"to": str(intro.name), "kind": "freund"})
	intro.links.append({"to": str(ct.name), "kind": "freund"})
	adjust(intro, {"liking": 3.0}, false)
	Persona._memory(ct, "%s introduced you — their name opened this door." % str(intro.name))
	Persona._memory(intro, "Vouched for you with %s." % str(ct.name))
	Mogul.grant_xp("networking", 2.0, "A door opened through a friend")
	memoir("%s introduced you to %s — a door that money alone would not have opened." % [str(intro.name), str(ct.name)], [str(intro.name), str(ct.name)])
	var text := "Over lunch, %s makes the introduction: [b]%s[/b] now takes your calls.\n\n%s" % [str(intro.name), str(ct.name), str(notable.get("desc", ""))]
	if Game.chance(0.5):
		Game.owe_favor(str(Game.pick(["galaInvite", "extraAudition"])), {"type": str(intro.type), "name": str(intro.name)})
		text += "\n\n⚠ Of course, nothing in this town is free: you owe %s one now." % str(intro.name)
	Game.log_msg("New in your book: %s (introduced by %s)." % [str(ct.name), str(intro.name)], "deal")
	return {"ok": true, "text": text}


# =====================================================================
# Feature 13 — Social capital: what a contact is actually good for
# =====================================================================
func capital_of(ct: Dictionary) -> Array:
	var out: Array = []
	if is_vip(ct):
		out.append({"icon": "🚪", "label": "Access", "active": not gate_blocks(ct),
			"desc": "An audience with someone who decides things — once the anteroom lets you through."})
	if ct.get("circles", []).has("presse"):
		out.append({"icon": "🗞", "label": "Information", "active": dim(ct, "trust") >= 60.0,
			"desc": "From trust 60: passes you stories before they print."})
	out.append({"icon": "🪜", "label": "Referral", "active": dim(ct, "liking") >= 55.0 and dim(ct, "trust") >= 45.0,
		"desc": "Likes and trusts you enough to vouch for you with their own circle."})
	if ct.get("circles", []).has("studio"):
		out.append({"icon": "🎬", "label": "Credibility", "active": dim(ct, "respect") >= 60.0,
			"desc": "From respect 60: their word softens studios toward your pitches."})
	out.append({"icon": "🪝", "label": "Marker", "active": dim(ct, "dependence") >= 50.0,
		"desc": "Owes you enough to be called on — cash in leverage for a concrete favor."})
	return out


func marker_blocked_reason(ct: Dictionary) -> String:
	if dim(ct, "dependence") < 50.0:
		return "Not enough leverage yet"
	if Game.mi() - int(ct.get("markerMi", -99)) < 2:
		return "You called on them recently — markers need time to grow back"
	return ""


# Calling in a marker: leverage becomes a concrete favor — and is spent.
func call_marker(cid) -> Dictionary:
	var ct := Persona.contact_by_id(cid)
	if ct.is_empty():
		return {"ok": false, "text": "Unknown contact."}
	var reason := marker_blocked_reason(ct)
	if reason != "":
		return {"ok": false, "text": reason}
	ct.markerMi = Game.mi()
	adjust(ct, {"dependence": -MARKER_COST, "irritation": 3.0}, false)
	var kind := "extraAudition"
	match str(ct.type):
		"kolumnist", "journalist", "verleger": kind = "suppressStory"
		"regisseur": kind = "scriptAccess"
		"produzent": kind = "billing"
		"studio", "financier", "gastgeberin", "anwalt": kind = str(Game.pick(["galaInvite", "extraAudition"]))
	Game.grant_favor(kind, {"type": str(ct.type), "name": str(ct.name)}, true)
	Persona._memory(ct, "You called in a marker. Debt paid — noted.")
	memoir("You called in a marker with %s: %s." % [str(ct.name), str(Game.FAVOR_KINDS[kind].name)], [str(ct.name)])
	return {"ok": true, "text": "One sentence is enough — %s knows exactly what you mean. The favor is yours: [b]%s[/b].\n\nThe marker is spent, and being reminded of debts never makes anyone warmer." % [str(ct.name), str(Game.FAVOR_KINDS[kind].name)]}


# Credibility (Feature 13): a respected studio contact softens pitches
# at their house. Called from Game.submit_pitch.
func pitch_bonus(casting: Dictionary) -> float:
	var st := _st()
	if st == null or not st.has("contacts"):
		return 0.0
	var studio_name := str(Game._studio(str(casting.get("studioId", ""))).name)
	for ct in st.contacts:
		if ct.get("circles", []).has("studio") and dim(ct, "respect") >= 60.0 and str(ct.name).contains(studio_name):
			return 0.05
	return 0.0


# =====================================================================
# Feature 10 — The career memoir: decisions stay traceable for decades
# =====================================================================
func memoir(text: String, people: Array = []) -> void:
	var st := _st()
	if st == null or not st.has("memoirs"):
		return
	st.memoirs.append({"mi": Game.mi(), "text": text, "people": people})
	while st.memoirs.size() > MEMOIR_MAX:
		st.memoirs.pop_front()


# Everything a contact remembers about you — including how it started.
func bond_story(ct: Dictionary) -> Array:
	var out: Array = []
	for m in _st().get("memoirs", []):
		if m.get("people", []).has(str(ct.name)):
			out.append(m)
	return out


# =====================================================================
# Feature 16 — Contact upkeep: occasions keep relationships alive
# =====================================================================
func open_occasions() -> Array:
	return _st().get("occasions", []).filter(func(o): return str(o.status) == "open")


func _spawn_occasions() -> void:
	var st := _st()
	if open_occasions().size() >= OCCASIONS_MAX:
		return
	var pool: Array = st.contacts.duplicate()
	pool.shuffle()
	for ct in pool:
		if not Game.chance(0.12):
			continue
		if st.occasions.any(func(o): return str(o.status) == "open" and str(o.ctName) == str(ct.name)):
			continue
		var kinds := ["birthday", "callback", "crisis"]
		if ["regisseur", "produzent", "studio"].has(str(ct.type)):
			kinds.append("premiere")
		var kind: String = Game.pick(kinds)
		st.occasions.append({"id": Game.next_id(), "ctName": str(ct.name), "kind": kind,
			"madeMi": Game.mi(), "dueMi": Game.mi() + Game.rndi(1, 2), "status": "open"})
		Game.log_msg("%s %s: %s — a small gesture now counts double." % [str(OCCASION_KINDS[kind].icon), str(OCCASION_KINDS[kind].name), str(ct.name)], "info")
		break
	while st.occasions.size() > 12:
		var oldest = null
		for occ in st.occasions:
			if str(occ.status) != "open" and (oldest == null or int(occ.madeMi) < int(oldest.madeMi)):
				oldest = occ
		if oldest == null:
			break
		st.occasions.erase(oldest)


func occasion_blocked_reason(occ: Dictionary) -> String:
	var def: Dictionary = OCCASION_KINDS[str(occ.kind)]
	if int(_st().contactAP) < int(def.ap):
		return "No contact time left this week"
	if float(_st().player.cash) < roundf(float(def.cost) * Game.infl(_st().year)):
		return "Privately short on cash"
	return ""


func occasion_respond(occ_id) -> Dictionary:
	var st := _st()
	for occ in st.occasions:
		if int(occ.id) != int(occ_id) or str(occ.status) != "open":
			continue
		var reason := occasion_blocked_reason(occ)
		if reason != "":
			return {"ok": false, "text": reason}
		var ct := contact_by_name(str(occ.ctName))
		if ct.is_empty():
			occ.status = "done"
			return {"ok": false, "text": "They are no longer in your book."}
		var def: Dictionary = OCCASION_KINDS[str(occ.kind)]
		var cost := roundf(float(def.cost) * Game.infl(st.year))
		if cost > 0.0:
			Persona.book(-cost, "%s %s — %s" % [str(def.icon), str(def.name), str(ct.name)])
		st.contactAP = int(st.contactAP) - int(def.ap)
		occ.status = "done"
		var text := ""
		match str(occ.kind):
			"birthday":
				adjust(ct, {"liking": 4.0, "closeness": 2.0})
				Persona._memory(ct, "You remembered the birthday.")
				text = "A handwritten card and their favorite flowers. Small gestures, long memories."
			"premiere":
				adjust(ct, {"respect": 3.0, "liking": 3.0})
				Persona._memory(ct, "Flowers and a note for the premiere.")
				text = "Your note arrives before the reviews do — that is the trick."
			"crisis":
				adjust(ct, {"trust": 7.0, "closeness": 5.0})
				add_fact(ct, "stood by them in a rough patch", 1, 2.0)
				Persona._memory(ct, "You helped when it mattered — personally.")
				text = "No press, no favors asked — just help. This is how bonds are actually made."
			"callback":
				adjust(ct, {"liking": 3.0, "trust": 2.0})
				Persona._memory(ct, "You called back promptly.")
				text = "You return the call the same week. In this town, that alone is a distinction."
		ct.lastMi = Game.mi()
		Mogul.grant_xp("networking", 1.0, "Kept a relationship alive")
		return {"ok": true, "text": "%s %s — %s.\n\n%s" % [str(def.icon), str(def.name), str(ct.name), text]}
	return {"ok": false, "text": "The moment has passed."}


func _tick_occasions() -> void:
	var st := _st()
	for occ in st.occasions:
		if str(occ.status) != "open" or Game.mi() <= int(occ.dueMi):
			continue
		var ct := contact_by_name(str(occ.ctName))
		# Delegation (Feature 4 meets 16): the assistant covers the small stuff.
		if Persona.has_assistant() and Persona.rule("occasions") and ["birthday", "callback"].has(str(occ.kind)) and not ct.is_empty():
			occ.status = "delegated"
			Game.book(-roundf(10.0 * Game.infl(st.year)), "buero", "Assistant: flowers & callbacks")
			adjust(ct, {"liking": 1.5}, false)
			Persona._memory(ct, "Your assistant handled it — noted, with a thin smile.")
			continue
		occ.status = "missed"
		if ct.is_empty():
			continue
		adjust(ct, {"irritation": 4.0, "closeness": -3.0, "liking": -2.0})
		add_fact(ct, "could not even be bothered to call", -1, 1.0)
		Persona._memory(ct, "You did not even call. People collect such things.")
	_spawn_occasions()


# =====================================================================
# Feature 17 — Who knows what: information comes with the job
# =====================================================================
func info_blocked_reason(ct: Dictionary) -> String:
	if dim(ct, "trust") < 40.0:
		return "They don't trust you with more than small talk (trust 40 needed)"
	if Game.mi() - int(ct.get("infoMi", -99)) < 2:
		return "You tapped them recently — sources need time"
	if int(_st().contactAP) < 1:
		return "No contact time left this week"
	return ""


func ask_info(cid) -> Dictionary:
	var st := _st()
	var ct := Persona.contact_by_id(cid)
	if ct.is_empty():
		return {"ok": false, "text": "Unknown contact."}
	var reason := info_blocked_reason(ct)
	if reason != "":
		return {"ok": false, "text": reason}
	st.contactAP = int(st.contactAP) - 1
	ct.infoMi = Game.mi()
	Mogul.grant_xp("networking", 1.0, "Worked a source")
	var lines: Array = []
	match str(ct.type):
		"journalist", "kolumnist", "verleger":
			var revealed := 0
			var quota := 2 if str(ct.type) == "verleger" else 1
			for rumor in st.rumors:
				if revealed >= quota:
					break
				if not bool(rumor.knownToPlayer):
					rumor.knownToPlayer = true
					revealed += 1
					lines.append("A story that has not reached print yet lands on your side of the table.")
					if dim(ct, "trust") >= 70.0:
						lines.append("They even tell you who is carrying it: %s." % ", ".join(rumor.get("holders", [])))
			if revealed == 0:
				adjust(ct, {"liking": 1.0}, false)
				lines.append("A quiet week — nothing on the wire that concerns you. Good to know, too.")
		"regisseur", "produzent":
			var found := false
			for cs in st.castings:
				if bool(cs.get("hidden", false)) and str(cs.get("netSource", "")) != "":
					cs.hidden = false
					cs.netSource = ""
					found = true
					lines.append("They slide a project across the table that was never announced: “%s”." % str(cs.title))
					break
			if not found and dim(ct, "trust") >= 60.0:
				Game.spawn_castings(1)
				lines.append("Nothing on their desk — but they make a call, and by evening a new project is on yours.")
			elif not found:
				var cs2: Array = st.castings.filter(func(c): return not bool(c.get("hidden", false)))
				if cs2.size():
					var pickc: Dictionary = Game.pick(cs2)
					lines.append("On “%s” they whisper: the script reads like a %d out of 100." % [str(pickc.title), Game.script_insight(pickc)])
				else:
					lines.append("The town is quiet. Even the liars have nothing.")
		"studio":
			if st.productions.size():
				var prod: Dictionary = Game.pick(st.productions)
				var base := 35.0 + float(prod.prestige) * 8.0 + float(Game.hashs(str(prod.id) + "scr") % 21)
				var honest := "the dailies are genuinely good — the studio quietly raises expectations" if base + float(prod.get("qualityMod", 0.0)) >= 55.0 else "the dailies worry people — do not plan on a triumph"
				lines.append("Behind closed doors, on “%s”: %s." % [str(prod.title), honest])
			else:
				Game.spawn_castings(1)
				lines.append("Nothing shooting that concerns you — but they mention a project the town has not heard of yet.")
		"anwalt":
			var cleaned := false
			for rec in st.backroom:
				if str(rec.status) == "open" and bool(rec.paper):
					rec.paper = false
					cleaned = true
					lines.append("One folder, one fireplace: the paper trail of your arrangement “%s” no longer exists." % str(Mogul.deal_def(str(rec.dealId)).get("name", "")))
					break
			if not cleaned:
				_st().player.discretion = clampf(float(_st().player.discretion) + 3.0, 0.0, 100.0)
				lines.append("They comb through your affairs and find no loose ends. You sleep better (discretion +3).")
		"financier":
			var tip_line := Mogul.maybe_market_tip(ct)
			lines.append(tip_line if tip_line != "" else "The money is nervous, they say — nothing concrete this week.")
		"gastgeberin":
			if Game.chance(0.5):
				Game.grant_favor("galaInvite", {"type": str(ct.type), "name": str(ct.name)})
				lines.append("An envelope with your name on it: an invitation to an evening where everyone who matters will be.")
			else:
				var others: Array = st.contacts.filter(func(o): return str(o.name) != str(ct.name))
				if others.size():
					var boost: Dictionary = Game.pick(others)
					adjust(boost, {"closeness": 3.0}, false)
					lines.append("She mentions, in passing, what %s really thinks of you — useful, flattering, and only slightly indiscreet (closeness +3)." % str(boost.name))
	Persona._memory(ct, "Passed you information — quietly.")
	var head := "🔍 %s knows things by trade — and shares them with you." % str(ct.name)
	return {"ok": true, "text": head + "\n\n" + "\n".join(lines)}


# Player passes knowledge on (Feature 19): a scoop for the press earns
# leverage — and leaves your fingerprints on the story.
func share_story_blocked_reason(ct: Dictionary) -> String:
	if not ["journalist", "kolumnist", "verleger"].has(str(ct.type)):
		return "Not in the news business"
	if int(_st().contactAP) < 1:
		return "No contact time left this week"
	if _shareable_rumor().is_empty():
		return "Nothing in your notebook they would print (that doesn't hurt your own clients)"
	return ""


func _shareable_rumor() -> Dictionary:
	for rumor in _st().rumors:
		if not bool(rumor.knownToPlayer) or bool(rumor.get("sharedByPlayer", false)):
			continue
		var c = Game.rumor_subject_client(rumor)
		if c == null and str(rumor.get("subject", "")) != "agency":
			return rumor
	return {}


func share_story(cid) -> Dictionary:
	var ct := Persona.contact_by_id(cid)
	if ct.is_empty():
		return {"ok": false, "text": "Unknown contact."}
	var reason := share_story_blocked_reason(ct)
	if reason != "":
		return {"ok": false, "text": reason}
	var st := _st()
	var rumor := _shareable_rumor()
	st.contactAP = int(st.contactAP) - 1
	rumor["sharedByPlayer"] = true
	if not rumor.holders.has("Journalists"):
		rumor.holders.append("Journalists")
	rumor.belief = clampf(float(rumor.belief) + 6.0, 0.0, 100.0)
	adjust(ct, {"trust": 3.0, "dependence": 5.0}, false)
	st.player.discretion = clampf(float(st.player.discretion) - 2.0, 0.0, 100.0)
	Game.record_identity("skrupellos", 0.5)
	Persona._memory(ct, "You fed them a story — they owe you column inches.")
	Mogul.grant_xp("media", 1.0, "Placed a story")
	return {"ok": true, "text": "You slide the story about %s across the table. %s takes notes, buys the next round — and owes you.\n\n(The story gains reach; your fingerprints are on it: discretion −2.)" % [Game.rumor_subject_name(rumor), str(ct.name)]}


# =====================================================================
# Feature 18/19 — Subjective reputation & how knowledge travels
# =====================================================================
func add_fact(ct: Dictionary, text: String, tone: int, weight: float = 1.0, via: String = "") -> void:
	if ct.is_empty():
		return
	if not ct.has("facts"):
		ct["facts"] = []
	if ct.facts.any(func(f): return str(f.text) == text):
		return
	ct.facts.push_front({"mi": Game.mi(), "text": text, "tone": tone, "weight": weight, "via": via})
	while ct.facts.size() > FACTS_MAX:
		ct.facts.pop_back()


func opinion_score(ct: Dictionary) -> float:
	var score := 0.0
	for f in ct.get("facts", []):
		score += float(f.tone) * float(f.weight)
	return score


# Everyone forms their own picture — from what actually reached them.
func opinion_label(ct: Dictionary) -> String:
	var score := opinion_score(ct)
	if score <= -3.0:
		return "considers you untrustworthy — and says so"
	if dim(ct, "irritation") >= 25.0:
		return "finds you tiresome right now"
	if score <= -1.0:
		return "has quiet doubts about you"
	if score >= 3.0 and dim(ct, "trust") >= 50.0:
		return "considers your word good currency"
	if score >= 1.5:
		return "speaks well of you when your name comes up"
	if dim(ct, "respect") >= 60.0:
		return "takes you seriously as a player"
	if float(ct.rel) >= 60.0:
		return "is genuinely fond of you"
	if float(ct.rel) >= 35.0:
		return "sees you as one of many — so far"
	return "barely has a picture of you yet"


# Knowledge moves through the web: what one hears, friends hear too —
# a little garbled, and bad news travels faster.
func _spread_facts(force: bool = false) -> void:
	var st := _st()
	for ct in st.contacts:
		for f in ct.get("facts", []).duplicate():
			if str(f.get("via", "")) != "" and not force:
				continue
			if Game.mi() - int(f.mi) > 2 and not force:
				continue
			var p := 0.3 + (0.15 if int(f.tone) < 0 else 0.0)
			for link in ct.get("links", []):
				if not force and not Game.chance(p):
					continue
				var other := contact_by_name(str(link.to))
				if other.is_empty() or other.get("facts", []).any(func(g): return str(g.text) == str(f.text)):
					continue
				add_fact(other, str(f.text), int(f.tone), float(f.weight) * 0.6, str(ct.name))
				Persona._memory(other, "Heard from %s: you %s." % [str(ct.name), str(f.text)])


# =====================================================================
# Feature 20 — Opportunities come through people, not menus
# =====================================================================
func _tick_reveal_castings(force: bool = false) -> void:
	var st := _st()
	for cs in st.castings:
		if not bool(cs.get("hidden", false)) or str(cs.get("netSource", "")) == "":
			continue
		for ct in st.contacts:
			if str(ct.type) != str(cs.netSource) or float(ct.rel) < 45.0:
				continue
			if force or Game.chance(0.5 + dim(ct, "trust") / 200.0):
				cs.hidden = false
				cs.netSource = ""
				Game.log_msg("%s tips you off: “%s” is casting — quietly, for now." % [str(ct.name), str(cs.title)], "deal")
				Persona._memory(ct, "Tipped you off about “%s” before the town knew." % str(cs.title))
				add_fact(ct, "brought you in early on a project", 1, 0.5)
			break


# =====================================================================
# Feature 21 — Networking events leave permanent traces
# =====================================================================
func can_gala() -> bool:
	return Game.has_favor("galaInvite") and not Persona.is_away() and int(_st().contactAP) >= 1


# A person you have not met yet, drawn from the data pools.
func _meet_someone(origin: String) -> Dictionary:
	var st := _st()
	var candidates: Array = []
	for type_s in Data.CONTACT_PERSONS:
		for cname in Data.CONTACT_PERSONS[type_s]:
			if not st.contacts.any(func(ct): return str(ct.name) == str(cname)):
				candidates.append({"type": str(type_s), "name": str(cname)})
	if candidates.is_empty():
		return {}
	var pickp: Dictionary = Game.pick(candidates)
	var ct := Persona._add_contact(str(pickp.type), str(pickp.name))
	ct.dims.liking = float(Game.rndi(20, 32))
	ct.dims.trust = float(Game.rndi(12, 22))
	ct.rel = derived_rel(ct)
	Persona._memory(ct, "You met %s." % origin)
	memoir("You met %s %s." % [str(ct.name), origin], [str(ct.name)])
	return ct


func attend_gala() -> Dictionary:
	if not can_gala():
		return {"ok": false, "text": "No invitation, no gala — or you are simply not in town."}
	var st := _st()
	Game.consume_favor("galaInvite")
	st.contactAP = int(st.contactAP) - 1
	st.player.energy = clampf(float(st.player.energy) - 5.0, 0.0, 100.0)
	var lines: Array = ["Chandeliers, orchestra, and everyone pretending not to look at everyone else."]
	var met := _meet_someone("at the gala")
	if not met.is_empty():
		lines.append("A handshake by the bar becomes a name in your book: [b]%s[/b] takes your calls now." % str(met.name))
	if Game.chance(0.4) and st.contacts.size() > 0:
		var pr_ct: Dictionary = Game.pick(st.contacts)
		lines.append(Persona._make_promise(pr_ct))
	if Game.chance(0.35):
		var kind: String = Game.pick(["extraAudition", "billing", "scriptAccess", "suppressStory"])
		var fav := Game.grant_favor(kind, Game.favor_contact_for(kind))
		lines.append("Between two toasts, %s leans in: they owe you one (%s)." % [fav["from"].get("name", "?"), str(Game.FAVOR_KINDS[kind].name)])
	if Game.chance(0.3) and st.contacts.size() > 0:
		var tip_line := Mogul.maybe_market_tip(Game.pick(st.contacts))
		if tip_line != "":
			lines.append(tip_line)
	if Game.chance(0.25):
		Game.spawn_castings(1)
		lines.append("A producer corners you about a project that is not announced yet — it is on your desk in the morning.")
	if Game.chance(0.3):
		Game.grant_favor("galaInvite", Game.favor_contact_for("galaInvite"), true)
		lines.append("Before you leave, a hostess touches your arm: you are on the list for the next one, too.")
	Mogul.grant_xp("networking", 2.0, "Worked a gala")
	memoir("An evening at the gala — new names, new promises, new debts.")
	return {"ok": true, "text": "\n".join(lines)}


# A chance encounter at the club bar (hooked from the club channel).
func club_encounter() -> String:
	var met := _meet_someone("over a late glass at the club")
	if met.is_empty():
		return ""
	return "At the bar, an introduction without an introducer: [b]%s[/b] is in your book now." % str(met.name)


# =====================================================================
# Feature 22 — Dynamic NPC careers: be kind on the way up
# =====================================================================
func _retitle(cname: String, new_type: String) -> String:
	var parts := cname.split(" ")
	var tail := " ".join(parts.slice(maxi(0, parts.size() - 2)))
	return "%s %s" % [str(Data.CONTACT_ROLES.get(new_type, new_type)), tail]


func promote_contact(ct: Dictionary) -> String:
	if not CAREER_STEPS.has(str(ct.type)):
		return ""
	var old_name := str(ct.name)
	var new_type := str(CAREER_STEPS[str(ct.type)])
	var new_name := _retitle(old_name, new_type)
	if new_type == "studio":
		var studio: Dictionary = Game.pick(Game.active_studios())
		new_name = "Studio boss %s" % " ".join(old_name.split(" ").slice(maxi(0, old_name.split(" ").size() - 2)))
		Persona._memory(ct, "Now runs the shop at %s." % str(studio.name))
	# Promises and occasions follow the person, not the business card.
	for pr in _st().promises:
		if str(pr.to) == old_name:
			pr.to = new_name
	for occ in _st().occasions:
		if str(occ.ctName) == old_name:
			occ.ctName = new_name
	for other in _st().contacts:
		for l in other.get("links", []):
			if str(l.to) == old_name:
				l.to = new_name
	ct.name = new_name
	ct.type = new_type
	ct.circles = Data.CONTACT_CIRCLES.get(new_type, []).duplicate()
	ct.vip = Data.CONTACT_VIP_TYPES.has(new_type)
	if bool(ct.vip):
		# Their new anteroom already knows your name — if they like you.
		var first: String = Game.pick(Data.NPC_FIRST_F if Game.chance(0.7) else Data.NPC_FIRST_M)
		ct["gate"] = {"name": "Secretary %s %s" % [first, Game.pick(Data.NPC_LAST)],
			"rel": clampf(20.0 + dim(ct, "liking") * 0.4, 0.0, 100.0)}
	adjust(ct, {"respect": 8.0, "closeness": -4.0}, false)
	if opinion_score(ct) > 0.0 or dim(ct, "liking") >= 50.0:
		adjust(ct, {"dependence": 8.0}, false)
		add_fact(ct, "were kind on the way up", 1, 1.5)
		Persona._memory(ct, "Rose to %s — and remembers who was kind before it mattered." % str(Data.CONTACT_ROLES.get(new_type, new_type)))
	else:
		Persona._memory(ct, "Rose to %s. Your file with them is thin." % str(Data.CONTACT_ROLES.get(new_type, new_type)))
	memoir("%s rises to %s — you knew them when." % [new_name, str(Data.CONTACT_ROLES.get(new_type, new_type))], [new_name])
	Game.log_msg("People move: %s is now %s." % [old_name, str(Data.CONTACT_ROLES.get(new_type, new_type))], "deal")
	return new_name


# The anteroom takes the big office: the secretary you sent flowers to
# is suddenly a producer — early kindness pays off years later.
func gate_rises(vip_ct: Dictionary) -> Dictionary:
	var gate := gate_of(vip_ct)
	if gate.is_empty():
		return {}
	var gate_name := str(gate.name)
	var tail := " ".join(gate_name.split(" ").slice(maxi(0, gate_name.split(" ").size() - 2)))
	var ct := Persona._add_contact("produzent", "Producer %s" % tail)
	ct.dims.liking = clampf(float(gate.rel) * 0.6, 0.0, 100.0)
	ct.dims.trust = clampf(float(gate.rel) * 0.4, 0.0, 100.0)
	ct.dims.closeness = 20.0
	ct.rel = derived_rel(ct)
	if float(gate.rel) >= 60.0:
		add_fact(ct, "were kind when they were still answering phones", 1, 2.0)
		Persona._memory(ct, "You sent flowers when they ran an anteroom. They have not forgotten.")
	else:
		Persona._memory(ct, "Knows you from the anteroom days — vaguely.")
	var first: String = Game.pick(Data.NPC_FIRST_F if Game.chance(0.7) else Data.NPC_FIRST_M)
	vip_ct["gate"] = {"name": "Secretary %s %s" % [first, Game.pick(Data.NPC_LAST)], "rel": float(Game.rndi(10, 25))}
	memoir("%s left the anteroom and became a producer — careers start small in this town." % str(ct.name), [str(ct.name)])
	Game.log_msg("%s trades the anteroom for a producer's office. Small people rarely stay small." % str(ct.name), "deal")
	return ct


# Your former assistant does not vanish — this town recycles everyone.
func assistant_departs(a: Dictionary, force: bool = false) -> void:
	if a.is_empty() or (not force and not Game.chance(0.6)):
		return
	var type_s: String = Game.pick(["produzent", "journalist"])
	var ct := Persona._add_contact(type_s, "%s %s" % [str(Data.CONTACT_ROLES.get(type_s, type_s)), str(a.name)])
	var months := Game.mi() - int(a.get("hiredMi", Game.mi()))
	ct.dims.liking = clampf(25.0 + float(a.skill) * 0.2, 0.0, 100.0)
	ct.dims.trust = clampf(20.0 + float(months) * 0.5, 0.0, 100.0)
	ct.rel = derived_rel(ct)
	Persona._memory(ct, "Ran your front desk for %d months — knows how you work." % maxi(months, 1))
	memoir("%s left your front desk and stayed in the business — the town recycles everyone." % str(ct.name), [str(ct.name)])
	Game.log_msg("%s lands on their feet — and stays a familiar face in your book." % str(ct.name), "info")


func _tick_npc_careers() -> void:
	var st := _st()
	# At most one rise per month — careers take years, not weeks.
	for ct in st.contacts:
		if CAREER_STEPS.has(str(ct.type)) and Game.chance(0.015):
			promote_contact(ct)
			return
	for ct in st.contacts:
		if not gate_of(ct).is_empty() and Game.chance(0.008):
			gate_rises(ct)
			return


# =====================================================================
# Monthly tick: capital pays out, irritation cools, anterooms whisper
# =====================================================================
func tick_month() -> void:
	var st := _st()
	if st == null or not st.has("memoirs"):
		return
	for ct in st.contacts:
		if not ct.has("dims"):
			continue
		# Anger cools — slowly. Warmth needs contact; that decay lives
		# in the promise/contact tick.
		if float(ct.dims.irritation) > 0.0:
			adjust(ct, {"irritation": -2.0}, false)
	_tick_occasions()
	_tick_reveal_castings()
	_spread_facts()
	_tick_npc_careers()
	_tick_gates_month()
	# Information: trusted press contacts pass stories along.
	for ct in st.contacts:
		if ct.get("circles", []).has("presse") and dim(ct, "trust") >= 60.0 and Game.chance(0.3):
			for rumor in st.rumors:
				if not bool(rumor.knownToPlayer):
					rumor.knownToPlayer = true
					Game.log_msg("%s calls before the presses run: a story is circulating that concerns you." % str(ct.name), "info")
					break
			break
	# A trusted lawyer quietly buries an old debt now and then.
	for ct in st.contacts:
		if str(ct.type) == "anwalt" and dim(ct, "trust") >= 60.0 and not st.debts.is_empty() and Game.chance(0.25):
			var debt: Dictionary = st.debts[0]
			Game.remove_debt(debt.id)
			Game.log_msg("%s makes an old obligation disappear — cleanly, on paper, forever." % str(ct.name), "deal")
			break
