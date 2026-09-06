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
	# Migration Feature 33: Loyalität, Auslastung, Gehaltsbonus nachrüsten
	for s in st.staff:
		for skey in [["loyalty", 55.0], ["load", 0.0], ["wageBonus", 0.0], ["raiseMi", -99]]:
			if not s.has(skey[0]):
				s[skey[0]] = skey[1]


func fee_cap() -> float:
	return roundf(float(_st().delegation.feeCap) * Util.infl(_st().year))


# =====================================================================
# Anstellung
# =====================================================================
func wage(s: Dictionary) -> float:
	return roundf((150.0 + float(s.skill) * 2.0) * (1.0 + float(s.get("wageBonus", 0.0))) * Util.infl(_st().year))


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
	var first: String = Util.pick(Data.NPC_FIRST_F if Util.chance(0.5) else Data.NPC_FIRST_M)
	var s := {"id": Game.next_id(), "name": "%s %s" % [first, Util.pick(Data.NPC_LAST)],
		"focus": focus, "skill": Util.rndi(35, 70), "trait": str(Util.pick(Data.STAFF_TRAITS.keys())),
		"mode": "propose", "hiredMi": Game.mi(), "actsWeek": -99,
		"loyalty": float(Util.rndi(45, 70)), "load": 0.0, "wageBonus": 0.0, "raiseMi": -99}
	_st().staff.append(s)
	Game.log_msg("%s joins the %s — wages %s a month, opinions included." % [str(s.name), str(Data.STAFF_FOCI[focus].name).to_lower(), Util.fmt_money(wage(s))], "deal")
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


# Gehaltserhöhung (Feature 33/35): das billigste Mittel gegen Abwerbung.
func raise_blocked_reason(sid) -> String:
	var s := staffer_by_id(sid)
	if s.is_empty():
		return "Unknown"
	if Game.mi() - int(s.get("raiseMi", -99)) < 6:
		return "The last raise is still fresh"
	return ""


func give_raise(sid) -> void:
	var s := staffer_by_id(sid)
	if s.is_empty() or raise_blocked_reason(sid) != "":
		return
	s.raiseMi = Game.mi()
	s.wageBonus = float(s.get("wageBonus", 0.0)) + 0.2
	s.loyalty = clampf(float(s.get("loyalty", 55.0)) + 15.0, 0.0, 100.0)
	Game.log_msg("%s gets a raise — loyalty is cheaper than a spin-off." % str(s.name), "info")


# Fehlerneigung (Feature 33): Kompetenz, Loyalität und Überlastung
# entscheiden, wie gut delegierte Arbeit wirklich ist.
func mishap_chance(s: Dictionary) -> float:
	return clampf(0.06 + float(s.get("load", 0.0)) / 300.0
		+ (50.0 - float(s.skill)) / 500.0
		+ (40.0 - float(s.get("loyalty", 55.0))) / 500.0, 0.02, 0.5)


func _note_act(s: Dictionary) -> void:
	s.load = clampf(float(s.get("load", 0.0)) + 10.0, 0.0, 100.0)


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
		# Erholung (Feature 33): Auslastung fällt, wenn nichts ansteht
		s.load = clampf(float(s.get("load", 0.0)) - 4.0, 0.0, 100.0)
		if str(s.mode) == "off" or int(s.get("actsWeek", -99)) == Game.wi():
			continue
		if not Util.chance(0.45):
			continue
		s.actsWeek = Game.wi()
		_note_act(s)
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
	# Fehler (Feature 33): ein überlasteter oder illoyaler Mitarbeiter
	# verbrennt den Pitch — und ein Stück Studio-Beziehung gleich mit.
	if Util.chance(mishap_chance(s)):
		Game.state.studioRel[pick.casting.studioId] = clampi(int(Game.state.studioRel.get(pick.casting.studioId, 40)) - 3, 0, 100)
		pick.role.rejected.append(int(pick.client.id))
		Game.log_msg("%s botches the pitch for “%s” — wrong tone, wrong day. The studio remembers (relations −3)." % [str(s.name), str(pick.casting.title)], "bad")
		return
	var res: Dictionary = Game.submit_pitch(int(pick.casting.id), int(pick.roleIdx), int(pick.client.id))
	if not bool(res.get("success", false)):
		Game.log_msg("%s pitched %s for “%s” — the studio passed. Filed under experience." % [str(s.name), Game.client_name(pick.client), str(pick.casting.title)], "info")
		return
	# Charakterzug färbt die Gage: Studiofreunde geben zu schnell nach.
	Game.pitch_ctx.fee = roundi(float(Game.pitch_ctx.fee) * (1.0 + float(trait_def(s).get("fee", 0.0)) + float(s.skill) / 1000.0))
	Game.accept_offer()
	# Persönliche Betreuung (Feature 34): große Namen merken, wenn nur
	# der Angestellte anruft.
	if float(pick.client.fame) >= 60.0:
		Game.change_trust(pick.client, -2.0)
		Game.log_msg("%s notices the boss didn't make this call personally." % Game.client_name(pick.client), "info")
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
		reason = "Money rule: the fee sits above your %s approval cap." % Util.fmt_money(fee_cap())
	var title := "Escalation from the deal desk" if (str(s.mode) == "auto") else "A recommendation from %s" % str(s.name)
	var body := "%s: “%s” is casting — I recommend pitching [b]%s[/b] (fit reads %s, fee about %s). I put my certainty at ~%d%%.%s%s" % [
		str(s.name), str(pick.casting.title), Game.client_name(pick.client), Util.grade(float(pick.fit)),
		Util.fmt_money(float(pick.fee)), confidence(s),
		("\n\n" + reason) if reason != "" else "", _bias_line(s)]
	events.append({"title": title, "text": body, "choices": [
		{"label": "Approve — let them run it", "fn": func(): _exec_pitch(s, pick)},
		{"label": "Not this one"},
		{"label": "I'll handle it personally", "fn": func(): Game.log_msg("You take the %s file back onto your own desk." % str(pick.casting.title), "info")},
	]})


# ---------- Research ----------
func _research_run() -> void:
	Game.book(-roundf(40.0 * Util.infl(_st().year)), "buero", "Research: readers & typists")
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
			{"label": "Approve the budget (−%s)" % Util.fmt_money(roundf(40.0 * Util.infl(_st().year))), "fn": func(): _research_run()},
			{"label": "Not this month"},
		]})


# ---------- Care ----------
func _coldest_contact() -> Dictionary:
	var coldest := {}
	for ct in _st().contacts:
		if coldest.is_empty() or float(ct.rel) < float(coldest.rel):
			coldest = ct
	return coldest


# QA-07: liefert das konkrete Ergebnis (true = Geste gelungen), damit die
# Meldungen der Aufrufer der Wahrheit entsprechen. `roll` erlaubt Tests,
# den Zufall zu kontrollieren (< mishap_chance ⇒ Patzer); -1 = echter Wurf.
func _care_gesture(s: Dictionary, ct: Dictionary, roll: float = -1.0) -> bool:
	Game.book(-roundf(8.0 * Util.infl(_st().year)), "buero", "Care desk: flowers & couriers")
	# Fehler (Feature 33): die falsche Karte zum falschen Anlass
	if (roll if roll >= 0.0 else randf()) < mishap_chance(s):
		Network.adjust(ct, {"irritation": 3.0, "liking": -1.0}, false)
		Persona._memory(ct, "%s sent condolences — to a premiere. People talk." % str(s.name))
		Game.log_msg("%s mixes up the card files — %s got the wrong flowers with the wrong note." % [str(s.name), str(ct.name)], "bad")
		return false
	Network.adjust(ct, {"liking": 1.5 + float(s.skill) / 60.0, "closeness": 1.0}, false)
	ct.lastMi = Game.mi()
	Persona._memory(ct, "%s kept in touch on the agency's behalf." % str(s.name))
	return true


func _work_care(s: Dictionary, events: Array) -> void:
	var ct := _coldest_contact()
	if ct.is_empty():
		return
	if str(s.mode) == "auto":
		# QA-07: der Digest meldet das echte Ergebnis, kein Pauschal-Erfolg.
		if _care_gesture(s, ct):
			_st().weekDigest.append("%s kept %s warm" % [str(s.name), str(ct.name)])
		else:
			_st().weekDigest.append("%s botched a gesture toward %s — wrong card, wrong note" % [str(s.name), str(ct.name)])
		return
	events.append({"title": "A recommendation from %s" % str(s.name),
		"text": "%s: [b]%s[/b] is cooling off (relationship %d). A gesture from the office would hold the line — though nothing replaces you showing up yourself. Certainty ~%d%%.%s" % [str(s.name), str(ct.name), roundi(float(ct.rel)), confidence(s), _bias_line(s)],
		"choices": [
			{"label": "Send a gesture (−%s)" % Util.fmt_money(roundf(8.0 * Util.infl(_st().year))), "fn": func():
				if _care_gesture(s, ct):
					return "The gesture lands. %s feels remembered." % str(ct.name)
				return "It backfires: wrong flowers, wrong note. %s is more irritated than before." % str(ct.name)},
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
	var cost := roundf(12000.0 * Util.infl(_st().year) * (0.5 if Mogul.has_ability("spin_doctor") else 1.0))
	var scandal_rule: bool = bool(_st().delegation.escalateScandal) and float(rumor.belief) >= 55.0
	if str(s.mode) == "auto" and not scandal_rule and (Game.has_favor("suppressStory") or (cost <= fee_cap() and float(_st().agency.cash) >= cost)):
		Scandal.suppress_rumor(int(rumor.id))
		_st().weekDigest.append("%s buried a story before it grew teeth" % str(s.name))
		return
	var title := "Escalation from the crisis desk" if str(s.mode) == "auto" else "A recommendation from %s" % str(s.name)
	var reason := "\n\nYour standing rule: stories this loud (belief %d) always reach your desk." % roundi(float(rumor.belief)) if scandal_rule else ""
	events.append({"title": title,
		"text": "%s: The story about [b]%s[/b] is gaining belief (%d). I recommend suppressing it — favor or %s. Risk: the source may dig further. Certainty ~%d%%.%s%s" % [str(s.name), Scandal.rumor_subject_name(rumor), roundi(float(rumor.belief)), Util.fmt_money(cost), confidence(s), reason, _bias_line(s)],
		"choices": [
			{"label": "Approve — bury it", "fn": func(): Game.log_msg(Scandal.suppress_rumor(int(rumor.id)), "info")},
			{"label": "Just deny it", "fn": func(): Game.log_msg(Scandal.deny_rumor(int(rumor.id)), "info")},
			{"label": "I'll handle this one myself"},
		]})


# Warnzeichen für das Morgen-Briefing (Feature 33/35).
func briefing_items() -> Array:
	var items: Array = []
	for s in _st().get("staff", []):
		if float(s.get("loyalty", 55.0)) < 40.0:
			items.append("🗂 %s seems restless lately — a raise or lighter load might keep them%s." % [str(s.name),
				" (loyalty %d)" % roundi(float(s.loyalty)) if bias_visible() else ""])
		elif float(s.get("load", 0.0)) >= 70.0:
			items.append("🗂 %s is drowning in files — overloaded people make expensive mistakes." % str(s.name))
	return items


# =====================================================================
# Monats-Tick: Löhne, Lernen, Loyalität — und Abwerbung (Feature 35)
# =====================================================================
func tick_month(events: Array = []) -> void:
	var st := _st()
	if st == null or not st.has("staff"):
		return
	for s in st.staff.duplicate():
		Game.book(-wage(s), "buero", "Wages: %s (%s)" % [str(s.name), str(Data.STAFF_FOCI.get(str(s.focus), {}).get("name", "?"))])
		s.skill = clampi(int(s.skill) + (2 if Mogul.has_ability("mentor") else 1), 10, 95)
		# Loyalität (Feature 33): Vertrauen und Erfolg binden, Überlastung
		# und Bevormundung treiben fort.
		var drift := 0.0
		drift += 1.5 if str(s.mode) == "auto" else (0.0 if str(s.mode) == "propose" else -1.5)
		drift -= 2.0 if float(s.get("load", 0.0)) >= 70.0 else 0.0
		drift += 1.0 if int(st.agency.rep) >= 60 else 0.0
		s.loyalty = clampf(float(s.get("loyalty", 55.0)) + drift, 0.0, 100.0)
		# Abwerbung & Abspaltung (Feature 35): gute Leute mit schlechter
		# Bindung gehen — zur Konkurrenz oder in die Selbstständigkeit.
		if float(s.loyalty) < 30.0 and int(s.skill) >= 55 and Util.chance(0.15):
			_defect(s, events)
	if st.staff.size():
		Mogul.grant_xp("leadership", 0.5 * st.staff.size(), "Running a staff")


func _defect(s: Dictionary, events: Array) -> void:
	var st := _st()
	st.staff.erase(s)
	var takes_client: bool = str(s.focus) == "deals" and st.clients.size() > 0 and Util.chance(0.5)
	var poached = null
	if takes_client:
		for c in st.clients:
			if poached == null or float(c.loyalty) < float(poached.loyalty):
				poached = c
	if Util.chance(0.5) and st.rivals.size() > 0:
		# Zur Konkurrenz — mit Aktenkenntnis und schlechtem Gewissen.
		var rival: Dictionary = Util.pick(st.rivals)
		rival.grudge = clampf(float(rival.grudge) + 10.0, 0.0, 100.0)
		if poached != null:
			Rivals.rival_poach_client(str(rival.id), poached)
		Network.memoir("%s defected to %s%s — trained by you, used against you." % [str(s.name), str(rival.name), " and took %s along" % Game.client_name(poached) if poached != null else ""], [str(s.name)])
		events.append({"title": "A defection", "text": "[b]%s[/b] clears the desk overnight and reappears at %s%s.\n\nEverything they know about your files, they now know for the other side." % [str(s.name), str(rival.name), " — with %s in tow" % Game.client_name(poached) if poached != null else ""], "choices": [{"label": "Change the locks"}]})
		Game.log_msg("%s defects to %s. Loyalty is a wage you didn't pay." % [str(s.name), str(rival.name)], "bad")
	else:
		# Die eigene Agentur — der Traum jedes guten Angestellten.
		var name_parts := str(s.name).split(" ")
		var tail := str(name_parts[name_parts.size() - 1])
		var new_rival := {"id": "spinoff_%d" % Game.next_id(), "name": "%s & Associates" % tail,
			"style": "nachwuchs", "clients": [], "grudge": 20.0, "rel": 0.0,
			"studioId": str(Game.active_studios()[0].id) if Game.active_studios().size() else ""}
		st.rivals.append(new_rival)
		if poached != null:
			Rivals.rival_poach_client(str(new_rival.id), poached)
		Network.memoir("%s left to found %s — your training, their letterhead." % [str(s.name), str(new_rival.name)], [str(s.name)])
		var spin_extra := ", with %s as founding client" % Game.client_name(poached) if poached != null else ""
		events.append({"title": "A spin-off",
			"text": "[b]%s[/b] resigns — politely, finally — and opens [b]%s[/b] three blocks away%s.\n\nThe town loves nothing more than a protégé with sharp elbows." % [str(s.name), str(new_rival.name), spin_extra],
			"choices": [{"label": "Send flowers. Sharpen knives."}]})
		Game.log_msg("%s founds %s — the market just got one agency more crowded." % [str(s.name), str(new_rival.name)], "bad")
