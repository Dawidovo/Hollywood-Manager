extends Node
# =====================================================================
# Hollywood Manager — The manager as a person (split out of Game.gd).
# Covers: personal finances & career ladder, condition (energy/stress/
# health), contact book with real communication channels, the promise
# register, the node map (locations & presence) and the personal
# assistant with delegation rules.
# Data-driven: career levels, reputation titles, contacts and locations
# come from data/*.json and can be extended via user://data/ mods.
# All amounts are in 1925 dollars and scaled with Util.infl().
# =====================================================================

const PLAYER_LEDGER_MAX := 120
# Share of monthly commissions paid out privately as a success royalty.
const ROYALTY := 0.08
# Contact points per week: how much relationship time the manager has.
const AP_PER_WEEK := 3
const CONTACT_LOG_MAX := 8
const PROMISES_MAX := 30
# Assistant: base wage (1925 $/month) plus skill-dependent part.
const ASSISTANT_BASE_WAGE := 120.0


func _st() -> Dictionary:
	return Game.state


# =====================================================================
# Player: separate private finances, condition, career
# =====================================================================
func default_player() -> Dictionary:
	return {
		"cash": 0.0, "career": 0,
		"energy": 70.0, "stress": 20.0, "health": 85.0,
		"pubRep": 10.0, "indRep": 15.0, "discretion": 50.0, "influence": 5.0,
		"ledger": [], "monthFlags": {},
		"location": "la", "locActWeek": -99, "awayNoted": false,
		"privateLife": {"partner": null, "marriedMi": -1, "friends": 0, "lastVacMi": 0, "courtMi": -99, "proposalAsked": false},
	}


# Migration: retrofit state.player (and missing fields) on old saves.
func ensure_player() -> void:
	var st := _st()
	if st == null:
		return
	if not st.has("player") or not (st.player is Dictionary):
		st["player"] = default_player()
		# Legacy saves: derive the career level from what was achieved so a
		# mogul-grade save does not wake up as a junior agent.
		while _promotion_due():
			st.player.career = int(st.player.career) + 1
	var defaults := default_player()
	for key in defaults:
		if not st.player.has(key):
			st.player[key] = defaults[key]
	if not st.has("assistant"):
		st["assistant"] = null


func player() -> Dictionary:
	return _st().player


func career_def() -> Dictionary:
	return Data.CAREER_LEVELS[clampi(int(player().career), 0, Data.CAREER_LEVELS.size() - 1)]


func salary() -> float:
	return roundf(float(career_def().salary) * Util.infl(_st().year))


func living_cost() -> float:
	# Familie (Feature 44): ein gemeinsamer Haushalt lebt größer
	var family_mult := 1.12 if is_married() else 1.0
	return roundf(float(career_def().living) * Util.infl(_st().year) * family_mult)


# Earned reputation title, derived from the moral identity — you don't
# pick an archetype, the business decides what you are.
func title() -> String:
	var tops: Array = Game.identity_top_labels()
	if tops.is_empty() or Game.identity_total() < 3.0:
		return "No reputation yet"
	for key in Game.IDENTITY_KEYS:
		if str(Game.IDENTITY_LABELS[key]) == str(tops[0]):
			return str(Data.REPUTATION_TITLES.get(key, "No reputation yet"))
	return "No reputation yet"


func book(amount: float, text: String) -> void:
	var p := player()
	p.cash = float(p.cash) + amount
	p.ledger.append({"mi": Game.mi(), "amount": amount, "text": text})
	while p.ledger.size() > PLAYER_LEDGER_MAX:
		p.ledger.pop_front()


# Promotion requirements for the next level; empty array = top reached.
func promotion_requirements() -> Array:
	var st := _st()
	var idx := int(st.player.career)
	if idx >= Data.CAREER_LEVELS.size() - 1:
		return []
	var req: Dictionary = Data.CAREER_LEVELS[idx + 1].get("req", {})
	var p: Dictionary = st.player
	var out: Array = []
	if req.has("rep"):
		out.append({"label": "Agency reputation %d" % int(req.rep), "met": int(st.agency.rep) >= int(req.rep)})
	if req.has("films"):
		out.append({"label": "%d brokered films" % int(req.films), "met": st.released.size() >= int(req.films)})
	if req.has("clients"):
		out.append({"label": "%d clients" % int(req.clients), "met": st.clients.size() >= int(req.clients)})
	if req.has("indRep"):
		out.append({"label": "Industry standing %d" % int(req.indRep), "met": float(p.indRep) >= float(req.indRep)})
	if req.has("influence"):
		out.append({"label": "Influence %d" % int(req.influence), "met": float(p.influence) >= float(req.influence)})
	if req.has("wealth"):
		var need := roundf(float(req.wealth) * Util.infl(st.year))
		out.append({"label": "Private wealth %s" % Util.fmt_money(need), "met": float(p.cash) >= need})
	return out


func _promotion_due() -> bool:
	var reqs := promotion_requirements()
	if reqs.is_empty():
		return false
	return reqs.all(func(r): return bool(r.met))


func _check_promotion(events: Array) -> void:
	if not _promotion_due():
		return
	var p := player()
	p.career = int(p.career) + 1
	var lvl := career_def()
	p.indRep = clampf(float(p.indRep) + 5.0, 0.0, 100.0)
	p.pubRep = clampf(float(p.pubRep) + 4.0, 0.0, 100.0)
	p.influence = clampf(float(p.influence) + 8.0, 0.0, 100.0)
	Game.log_msg("Promotion: you are now considered a %s. Salary and expectations rise." % str(lvl.name), "history")
	Game.press_event("Business", "People move: %s is now talked about as a %s." % [_st().agency.name, str(lvl.name)])
	events.append({"title": "Promotion", "text": "The industry knows your name now: [b]%s[/b].\n\nYour salary rises to %s a month — and your lifestyle follows (%s living costs)." % [str(lvl.name), Util.fmt_money(salary()), Util.fmt_money(living_cost())], "choices": [{"label": "Continue"}]})
	# Endgame (Feature 9): partnership buy-in & mogul recognition
	Mogul.on_promotion(events)


# Weekly condition tick: workload drains energy and builds stress.
func tick_week() -> void:
	var st := _st()
	var p: Dictionary = st.player
	var workload: float = st.clients.size() * 1.0 + st.productions.size() * 0.5 + st.castings.size() * 0.25
	# Erholung belohnt rausgenommenen Druck: unter Stress 40 regeneriert der
	# Körper spürbar mit — unter Dauerlast bleibt die Abwärtsspirale bestehen
	# (Balance-Chunk 20: Energie soll pendeln, nicht strukturell erodieren).
	var rest_bonus := 2.5 if float(p.stress) < 40.0 else 0.0
	p.energy = clampf(float(p.energy) + 9.0 + rest_bonus - workload * 1.1, 0.0, 100.0)
	p.stress = clampf(float(p.stress) - 4.0 + workload * 0.8 + (4.0 if st.agency.cash < 0 else 0.0), 0.0, 100.0)
	# Ausgehende Briefe (Feature 23): die Wirkung kommt mit der Zustellung.
	for mail in st.get("outMail", []).duplicate():
		if Game.wi() < int(mail.dueWi):
			continue
		st.outMail.erase(mail)
		var ct := Network.contact_by_name(str(mail.ctName))
		if ct.is_empty():
			continue
		Network.apply_channel(ct, "letter", float(mail.gain))
		_memory(ct, "Your letter arrived — considered words, kept in a drawer.")
		Game.log_msg("Your letter reaches %s — a page like that outweighs ten phone calls." % str(ct.name), "info")
	_tick_location_week()
	_tick_assistant_week()


# Monthly close for the player: runs inside Game._month_close BEFORE the
# ledger month is finalized so the bookings land in the closing month.
func tick_month(events: Array) -> void:
	var st := _st()
	var p: Dictionary = st.player
	# Salary & royalty: the agency pays, the manager collects.
	var pay := salary()
	var provisions := float(Game.live_month(Game.mi()).byCat.get("provision", 0.0))
	var royalty := roundf(maxf(provisions, 0.0) * ROYALTY)
	Game.book(-(pay + royalty), "gehalt", "Manager salary & royalty (%s)" % str(career_def().name))
	book(pay, "Salary (%s)" % str(career_def().name))
	if royalty > 0.0:
		book(royalty, "Success royalty (%d%% of commissions)" % roundi(ROYALTY * 100.0))
	# Lifestyle: grows with the career level, always due.
	book(-living_cost(), "Living costs (%s lifestyle)" % str(career_def().name))
	# Private debt: negative balance accrues interest.
	if float(p.cash) < 0.0:
		var interest := roundf(float(p.cash) * 0.02)
		book(interest, "Interest on private debt")
		Game.log_msg("Privately in the red: %s of debt weighs on you." % Util.fmt_money(-float(p.cash)), "bad")
	# Health follows chronic stress.
	if float(p.stress) >= 70.0:
		p.health = clampf(float(p.health) - (float(p.stress) - 60.0) * 0.25, 5.0, 100.0)
	else:
		p.health = clampf(float(p.health) + 1.5, 5.0, 100.0)
	# Burnout: drained AND wired — bad calls pile up.
	if float(p.energy) < 20.0 and float(p.stress) > 75.0 and not p.monthFlags.has("burnout"):
		p.monthFlags["burnout"] = true
		st.instinct = clampi(int(st.instinct) - 2, 5, 100)
		Game.log_msg("Burned out: you make tired decisions (instinct −2).", "bad")
		events.append({"title": "Burned out", "text": "Too many nights at the office, too many crises. Your gut feeling dulls (instinct −2).\n\nTake a break — or delegate the less important clients.", "choices": [{"label": "Continue"}]})
	# Collapse: the clinic is expensive, public, and unavoidable.
	if float(p.health) <= 15.0 and not p.monthFlags.has("collapse"):
		p.monthFlags["collapse"] = true
		Network.memoir("A collapse puts you in a clinic — the columns write about it for weeks.")
		book(-roundf(800.0 * Util.infl(st.year)), "Clinic stay after collapse")
		p.health = 45.0
		p.energy = 60.0
		p.stress = clampf(float(p.stress) - 35.0, 0.0, 100.0)
		p.pubRep = clampf(float(p.pubRep) - 4.0, 0.0, 100.0)
		Game.log_msg("Collapse — a week in a clinic, and the columns write about it.", "bad")
		events.append({"title": "Collapse", "text": "Your body pulls the emergency brake: a clinic stay, discretion impossible.\n\nHealth stabilized, but the public took notice.", "choices": [{"label": "Continue"}]})
	# Reputation & influence drift toward their targets.
	p.indRep = clampf(float(p.indRep) + (float(st.agency.rep) - float(p.indRep)) * 0.15, 0.0, 100.0)
	p.pubRep = clampf(float(p.pubRep) + (float(p.indRep) * 0.9 - float(p.pubRep)) * 0.1, 0.0, 100.0)
	var infl_target := clampf(int(p.career) * 14.0 + st.favors.size() * 4.0 + (float(st.agency.rep) - 50.0) * 0.2, 0.0, 100.0)
	p.influence = clampf(float(p.influence) + (infl_target - float(p.influence)) * 0.2, 0.0, 100.0)
	p.discretion = clampf(float(p.discretion) + (50.0 - float(p.discretion)) * 0.05, 0.0, 100.0)
	_check_promotion(events)
	# Privatleben (Feature 44): Partnerschaft, Freundschaften, Familie
	_tick_private_life(events)
	_tick_contacts_month(events)
	_tick_location_month()
	_tick_assistant_month()
	p.monthFlags = {}


# Crises gnaw at the manager personally (hooked from Game.log_msg).
func on_bad_news() -> void:
	var st := _st()
	if st != null and st.has("player") and st.player is Dictionary:
		st.player.stress = clampf(float(st.player.get("stress", 20.0)) + 2.0, 0.0, 100.0)


# ---------- Personal actions (once per month each) ----------
func can_act(flag: String) -> bool:
	return _st() != null and not player().monthFlags.has(flag)


func vacation() -> void:
	if not can_act("vacation"):
		return
	var p := player()
	p.monthFlags["vacation"] = true
	book(-roundf(220.0 * Util.infl(_st().year)), "Weekend in Palm Springs")
	p.energy = clampf(float(p.energy) + 22.0, 0.0, 100.0)
	p.stress = clampf(float(p.stress) - 22.0, 0.0, 100.0)
	p.health = clampf(float(p.health) + 3.0, 0.0, 100.0)
	# Privatleben (Feature 44): freie Tage nähren Partnerschaft & Freundschaften
	var pl := private_life()
	pl.lastVacMi = Game.mi()
	if pl.partner != null:
		pl.partner.rel = clampf(float(pl.partner.rel) + 5.0, 0.0, 100.0)
		Game.log_msg("Time off in Palm Springs — together, for once. It shows.", "info")
		return
	Game.log_msg("Time off in Palm Springs — your head is clear again.", "info")


# =====================================================================
# Privatleben, abstrahiert (Feature 44): Partnerschaft, Freundschaften
# und Familie erzeugen Zeitansprüche, Rückhalt — und Konflikte.
# =====================================================================
func private_life() -> Dictionary:
	return player().privateLife


func is_married() -> bool:
	var pl_dict = player().get("privateLife")
	return pl_dict != null and int(pl_dict.get("marriedMi", -1)) >= 0


# Zentrale Schaltstelle für die Brief-Ops (data/letters, op "private_life").
func private_action(action: String, amount: float, sender: String) -> String:
	var pl := private_life()
	var p := player()
	match action:
		"courtship_accept":
			pl.partner = {"name": sender, "rel": 55.0, "sinceMi": Game.mi()}
			Network.memoir("You started seeing %s — something in your life that is not the business." % sender, [sender])
			return "You and %s will see each other again." % sender
		"courtship_decline":
			pl.courtMi = Game.mi()
			return ""
		"evening":
			if pl.partner != null:
				pl.partner.rel = clampf(float(pl.partner.rel) + 7.0, 0.0, 100.0)
				p.stress = clampf(float(p.stress) - 4.0, 0.0, 100.0)
				p.energy = clampf(float(p.energy) - 2.0, 0.0, 100.0)
			return ""
		"tension":
			if pl.partner != null:
				pl.partner.rel = clampf(float(pl.partner.rel) + 10.0, 0.0, 100.0)
				p.stress = clampf(float(p.stress) + 3.0, 0.0, 100.0)
			return ""
		"partner_rel":
			if pl.partner != null:
				pl.partner.rel = clampf(float(pl.partner.rel) + amount, 0.0, 100.0)
			return ""
		"proposal_accept":
			pl.marriedMi = Game.mi()
			p.pubRep = clampf(float(p.pubRep) + 2.0, 0.0, 100.0)
			if pl.partner != null:
				pl.partner.rel = clampf(float(pl.partner.rel) + 10.0, 0.0, 100.0)
				Network.memoir("You married %s. The columns approve; the living costs don't." % str(pl.partner.name), [str(pl.partner.name)])
			return "Married. The town reads about it over breakfast."
		"friend_add":
			pl.friends = mini(int(pl.friends) + 1, 3)
			pl.lastVacMi = maxi(int(pl.lastVacMi), Game.mi() - 4)
			return "A friendship outside the business — rarer than any favor."
	return ""


# Monatstakt des Privatlebens: Nähe braucht Zeit, Rückhalt zahlt zurück.
func _tick_private_life(events: Array) -> void:
	var st := _st()
	var pl := private_life()
	var p := player()
	# Alleinstehend: hin und wieder klopft das Leben an.
	if pl.partner == null:
		if Game.mi() - int(pl.courtMi) >= 6 and float(p.stress) < 70.0 and Util.chance(0.08):
			pl.courtMi = Game.mi()
			var first: String = Util.pick(Data.NPC_FIRST_F if Util.chance(0.5) else Data.NPC_FIRST_M)
			Dialogs.spawn_letter_named("courtship", "%s %s" % [first, Util.pick(Data.NPC_LAST)])
	else:
		var partner: Dictionary = pl.partner
		partner.rel = clampf(float(partner.rel) - 1.5, 0.0, 100.0)
		# Zeitanspruch: ein Abend gehört (fast) jeden Monat den beiden.
		if Util.chance(0.5) and not st.inbox.any(func(l): return str(l.tid) == "partner_evening" and str(l.status) == "open"):
			Dialogs.spawn_letter_named("partner_evening", str(partner.name))
		# Rückhalt: eine gute Partnerschaft trägt durch die Krisenwochen.
		if float(partner.rel) >= 50.0:
			p.stress = clampf(float(p.stress) - 2.0, 0.0, 100.0)
			p.health = clampf(float(p.health) + 0.5, 5.0, 100.0)
		elif float(partner.rel) < 35.0 and Util.chance(0.3):
			Dialogs.spawn_letter_named("partner_conflict", str(partner.name))
		# Die Frage aller Fragen — einmal.
		if not is_married() and not bool(pl.get("proposalAsked", false)) and float(partner.rel) >= 75.0 and Game.mi() - int(partner.sinceMi) >= 12:
			pl.proposalAsked = true
			Dialogs.spawn_letter_named("partner_proposal", str(partner.name))
		# Bruch: irgendwann ist es vorbei — öffentlich, wie alles hier.
		if float(partner.rel) < 20.0:
			var partner_name := str(partner.name)
			var was_married := is_married()
			pl.partner = null
			pl.proposalAsked = false
			pl.marriedMi = -1
			p.stress = clampf(float(p.stress) + 8.0, 0.0, 100.0)
			p.pubRep = clampf(float(p.pubRep) - 3.0, 0.0, 100.0)
			Network.memoir("The %s with %s ended — the columns wrote about it before your friends knew." % ["marriage" if was_married else "relationship", partner_name], [partner_name])
			events.append({"title": "An ending", "text": "It ends the way these things end in this town: quietly at home, loudly in the columns.\n\n%s is gone, the apartment is too big, and the phone keeps ringing with business." % partner_name, "choices": [{"label": "Back to work"}]})
			Game.log_msg("Separation from %s — the gossip pages feast for a week." % partner_name, "bad")
	# Freundschaften außerhalb der Branche: Rückhalt, aber sie wollen gelebt werden.
	if int(pl.friends) > 0:
		p.stress = clampf(float(p.stress) - float(pl.friends), 0.0, 100.0)
		if int(pl.lastVacMi) > 0 and Game.mi() - int(pl.lastVacMi) > 8:
			pl.friends = int(pl.friends) - 1
			pl.lastVacMi = Game.mi() - 4
			Game.log_msg("A friendship outside the business quietly starves — you never had the time.", "bad")


func checkup() -> void:
	if not can_act("checkup"):
		return
	var p := player()
	p.monthFlags["checkup"] = true
	book(-roundf(150.0 * Util.infl(_st().year)), "Doctor's checkup in Beverly Hills")
	p.health = clampf(float(p.health) + 10.0, 0.0, 100.0)
	Game.log_msg("Checkup at the doctor's — solid results, juicy bill.", "info")


# Private draw: one extra month's salary out of the agency account.
func draw() -> void:
	if not can_act("draw"):
		return
	var amount := salary()
	if float(_st().agency.cash) < amount:
		return
	player().monthFlags["draw"] = true
	Game.book(-amount, "gehalt", "Private draw by the manager")
	book(amount, "Private draw from the agency")
	Game.log_msg("Private draw: %s moves from the agency to your own account." % Util.fmt_money(amount), "info")


# Private injection: your own money bails out (or fattens) the agency.
func inject(amount: float) -> void:
	var p := player()
	if amount <= 0.0 or float(p.cash) < amount:
		return
	book(-amount, "Private injection into the agency")
	Game.book(amount, "sonstiges", "Private injection by the manager")
	Game.log_msg("You put %s of your own money into the agency." % Util.fmt_money(amount), "info")


# =====================================================================
# Contact book & promises: interaction over real channels
# =====================================================================
# Starting cast: one person per role from data/contacts (start_roster)
# plus a studio boss — the people everything in Hollywood runs through.
func init_contacts() -> void:
	var st := _st()
	st.contacts = []
	for ctype in Data.CONTACT_START_ROSTER:
		var cname := str(Util.pick(Data.CONTACT_PERSONS[ctype]))
		if st.contacts.any(func(ct): return str(ct.name) == cname):
			continue
		_add_contact(str(ctype), cname)
	var sid := str(Util.pick(Game.active_studios()).id)
	_add_contact("studio", "Studio boss of %s" % Game._studio(sid).name)


func _add_contact(ctype: String, cname: String) -> Dictionary:
	var ct := {"id": Game.next_id(), "type": ctype, "name": cname, "rel": float(Util.rndi(15, 35)),
		"lastMi": Game.mi(), "lastActWeek": -99, "log": [], "waitNoted": false}
	_st().contacts.append(ct)
	# Netzwerk (Features 11/12/14): Dimensionen, Kreise, ggf. Vorzimmer
	Network.seed_contact(ct)
	return ct


func contact_by_id(cid) -> Dictionary:
	for ct in _st().contacts:
		if int(ct.id) == int(cid):
			return ct
	return {}


func _memory(ct: Dictionary, text: String) -> void:
	ct.log.push_front({"mi": Game.mi(), "text": text})
	while ct.log.size() > CONTACT_LOG_MAX:
		ct.log.pop_back()


# Favor traffic rubs off on the contact book (existing contacts only).
func touch_contact_person(person: Dictionary, delta: float, memo: String = "") -> void:
	var st := _st()
	if st == null or not st.has("contacts"):
		return
	for ct in st.contacts:
		if str(ct.name) == str(person.get("name", "")):
			Network.touch(ct, delta)
			if memo != "":
				_memory(ct, memo)
			return


# Contact time per week — society lions (Feature 6) squeeze in one more.
func ap_per_week() -> int:
	return AP_PER_WEEK + (1 if Mogul.has_ability("society") else 0)


func channel_cost(key: String) -> float:
	return roundf(float(Data.CONTACT_CHANNELS[key].cost) * Util.infl(_st().year) * Mogul.channel_cost_mult(key))


# Why a channel is unavailable for this contact right now ("" = fine).
func contact_blocked_reason(ct: Dictionary, key: String) -> String:
	var ch: Dictionary = Data.CONTACT_CHANNELS[key]
	# Presence matters: meetings and club nights only happen in town.
	if is_away() and (key == "meet" or key == "club"):
		return "You are not in Los Angeles"
	if key == "aide" and not has_assistant():
		return "You employ no assistant"
	# Gatekeeper (Feature 14): to important people, the anteroom IS the door.
	if (key == "meet" or key == "club") and Network.gate_blocks(ct):
		return "%s guards the calendar — charm the anteroom first" % str(Network.gate_of(ct).get("name", "The anteroom"))
	if int(ct.lastActWeek) == Game.wi():
		return "Already contacted this week"
	if int(_st().contactAP) < Mogul.channel_ap(key):
		return "No contact time left"
	if float(player().cash) < channel_cost(key):
		return "Privately short on cash"
	return ""


# Ein Kanal-Gespräch beginnen, das als Dialog (Feature: Dialogsystem)
# weiterläuft: Kosten, Zeit, Energie & Versprechen laufen hier, die
# eigentliche Unterhaltung übernimmt die Dialog-Engine.
func begin_channel_dialog(cid, key: String) -> Dictionary:
	var st := _st()
	var ct := contact_by_id(cid)
	if ct.is_empty() or not Data.CONTACT_CHANNELS.has(key):
		return {"ok": false, "text": "Unknown contact."}
	var reason := contact_blocked_reason(ct, key)
	if reason != "":
		return {"ok": false, "text": reason}
	var ch: Dictionary = Data.CONTACT_CHANNELS[key]
	var cost := channel_cost(key)
	if cost > 0.0:
		book(-cost, "%s %s — %s" % [str(ch.icon), str(ch.name), str(ct.name)])
	st.contactAP = int(st.contactAP) - Mogul.channel_ap(key)
	st.player.energy = clampf(float(st.player.energy) - float(ch.energy), 0.0, 100.0)
	ct.lastActWeek = Game.wi()
	ct.lastMi = Game.mi()
	# Persönliche Betreuung (Feature 34): DU bist erschienen
	ct["lastPersonalMi"] = Game.mi()
	ct.waitNoted = false
	_fulfill_promises(ct)
	Mogul.grant_xp("networking", 1.0, "Kept a relationship alive")
	if key == "meet":
		Mogul.grant_xp("people", 1.0, "Face to face, you learn the most")
	# Kommunikationsbudget (Feature 29): große Szenen zählen
	Dialogs.note_scene()
	return {"ok": true}


# Reaching out over a channel: costs, relationship effect, risks,
# memory — and open promises to this person count as kept.
func contact_interact(cid, key: String) -> Dictionary:
	var st := _st()
	var ct := contact_by_id(cid)
	if ct.is_empty() or not Data.CONTACT_CHANNELS.has(key):
		return {"ok": false, "text": "Unknown contact."}
	var reason := contact_blocked_reason(ct, key)
	if reason != "":
		return {"ok": false, "text": reason}
	var ch: Dictionary = Data.CONTACT_CHANNELS[key]
	var cost := channel_cost(key)
	if cost > 0.0:
		book(-cost, "%s %s — %s" % [str(ch.icon), str(ch.name), str(ct.name)])
	st.contactAP = int(st.contactAP) - Mogul.channel_ap(key)
	st.player.energy = clampf(float(st.player.energy) - float(ch.energy), 0.0, 100.0)
	ct.lastActWeek = Game.wi()
	ct.lastMi = Game.mi()
	# Persönliche Betreuung (Feature 34): alles außer dem Assistenten zählt
	# als eigenes Erscheinen.
	if key != "aide":
		ct["lastPersonalMi"] = Game.mi()
	ct.waitNoted = false
	var gain := float(Util.rndi(int(ch.rel_min), int(ch.rel_max)))
	var lines: Array = []
	match key:
		"call":
			if Util.chance(0.15):
				gain = -2.0
				st.player.stress = clampf(float(st.player.stress) + 2.0, 0.0, 100.0)
				lines.append("With no time to think, a tactless remark slips out — the call goes sour.")
				_memory(ct, "Botched phone call — your tone landed badly.")
			else:
				lines.append("A short, good conversation — you stay in business.")
				_memory(ct, "Called personally.")
		"meet":
			lines.append("A long dinner, genuine attention — this is how trust is built.")
			_memory(ct, "You showed up in person — people don't forget that.")
			if Util.chance(0.25):
				lines.append(_make_promise(ct))
		"letter":
			# Feature 23: der Brief wirkt erst, wenn er ankommt — dafür mehr.
			_st().outMail.append({"ctName": str(ct.name), "gain": gain,
				"dueWi": Game.wi() + int(ch.get("delay_weeks", 1))})
			gain = 0.0
			lines.append("You take your time with the wording — this page should be kept, not skimmed. It will arrive within the week.")
			_memory(ct, "A letter of yours is on its way.")
		"note":
			lines.append("A precise message, cleanly worded.")
			_memory(ct, "Reached out in writing.")
			# Back channels (Feature 6): discreet couriers leak half as often
			if Util.chance(0.05 if Mogul.has_ability("back_channels") else 0.1):
				st.player.discretion = clampf(float(st.player.discretion) - 5.0, 0.0, 100.0)
				Scandal.add_rumor("agency", "A private note from %s to %s is circulating in copies." % [st.agency.name, ct.name], true, "skandal", ["Journalists"], 20.0, true)
				lines.append("The message got passed around — copies are circulating (discretion −5).")
		"gift":
			# The true wish (Feature 6): you always know what lands
			if float(ct.rel) < 25.0 and not Mogul.has_ability("true_wish") and Util.chance(0.5):
				gain = -4.0
				lines.append("The gift reads as a clumsy attempt to buy goodwill — frowns instead of thanks.")
				_memory(ct, "Inappropriate gift at the wrong moment.")
			else:
				lines.append("A thoughtful gesture that sticks in the memory.")
				_memory(ct, "Received a tasteful gift.")
		"aide":
			if Util.chance(0.25):
				gain = 0.0
				lines.append("They let your assistant feel that they expected the boss.")
			else:
				lines.append("Your assistant handles it solidly — but nothing more.")
			_memory(ct, "Only the assistant came by.")
		"club":
			lines.append("In the club's back room people talk more openly than in any office.")
			_memory(ct, "An evening at the private club — confidential and long.")
			if Util.chance(0.25):
				var kinds := ["extraAudition", "suppressStory", "scriptAccess", "billing", "galaInvite"]
				var fav := Game.grant_favor(str(Util.pick(kinds)), {"type": str(ct.type), "name": str(ct.name)})
				lines.append("Over the second glass, %s makes you a promise: %s." % [str(ct.name), str(Game.FAVOR_KINDS[str(fav.kind)].name)])
			if Util.chance(0.2):
				for rumor in st.rumors:
					if not bool(rumor.knownToPlayer):
						rumor.knownToPlayer = true
						lines.append("A name drops in passing — a rumor reaches you that you'd never have heard otherwise.")
						break
			if Util.chance(0.3):
				# Club-Zusagen haben Ohren am Nebentisch (Feature 30)
				lines.append(_make_promise(ct, "", 1))
			# Market whispers (Feature 7): the club is where tips are born
			if Util.chance(0.2):
				var tip_line: String = Mogul.maybe_market_tip(ct)
				if tip_line != "":
					lines.append(tip_line)
			# Chance encounters (Feature 21): the bar introduces people
			if Util.chance(0.12):
				var enc: String = Network.club_encounter()
				if enc != "":
					lines.append(enc)
			if Util.chance(0.15):
				st.player.discretion = clampf(float(st.player.discretion) - 3.0, 0.0, 100.0)
				lines.append("Someone with good ears sat at the next table (discretion −3).")
	# Mehrdimensional (Feature 12): jeder Kanal bewegt andere Saiten
	Network.apply_channel(ct, key, gain)
	Mogul.grant_xp("networking", 1.0, "Kept a relationship alive")
	if key == "meet":
		Mogul.grant_xp("people", 1.0, "Face to face, you learn the most")
	_fulfill_promises(ct)
	var head := "%s %s — %s: relationship %s%d, now %d/100." % [str(ch.icon), str(ch.name), str(ct.name),
		"+" if gain >= 0.0 else "", roundi(gain), roundi(float(ct.rel))]
	return {"ok": true, "text": head + "\n\n" + "\n".join(lines)}


# ---------- Promise register (Feature 30) ----------
# Jede Zusage hat Inhalt (kind), Frist, Beteiligte, Zeugen und eine
# Schriftform — und daraus abgeleitete Folgen bei Erfüllung und Bruch.
func _make_promise(ct: Dictionary, kind: String = "", witnesses: int = 0, written: bool = false) -> String:
	var kinds := Data.CONTACT_PROMISE_KINDS
	if kind == "" or not kinds.has(kind):
		kind = str(Util.pick(kinds.keys())) if kinds.size() else "callback"
	var def: Dictionary = kinds.get(kind, {"name": "Stay in touch", "icon": "🤞", "months_min": 2, "months_max": 4,
		"text": "You promised {contact} to be in touch again soon."})
	var due := Game.mi() + Util.rndi(int(def.get("months_min", 2)), int(def.get("months_max", 4)))
	_st().promises.append({"id": Game.next_id(), "to": str(ct.name), "kind": kind,
		"madeMi": Game.mi(), "dueMi": due, "witnesses": witnesses, "written": written,
		"text": str(def.text).replace("{contact}", str(ct.name)), "status": "open"})
	while _st().promises.size() > PROMISES_MAX:
		_st().promises.pop_front()
	_memory(ct, "Remembers your promise: %s." % str(def.name).to_lower())
	var suffix := ""
	if witnesses > 0:
		suffix = " %d other(s) heard it." % witnesses
	elif written:
		suffix = " It is in writing."
	return "On parting you make a promise: %s. %s will remember it.%s" % [str(def.name).to_lower(), str(ct.name), suffix]


# Any contact keeps open promises to that person. Witnesses multiply
# the payoff — word kept in front of people is worth more (Feature 30).
func _fulfill_promises(ct: Dictionary) -> void:
	for pr in _st().promises:
		if str(pr.status) == "open" and str(pr.to) == str(ct.name):
			pr.status = "kept"
			var w := int(pr.get("witnesses", 0))
			Network.adjust(ct, {"trust": 5.0 + 1.5 * w, "liking": 2.0}, false)
			Network.add_fact(ct, "kept a promise to them", 1, 1.0 + 0.5 * w)
			if w > 0:
				player().indRep = clampf(float(player().indRep) + 0.5 * w, 0.0, 100.0)
			_memory(ct, "You kept your word.")
			Game.log_msg("Promise kept: %s appreciates it%s." % [str(ct.name), " — and the witnesses noticed too" if w > 0 else ""], "deal")


# Monthly tick: broken promises, relationship decay, relationship perks.
func _tick_contacts_month(events: Array) -> void:
	var st := _st()
	for pr in st.promises:
		if str(pr.status) == "open" and Game.mi() > int(pr.dueMi):
			pr.status = "broken"
			st.player.stress = clampf(float(st.player.stress) + 3.0, 0.0, 100.0)
			var w := int(pr.get("witnesses", 0))
			for ct in st.contacts:
				if str(ct.name) == str(pr.to):
					# Gebrochenes Wort: Vertrauen bricht, Ärger bleibt — vor
					# Zeugen gebrochen bricht es lauter (Feature 30)
					Network.adjust(ct, {"trust": -10.0 - 2.0 * w, "liking": -4.0, "irritation": 8.0})
					Network.add_fact(ct, "broke a promise to them", -1, 2.0 + 1.0 * w)
					_memory(ct, "You broke your promise.")
			# Schriftliche Zusagen hinterlassen Beweise, bezeugte Gerede.
			if bool(pr.get("written", false)) and Util.chance(0.5):
				st.player.pubRep = clampf(float(st.player.pubRep) - 2.0, 0.0, 100.0)
				Scandal.add_rumor("agency", "%s is said to break written promises — and someone kept the letter." % str(st.agency.name), true, "skandal", ["Journalists"], 25.0, true)
			Network.memoir("Promise broken: %s waited in vain%s." % [str(pr.to), " — in front of witnesses" if w > 0 else ""], [str(pr.to)])
			Game.log_msg("Promise broken: %s waited in vain." % str(pr.to), "bad")
	# Neglected contacts cool off — and note it exactly once.
	for ct in st.contacts:
		var idle := Game.mi() - int(ct.lastMi)
		if idle >= 4:
			Network.adjust(ct, {"closeness": -3.0, "liking": -1.0}, false)
			if not bool(ct.get("waitNoted", false)):
				ct.waitNoted = true
				_memory(ct, "Has been waiting for months to hear from you.")
	# Good relationships pay off (at most one gesture per month).
	var warm: Array = st.contacts.filter(func(ct): return float(ct.rel) >= 65.0)
	warm.shuffle()
	for ct in warm:
		if not Util.chance(0.15):
			continue
		match str(ct.type):
			"produzent":
				Game.grant_favor(Util.pick(["extraAudition", "billing"]), {"type": "produzent", "name": str(ct.name)})
			"regisseur":
				Game.grant_favor("scriptAccess", {"type": "regisseur", "name": str(ct.name)})
			"kolumnist", "journalist":
				Game.grant_favor("suppressStory", {"type": str(ct.type), "name": str(ct.name)})
			"studio":
				for s in Data.STUDIOS:
					if str(ct.name).contains(str(s.name)):
						st.studioRel[s.id] = clampi(int(st.studioRel.get(s.id, 40)) + 3, 0, 100)
						Game.log_msg("%s opens doors for you at %s (relations +3)." % [str(ct.name), str(s.name)], "deal")
		events.append({"title": "A call that pays off", "text": "Relationship work pays: [b]%s[/b] thinks of you without being asked." % str(ct.name), "choices": [{"label": "Continue"}]})
		break


# Migration: retrofit the contact book on old saves; map legacy
# German promise statuses onto the English ones.
func ensure_contacts() -> void:
	var st := _st()
	if st == null:
		return
	if not st.has("contacts") or not (st.contacts is Array) or st.contacts.is_empty():
		init_contacts()
	for ct in st.contacts:
		if not ct.has("lastActWeek"):
			ct["lastActWeek"] = -99
		if not ct.has("waitNoted"):
			ct["waitNoted"] = false
		if not ct.has("log"):
			ct["log"] = []
	if not st.has("contactAP"):
		st["contactAP"] = AP_PER_WEEK
	if not st.has("promises"):
		st["promises"] = []
	var status_map := {"offen": "open", "gehalten": "kept", "gebrochen": "broken"}
	for pr in st.promises:
		if status_map.has(str(pr.status)):
			pr.status = status_map[str(pr.status)]
		# Migration Feature 30: Altbestand wird zur mündlichen Rückruf-Zusage
		if not pr.has("kind"):
			pr["kind"] = "callback"
		if not pr.has("witnesses"):
			pr["witnesses"] = 0
		if not pr.has("written"):
			pr["written"] = false


# =====================================================================
# Locations & presence: the node map
# =====================================================================
func location_id() -> String:
	return str(player().get("location", "la"))


func location_def(id_s: String = "") -> Dictionary:
	return Data.LOCATION_BY_ID.get(id_s if id_s != "" else location_id(), Data.LOCATION_BY_ID.get("la", {}))


func is_away() -> bool:
	return location_id() != "la"


func travel_cost(id_s: String) -> float:
	# Jet share & Manhattan apartment (Feature 5) discount or waive the trip
	return roundf(float(Data.LOCATION_BY_ID[id_s].cost) * Util.infl(_st().year) * Mogul.travel_cost_mult(id_s))


# Why a trip is impossible right now ("" = possible).
func travel_blocked_reason(id_s: String) -> String:
	if not Data.LOCATION_BY_ID.has(id_s):
		return "Unknown destination"
	if id_s == location_id():
		return "You are already here"
	var loc: Dictionary = Data.LOCATION_BY_ID[id_s]
	if loc.has("months") and not loc.months.has(int(_st().month)):
		return "Festival season only (%s)" % Game.MONTHS[int(loc.months[0]) - 1]
	if not Game.can_spend(travel_cost(id_s)):
		return "Not even on credit — the agency account is too deep in the red"
	return ""


# Travel is abstracted: the trip eats the week's contact time and some
# energy — in exchange you are there immediately (returning works alike).
func travel_to(id_s: String) -> bool:
	if travel_blocked_reason(id_s) != "":
		return false
	var st := _st()
	var loc: Dictionary = Data.LOCATION_BY_ID[id_s]
	var cost := travel_cost(id_s)
	if cost > 0.0:
		Game.book(-cost, "reisen", "Trip to %s" % str(loc.name))
	# Reiseorganisation (Feature 32): der Assistent bucht, packt, plant —
	# die Anreise kostet weniger Substanz und frisst nicht die ganze Woche.
	var organized := rule("travel")
	st.player.energy = clampf(float(st.player.energy) - float(loc.energy) * Mogul.travel_energy_mult() * (0.7 if organized else 1.0), 0.0, 100.0)
	st.contactAP = 1 if organized else 0
	st.player.location = id_s
	st.player.awayNoted = false
	if organized:
		Game.log_msg("%s handled tickets, hotel and telegrams — you arrive with the week half intact." % str(assistant().name), "info")
	Mogul.grant_xp("networking", 1.0, "Showed your face out of town")
	Game.log_msg("You travel to %s — the week belongs to the journey." % str(loc.name), "info")
	return true


func location_action_available() -> bool:
	return location_def().get("action") != null and int(player().get("locActWeek", -99)) != Game.wi()


# Declarative effect block from data/locations: stats, bookings,
# identity, plus optional lucky/risk branches. Fully moddable.
func _apply_effects(effects: Dictionary) -> void:
	var st := _st()
	var p: Dictionary = st.player
	for key in effects:
		var v: float = float(effects[key])
		match str(key):
			"pubRep": p.pubRep = clampf(float(p.pubRep) + v, 0.0, 100.0)
			"indRep": p.indRep = clampf(float(p.indRep) + v, 0.0, 100.0)
			"influence": p.influence = clampf(float(p.influence) + v, 0.0, 100.0)
			"discretion": p.discretion = clampf(float(p.discretion) + v, 0.0, 100.0)
			"stress": p.stress = clampf(float(p.stress) + v, 0.0, 100.0)
			"energy": p.energy = clampf(float(p.energy) + v, 0.0, 100.0)
			"health": p.health = clampf(float(p.health) + v, 5.0, 100.0)
			"cash": book(v * Util.infl(st.year), "Location action")
			"instinct": st.instinct = clampi(int(st.instinct) + int(v), 5, 100)
			"book": Game.book(roundf(v * Util.infl(st.year)), "reisen", "Expenses on location")
			"identity": Game.record_identity(str(effects[key]), 0.5)


func do_location_action() -> String:
	if not location_action_available():
		return ""
	var st := _st()
	var loc := location_def()
	var act: Dictionary = loc.action
	st.player.locActWeek = Game.wi()
	_apply_effects(act.get("effects", {}))
	# Lucky branch: e.g. festival favors on the Croisette.
	var lucky: Dictionary = act.get("lucky", {})
	if not lucky.is_empty() and Util.chance(float(lucky.get("chance", 0.0))):
		if lucky.has("favor"):
			Game.grant_favor(str(Util.pick(lucky.favor)), Game.favor_contact_for("extraAudition"))
		_apply_effects(lucky.get("effects", {}))
		return str(lucky.get("text", ""))
	# Risk branch: e.g. being spotted in Vegas.
	var risk: Dictionary = act.get("risk", {})
	if not risk.is_empty() and Util.chance(float(risk.get("chance", 0.0))):
		_apply_effects(risk.get("effects", {}))
		if risk.has("rumor"):
			Scandal.add_rumor("agency", str(risk.rumor).replace("{agency}", str(st.agency.name)), true, "skandal", ["Party guests"], 15.0, true)
		return str(risk.get("text", ""))
	if int(act.get("casting", 0)) > 0:
		Game.spawn_castings(int(act.casting))
		Game.log_msg("Talks on location put a project on your desk.", "deal")
	return str(act.get("text", ""))


# Weekly location effects (data-driven) + the price of absence.
func _tick_location_week() -> void:
	var st := _st()
	_apply_effects(location_def().get("weekly", {}))
	# Absence has a price: the clients back in L.A. feel left alone.
	if is_away():
		for c in st.clients:
			c.trust = clampf(float(c.trust) - 0.5, 0.0, float(c.get("trustCap", 100.0)))
			c.mood = clampf(float(c.mood) - 1.0, 0.0, 100.0)
		if not bool(st.player.get("awayNoted", false)) and not st.clients.is_empty():
			st.player.awayNoted = true
			Game.log_msg("Your clients notice that you are out of town.", "bad")


# Season windows: after the festival you head back to L.A. automatically.
func _tick_location_month() -> void:
	var loc := location_def()
	if loc.has("months") and not loc.months.has(int(_st().month)):
		_st().player.location = "la"
		Game.log_msg("The festival is over — back to Los Angeles.", "info")


# =====================================================================
# Assistant & delegation (Feature: from doing to managing)
# =====================================================================
func has_assistant() -> bool:
	return _st() != null and _st().get("assistant") != null


func assistant() -> Dictionary:
	return _st().assistant if has_assistant() else {}


func assistant_wage() -> float:
	if not has_assistant():
		return 0.0
	return roundf((ASSISTANT_BASE_WAGE + float(assistant().skill) * 1.5) * Util.infl(_st().year))


# Hiring: one candidate from the name pool; skill decides wage & effect.
func hire_assistant() -> Dictionary:
	if has_assistant():
		return assistant()
	var first: String = Util.pick(Data.NPC_FIRST_F if Util.chance(0.6) else Data.NPC_FIRST_M)
	var cand := {"name": "%s %s" % [first, Util.pick(Data.NPC_LAST)], "skill": Util.rndi(35, 65),
		"hiredMi": Game.mi(), "rules": {"upkeep": true, "briefing": true, "occasions": false, "mailfilter": false, "travel": true}}
	_st().assistant = cand
	Game.log_msg("%s starts as your assistant — the front desk is finally covered." % str(cand.name), "deal")
	return cand


func fire_assistant() -> void:
	if not has_assistant():
		return
	var a := assistant()
	Game.log_msg("%s leaves the agency. The phone rings unanswered again." % str(a.name), "info")
	_st().assistant = null
	# NPC-Karrieren (Feature 22): die Stadt recycelt jeden — Ex-Angestellte
	# tauchen als Produzenten oder Journalisten wieder auf.
	Network.assistant_departs(a)


func set_rule(rule: String, value: bool) -> void:
	if has_assistant():
		assistant().rules[rule] = value


func rule(rule_s: String) -> bool:
	return has_assistant() and bool(assistant().rules.get(rule_s, false))


# Weekly: delegation relieves the manager; with the upkeep rule on, the
# assistant keeps one neglected contact warm (agency pays the expenses).
func _tick_assistant_week() -> void:
	if not has_assistant():
		return
	var st := _st()
	var a := assistant()
	st.player.stress = clampf(float(st.player.stress) - float(a.skill) * 0.02, 0.0, 100.0)
	if rule("upkeep"):
		# Born delegators (Feature 6) get two courtesy calls out of the week.
		var quota := 2 if Mogul.has_ability("delegator") else 1
		for ct in st.contacts:
			if quota <= 0:
				break
			if Game.mi() - int(ct.lastMi) >= 2 and int(ct.lastActWeek) != Game.wi():
				Game.book(-roundf(5.0 * Util.infl(st.year)), "buero", "Assistant: courtesies & couriers")
				Network.adjust(ct, {"liking": 1.0 + float(a.skill) / 50.0}, false)
				ct.lastMi = Game.mi()
				ct.waitNoted = false
				_memory(ct, "%s checked in on your behalf." % str(a.name))
				quota -= 1


# Monthly: wages from the agency; the assistant learns on the job.
func _tick_assistant_month() -> void:
	if not has_assistant():
		return
	var a := assistant()
	Game.book(-assistant_wage(), "buero", "Assistant wages (%s)" % str(a.name))
	# Mentors (Feature 6) teach twice as fast — and leading people teaches you.
	a.skill = clampi(int(a.skill) + (2 if Mogul.has_ability("mentor") else 1), 10, 90)
	Mogul.grant_xp("leadership", 1.0, "A month of leading people")


# The morning note: a short decision brief instead of raw chaos.
func assistant_briefing() -> Dictionary:
	if not has_assistant() or not rule("briefing"):
		return {}
	var st := _st()
	var items: Array = []
	for pr in st.promises:
		if str(pr.status) == "open" and int(pr.dueMi) <= Game.mi() + 1:
			items.append("⏳ Promise to %s is coming due — I'd call this week." % str(pr.to))
	for ct in st.contacts:
		if Game.mi() - int(ct.lastMi) >= 3:
			items.append("📇 %s hasn't heard from you in months — a note would help." % str(ct.name))
	for c in st.clients:
		if float(c.mood) < 40.0 or float(c.trust) < 30.0:
			items.append("👥 %s seems unhappy — personal attention recommended." % Game.client_name(c))
	for cs in st.castings:
		if int(cs.deadline) <= 2 and not bool(cs.get("hidden", false)):
			items.append("🎬 “%s” casts in %d week(s) — open roles are waiting." % [str(cs.title), int(cs.deadline)])
	# Unruhige Mitarbeiter (Feature 33/35): Warnzeichen vor der Kündigung
	items.append_array(Staff.briefing_items())
	# Anlässe & liegengebliebene Post (Feature 32): der Assistent erinnert
	for occ in Network.open_occasions():
		items.append("💐 %s (%s) — a gesture before %s would land well." % [str(Network.OCCASION_KINDS[str(occ.kind)].name), str(occ.ctName), Game.mi_str(occ.dueMi)])
	for letter in Dialogs.open_letters():
		if Game.wi() >= int(letter.expireWi) - 1:
			items.append("%s The %s from %s expires — answer it or lose it." % [Dialogs.mail_icon(), Dialogs.mail_word().to_lower(), letter["from"].get("name", "?")])
	# Empire desk (Features 5–9): due deals, maturing tips, opening stakes
	items.append_array(Mogul.briefing_items())
	if items.is_empty():
		return {}
	var text := "%s puts a note on your desk:\n\n%s" % [str(assistant().name), "\n".join(items.slice(0, 4))]
	return {"title": "Assistant's morning note", "text": text, "choices": [{"label": "Noted"}]}
