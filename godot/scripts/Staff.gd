extends Node
# =====================================================================
# Hollywood Manager — Mitarbeiter & Delegation (Features 32–36).
# Angestellte übernehmen Verhandlungen, Recherche, Kontaktpflege und
# Krisen — ganz oder teilweise. Sie liefern Empfehlungen mit Begründung,
# Unsicherheit und (verdecktem) Eigeninteresse; Delegationsregeln legen
# fest, was automatisch erledigt und was zwingend vorgelegt wird; die
# Eskalation meldet Vorgänge nach Risiko, Geldwert und Klientenstatus
# zurück an den Spieler.
# Aufgabenfelder & Charakterzüge kommen aus data/staff/*.json (moddbar).
# =====================================================================

const STAFF_MAX := 3
const MODES := ["off", "propose", "auto"]
const MODE_LABELS := {"off": "Paused", "propose": "Proposes", "auto": "Autonomous"}


func _st() -> Dictionary:
	return Game.state


func _p() -> Dictionary:
	return Game.state.player


# =====================================================================
# State & Migration
# =====================================================================
func init_state() -> void:
	var st := _st()
	st["staff"] = []
	st["delegation"] = {"feeCap": 15000, "vipFame": 70, "escalateScandal": true}


func ensure_staff() -> void:
	var st := _st()
	if st == null:
		return
	if not st.has("staff") or not (st.staff is Array):
		st["staff"] = []
	if not st.has("delegation") or not (st.delegation is Dictionary):
		st["delegation"] = {}
	for key in [["feeCap", 15000], ["vipFame", 70], ["escalateScandal", true]]:
		if not st.delegation.has(key[0]):
			st.delegation[key[0]] = key[1]


func fee_cap() -> float:
	return roundf(float(_st().delegation.feeCap) * Game.infl(_st().year))


# =====================================================================
# Anstellung
# =====================================================================
func wage(s: Dictionary) -> float:
	return roundf((150.0 + float(s.skill) * 2.0) * Game.infl(_st().year))


func hire_blocked_reason(focus: String) -> String:
	if not Data.STAFF_FOCI.has(focus):
		return "Unknown desk"
	if _st().staff.size() >= STAFF_MAX:
		return "The office has no more desks (max %d)" % STAFF_MAX
	if _st().staff.any(func(s): return str(s.focus) == focus):
		return "That desk is already covered"
	return ""


func hire(focus: String) -> Dictionary:
	if hire_blocked_reason(focus) != "":
		return {}
	var first: String = Game.pick(Data.NPC_FIRST_F if Game.chance(0.5) else Data.NPC_FIRST_M)
	var s := {"id": Game.next_id(), "name": "%s %s" % [first, Game.pick(Data.NPC_LAST)],
		"focus": focus, "skill": Game.rndi(35, 70), "trait": str(Game.pick(Data.STAFF_TRAITS.keys())),
		"mode": "propose", "hiredMi": Game.mi(), "actsWeek": -99}
	_st().staff.append(s)
	Game.log_msg("%s joins the %s — wages %s a month, opinions included." % [str(s.name), str(Data.STAFF_FOCI[focus].name).to_lower(), Game.fmt_money(wage(s))], "deal")
	Network.memoir("%s joined the agency (%s)." % [str(s.name), str(Data.STAFF_FOCI[focus].name)], [str(s.name)])
	return s


func fire(sid) -> void:
	for s in _st().staff.duplicate():
		if int(s.id) == int(sid):
			_st().staff.erase(s)
			Game.log_msg("%s clears the desk. The %s falls back to you." % [str(s.name), str(Data.STAFF_FOCI.get(str(s.focus), {}).get("name", "desk")).to_lower()], "info")
			# Die Stadt recycelt jeden (Feature 22)
			Network.assistant_departs({"name": str(s.name), "skill": int(s.skill), "hiredMi": int(s.hiredMi)})
			return


func staffer_by_id(sid) -> Dictionary:
	for s in _st().staff:
		if int(s.id) == int(sid):
			return s
	return {}


func set_mode(sid, mode: String) -> void:
	var s := staffer_by_id(sid)
	if not s.is_empty() and MODES.has(mode):
		s.mode = mode


func cycle_mode(sid) -> void:
	var s := staffer_by_id(sid)
	if s.is_empty():
		return
	s.mode = MODES[(MODES.find(str(s.mode)) + 1) % MODES.size()]


# =====================================================================
# Empfehlungen (Feature 34): Begründung, Unsicherheit, Eigeninteresse
# =====================================================================
func trait_def(s: Dictionary) -> Dictionary:
	return Data.STAFF_TRAITS.get(str(s.trait), {})


# Die genannte Sicherheit ist die des Mitarbeiters — nicht die Wahrheit.
func confidence(s: Dictionary) -> int:
	return clampi(roundi(40.0 + float(s.skill) * 0.5 + float(trait_def(s).get("confidence", 0))), 20, 95)


# Ab Führungslevel 2 liest der Spieler die Agenda seiner Leute.
func bias_visible() -> bool:
	return Mogul.level("leadership") >= 2


func _bias_line(s: Dictionary) -> String:
	if bias_visible():
		return "\n[i]Your read on %s: %s.[/i]" % [str(s.name), str(trait_def(s).get("hint", "no angle you can find"))]
	return ""


# =====================================================================
# Wochen-Tick: Vorschläge, autonome Arbeit, Eskalationen (35/36)
# =====================================================================
func tick_week(events: Array) -> void:
	var st := _st()
	if st == null or not st.has("staff"):
		return
	for s in st.staff:
		if str(s.mode) == "off" or int(s.get("actsWeek", -99)) == Game.wi():
			continue
		if not Game.chance(0.45):
			continue
		s.actsWeek = Game.wi()
		match str(s.focus):
			"deals":
				_work_deals(s, events)
			"research":
				_work_research(s, events)
			"care":
				_work_care(s, events)
			"crisis":
				_work_crisis(s, events)


# ---------- Deal desk ----------
func _best_pitch() -> Dictionary:
	var best := {}
	var best_fit := 0
	for cs in _st().castings:
		if bool(cs.get("hidden", false)):
			continue
		for ri in cs.roles.size():
			var role: Dictionary = cs.roles[ri]
			if role.filled != null:
				continue
			for e in Game.eligible_clients(cs, role):
				if int(e.fit) > best_fit:
					best_fit = int(e.fit)
					best = {"casting": cs, "roleIdx": ri, "role": role, "client": e.c, "fit": int(e.fit),
						"fee": Game.role_fee_for(cs, role, e.c)}
	return best


func _exec_pitch(s: Dictionary, pick: Dictionary) -> void:
	var res: Dictionary = Game.submit_pitch(int(pick.casting.id), int(pick.roleIdx), int(pick.client.id))
	if not bool(res.get("success", false)):
		Game.log_msg("%s pitched %s for “%s” — the studio passed. Filed under experience." % [str(s.name), Game.client_name(pick.client), str(pick.casting.title)], "info")
		return
	# Charakterzug färbt die Gage: Studiofreunde geben zu schnell nach.
	Game.pitch_ctx.fee = roundi(float(Game.pitch_ctx.fee) * (1.0 + float(trait_def(s).get("fee", 0.0)) + float(s.skill) / 1000.0))
	Game.accept_offer()
	Game.log_msg("%s closes: %s takes a role in “%s”. Delegation, when it works." % [str(s.name), Game.client_name(pick.client), str(pick.casting.title)], "deal")
	Mogul.grant_xp("leadership", 1.0, "A staffer closed a deal")


func _work_deals(s: Dictionary, events: Array) -> void:
	var pick := _best_pitch()
	if pick.is_empty():
		return
	var vip: bool = float(pick.client.fame) >= float(_st().delegation.vipFame)
	var over_cap: bool = float(pick.fee) > fee_cap()
	if str(s.mode) == "auto" and not vip and not over_cap:
		_exec_pitch(s, pick)
		_st().weekDigest.append("%s worked the phones on “%s”" % [str(s.name), str(pick.casting.title)])
		return
	# Eskalation (36) bzw. Vorschlag (34): der Spieler entscheidet.
	var reason := ""
	if vip:
		reason = "Client rule: %s is above your %d-fame line — always your call." % [Game.client_name(pick.client), int(_st().delegation.vipFame)]
	elif over_cap:
		reason = "Money rule: the fee sits above your %s approval cap." % Game.fmt_money(fee_cap())
	var title := "Escalation from the deal desk" if (str(s.mode) == "auto") else "A recommendation from %s" % str(s.name)
	var body := "%s: “%s” is casting — I recommend pitching [b]%s[/b] (fit reads %s, fee about %s). I put my certainty at ~%d%%.%s%s" % [
		str(s.name), str(pick.casting.title), Game.client_name(pick.client), Game.grade(float(pick.fit)),
		Game.fmt_money(float(pick.fee)), confidence(s),
		("\n\n" + reason) if reason != "" else "", _bias_line(s)]
	events.append({"title": title, "text": body, "choices": [
		{"label": "Approve — let them run it", "fn": func(): _exec_pitch(s, pick)},
		{"label": "Not this one"},
		{"label": "I'll handle it personally", "fn": func(): Game.log_msg("You take the %s file back onto your own desk." % str(pick.casting.title), "info")},
	]})


# ---------- Research ----------
func _research_run() -> void:
	Game.book(-roundf(40.0 * Game.infl(_st().year)), "buero", "Research: readers & typists")
	_st().coverageQueue = int(_st().get("coverageQueue", 0)) + 1
	Network._tick_reveal_castings(true)


func _work_research(s: Dictionary, events: Array) -> void:
	if str(s.mode) == "auto":
		_research_run()
		_st().weekDigest.append("%s fed the coverage pile" % str(s.name))
		return
	events.append({"title": "A recommendation from %s" % str(s.name),
		"text": "%s: The story department is running dry. Give me a small budget and I'll have fresh coverage on your desk — and I hear at least one project is being cast without an announcement. Certainty ~%d%%.%s" % [str(s.name), confidence(s), _bias_line(s)],
		"choices": [
			{"label": "Approve the budget (−%s)" % Game.fmt_money(roundf(40.0 * Game.infl(_st().year))), "fn": func(): _research_run()},
			{"label": "Not this month"},
		]})


# ---------- Care ----------
func _coldest_contact() -> Dictionary:
	var coldest := {}
	for ct in _st().contacts:
		if coldest.is_empty() or float(ct.rel) < float(coldest.rel):
			coldest = ct
	return coldest


func _care_gesture(s: Dictionary, ct: Dictionary) -> void:
	Game.book(-roundf(8.0 * Game.infl(_st().year)), "buero", "Care desk: flowers & couriers")
	Network.adjust(ct, {"liking": 1.5 + float(s.skill) / 60.0, "closeness": 1.0}, false)
	ct.lastMi = Game.mi()
	Persona._memory(ct, "%s kept in touch on the agency's behalf." % str(s.name))


func _work_care(s: Dictionary, events: Array) -> void:
	var ct := _coldest_contact()
	if ct.is_empty():
		return
	if str(s.mode) == "auto":
		_care_gesture(s, ct)
		_st().weekDigest.append("%s kept %s warm" % [str(s.name), str(ct.name)])
		return
	events.append({"title": "A recommendation from %s" % str(s.name),
		"text": "%s: [b]%s[/b] is cooling off (relationship %d). A gesture from the office would hold the line — though nothing replaces you showing up yourself. Certainty ~%d%%.%s" % [str(s.name), str(ct.name), roundi(float(ct.rel)), confidence(s), _bias_line(s)],
		"choices": [
			{"label": "Send a gesture (−%s)" % Game.fmt_money(roundf(8.0 * Game.infl(_st().year))), "fn": func(): _care_gesture(s, ct)},
			{"label": "I'll go myself when I can"},
		]})


# ---------- Crisis desk ----------
func _worst_rumor() -> Dictionary:
	var worst := {}
	for rumor in _st().rumors:
		if not bool(rumor.knownToPlayer) or float(rumor.belief) < 25.0:
			continue
		if worst.is_empty() or float(rumor.belief) > float(worst.belief):
			worst = rumor
	return worst


func _work_crisis(s: Dictionary, events: Array) -> void:
	var rumor := _worst_rumor()
	if rumor.is_empty():
		return
	var cost := roundf(12000.0 * Game.infl(_st().year) * (0.5 if Mogul.has_ability("spin_doctor") else 1.0))
	var scandal_rule: bool = bool(_st().delegation.escalateScandal) and float(rumor.belief) >= 55.0
	if str(s.mode) == "auto" and not scandal_rule and (Game.has_favor("suppressStory") or (cost <= fee_cap() and float(_st().agency.cash) >= cost)):
		Game.suppress_rumor(int(rumor.id))
		_st().weekDigest.append("%s buried a story before it grew teeth" % str(s.name))
		return
	var title := "Escalation from the crisis desk" if str(s.mode) == "auto" else "A recommendation from %s" % str(s.name)
	var reason := "\n\nYour standing rule: stories this loud (belief %d) always reach your desk." % roundi(float(rumor.belief)) if scandal_rule else ""
	events.append({"title": title,
		"text": "%s: The story about [b]%s[/b] is gaining belief (%d). I recommend suppressing it — favor or %s. Risk: the source may dig further. Certainty ~%d%%.%s%s" % [str(s.name), Game.rumor_subject_name(rumor), roundi(float(rumor.belief)), Game.fmt_money(cost), confidence(s), reason, _bias_line(s)],
		"choices": [
			{"label": "Approve — bury it", "fn": func(): Game.log_msg(Game.suppress_rumor(int(rumor.id)), "info")},
			{"label": "Just deny it", "fn": func(): Game.log_msg(Game.deny_rumor(int(rumor.id)), "info")},
			{"label": "I'll handle this one myself"},
		]})


# =====================================================================
# Monats-Tick: Löhne, Lernen, Führungserfahrung
# =====================================================================
func tick_month() -> void:
	var st := _st()
	if st == null or not st.has("staff"):
		return
	for s in st.staff:
		Game.book(-wage(s), "buero", "Wages: %s (%s)" % [str(s.name), str(Data.STAFF_FOCI.get(str(s.focus), {}).get("name", "?"))])
		s.skill = clampi(int(s.skill) + (2 if Mogul.has_ability("mentor") else 1), 10, 95)
	if st.staff.size():
		Mogul.grant_xp("leadership", 0.5 * st.staff.size(), "Running a staff")
