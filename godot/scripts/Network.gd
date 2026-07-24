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
