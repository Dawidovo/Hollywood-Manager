extends Node
# =====================================================================
# Hollywood Manager (Godot) — Ereignis-Katalog
# Jedes Ereignis: id, cd (Cooldown), weight() -> 0 = Bedingungen nicht
# erfüllt, build() -> Modal-Dict {title, text, choices:[{label, fn}]}.
# Entscheidungen wirken auch auf die Karriere-DNA der Betroffenen.
# =====================================================================

func all_events() -> Array:
	return [
		{"id":"call3am",      "cd":10, "weight": _w_call3am,      "build": _b_call3am},
		{"id":"leak",         "cd":9,  "weight": _w_leak,         "build": _b_leak},
		{"id":"rename",       "cd":14, "weight": _w_rename,       "build": _b_rename},
		{"id":"director",     "cd":10, "weight": _w_director,     "build": _b_director},
		{"id":"poach",        "cd":10, "weight": _w_poach,        "build": _b_poach},
		{"id":"tworoles",     "cd":12, "weight": _w_tworoles,     "build": _b_tworoles},
		{"id":"cutrole",      "cd":12, "weight": _w_cutrole,      "build": _b_cutrole},
		{"id":"stunt",        "cd":10, "weight": _w_stunt,        "build": _b_stunt},
		{"id":"franchise",    "cd":18, "weight": _w_franchise,    "build": _b_franchise},
		{"id":"passion",      "cd":14, "weight": _w_passion,      "build": _b_passion},
		{"id":"packageEvent", "cd":12, "weight": _w_package,      "build": _b_package},
		{"id":"romance",      "cd":14, "weight": _w_romance,      "build": _b_romance},
		{"id":"photos",       "cd":16, "weight": _w_photos,       "build": _b_photos},
		{"id":"oscarCampaign","cd":10, "weight": _w_oscar,        "build": _b_oscar},
		{"id":"breakdown",    "cd":8,  "weight": _w_breakdown,    "build": _b_breakdown},
		{"id":"strike",       "cd":40, "weight": _w_strike,       "build": _b_strike},
		{"id":"talkieTest",   "cd":6,  "weight": _w_talkie,       "build": _b_talkie},
		{"id":"censor",       "cd":12, "weight": _w_censor,       "build": _b_censor},
		{"id":"blacklist",    "cd":20, "weight": _w_blacklist,    "build": _b_blacklist},
		{"id":"television",   "cd":14, "weight": _w_tv,           "build": _b_tv},
		# "favor" und "press" sind als JSON-Events nach data/events/core.json migriert
		{"id":"powerFigure",  "cd":24, "weight": _w_power_figure, "build": _b_power_figure},
		{"id":"favorCalled",  "cd":10, "weight": _w_favor_called, "build": _b_favor_called},
		{"id":"gala",         "cd":8,  "weight": _w_gala,         "build": _b_gala},
		# Klausel-Folgeereignisse (Feature 8): feuern NUR bei vorhandener Klausel
		{"id":"sequelCrisis", "cd":6,  "weight": _w_sequel_crisis, "build": _b_sequel_crisis},
		{"id":"escalatorBalk","cd":14, "weight": _w_escalator_balk,"build": _b_escalator_balk},
		{"id":"creativeVeto", "cd":12, "weight": _w_creative_veto, "build": _b_creative_veto},
		{"id":"moralExit",    "cd":10, "weight": _w_moral_exit,    "build": _b_moral_exit},
		{"id":"likeness",     "cd":16, "weight": _w_likeness,      "build": _b_likeness},
		{"id":"endorsement",  "cd":14, "weight": _w_endorsement,   "build": _b_endorsement},
	]

# ---------- Helfer ----------
func _free_clients() -> Array:
	return Game.state.clients.filter(func(c): return Game.is_free(c))

func _in_production() -> Variant:
	var hits: Array = []
	for prod in Game.state.productions:
		for r in prod.roles:
			if r.filled != null and r.filled.get("clientId") != null:
				var c = Game.client(r.filled.clientId)
				if c != null:
					hits.append({"c": c, "prod": prod, "role": r})
	return Util.pick(hits) if hits.size() else null

func _nm(c) -> String:
	return Game.client_name(c)

func _fmt(v) -> String:
	return Util.fmt_money(v)

func _rel(sid: String, delta: int) -> void:
	Game.state.studioRel[sid] = clampi(int(Game.state.studioRel[sid]) + delta, 0, 100)

func _dna(c, key: String, delta: float) -> void:
	c.dna[key] = clampf(c.dna[key] + delta, -100.0, 100.0)

# ---------- 0. Der Anruf um drei Uhr morgens ----------
func _w_call3am() -> float:
	return 1.2 if _free_clients().any(func(c): return c.fame >= 30) else 0.0

func _b_call3am() -> Dictionary:
	var c = Util.pick(_free_clients().filter(func(x): return x.fame >= 30))
	var studio = Util.pick(Game.active_studios())
	var fee = roundi(Util.ask_fee(c.fame, Game.state.year) * 1.1)
	return {"title": "The three a.m. phone call",
		"text": "[i]“Our lead is in the hospital. Shooting starts the day after tomorrow. Can %s step in? Yes or no — now.”[/i]\n\n%s offers a lead role. Fee: ca. %s. But: no preparation, shooting starts immediately." % [_nm(c), studio.name, _fmt(fee)],
		"choices": [
			{"label": "Say yes immediately", "fn": func():
				var r = Game.quick_production(c, {"studio": studio, "feeMult": 1.1})
				c.exhaustion = clampf(c.exhaustion + 30.0, 0.0, 100.0)
				c.heat = clampf(c.heat + 4.0, -10.0, 10.0)
				_dna(c, "verlass", 6.0)
				if Util.chance(0.7):
					c.fame = clampf(c.fame + 3.0, 5.0, 100.0)
					return "%s is in front of the camera 36 hours later. The industry talks about this save. (+%s commission, exhaustion rises sharply)" % [_nm(c), _fmt(r.income)]
				c.mood = clampf(c.mood - 6.0, 0.0, 100.0)
				return "%s steps in but looks visibly unprepared. The money is right (%s commission), the shine less so." % [_nm(c), _fmt(r.income)]},
			{"label": "Demand a higher fee", "fn": func():
				if Util.chance(0.55):
					var r = Game.quick_production(c, {"studio": studio, "feeMult": 1.6})
					c.exhaustion = clampf(c.exhaustion + 30.0, 0.0, 100.0)
					c.heat = clampf(c.heat + 5.0, -10.0, 10.0)
					c.fame = clampf(c.fame + 3.0, 5.0, 100.0)
					return "“Fine, damn it. But the car is at the door in one hour.” — %s fee, %s commission. A coup." % [_fmt(r.fee), _fmt(r.income)]
				_rel(studio.id, -2)
				return "Silence on the other end. Then: “We have somebody else.” The chance is gone."},
			{"label": "Decline", "fn": func():
				_rel(studio.id, -4)
				c.mood = clampf(c.mood + 4.0, 0.0, 100.0)
				return "%s keeps sleeping. %s won't forget this — but your client knows you don't burn them out." % [_nm(c), studio.name]},
		]}

# ---------- 1. Das geleakte Vorsprechen ----------
func _w_leak() -> float:
	return 1.0 if Game.state.clients.size() else 0.0

func _b_leak() -> Dictionary:
	var c = Game.random_client()
	var cost = roundi(12000.0 * Util.infl(Game.state.year))
	var has_pr: bool = c.perks.has("pr")
	var choices: Array = [
		{"label": "Go legal (%s)" % _fmt(cost), "fn": func():
			Game.book(-float(cost), "pr_recht", "Lawyers: confiscate the leaked tape (%s)" % _nm(c))
			c.mood = clampf(c.mood + 5.0, 0.0, 100.0)
			return "The lawyers collect every copy. Expensive, but the image is protected."},
		{"label": "Publish it with self-irony", "fn": func():
			if Util.chance(0.75 if has_pr else 0.55):
				c.heat = clampf(c.heat + 4.0, -10.0, 10.0)
				c.fame = clampf(c.fame + 2.0, 5.0, 100.0)
				_dna(c, "familie", 4.0)
				return "The gag lands: %s is suddenly seen as approachable and funny. The town loves it." % _nm(c)
			c.fame = clampf(c.fame - (1.0 if has_pr else 3.0), 5.0, 100.0)
			return "The humor doesn't land everywhere. A few mockers remain — not a disaster, but not pretty."},
		{"label": "Ignore it", "fn": func():
			if Util.chance(0.85 if has_pr else 0.65):
				return "Two weeks later nobody talks about it anymore. Well played."
			c.heat = clampf(c.heat - 2.0, -10.0, 10.0)
			return "The tape sticks around longer than expected. %s loses some momentum." % _nm(c)},
	]
	if Game.has_favor("suppressStory"):
		choices.insert(0, {"label": "Call in a favor: make the tape disappear", "fn": func():
			Game.consume_favor("suppressStory")
			c.mood = clampf(c.mood + 4.0, 0.0, 100.0)
			return "One call to an old friend from the gossip column — and every copy of the tape vanishes. The town is already laughing about something else."})
	return {"title": "The leaked audition",
		"text": "[i]“Have you seen the tape? All of Hollywood is laughing.”[/i]\n\nAn embarrassing recording of %s's audition is circulating in the industry.%s" % [_nm(c), " Your PR handling is already softening the damage." if has_pr else ""],
		"choices": choices}

# ---------- 2. Ein neuer Name für einen neuen Star ----------
func _w_rename() -> float:
	var cand = Game.state.clients.filter(func(c): return c.fame < 50)
	return (1.2 if Game.state.year < 1970 else 0.5) if cand.size() else 0.0

func _b_rename() -> Dictionary:
	var c = Game.random_client(func(x): return x.fame < 50)
	var cost = roundi(8000.0 * Util.infl(Game.state.year))
	return {"title": "A new name for a new star",
		"text": "[i]“%s? No human being can pronounce that. We were thinking of something … more sellable.”[/i]\n\nThe studio considers your client's name hard to market." % _nm(c),
		"choices": [
			{"label": "Accept the renaming", "fn": func():
				c.fame = clampf(c.fame + 4.0, 5.0, 100.0)
				c.mood = clampf(c.mood - 10.0, 0.0, 100.0)
				_dna(c, "unikat", -6.0)
				return "The new name soon shines on posters. The marketing works — but %s feels like merchandise." % _nm(c)},
			{"label": "Defend the name", "fn": func():
				c.loyalty = clampf(c.loyalty + 10.0, 0.0, 100.0)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 2, 0, 100)
				_dna(c, "unikat", 5.0)
				_rel(Util.pick(Game.active_studios()).id, -4)
				return "“The name stays.” %s will never forget this — the studio will, sooner." % _nm(c)},
			{"label": "Compromise: a stage name (%s PR)" % _fmt(cost), "fn": func():
				Game.book(-float(cost), "pr_recht", "PR campaign: stage name for %s" % _nm(c))
				c.fame = clampf(c.fame + 2.0, 5.0, 100.0)
				c.mood = clampf(c.mood - 3.0, 0.0, 100.0)
				return "A stage name for the posters, the real name for friends. Everyone can live with it."},
		]}

# ---------- 3. Der Regisseur will deinen Klienten loswerden ----------
func _w_director() -> float:
	return 1.0 if _in_production() != null else 0.0

func _b_director() -> Dictionary:
	var hit = _in_production()
	var c = hit.c
	var prod = hit.prod
	var fee = hit.role.filled.get("fee", 100000)
	var choices: Array = [
		{"label": "Defend the client publicly", "fn": func():
			c.loyalty = clampf(c.loyalty + 12.0, 0.0, 100.0)
			_rel(prod.studioId, -6)
			prod.qualityMod = prod.get("qualityMod", 0.0) - 3.0
			_dna(c, "verlass", -4.0)
			return "You face the press and stand behind your client. %s stays — the mood on set stays frosty." % _nm(c)},
		{"label": "Mediate behind closed doors", "fn": func():
			var p = clampf(0.35 + Game.state.agency.rep / 200.0 + minf(0.15, Game.state.favors.size() * 0.03), 0.2, 0.9)
			if Util.chance(p):
				c.loyalty = clampf(c.loyalty + 5.0, 0.0, 100.0)
				prod.qualityMod = prod.get("qualityMod", 0.0) + 3.0
				Game.grant_favor("scriptAccess", {"type": "regisseur", "name": str(Util.pick(Data.CONTACT_PERSONS.regisseur))})
				return "Two hours, a bottle of whiskey, a handshake. The shoot continues — better than before. And the director owes you now."
			c.mood = clampf(c.mood - 5.0, 0.0, 100.0)
			return "The ceasefire holds, but the atmosphere stays poisoned. At least the film gets finished."},
		{"label": "Agree to dissolve the contract", "fn": func():
			var sev = roundi(fee * 0.5)
			Game.book(float(roundi(sev * c.commission / 100.0)), "abfindung", "Severance, contract dissolved: %s (“%s”)" % [_nm(c), prod.title])
			c.fame = clampf(c.fame - 4.0, 5.0, 100.0)
			c.busyUntil = Game.mi()
			c.mood = clampf(c.mood - 8.0, 0.0, 100.0)
			_dna(c, "verlass", -8.0)
			for r in prod.roles:
				if r.filled != null and r.filled.get("clientId") != null and int(r.filled.clientId) == int(c.id):
					r.filled = {"npc": true, "name": "Replacement cast", "talent": 55, "fame": 30}
			return "Severance: %s (your commission: %s). %s is free again — but the industry registers the ouster." % [_fmt(sev), _fmt(sev * c.commission / 100.0), _nm(c)]},
	]
	if Game.has_favor("extraAudition") or Game.has_favor("scriptAccess"):
		choices.insert(1, {"label": "Call in a favor: the director relents", "fn": func():
			if Game.consume_favor("scriptAccess") or Game.consume_favor("extraAudition"):
				c.loyalty = clampf(c.loyalty + 6.0, 0.0, 100.0)
				prod.qualityMod = prod.get("qualityMod", 0.0) + 3.0
				return "A shared past is a proud currency in this town. The director smiles, apologizes to %s — the shoot goes on." % _nm(c)
			return "The matching favor was already spent."})
	return {"title": "The director wants your client gone",
		"text": "[i]“Either %s leaves my set, or I do.”[/i]\n\nAfter a fierce argument on “%s”, the director demands a recasting." % [_nm(c), prod.title],
		"choices": choices}

# ---------- 4. Die Abwerbung ----------
func _w_poach() -> float:
	if Game.state.clients.is_empty():
		return 0.0
	var sorted: Array = Game.state.clients.duplicate()
	sorted.sort_custom(func(a, b): return a.fame > b.fame)
	if Game.has_mitigated_secret(sorted[0], "wechselabsicht"):
		return 0.3
	return 1.2 if Game.state.clients.any(func(c): return c.loyalty < 70) else 0.4

func _b_poach() -> Dictionary:
	var sorted = Game.state.clients.duplicate()
	sorted.sort_custom(func(a, b): return a.fame > b.fame)
	var c = sorted[0]
	var rival = Game.pick_poach_rival()
	var rival_id := str(rival.id) if rival != null else ""
	var rival_name := str(rival.name) if rival != null else "a big rival agency"
	var prepared := Game.has_mitigated_secret(c, "wechselabsicht")
	var cost = roundi(c.fame * (540.0 if prepared else 900.0) * Util.infl(Game.state.year))
	return {"title": "The poaching attempt",
		"text": "[i]“With us you wouldn't be a client. You would be THE client.”[/i]\n\n%s is courting your most valuable name: %s (loyalty %d/100).%s" % [rival_name, _nm(c), roundi(c.loyalty), "\n\n[color=#7da05c]You knew about the thoughts of leaving. Contract, arguments and budget are already prepared.[/color]" if prepared else ""],
		"choices": [
			{"label": "Outbid them financially (%s)" % _fmt(cost), "fn": func():
				Game.book(-float(cost), "bonus", "Loyalty bonus: %s" % _nm(c))
				c.loyalty = clampf(c.loyalty + 15.0, 0.0, 100.0)
				c.mood = clampf(c.mood + 5.0, 0.0, 100.0)
				Game.change_trust(c, 6.0 if prepared else 3.0)
				if rival != null:
					rival.grudge = clampf(float(rival.grudge) + 14.0, 0.0, 100.0)
					rival.rel = clampf(float(rival.rel) - 8.0, -100.0, 100.0)
				return "A better car, a better suite, a better contract. %s stays — loyalty can be rented." % _nm(c)},
			{"label": "Argue with successes and loyalty", "fn": func():
				var wins = c.films.filter(func(f): return f.verdict == "Hit" or f.verdict == "Blockbuster").size()
				var p = clampf(c.loyalty / 100.0 + wins * 0.08 + Game.state.agency.rep / 300.0 + (0.28 if prepared else 0.0), 0.2, 0.98)
				if Util.chance(p):
					c.loyalty = clampf(c.loyalty + 8.0, 0.0, 100.0)
					Game.change_trust(c, 8.0 if prepared else 3.0)
					if rival != null:
						rival.grudge = clampf(float(rival.grudge) + 18.0, 0.0, 100.0)
						rival.rel = clampf(float(rival.rel) - 10.0, -100.0, 100.0)
					return "“I know who I owe my career to.” %s declines — out of conviction." % _nm(c)
				if rival_id != "":
					Game.rival_poach_client(rival_id, c)
				else:
					Game.state.clients.erase(c)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 4, 0, 100)
				Game.log_msg("%s moves to %s." % [_nm(c), rival_name], "bad")
				return "The arguments are not enough. %s signs elsewhere — a heavy blow." % _nm(c)},
			{"label": "Let them go", "fn": func():
				if rival_id != "":
					Game.rival_poach_client(rival_id, c)
				else:
					Game.state.clients.erase(c)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 3, 0, 100)
				Game.log_msg("%s leaves the agency for %s." % [_nm(c), rival_name], "info")
				return "No bidding war. You part politely — the reputation suffers a little, the till does not."},
		]}

# ---------- 5. Zwei Klienten, eine Rolle ----------
func _w_tworoles() -> float:
	var f = _free_clients()
	var m = f.filter(func(c): return Game.actor_by_id[c.aid].g == "m")
	var w = f.filter(func(c): return Game.actor_by_id[c.aid].g == "f")
	return 0.9 if (m.size() >= 2 or w.size() >= 2) else 0.0

func _b_tworoles() -> Dictionary:
	var f = _free_clients()
	var m = f.filter(func(c): return Game.actor_by_id[c.aid].g == "m")
	var w = f.filter(func(c): return Game.actor_by_id[c.aid].g == "f")
	var duo = (m if m.size() >= 2 else w).duplicate()
	duo.sort_custom(func(a, b): return a.fame > b.fame)
	var star = duo[0]
	var up = duo[duo.size() - 1]
	return {"title": "Two clients, one role",
		"text": "A studio is casting the lead for a big picture — and both %s (fame %d) and %s (fame %d) are in the running. Both expect your full support." % [_nm(star), roundi(star.fame), _nm(up), roundi(up.fame)],
		"choices": [
			{"label": "Back %s (safe)" % _nm(star), "fn": func():
				var r = Game.quick_production(star, {})
				up.loyalty = clampf(up.loyalty - 8.0, 0.0, 100.0)
				up.mood = clampf(up.mood - 8.0, 0.0, 100.0)
				return "%s gets the role (%s commission). %s smiles a little thinner at the next meeting." % [_nm(star), _fmt(r.income), _nm(up)]},
			{"label": "Champion %s (risky)" % _nm(up), "fn": func():
				star.mood = clampf(star.mood - 6.0, 0.0, 100.0)
				if Util.chance(0.6):
					var r = Game.quick_production(up, {})
					up.fame = clampf(up.fame + 5.0, 5.0, 100.0)
					up.loyalty = clampf(up.loyalty + 14.0, 0.0, 100.0)
					return "You fight for the newcomer — and win. %s gets the role (%s commission) and will never forget it." % [_nm(up), _fmt(r.income)]
				up.loyalty = clampf(up.loyalty + 6.0, 0.0, 100.0)
				return "In the end the studio casts externally. No deal — but %s saw that you believe in them." % _nm(up)},
			{"label": "Stay neutral", "fn": func():
				star.mood = clampf(star.mood - 4.0, 0.0, 100.0)
				up.mood = clampf(up.mood - 4.0, 0.0, 100.0)
				return "You stay out of it; the studio decides externally. Fair — but both would have wished for more effort."},
		]}

# ---------- 6. Die Rolle wurde herausgeschnitten ----------
func _w_cutrole() -> float:
	return 0.8 if _in_production() != null else 0.0

func _b_cutrole() -> Dictionary:
	var hit = _in_production()
	var c = hit.c
	var prod = hit.prod
	var fee = hit.role.filled.get("fee", 100000)
	return {"title": "The role got cut",
		"text": "After a disastrous test screening of “%s”, almost the entire role of %s falls victim to the scissors." % [prod.title, _nm(c)],
		"choices": [
			{"label": "Demand reshoots", "fn": func():
				var p = clampf(c.fame / 120.0 + int(c.get("awards", 0)) * 0.1 + Game.state.studioRel[prod.studioId] / 250.0, 0.15, 0.85)
				if Util.chance(p):
					prod.qualityMod = prod.get("qualityMod", 0.0) + 4.0
					prod.weeksLeft = int(prod.weeksLeft) + 4
					return "The studio caves: reshoots are scheduled. The role stays — the film even gets better."
				c.mood = clampf(c.mood - 5.0, 0.0, 100.0)
				return "“The cut stands.” At least you tried — %s knows that." % _nm(c)},
			{"label": "Negotiate extra compensation", "fn": func():
				var extra = roundi(fee * 0.3)
				Game.book(float(roundi(extra * c.commission / 100.0)), "provision", "Top-up after the cut conflict: %s (“%s”)" % [_nm(c), prod.title])
				c.mood = clampf(c.mood - 3.0, 0.0, 100.0)
				return "Money instead of visibility: %s extra (%s commission). No fame, but peace." % [_fmt(extra), _fmt(extra * c.commission / 100.0)]},
			{"label": "Take the conflict public", "fn": func():
				c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
				_rel(prod.studioId, -8)
				_dna(c, "familie", -4.0)
				return "“Studio mutilates film!” — The press loves the fight, %s is the talk of the town. The studio rages." % _nm(c)},
		]}

# ---------- 7. Der gefährliche Stunt ----------
func _w_stunt() -> float:
	var hit = _in_production()
	if hit == null:
		return 0.0
	return 1.0 if ["action","adventure","western","thriller"].has(hit.prod.genre) else 0.3

func _b_stunt() -> Dictionary:
	var hit = _in_production()
	var c = hit.c
	var prod = hit.prod
	return {"title": "The dangerous stunt",
		"text": "[i]“The audience notices the difference. We want %s to do the jump.”[/i]\n\nThe production of “%s” demands a risky stunt without a double." % [_nm(c), prod.title],
		"choices": [
			{"label": "Agree", "fn": func():
				if Util.chance(0.7):
					c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
					c.fame = clampf(c.fame + 2.0, 5.0, 100.0)
					prod.qualityMod = prod.get("qualityMod", 0.0) + 2.0
					return "The stunt lands on the first take. The set photos travel around the world."
				c.exhaustion = clampf(c.exhaustion + 25.0, 0.0, 100.0)
				prod.weeksLeft = int(prod.weeksLeft) + 4
				return "The jump goes wrong — bruises, a break in shooting, a scare. %s recovers, but the schedule wobbles." % _nm(c)},
			{"label": "Demand a stunt double", "fn": func():
				_rel(prod.studioId, -2)
				Game.record_identity("klientenorientiert", 2.0)
				return "The double takes over. The director grumbles, your client stays in one piece. That is exactly what you are paid for."},
			{"label": "Negotiate hazard pay & insurance", "fn": func():
				var extra = roundi(Util.ask_fee(c.fame, Game.state.year) * 0.2)
				Game.book(float(roundi(extra * c.commission / 100.0)), "provision", "Hazard pay: %s (“%s”)" % [_nm(c), prod.title])
				c.exhaustion = clampf(c.exhaustion + 10.0, 0.0, 100.0)
				if Game.consume_favor("billing") or Game.consume_favor("extraAudition"):
					return "%s jumps — for %s hazard pay. A favor called in with the line producer smooths the waters." % [_nm(c), _fmt(extra)]
				_rel(prod.studioId, -2)
				return "%s jumps — for %s hazard pay. The hard haggling leaves a sour aftertaste at the studio." % [_nm(c), _fmt(extra)]},
		]}

# ---------- 8. Die Franchise-Falle ----------
func _w_franchise() -> float:
	var cand = _free_clients().filter(func(c): return c.fame >= 55 and not c.flags.get("typecast", false))
	return (1.1 if Game.state.year >= 1977 else 0.5) if cand.size() else 0.0

func _b_franchise() -> Dictionary:
	var c = Util.pick(_free_clients().filter(func(x): return x.fame >= 55 and not x.flags.get("typecast", false)))
	var fee = roundi(Util.ask_fee(c.fame, Game.state.year) * 2.0)
	return {"title": "The franchise trap",
		"text": "[i]“Five films. One character. Your client becomes immortal — as exactly this one role.”[/i]\n\nA studio offers %s a contract for five sequels. Advance guarantee: %s." % [_nm(c), _fmt(fee)],
		"choices": [
			{"label": "Sign immediately", "fn": func():
				Game.book(float(roundi(fee * c.commission / 100.0)), "provision", "Franchise advance guarantee: %s" % _nm(c))
				c.fame = clampf(c.fame + 6.0, 5.0, 100.0)
				c.heat = clampf(c.heat + 4.0, -10.0, 10.0)
				c.flags["typecast"] = true
				c.busyUntil = Game.mi() + 4
				_dna(c, "unikat", -12.0)
				_dna(c, "popular", 8.0)
				Game.record_identity("kommerziell", 2.0)
				return "Signature, check, headline: %s commission right away. But from now on everyone sees only the one character (typecasting)." % _fmt(fee * c.commission / 100.0)},
			{"label": "Demand fewer films, higher fee", "fn": func():
				if Util.chance(0.5):
					var f2 = roundi(fee * 0.75)
					Game.book(float(roundi(f2 * c.commission / 100.0)), "provision", "Franchise deal (3 films): %s" % _nm(c))
					c.fame = clampf(c.fame + 5.0, 5.0, 100.0)
					c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
					c.busyUntil = Game.mi() + 4
					_dna(c, "popular", 5.0)
					return "Three films instead of five, but royally paid: %s (%s commission) — without the typecasting clause. Masterfully negotiated." % [_fmt(f2), _fmt(f2 * c.commission / 100.0)]
				return "The studio waves it off: “Five or none.” The deal collapses — but nobody loses face."},
			{"label": "Decline", "fn": func():
				c.loyalty = clampf(c.loyalty + 6.0, 0.0, 100.0)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 2, 0, 100)
				_dna(c, "unikat", 4.0)
				return "“My client is an actor, not an action figure.” The industry nods with respect."},
		]}

# ---------- 9. Das Herzensprojekt ----------
func _w_passion() -> float:
	return 0.9 if _free_clients().size() else 0.0

func _b_passion() -> Dictionary:
	var c = Util.pick(_free_clients())
	var invest = roundi(30000.0 * Util.infl(Game.state.year))
	return {"title": "The passion project",
		"text": "[i]“It pays almost nothing, I know. But this script — something like this comes once in a lifetime.”[/i]\n\n%s desperately wants to be in a small, artistic film." % _nm(c),
		"choices": [
			{"label": "Support it", "fn": func():
				Game.quick_production(c, {"feeMult": 0.15, "prestige": 3, "genre": "drama"})
				c.loyalty = clampf(c.loyalty + 12.0, 0.0, 100.0)
				c.mood = clampf(c.mood + 10.0, 0.0, 100.0)
				Game.record_identity("kuenstlerisch", 2.0)
				Game.record_identity("klientenorientiert", 1.0)
				return "Barely a fee, plenty of heart. %s beams — and prestige films have reinvented more than one career." % _nm(c)},
			{"label": "Advise against it", "fn": func():
				c.mood = clampf(c.mood - 8.0, 0.0, 100.0)
				return "“Art doesn't pay commission.” %s complies — with audible teeth-grinding." % _nm(c)},
			{"label": "Co-finance it as the agency (%s)" % _fmt(invest), "fn": func():
				Game.book(-float(invest), "investition", "Stake in the passion project: %s" % _nm(c))
				Game.quick_production(c, {"feeMult": 0.15, "prestige": 3, "genre": "drama", "qualityMod": 5.0})
				Game.record_identity("kuenstlerisch", 3.0)
				c.loyalty = clampf(c.loyalty + 15.0, 0.0, 100.0)
				if Util.chance(0.35):
					Game.book(float(invest * 4), "investition", "Return from the passion project: %s" % _nm(c))
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 4, 0, 100)
					return "You step in as a producer — and the film becomes a phenomenon: %s in returns plus prestige." % _fmt(invest * 4)
				return "You step in as a producer. Whether it pays off, the premiere will show — %s, at least, is devoted to you." % _nm(c)},
		]}

# ---------- 11. Der Paketdeal ----------
func _w_package() -> float:
	var stars = _free_clients().filter(func(c): return c.fame >= 60)
	var ups = _free_clients().filter(func(c): return c.fame < 40)
	return 0.9 if (stars.size() and ups.size()) else 0.0

func _b_package() -> Dictionary:
	var star = Util.pick(_free_clients().filter(func(c): return c.fame >= 60))
	var up = Util.pick(_free_clients().filter(func(c): return c.fame < 40))
	var studio = Util.pick(Game.active_studios())
	return {"title": "The package deal",
		"text": "%s desperately wants %s for a big picture. Your chance to place the unknown %s in the bargain — or to demand more." % [studio.name, _nm(star), _nm(up)],
		"choices": [
			{"label": "Offer both as a package", "fn": func():
				_rel(studio.id, -3)
				if Util.chance(0.7):
					var r1 = Game.quick_production(star, {"studio": studio})
					var r2 = Game.quick_production(up, {"studio": studio, "roleType": "support"})
					up.fame = clampf(up.fame + 6.0, 5.0, 100.0)
					return "The studio swallows the toad: both are cast (%s commission in total). %s gets the stage of a lifetime." % [_fmt(r1.income + r2.income), _nm(up)]
				var r1 = Game.quick_production(star, {"studio": studio})
				return "“We'll take the star. Not the entourage.” At least %s is cast (%s commission)." % [_nm(star), _fmt(r1.income)]},
			{"label": "Place only the star", "fn": func():
				var r = Game.quick_production(star, {"studio": studio})
				return "A clean, safe close: %s fee, %s commission. No risk, no bonus." % [_fmt(r.fee), _fmt(r.income)]},
			{"label": "Also demand creative control", "fn": func():
				if Util.chance(0.35):
					var r = Game.quick_production(star, {"studio": studio, "feeMult": 1.7, "qualityMod": 5.0})
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 5, 0, 100)
					Game.grant_favor("billing", {"type": "studio", "name": str(studio.name), "studioId": str(studio.id)})
					return "Final cut, casting veto, %s fee — a deal of the century. The industry speaks of your agency with new respect, and %s owes you." % [_fmt(r.fee), studio.name]
				_rel(studio.id, -3)
				return "“Creative control? For an agent?” The studio hangs up. The deal is dead."},
		]}

# ---------- 12. Die vorgetäuschte Romanze ----------
func _w_romance() -> float:
	return 0.8 if Game.state.clients.size() else 0.0

func _b_romance() -> Dictionary:
	var c = Game.random_client()
	return {"title": "The staged romance",
		"text": "[i]“Two stars, one restaurant, one photographer who happens to be present. The headlines write themselves.”[/i]\n\nA PR consultant proposes a staged relationship between %s and a co-star." % _nm(c),
		"choices": [
			{"label": "Accept the campaign", "fn": func():
				c.heat = clampf(c.heat + 5.0, -10.0, 10.0)
				c.fame = clampf(c.fame + 2.0, 5.0, 100.0)
				_dna(c, "romantik", 5.0)
				if Util.chance(0.25):
					Game.state.followups.append({"type": "romanceLeak", "cid": int(c.id), "due": Game.mi() + Util.rndi(3, 7)})
				return "The “relationship” dominates the gossip columns. %s is everywhere — as long as nobody asks how real it all is." % _nm(c)},
			{"label": "Decline", "fn": func():
				c.loyalty = clampf(c.loyalty + 4.0, 0.0, 100.0)
				return "No theater. %s appreciates that you don't sell their private life." % _nm(c)},
			{"label": "Leak the proposal to the press", "fn": func():
				c.heat = clampf(c.heat + 2.0, -10.0, 10.0)
				for s in Game.active_studios().slice(0, 2):
					_rel(s.id, -3)
				return "“PR consultant tried to fake a romance!” — A short laugh at the studios' expense. They remember that."},
		]}

# ---------- 13. Fotos aus der Vergangenheit ----------
func _w_photos() -> float:
	return 0.9 if Game.state.clients.any(func(c): return c.fame >= 40) else 0.0

func _b_photos() -> Dictionary:
	var c = Game.random_client(func(x): return x.fame >= 40)
	var cost = roundi((20000.0 + c.fame * 400.0) * Util.infl(Game.state.year))
	var choices: Array = [
		{"label": "Buy the exclusive rights (%s)" % _fmt(cost), "fn": func():
			Game.book(-float(cost), "pr_recht", "Exclusive rights: old photos of %s" % _nm(c))
			c.flags["photosSecured"] = true
			c.loyalty = clampf(c.loyalty + 8.0, 0.0, 100.0)
			return "The negatives move into your safe. Expensive — but control is priceless."},
		{"label": "Preempt it with an honest interview", "fn": func():
			c.flags["photosSecured"] = true
			if Util.chance(0.55):
				c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
				c.fame = clampf(c.fame + 1.0, 5.0, 100.0)
				_dna(c, "unikat", 3.0)
				return "“Yes, that was me. So?” — The candor disarms everyone. The photos have become worthless."
			c.fame = clampf(c.fame - 3.0, 5.0, 100.0)
			_dna(c, "familie", -4.0)
			return "The interview turns bumpy, a few headlines stay ugly. But the subject is done — for good."},
		{"label": "Request a court injunction", "fn": func():
			var p = clampf(0.3 + Game.state.agency.rep / 200.0 + minf(0.12, Game.state.favors.size() * 0.04), 0.2, 0.85)
			if Util.chance(p):
				c.flags["photosSecured"] = true
				return "The judge forbids publication. Your lawyers are the best in town."
			Game.state.followups.append({"type": "photosReturn", "cid": int(c.id), "due": Game.mi() + Util.rndi(3, 8)})
			return "The request is denied. The paper bides its time — the photos keep hovering like a sword of Damocles."},
		{"label": "Ask for a delay (you will owe a favor)", "fn": func():
			Game.owe_favor("suppressStory", Game.favor_contact_for("suppressStory"))
			c.flags["photosSecured"] = true
			return "The paper puts the photos on ice — as an investment in your future friendship. One day the favor will be called in."},
	]
	if Game.has_favor("suppressStory"):
		choices.insert(0, {"label": "Call in a favor: the newsroom buries the story", "fn": func():
			Game.consume_favor("suppressStory")
			c.flags["photosSecured"] = true
			c.loyalty = clampf(c.loyalty + 6.0, 0.0, 100.0)
			return "One call to an old friend at the publisher. The negatives stay in the drawer — forever."})
	return {"title": "Photos from the past",
		"text": "[i]“These pictures don't fit your client's clean image. We thought you'd want to see them first.”[/i]\n\nA newspaper owns compromising old photos of %s." % _nm(c),
		"choices": choices}

# ---------- 14. Die Oscar-Kampagne (Nov–Jan) ----------
func _has_oscar_candidate(c) -> bool:
	return c.films.any(func(f): return int(f.year) >= int(Game.state.year) - 1 and f.lead and int(f.quality) >= 60)

func _w_oscar() -> float:
	if not [11, 12, 1].has(int(Game.state.month)):
		return 0.0
	return 3.0 if Game.state.clients.any(_has_oscar_candidate) else 0.0

func _b_oscar() -> Dictionary:
	var c = Game.random_client(_has_oscar_candidate)
	var cost = roundi(50000.0 * Util.infl(Game.state.year))
	var choices: Array = [
		{"label": "Fund a big campaign (%s)" % _fmt(cost), "fn": func():
			Game.book(-float(cost), "pr_recht", "Oscar campaign: %s" % _nm(c))
			c.campaign = 25.0
			return "Ads, screenings, galas: all of Hollywood now knows who is to be nominated."},
		{"label": "Call in a favor (Academy contacts)", "fn": func():
			if Game.consume_favor("galaInvite") or Game.consume_favor("billing"):
				c.campaign = 18.0
				return "A few calls to old friends at the Academy. No invoice — just a favor crossed off."
			return "Nobody suitable owes you (anymore). Maybe the film is enough on its own."},
		{"label": "Campaign on credit (you will owe a favor)", "fn": func():
			Game.owe_favor("galaInvite", Game.favor_contact_for("suppressStory"))
			c.campaign = 12.0
			return "A PR legend leans on her contacts — on credit. One day the phone rings, and somebody demands a return."},
		{"label": "Trust the film", "fn": func():
			c.campaign = 5.0
			return "Quality prevails — sometimes. In February you will know more."},
	]
	if Game.state.favors.size() > 0:
		var sid: String = str(Game.state.released[0].studioId) if Game.state.released.size() else str(Util.pick(Game.active_studios()).id)
		choices.insert(2, {"label": "Pass a favor to the studio (relations +)", "fn": func():
			if Game.pass_any_favor_to_studio(sid):
				c.campaign = 8.0
				return "You hand your contacts to the studio — all of Hollywood sees who knows whom here. The relationship grows noticeably."
			return "You have no open favors to pass along."})
	return {"title": "The Oscar campaign",
		"text": "%s has a real shot at a nomination with that last performance — but without a campaign, the Academy likes to look elsewhere." % _nm(c),
		"choices": choices}

# ---------- 15. Der Zusammenbruch ----------
func _w_breakdown() -> float:
	for prod in Game.state.productions:
		for r in prod.roles:
			if r.filled != null and r.filled.get("clientId") != null:
				var c = Game.client(r.filled.clientId)
				if c != null and c.exhaustion >= 60 and not Game.has_mitigated_secret(c, "sucht") and not Game.has_mitigated_secret(c, "gesundheit"):
					return 2.0
	return 0.0

func _b_breakdown() -> Dictionary:
	var candidates: Array = []
	for prod in Game.state.productions:
		for r in prod.roles:
			if r.filled != null and r.filled.get("clientId") != null:
				var c2 = Game.client(r.filled.clientId)
				if c2 != null and c2.exhaustion >= 60 and not Game.has_mitigated_secret(c2, "sucht") and not Game.has_mitigated_secret(c2, "gesundheit"):
					candidates.append({"c": c2, "prod": prod})
	var hit = Util.pick(candidates)
	var c = hit.c
	var prod = hit.prod
	var cost = roundi(15000.0 * Util.infl(Game.state.year))
	return {"title": "The breakdown",
		"text": "[i]“%s did not show up on set today. The hotel says the door stays shut.”[/i]\n\nYour client is at the end of their strength (exhaustion %d/100). The production of “%s” has stopped." % [_nm(c), roundi(c.exhaustion), prod.title],
		"choices": [
			{"label": "Have the production paused", "fn": func():
				prod.weeksLeft = int(prod.weeksLeft) + 4
				_rel(prod.studioId, -4)
				c.exhaustion = clampf(c.exhaustion - 35.0, 0.0, 100.0)
				c.loyalty = clampf(c.loyalty + 10.0, 0.0, 100.0)
				Game.change_trust(c, 6.0)
				Game.record_identity("klientenorientiert", 2.0)
				return "You stand in front of your client: two weeks off, no discussion. The studio fumes, %s breathes again." % _nm(c)},
			{"label": "Arrange a discreet doctor (%s)" % _fmt(cost), "fn": func():
				Game.record_identity("diskret", 1.5)
				Game.book(-float(cost), "events", "Discreet doctor: %s" % _nm(c))
				c.exhaustion = clampf(c.exhaustion - 45.0, 0.0, 100.0)
				c.mood = clampf(c.mood + 6.0, 0.0, 100.0)
				return "A doctor who asks no questions. Three days later %s is back on set — recovered." % _nm(c)},
			{"label": "Push them back to work", "fn": func():
				c.exhaustion = clampf(c.exhaustion + 10.0, 0.0, 100.0)
				c.loyalty = clampf(c.loyalty - 12.0, 0.0, 100.0)
				_dna(c, "verlass", -8.0)
				if Util.chance(0.35):
					prod.weeksLeft = int(prod.weeksLeft) + 8
					return "%s drags themselves to the set — and collapses there for real. Now everything stands still, and it is your fault." % _nm(c)
				return "The show goes on. The schedule holds — but %s will resent this phone call for a long time." % _nm(c)},
		]}

# ---------- 16. Streik in Hollywood ----------
func _w_strike() -> float:
	if int(Game.state.strikeMonths) > 0:
		return 0.0
	var y = int(Game.state.year)
	for s in [1945, 1960, 1980, 1988, 2007, 2023]:
		if absi(y - s) <= 1:
			return 3.0
	return 0.12

func _b_strike() -> Dictionary:
	Game.state.strikeMonths = Util.rndi(2, 3)
	return {"title": "Strike in Hollywood",
		"text": "A labor dispute paralyzes the dream factory: castings and shoots rest for %d months. How does your agency position itself?" % int(Game.state.strikeMonths),
		"choices": [
			{"label": "Publicly support the strikers", "fn": func():
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 4, 0, 100)
				for s in Game.active_studios():
					_rel(s.id, -4)
				for c in Game.state.clients:
					c.loyalty = clampf(c.loyalty + 5.0, 0.0, 100.0)
				return "You side with the creatives. The studios boil — your clients applaud."},
			{"label": "Stay neutral", "fn": func():
				return "No statement, no enemies. You wait until the dust settles."},
			{"label": "Seek exemptions for your own productions", "fn": func():
				Game.state.strikeExempt = true
				Game.record_identity("studiotreu", 2.0)
				if Util.chance(0.4):
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 3, 0, 100)
					return "Your shoots keep running — but “strikebreaker agency” appears in a column anyway."
				return "Discreet lawyers, watertight old contracts: your productions keep running, and nobody writes about it."},
		]}

# ---------- 17. Der Tonfilm-Test (1927–1932) ----------
func _w_talkie() -> float:
	var y = int(Game.state.year)
	if y < 1927 or y > 1932:
		return 0.0
	return 2.5 if Game.state.clients.any(func(c): return Game.actor_by_id[c.aid].debut <= 1926) else 0.0

func _b_talkie() -> Dictionary:
	var c = Game.random_client(func(x): return Game.actor_by_id[x.aid].debut <= 1926)
	var cost = roundi(8000.0 * Util.infl(Game.state.year))
	return {"title": "The talkie test",
		"text": "[i]“We know the face. Now we want to hear the voice.”[/i]\n\nThe studio demands a speech and voice test from %s — the talkies are reshuffling all of Hollywood right now." % _nm(c),
		"choices": [
			{"label": "Book intensive voice training (%s)" % _fmt(cost), "fn": func():
				Game.book(-float(cost), "events", "Talkie voice training: %s" % _nm(c))
				if Util.chance(0.85):
					c.fame = clampf(c.fame + 4.0, 5.0, 100.0)
					return "Weeks with the best voice coach on the West Coast pay off: the voice carries."
				c.fame = clampf(c.fame - 3.0, 5.0, 100.0)
				return "Despite all the training the test is mixed. But the effort was noted."},
			{"label": "Take the test right away", "fn": func():
				if Util.chance(0.55):
					c.fame = clampf(c.fame + 4.0, 5.0, 100.0)
					return "Bullseye: the voice lands, the studio cheers. %s is among the winners of the sound revolution." % _nm(c)
				c.fame = clampf(c.fame - 7.0, 5.0, 100.0)
				c.mood = clampf(c.mood - 8.0, 0.0, 100.0)
				return "The recording is a disaster. “Maybe … with subtitles?”, a technician sneers."},
			{"label": "Bet on silents & foreign markets", "fn": func():
				c.fame = clampf(c.fame - 3.0, 5.0, 100.0)
				c.mood = clampf(c.mood + 3.0, 0.0, 100.0)
				return "No embarrassment, but a rearguard action: there is still work in Europe — the question is for how long."},
		]}

# ---------- 18. Die Zensurbehörde (1934–1954) ----------
func _w_censor() -> float:
	var y = int(Game.state.year)
	return 1.0 if (y >= 1934 and y <= 1954 and _in_production() != null) else 0.0

func _b_censor() -> Dictionary:
	var hit = _in_production()
	var c = hit.c
	var prod = hit.prod
	var cost = roundi(25000.0 * Util.infl(Game.state.year))
	return {"title": "The censorship office objects to the script",
		"text": "The Hays Office demands changes to “%s” — several scenes with %s cannot be shown as they are." % [prod.title, _nm(c)],
		"choices": [
			{"label": "Defuse the script", "fn": func():
				prod.qualityMod = prod.get("qualityMod", 0.0) - 5.0
				return "The scissors cut out everything objectionable. The film gets smoother — and a bit more inconsequential."},
			{"label": "Work with hints and paraphrases", "fn": func():
				var p = clampf(0.35 + Game.state.agency.rep / 150.0, 0.25, 0.8)
				if Util.chance(p):
					prod.qualityMod = prod.get("qualityMod", 0.0) + 5.0
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 2, 0, 100)
					return "A glance, a shadow, a closed door: the censors find nothing, the audience understands everything."
				prod.qualityMod = prod.get("qualityMod", 0.0) - 2.0
				return "A few hints survive, others fall to the scissors after all. A partial success."},
			{"label": "Attempt an independent release (%s)" % _fmt(cost), "fn": func():
				Game.book(-float(cost), "events", "Independent release “%s”" % prod.title)
				if Util.chance(0.3):
					prod.qualityMod = prod.get("qualityMod", 0.0) + 10.0
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 4, 0, 100)
					_dna(c, "unikat", 5.0)
					return "Into selected houses without the code seal — and the critics celebrate the courage. A succès de scandale in the best sense."
				prod.qualityMod = prod.get("qualityMod", 0.0) - 6.0
				_rel(prod.studioId, -5)
				return "Many theaters refuse to show the film without the seal. An expensive, risky experiment."},
		]}

# ---------- 19. Blacklisting-Ära (1947–1956, nur ab 4 Klienten) ----------
func _w_blacklist() -> float:
	var y = int(Game.state.year)
	if y < 1947 or y > 1956 or Game.state.clients.size() < 4:
		return 0.0
	return 1.5 if Game.state.clients.any(func(c): return not Game.has_mitigated_secret(c, "politik")) else 0.0

func _b_blacklist() -> Dictionary:
	var candidates: Array = Game.state.clients.filter(func(c): return not Game.has_mitigated_secret(c, "politik"))
	var warned: Array = candidates.filter(func(c): return Game.secret_of(c, "politik") != null)
	var c = Util.pick(warned if warned.size() else candidates)
	return {"title": "Suspicion of un-American activities",
		"text": "[i]“The committee summons %s. They are interested in … earlier acquaintances.”[/i]\n\nThe blacklist is spreading. How you act now defines your agency for years." % _nm(c),
		"choices": [
			{"label": "Defend the client publicly", "fn": func():
				c.loyalty = clampf(c.loyalty + 18.0, 0.0, 100.0)
				Game.change_trust(c, 12.0)
				for cl in Game.state.clients:
					cl.loyalty = clampf(cl.loyalty + 5.0, 0.0, 100.0)
				_dna(c, "unikat", 5.0)
				_dna(c, "familie", -5.0)
				if Util.chance(0.35):
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 8, 0, 100)
					for s in Game.active_studios():
						_rel(s.id, -8)
					return "Your statement is brave — and expensive. Studios hang up. But every client now knows you sacrifice nobody."
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 5, 0, 100)
				return "You alone speak plainly — and get through. In dark times, spine is the rarest currency."},
			{"label": "Have them work abroad under a pseudonym", "fn": func():
				c.busyUntil = Game.mi() + 6
				c.fame = clampf(c.fame - 5.0, 5.0, 100.0)
				c.loyalty = clampf(c.loyalty + 8.0, 0.0, 100.0)
				Game.change_trust(c, 7.0)
				return "%s shoots in Europe under a false name. The career freezes, but it does not die." % _nm(c)},
			{"label": "End the contract", "fn": func():
				Game.state.clients.erase(c)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 5, 0, 100)
				for cl in Game.state.clients:
					cl.loyalty = clampf(cl.loyalty - 12.0, 0.0, 100.0)
				for s in Game.active_studios():
					_rel(s.id, 4)
				Game.log_msg("%s was dropped in the blacklist era." % _nm(c), "bad")
				return "The agency is safe, the studios are pleased. But in the eyes of your remaining clients you read one question: “Would I have been next?”"},
		]}

# ---------- 20. Das Fernsehen klopft an (1948–1965) ----------
func _w_tv() -> float:
	var y = int(Game.state.year)
	if y < 1948 or y > 1965:
		return 0.0
	return 1.2 if _free_clients().any(func(c): return c.fame >= 40 and c.fame <= 75) else 0.0

func _b_tv() -> Dictionary:
	var c = Util.pick(_free_clients().filter(func(x): return x.fame >= 40 and x.fame <= 75))
	var monthly = roundi(9000.0 * Util.infl(Game.state.year) * (c.fame / 50.0) * c.commission / 100.0)
	return {"title": "Television comes knocking",
		"text": "[i]“Forget the movies. In five years there will be a set in every living room — and we need faces.”[/i]\n\nA network offers %s a series of their own: 12 months of guaranteed income (%s/month in commission), but the film establishment wrinkles its nose." % [_nm(c), _fmt(monthly)],
		"choices": [
			{"label": "Accept the offer", "fn": func():
				c.flags["tvIncome"] = {"monthly": monthly, "months": 12}
				c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
				c.busyUntil = Game.mi() + 3
				_dna(c, "popular", 8.0)
				_dna(c, "unikat", -4.0)
				return "%s becomes a television star: reliable money every month. The film prestige crumbles a little — but millions now know this face." % _nm(c)},
			{"label": "Negotiate guest appearances only", "fn": func():
				if Util.chance(0.5):
					Game.book(float(monthly * 3), "tv", "TV guest appearances: %s" % _nm(c))
					c.heat = clampf(c.heat + 2.0, -10.0, 10.0)
					return "The compromise works: individual appearances, full fee (%s), no exclusive contract." % _fmt(monthly * 3)
				return "The network wants all or nothing. The deal falls apart — but the door stays ajar."},
			{"label": "Reject television on principle", "fn": func():
				c.mood = clampf(c.mood + 2.0, 0.0, 100.0)
				c.loyalty = clampf(c.loyalty + 3.0, 0.0, 100.0)
				_dna(c, "unikat", 2.0)
				return "“My client is a movie star.” The classic image stays immaculate — whether that still looks smart in ten years, nobody knows."},
		]}

# ---------- Folge-Ereignisse ----------
func build_followup(fu: Dictionary) -> Variant:
	match fu.type:
		"photosReturn":
			var c = Game.client(fu.cid)
			if c == null or c.flags.get("photosSecured", false):
				return null
			var cost = roundi((12000.0 + c.fame * 200.0) * Util.infl(Game.state.year))
			var choices: Array = [
				{"label": "Buy them now (%s)" % _fmt(cost), "fn": func():
					Game.book(-float(cost), "pr_recht", "Tabloid photos bought: %s" % _nm(c))
					c.flags["photosSecured"] = true
					return "This time you don't hesitate. The matter is off the table for good."},
				{"label": "Sit it out", "fn": func():
					c.fame = clampf(c.fame - 3.0, 5.0, 100.0)
					c.flags["photosSecured"] = true
					_dna(c, "familie", -5.0)
					return "Three unpleasant weeks, then the outrage burns out. Scars remain."},
			]
			if Game.has_favor("suppressStory"):
				choices.insert(0, {"label": "Call in a favor: kill the story", "fn": func():
					Game.consume_favor("suppressStory")
					c.flags["photosSecured"] = true
					return "One word with the publisher is enough. The tabloid prints something about a congressman instead."})
			return {"title": "The photos resurface",
				"text": "As feared: the old pictures of %s are circulating again — this time with a tabloid." % _nm(c),
				"choices": choices}
		"romanceLeak":
			var c2 = Game.client(fu.cid)
			if c2 == null:
				return null
			var choices2: Array = [
				{"label": "Admit it and laugh", "fn": func():
					if Util.chance(0.6):
						c2.heat = clampf(c2.heat + 2.0, -10.0, 10.0)
						return "“Of course it was show — welcome to Hollywood.” The town laughs along. Lucky."
					c2.fame = clampf(c2.fame - 3.0, 5.0, 100.0)
					_dna(c2, "familie", -4.0)
					return "Part of the audience feels cheated. The shine takes scratches."},
				{"label": "Deny it", "fn": func():
					c2.heat = clampf(c2.heat - 2.0, -10.0, 10.0)
					return "Nobody quite believes the denial, but the story loses steam."},
			]
			if Game.has_favor("suppressStory"):
				choices2.insert(0, {"label": "Call in a favor: make the column disappear", "fn": func():
					Game.consume_favor("suppressStory")
					return "The columnist suddenly finds the story “no longer fit to print”. What counts in Hollywood is what gets printed — or doesn't."})
			return {"title": "The romance is exposed",
				"text": "A columnist reveals: %s's great love story was a PR staging." % _nm(c2),
				"choices": choices2}
		"homevideo":
			# Heimvideo-Ära (1980+): Flops können nachträglich Geld einspielen (Feature 14)
			var income := roundi(float(fu.get("budget", 0)) * Util.rndf(0.08, 0.16) * float(Game.state.market))
			var hvsid := str(fu.get("studioId", ""))
			var hv_studio := "The studio"
			if hvsid != "" and Game.state.studioRel.has(hvsid):
				hv_studio = Game._studio(hvsid).name
			return {"title": "A second life on video",
				"text": "“%s” — a flop back then — leads a quiet life of its own on home video: rental stores reorder, midnight screenings fill up, a small fan base writes letters. %s offers a retroactive participation." % [str(fu.get("title", "The film")), hv_studio],
				"choices": [
					{"label": "Accept the participation (+%s)" % _fmt(income), "fn": func():
						Game.book(float(income), "sonstiges", "Home video second run: “%s”" % str(fu.get("title", "")))
						if hvsid != "" and Game.state.studioRel.has(hvsid):
							_rel(hvsid, 2)
						return "The video store checks trickle in. Some films simply need a second life. (+%s)" % _fmt(income)},
					{"label": "Gamble on cult status", "fn": func():
						if Util.chance(0.5):
							var more := roundi(income * 1.7)
							Game.book(float(more), "sonstiges", "Home video cult status: “%s”" % str(fu.get("title", "")))
							return "Good instinct: the film becomes a midnight cult — the later settlement turns out much better. (+%s)" % _fmt(more)
						return "You wait for better terms — but the moment passes. The rental stores rearrange the shelf."},
				]}
	return null

# ---------- Phase 2: Klienten werden Machtfiguren ----------
func _w_power_figure() -> float:
	var candidates := Game.power_figure_candidates()
	if candidates.is_empty():
		return 0.0
	return 1.5 if candidates.any(func(c): return int(c.get("awards", 0)) >= 1) else 0.8

func _b_power_figure() -> Dictionary:
	var candidates := Game.power_figure_candidates()
	candidates.sort_custom(func(a, b): return (int(a.get("awards", 0)) * 30.0 + float(a.fame)) > (int(b.get("awards", 0)) * 30.0 + float(b.fame)))
	var c: Dictionary = candidates[0]
	var cid := int(c.id)
	var fractured := float(c.loyalty) < 30.0 or float(c.trust) < 30.0
	var director_cost := roundi(20000.0 * Util.infl(Game.state.year))
	var producer_cost := roundi(35000.0 * Util.infl(Game.state.year))
	var choices: Array = [
		{"label":"Prepare the director's chair (%s)" % _fmt(director_cost), "fn":func():
			if float(Game.state.agency.cash) < float(director_cost):
				return "The financing isn't there. The director's chair has to wait."
			Game.book(-float(director_cost), "investition", "Directing debut: %s" % _nm(c))
			Game.record_identity("kuenstlerisch", 2.0)
			Game.record_identity("klientenorientiert", 1.0)
			return Game.become_power_figure(cid, "director", true)},
		{"label":"Build a production company (%s)" % _fmt(producer_cost), "fn":func():
			if float(Game.state.agency.cash) < float(producer_cost):
				return "Without capital there is no production company. Not yet."
			Game.book(-float(producer_cost), "investition", "Producing debut: %s" % _nm(c))
			Game.record_identity("kommerziell", 1.0)
			Game.record_identity("klientenorientiert", 1.0)
			return Game.become_power_figure(cid, "producer", true)},
	]
	if fractured:
		choices.append({"label":"Let them go without a stake", "fn":func(): return Game.become_power_figure(cid, "producer", false, true)})
	else:
		choices.append({"label":"Stay in front of the camera for now", "fn":func(): return "[i]“I still have roles to play.”[/i] The power shift is postponed — at no cost."})
	return {"title":"The other side of the camera",
		"text":"[i]“I have stood on marks long enough. Maybe it is time to call ‘action’ myself.”[/i]\n\n%s is ready for Hollywood's next circle of power.%s" % [_nm(c), " The relationship, however, is so fractured that people already talk about a rival house of their own." if fractured else ""],
		"choices":choices}

# ---------- 21. Der Gefallen wird eingefordert ----------
func _w_favor_called() -> float:
	return 1.3 if Game.state.debts.size() else 0.0

func _b_favor_called() -> Dictionary:
	var debt = Util.pick(Game.state.debts)
	var did = int(debt.id)
	var creditor: String = str(debt["from"].get("name", "An old acquaintance"))
	var sid: String = str(debt["from"].get("studioId", ""))
	var demand: String = Util.pick(["gala", "pitch", "cameo"])
	var demands := {
		"gala": "one of your clients as the star guest of a charity gala — unpaid, but very public",
		"pitch": "that you refrain from entering one of your clients for a coveted role",
		"cameo": "a free cameo appearance in a friend's project",
	}
	var choices: Array = [
		{"label": "Honor it and deliver", "fn": func():
			Game.remove_debt(did)
			var msg := ""
			match demand:
				"gala":
					var c = Game.random_client()
					if c != null:
						c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
						c.exhaustion = clampf(c.exhaustion + 10.0, 0.0, 100.0)
						c.mood = clampf(c.mood - 4.0, 0.0, 100.0)
						msg = "%s beams into the flashbulbs for the good cause (+heat, some exhaustion)." % _nm(c)
					else:
						msg = "You cut the ribbon yourself — at least a photo in the local paper."
				"pitch":
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 1, 0, 100)
					msg = "You hold back at the casting. The industry registers your decency (reputation +1)."
				"cameo":
					var c2 = Game.random_client()
					if c2 != null:
						c2.exhaustion = clampf(c2.exhaustion + 8.0, 0.0, 100.0)
						c2.fame = clampf(c2.fame + 1.0, 5.0, 100.0)
						msg = "%s delivers a charming cameo — unpaid, but not unnoticed." % _nm(c2)
					else:
						msg = "You arrange the cameo through detours. It costs nerves, but no fame."
			if Util.chance(0.3):
				var kind_s: String = Util.pick(["extraAudition", "billing", "scriptAccess"])
				Game.grant_favor(kind_s, debt["from"])
				msg += " And because you were so easy about it, %s is now in your debt themselves." % creditor
			return "The debt is settled — %s is even with you. %s" % [creditor, msg]},
		{"label": "Refuse (costs standing)", "fn": func():
			Game.remove_debt(did)
			if sid != "" and Game.state.studioRel.has(sid):
				_rel(sid, -6)
				return "%s notes the refusal coolly. The relationship with %s suffers." % [creditor, Game._studio(sid).name]
			Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 2, 0, 100)
			return "The refusal makes the rounds. Some nod with understanding — others don't. (Reputation −2)"},
	]
	if Game.state.favors.size() > 0:
		choices.insert(1, {"label": "Counter with a favor of your own (spends 1 favor)", "fn": func():
			Game.consume_any_favor()
			Game.remove_debt(did)
			return "A favor against a favor — the classic currency of this town. You are even, and nobody lost face."})
	return {"title": "The favor is called in",
		"text": "[i]“You remember, don't you — back then I did you a favor. Now I need something.”[/i]\n\n%s calls it in: %s." % [creditor, demands[demand]],
		"choices": choices}

# ---------- 22. Die exklusive Einladung ----------
func _w_gala() -> float:
	return 1.0 if Game.has_favor("galaInvite") else 0.0

func _b_gala() -> Dictionary:
	Game.consume_favor("galaInvite")
	var studio = Util.pick(Game.active_studios())
	var c = Game.random_client(func(x): return Game.is_free(x))
	var choices: Array = [
		{"label": "Make connections", "fn": func():
			var f1 = Game.grant_favor(Util.pick(["extraAudition", "billing", "scriptAccess", "suppressStory"]))
			var msg := "Two hours, three handshakes, one promised lunch: %s now owes you something." % str(f1["from"].get("name", "Somebody important"))
			if Util.chance(0.5):
				var f2 = Game.grant_favor(Util.pick(["galaInvite", "extraAudition", "billing"]))
				msg += " And %s leaves something on the table for you too." % str(f2["from"].get("name", "a producer"))
			return msg},
		{"label": "Leave a favor to the host", "fn": func():
			Game.record_identity("studiotreu", 1.5)
			if Game.pass_any_favor_to_studio(studio.id):
				return "You let %s feel that you can afford to give up your trump cards. The relationship visibly deepens." % studio.name
			_rel(studio.id, 2)
			return "You have no favors in hand — but the evening itself works as a gesture."},
	]
	if c != null:
		choices.insert(1, {"label": "Set up a deal: showcase %s" % _nm(c), "fn": func():
			var r = Game.quick_production(c, {"studio": studio, "feeMult": 1.2})
			c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
			return "Between champagne and cedar wood, business is done: %s signs for “%s” (%s commission)." % [_nm(c), r.title, _fmt(r.income)]})
	return {"title": "The exclusive invitation",
		"text": "The invitation, called in, takes you to a closed event at %s — tuxedos, laughter, and in every corner somebody with something to give away." % studio.name,
		"choices": choices}


# =====================================================================
# Klausel-Folgeereignisse (Feature 8) — feuern NUR bei vorhandener Klausel
# =====================================================================

func _clients_with_clause(clause_id: String) -> Array:
	return Game.state.clients.filter(func(c): return c.get("clauses", []).has(clause_id))

# ---------- sequelOption: Die Fortsetzungs-Falle ----------
func _w_sequel_crisis() -> float:
	return 4.0 if Game.state.clients.any(func(c): return c.flags.get("sequelDue") != null) else 0.0

func _b_sequel_crisis() -> Dictionary:
	var c = Util.pick(Game.state.clients.filter(func(x): return x.flags.get("sequelDue") != null))
	var due: Dictionary = c.flags["sequelDue"]
	var sid := str(due.get("studioId", ""))
	var old_fee := int(due.get("fee", 0))
	var fair_fee := roundi(Util.ask_fee(c.fame, Game.state.year) * 1.4)
	var studio_name := "The studio"
	if sid != "" and Game.state.studioRel.has(sid):
		studio_name = Game._studio(sid).name
	var film_t := str(due.get("title", "The film"))
	var bonus := roundi(fair_fee * 0.35 * float(c.commission) / 100.0)
	var lawyer := roundi(25000.0 * Util.infl(Game.state.year))
	return {"title": "The sequel trap",
		"text": "“%s” became a blockbuster — and promptly %s pulls the old sequel-option clause out of the drawer: %s is to shoot the sequel at the first film's fee (%s instead of the market rate of %s).\n\n[i]“That is theft with a signature!”[/i] %s rages on the phone." % [film_t, studio_name, _nm(c), _fmt(old_fee), _fmt(fair_fee), _nm(c)],
		"choices": [
			{"label": "Renegotiate hard", "fn": func():
				c.flags.erase("sequelDue")
				if Util.chance(0.55):
					Game.book(float(bonus), "provision", "Sequel special bonus: %s (“%s II”)" % [_nm(c), film_t])
					Game.change_trust(c, 4.0)
					if sid != "" and Game.state.studioRel.has(sid):
						_rel(sid, -4)
					return "After two grinding weeks the studio caves: a special bonus instead of the old fee. %s breathes again — at %s they took note. (+%s commission)" % [_nm(c), studio_name, _fmt(bonus)]
				c.mood = clampf(c.mood - 8.0, 0.0, 100.0)
				if sid != "" and Game.state.studioRel.has(sid):
					_rel(sid, -8)
				return "The studio stays stubborn and points at the contract. %s will have to shoot the sequel at the old fee — with a mood to match." % _nm(c)},
			{"label": "Talk the client into honoring the contract", "fn": func():
				c.flags.erase("sequelDue")
				Game.change_trust(c, -6.0)
				Game.record_identity("studiotreu", 1.0)
				if sid != "" and Game.state.studioRel.has(sid):
					_rel(sid, 4)
				return "“A contract is a contract.” %s swallows it — silently. %s registers your loyalty favorably." % [_nm(c), studio_name]},
			{"label": "Threaten a lawsuit (%s legal fees)" % _fmt(lawyer), "fn": func():
				c.flags.erase("sequelDue")
				Game.book(-float(lawyer), "pr_recht", "Lawyers: sequel option contested (%s)" % _nm(c))
				if Util.chance(0.5):
					var win := roundi(fair_fee * 0.5 * float(c.commission) / 100.0)
					Game.book(float(win), "provision", "Settlement “%s II”: %s" % [film_t, _nm(c)])
					Game.change_trust(c, 6.0)
					return "A settlement at the courtroom gates: a juicy payout, a new fee. %s triumphs. (−%s lawyer, +%s settlement)" % [_nm(c), _fmt(lawyer), _fmt(win)]
				if sid != "" and Game.state.studioRel.has(sid):
					_rel(sid, -10)
				c.fame = clampf(c.fame - 3.0, 5.0, 100.0)
				return "The lawsuit fizzles — and the press loves the story of the “ungrateful star”. %s shoots at the old fee, with humility." % _nm(c)},
		]}

# ---------- escalator: Zögern an der Gagen-Leiter ----------
func _w_escalator_balk() -> float:
	return 0.9 if _clients_with_clause("escalator").size() > 0 else 0.0

func _b_escalator_balk() -> Dictionary:
	var c = Util.pick(_clients_with_clause("escalator"))
	var studio = Util.pick(Game.active_studios())
	var buyout := roundi(Util.ask_fee(c.fame, Game.state.year) * 0.8 * float(c.commission) / 100.0)
	return {"title": "Hesitation on the fee ladder",
		"text": "%s wants to cast %s again — but the escalator clause pushes the fee up with every film. Accounting sounds the alarm: either the clause goes, or the role goes to a cheaper face.\n\nThey offer you a clause buy-out: a one-time %s." % [studio.name, _nm(c), _fmt(buyout)],
		"choices": [
			{"label": "Accept the buy-out (+%s, clause is dropped)" % _fmt(buyout), "fn": func():
				c.clauses.erase("escalator")
				Game.book(float(buyout), "provision", "Escalator buy-out: %s" % _nm(c))
				Game.change_trust(c, -3.0)
				return "The money is right, the gesture is not: %s loses the fee ladder — and will remember. (+%s)" % [_nm(c), _fmt(buyout)]},
			{"label": "Defend the clause", "fn": func():
				Game.change_trust(c, 3.0)
				_rel(studio.id, -3)
				if Util.chance(0.6):
					return "%s swallows the ladder — the star is worth the trouble. %s beams: this is exactly what they pay you commission for." % [studio.name, _nm(c)]
				c.heat = clampf(c.heat - 2.0, -10.0, 10.0)
				return "%s pulls back and casts cheaper. The clause stays — but it now hangs on %s like a price tag." % [studio.name, _nm(c)]},
		]}

# ---------- creativeApproval: Der Klient sagt Nein ----------
func _w_creative_veto() -> float:
	return 1.0 if _clients_with_clause("creativeApproval").any(func(c): return Game.is_free(c)) else 0.0

func _b_creative_veto() -> Dictionary:
	var c = Util.pick(_clients_with_clause("creativeApproval").filter(func(x): return Game.is_free(x)))
	var studio = Util.pick(Game.active_studios())
	var genre: String = Util.pick(Data.GENRES.keys())
	var proj := Game.project_title(genre)
	var fee := roundi(Util.ask_fee(c.fame, Game.state.year))
	return {"title": "The creative veto",
		"text": "%s offers %s the lead in “%s” (%s) — a solid payday (%s). But the creative-approval clause gives %s a say, and the verdict is devastating:\n\n[i]“This script buries my career. I am not doing it.”[/i]" % [studio.name, _nm(c), proj, Data.GENRES[genre]["label"], _fmt(fee), _nm(c)],
		"choices": [
			{"label": "Respect the veto", "fn": func():
				Game.change_trust(c, 4.0)
				_rel(studio.id, -2)
				_dna(c, "unikat", 4.0)
				return "You stand behind your client. %s leaves the meeting upright — %s strikes you off the Christmas list for now." % [_nm(c), studio.name]},
			{"label": "Talk them around — the money is too good", "fn": func():
				if Util.chance(0.6):
					var r = Game.quick_production(c, {"studio": studio, "feeMult": 1.0})
					Game.change_trust(c, -5.0)
					c.mood = clampf(c.mood - 6.0, 0.0, 100.0)
					return "%s lets themselves be worn down and signs for “%s” (%s commission). Radio silence in the trailer from now on." % [_nm(c), r.title, _fmt(r.income)]
				Game.change_trust(c, -3.0)
				_rel(studio.id, -4)
				return "One argument, two furious parties — and no contract in the end. %s is offended, %s likewise." % [_nm(c), studio.name]},
			{"label": "Negotiate script revisions", "fn": func():
				if Util.chance(0.55):
					var r2 = Game.quick_production(c, {"studio": studio, "feeMult": 0.9})
					Game.change_trust(c, 3.0)
					_dna(c, "unikat", 2.0)
					return "Three new writers, two weeks of rework: “%s” becomes bearable. Everyone saves face (%s commission)." % [r2.title, _fmt(r2.income)]
				_rel(studio.id, -3)
				return "%s is not willing to invest in the script again. The project gathers dust in the drawer." % studio.name},
		]}

# ---------- moralClause: Der Sittenparagraph ----------
func _moral_case() -> Dictionary:
	for c in Game.state.clients:
		if not c.get("clauses", []).has("moralClause"):
			continue
		var rumor = null
		for ru in Game.state.rumors:
			if float(ru.get("belief", 0.0)) >= 60.0 and Game.rumor_subject_client(ru) == c:
				rumor = ru
				break
		if rumor == null:
			continue
		for p in Game.state.productions:
			for r2 in p.roles:
				if r2.filled != null and r2.filled.get("clientId") != null and int(r2.filled.clientId) == int(c.id):
					return {"c": c, "rumor": rumor, "prod": p, "role": r2}
	return {}

func _w_moral_exit() -> float:
	return 3.0 if _moral_case().size() > 0 else 0.0

func _b_moral_exit() -> Dictionary:
	var mc := _moral_case()
	var c = mc["c"]
	var rumor: Dictionary = mc["rumor"]
	var role = mc["role"]
	var prod: Dictionary = mc["prod"]
	var sid := str(prod.studioId)
	var studio_name := "A studio"
	if Game.state.studioRel.has(sid):
		studio_name = Game._studio(sid).name
	var lawyer := roundi(30000.0 * Util.infl(Game.state.year))
	var kick := func():
		role.filled = {"npc": true, "name": "Recast", "talent": 55, "fame": 30}
		c.busyUntil = Game.mi()
	return {"title": "The morality clause",
		"text": "The rumor about %s has cracked the credibility threshold — and %s pulls the morality clause from the contract of “%s”: the contract is dissolved via the morals paragraph, penalty-free, immediately. A recast is already being sounded out.\n\n[i]“%s”[/i]" % [_nm(c), studio_name, str(prod.title), str(rumor.get("text", ""))],
		"choices": [
			{"label": "Bring in the lawyers (%s)" % _fmt(lawyer), "fn": func():
				Game.book(-float(lawyer), "pr_recht", "Morality clause trial: %s" % _nm(c))
				if Util.chance(0.5):
					_rel(sid, -3)
					return "The lawyers pick the clause apart: a “scandal” is not proven, only talk. The contract holds — barely. (−%s)" % _fmt(lawyer)
				kick.call()
				c.fame = clampf(c.fame - 2.0, 5.0, 100.0)
				return "The court sees it differently. %s is out of the film — and the trial made the story truly big. (−%s)" % [_nm(c), _fmt(lawyer)]},
			{"label": "Accept it and limit the damage", "fn": func():
				kick.call()
				c.fame = clampf(c.fame - 4.0, 5.0, 100.0)
				Game.change_trust(c, 2.0)
				return "You quietly pull %s out of the line of fire. The film goes on — without your star, but without a mud fight." % _nm(c)},
			{"label": "A rebuttal in the press", "fn": func():
				var cost := roundi(15000.0 * Util.infl(Game.state.year))
				Game.book(-float(cost), "pr_recht", "Rebuttal: %s" % _nm(c))
				rumor["belief"] = clampf(float(rumor.belief) - 25.0, 0.0, 100.0)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 1, 0, 100)
				if float(rumor.belief) < 60.0 and Util.chance(0.7):
					return "The rebuttal runs everywhere. Belief in the rumor crumbles — %s lets the termination rest for now." % studio_name
				kick.call()
				return "The rebuttal fizzles. In the end there is just one more headline — and a recast. (−%s)" % _fmt(cost)},
		]}

# ---------- likenessRights: Das digitale Abbild (ab 2015) ----------
func _w_likeness() -> float:
	if int(Game.state.year) < 2015:
		return 0.0
	return 1.0 if _clients_with_clause("likenessRights").size() > 0 else 0.0

func _b_likeness() -> Dictionary:
	var c = Util.pick(_clients_with_clause("likenessRights"))
	var studio = Util.pick(Game.active_studios())
	var payment := roundi(Util.ask_fee(c.fame, Game.state.year) * 0.9 * float(c.commission) / 100.0)
	if Util.chance(0.5):
		return {"title": "The digital double",
			"text": "An attentive fan spots it first: in “%s”, %s walks through the frame — although %s never stood in front of this camera. %s pulled the digital likeness from the archive and reused it. The likeness-rights clause requires consent. There was none." % [Game.project_title(Util.pick(Data.GENRES.keys())), _nm(c), _nm(c), studio.name],
			"choices": [
				{"label": "File a lawsuit", "fn": func():
					var cost := roundi(40000.0 * Util.infl(Game.state.year))
					Game.book(-float(cost), "pr_recht", "Likeness lawsuit: %s" % _nm(c))
					if Util.chance(0.6):
						var win := roundi(float(payment) * 2.5)
						Game.book(float(win), "provision", "Likeness settlement: %s" % _nm(c))
						_rel(studio.id, -6)
						Game.change_trust(c, 5.0)
						return "The settlement sets a precedent for all of Hollywood: the likeness belongs to the person. (−%s lawyer, +%s settlement)" % [_fmt(cost), _fmt(win)]
					_rel(studio.id, -8)
					return "Years of expert reports, specialists, pixel counting — in the end the suit is dismissed. The law limps behind the technology. (−%s)" % _fmt(cost)},
				{"label": "Sell the license retroactively (+%s)" % _fmt(payment), "fn": func():
					Game.book(float(payment), "provision", "Likeness license: %s" % _nm(c))
					Game.change_trust(c, -4.0)
					return "A check instead of trouble. %s is not thrilled that you rent out their face after the fact — but the commission is right. (+%s)" % [_nm(c), _fmt(payment)]},
			]}
	return {"title": "The offer from the computer",
		"text": "%s wants to license the digital likeness of %s: advertising, games, virtual appearances — %s never has to stand in front of a camera again and still gets paid. Offer for the agency: %s.\n\n[i]“Well, I find it creepy”[/i], says %s." % [studio.name, _nm(c), _nm(c), _fmt(payment), _nm(c)],
		"choices": [
			{"label": "Sell (+%s)" % _fmt(payment), "fn": func():
				Game.book(float(payment), "provision", "Digital double license: %s" % _nm(c))
				Game.change_trust(c, -3.0)
				c.heat = clampf(c.heat + 2.0, -10.0, 10.0)
				return "The double now works around the clock — the human attached suddenly has a lot of free time and mixed feelings. (+%s)" % _fmt(payment)},
			{"label": "Decline — the client has veto power", "fn": func():
				Game.change_trust(c, 4.0)
				_dna(c, "unikat", 2.0)
				return "You respect the unease. %s stays flesh and blood — and trusts you a bit more." % _nm(c)},
		]}

# ---------- endorsement: Werbe-Pflichttermin ----------
func _w_endorsement() -> float:
	return 0.8 if _clients_with_clause("endorsement").size() > 0 else 0.0

func _b_endorsement() -> Dictionary:
	var c = Util.pick(_clients_with_clause("endorsement"))
	var pay := roundi((1200.0 + float(c.fame) * 45.0) * Util.infl(Game.state.year) * float(c.commission) / 100.0)
	var product: String = Util.pick(["an aftershave spot", "a watch campaign", "a soft-drink commercial", "a cigarette ad", "a car ad series"])
	return {"title": "The mandatory endorsement gig",
		"text": "The endorsement clause calls: %s is to shoot %s — three days of studio, a wide grin, zero artistic ambition. The agency earns along, but %s rolls their eyes anyway." % [_nm(c), product, _nm(c)],
		"choices": [
			{"label": "Squeeze the gig in (+%s)" % _fmt(pay), "fn": func():
				Game.book(float(pay), "provision", "Endorsement obligation: %s" % _nm(c))
				c.exhaustion = clampf(c.exhaustion + 8.0, 0.0, 100.0)
				Game.change_trust(c, -2.0)
				_dna(c, "familie", 2.0)
				return "Three days of smiling on cue. The account is happy, %s less so. (+%s, exhaustion rises)" % [_nm(c), _fmt(pay)]},
			{"label": "Cancel the gig (penalty)", "fn": func():
				var fine := roundi(float(pay) * 0.5)
				Game.book(-float(fine), "sonstiges", "Contract penalty, endorsement gig: %s" % _nm(c))
				Game.change_trust(c, 2.0)
				return "You pay the penalty and give your client three free days. Sometimes that is the better investment. (−%s)" % _fmt(fine)},
			{"label": "Turn it into a PR story", "fn": func():
				var pr_pay := roundi(float(pay) * 0.7)
				Game.book(float(pr_pay), "provision", "Endorsement obligation: %s" % _nm(c))
				c.heat = clampf(c.heat + 2.0, -10.0, 10.0)
				_dna(c, "popular", 2.0)
				return "You let a camera roll behind the camera: the spot becomes a story, the story a headline. Duty turns into PR. (+%s)" % _fmt(pr_pay)},
		]}
