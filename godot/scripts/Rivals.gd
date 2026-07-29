extends Node
# =====================================================================
# Rivalen-System (aus Game.gd extrahiert): Konkurrenz-Agenturen — Stile,
# Signings, Gerüchte-Attacken, Kooperationen, aktive Abwerbe-Duelle mit
# Gegenangeboten, Marktanteils-Ranking und Casting-Blockaden studiotreuer
# Häuser. Autoload "Rivals"; liest den Spielzustand über Game.state.
# =====================================================================

const RIVAL_STYLE_INFO := {
	"aggressiv": {"label":"Aggressive", "icon":"🦈"},
	"nachwuchs": {"label":"Up-and-coming", "icon":"🌱"},
	"studiotreu": {"label":"Studio-loyal", "icon":"🏛"},
	"prestige": {"label":"Prestige", "icon":"🎩"},
}

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
	var studios := Game.active_studios()
	for i in styles.size():
		Game.state.rivals.append({"id":"rival_%d" % i, "name":names[i], "style":styles[i], "clients":[], "grudge":0.0, "rel":0.0,
			"studioId":str(studios[i % studios.size()].id) if studios.size() else ""})

func rival_for_actor(actor_id: String) -> Variant:
	for rival in Game.state.get("rivals", []):
		if rival.get("clients", []).has(actor_id):
			return rival
	return null

func is_rival_client(actor_id: String) -> bool:
	return rival_for_actor(actor_id) != null

func rival_by_id(rival_id: String) -> Variant:
	for rival in Game.state.get("rivals", []):
		if str(rival.id) == rival_id:
			return rival
	return null

func pick_poach_rival() -> Variant:
	if Game.state.get("rivals", []).is_empty():
		return null
	var sorted: Array = Game.state.rivals.duplicate()
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
	var actor_name := Game.client_name(c)
	Game.state.clients.erase(c)
	if not rival.clients.has(actor_id):
		rival.clients.append(actor_id)
	rival.grudge = clampf(float(rival.grudge) + 20.0, 0.0, 100.0)
	rival.rel = clampf(float(rival.rel) - 15.0, -100.0, 100.0)
	Game.press_event("Client moves", "%s leaves %s for %s" % [actor_name, Game.state.agency.name, rival.name])

func _rival_candidate(rival: Dictionary) -> Variant:
	var pool := Game.available_actors()
	if pool.is_empty():
		return null
	match str(rival.style):
		"nachwuchs":
			var young: Array = pool.filter(func(a): return Util.age_of(a, Game.state.year) <= 28)
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
	var c = Game.random_client(func(x): return Game.is_free(x))
	if c == null:
		return null
	var rid := str(rival.id)
	var cid := int(c.id)
	var rival_name := str(rival.name)
	return {"title":"A call from %s" % rival_name,
		"text":"[i]“You don't have to like each other to build a good picture together.”[/i]\n\n%s offers a package cooperation: your client %s gets a role, the rival house fills out the rest of the cast." % [rival_name, Game.client_name(c)],
		"choices":[
			{"label":"Package it together", "fn":func():
				var cl = Game.client(cid)
				var rv = rival_by_id(rid)
				if cl == null or rv == null:
					return "The opportunity has passed."
				var result = Game.quick_production(cl, {"prestige":2 if str(rv.style) == "prestige" else 1})
				rv.grudge = maxf(0.0, float(rv.grudge) - 12.0)
				rv.rel = clampf(float(rv.rel) + 14.0, -100.0, 100.0)
				Game.press_event("Agencies", "%s and %s package “%s” together" % [Game.state.agency.name, rv.name, result.title])
				return "Two address books, one contract: “%s” goes into production." % result.title},
			{"label":"Decline politely", "fn":func(): return "You leave the door open. In Hollywood, tomorrow is another month."},
		]}

func tick_rivals(events: Array = [], force: bool = false) -> void:
	var cooperation_added := false
	for rival in Game.state.get("rivals", []):
		for actor_id in rival.clients.duplicate():
			var actor: Dictionary = Game.actor_by_id.get(str(actor_id), {})
			if actor.is_empty() or (actor.death != null and float(actor.death) <= float(Game.state.year)):
				rival.clients.erase(actor_id)
		var sign_chance := 0.07 if str(rival.style) == "nachwuchs" else 0.035
		if force or Util.chance(sign_chance):
			var actor = _rival_candidate(rival)
			if actor != null:
				rival.clients.append(str(actor.id))
				Game.press_event("Rival deals", "%s signs %s" % [rival.name, actor.name])
				Game.log_msg("Competition: %s signs %s." % [rival.name, actor.name], "info")
		if float(rival.grudge) >= 60.0 and Game.state.clients.size() and (force or Util.chance(0.18)):
			var target: Dictionary = Util.pick(Game.state.clients)
			var rumor := Scandal.add_rumor(int(target.id), "%s is sowing doubts about the reliability of %s in the studio corridors." % [rival.name, Game.client_name(target)], false, "skandal", ["Studios", "Assistants"], 14.0, true, "", 34.0)
			rumor["sourceRival"] = str(rival.id)
			Game.press_event("Agencies", "Ice age between %s and %s: studio corridors become a battlefield" % [Game.state.agency.name, rival.name])
		# Aktives Abwerbe-Duell (statt stillem Grudge): unzufriedene Klienten
		# bekommen ein konkretes Gegenangebot auf den Tisch gelegt.
		if Game.state.clients.size() and (force or Util.chance(0.04 + float(rival.grudge) / 500.0)):
			var poach_cands: Array = Game.state.clients.filter(func(pc):
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
	for c in Game.state.clients:
		own += float(c.fame)
	out.append({"name": str(Game.state.agency.name), "score": own, "isPlayer": true})
	for rival in Game.state.get("rivals", []):
		var score := 0.0
		for aid in rival.clients:
			var actor: Dictionary = Game.actor_by_id.get(str(aid), {})
			if not actor.is_empty():
				score += float(Util.fame_at(actor, Game.state.year))
		out.append({"name": str(rival.name), "score": score, "isPlayer": false})
	out.sort_custom(func(a, b): return float(a.score) > float(b.score))
	return out

# Abwerbe-Duell: Der Rivale legt ein konkretes Angebot auf den Tisch —
# mitbieten, an die gemeinsame Geschichte appellieren oder ziehen lassen.
func _rival_poach_event(rival: Dictionary, c: Dictionary) -> Dictionary:
	var rid := str(rival.id)
	var rival_name := str(rival.name)
	var cid := int(c.id)
	var bonus := roundi(Util.ask_fee(float(c.fame), Game.state.year) * 0.06)
	var appeal_p := clampf(0.30 + float(c.loyalty) / 200.0 + float(c.trust) / 250.0 + float(Game.attr("menschenkenntnis")) / 400.0, 0.1, 0.9)
	var duel_choices: Array = []
	# Schlüsselbegegnung (Teil A3): ab POACH_SCENE_FAME wird das Duell zur
	# vollen Szene mit Emotionslage; das klassische Modal bleibt Fallback.
	if float(c.fame) >= Balance.POACH_SCENE_FAME and Dialogs.has_dialog("poach_defense"):
		duel_choices.append({"label": "Meet %s face to face — the full conversation" % Game.client_name(c),
			"dialog": "poach_defense", "ctx": {"cid": cid, "rid": rid}})
	return {"title": "Poaching attempt: %s" % Game.client_name(c),
		"text": "[i]“Half the commission, twice the attention.”[/i]\n\n%s has made %s a concrete offer — and your client is listening. Loyalty %d, mood %d: this is not a bluff." % [rival_name, Game.client_name(c), roundi(float(c.loyalty)), roundi(float(c.mood))],
		"choices": duel_choices + [
			{"label": "Match the terms (signing bonus %s)" % Util.fmt_money(bonus), "fn": func():
				var cl = Game.client(cid)
				var rv = rival_by_id(rid)
				if cl == null:
					return "The moment has passed."
				if not Game.can_spend(float(bonus)):
					return "Not even the bank fronts this bonus anymore — and everyone at the table knows it."
				Game.book(-float(bonus), "bonus", "Counter-offer: %s stays" % Game.client_name(cl))
				cl.loyalty = clampf(float(cl.loyalty) + 10.0, 0.0, 100.0)
				Game.change_trust(cl, 4.0)
				if rv != null:
					rv.grudge = clampf(float(rv.grudge) + 12.0, 0.0, 100.0)
				Game.attr_gain("verhandlung", 0.3)
				Game.press_event("Agencies", "%s outbids %s — %s stays" % [Game.state.agency.name, rival_name, Game.client_name(cl)])
				return "Money talks loudest when it arrives first. %s signs the amendment — and %s crosses a name off a list." % [Game.client_name(cl), rival_name]},
			{"label": "[👁 %d %%] Appeal to everything you built together" % roundi(appeal_p * 100.0), "fn": func():
				var cl = Game.client(cid)
				var rv = rival_by_id(rid)
				if cl == null:
					return "The moment has passed."
				if Util.chance(appeal_p):
					Game.attr_gain("menschenkenntnis", 0.4)
					cl.loyalty = clampf(float(cl.loyalty) + 6.0, 0.0, 100.0)
					cl.mood = clampf(float(cl.mood) + 4.0, 0.0, 100.0)
					return "No numbers, just history: the first casting, the first premiere, the promise you kept. %s stays." % Game.client_name(cl)
				Game.attr_gain("menschenkenntnis", 0.15)
				_client_leaves_to_rival(cl, rv)
				return "The words are right, the timing is not. %s signs across town — politely, which somehow makes it worse." % Game.client_name(cl)},
			{"label": "Let them go", "fn": func():
				var cl = Game.client(cid)
				var rv = rival_by_id(rid)
				if cl == null:
					return "The moment has passed."
				_client_leaves_to_rival(cl, rv)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 2, 0, 100)
				return "Some fights cost more than the prize. The roster is shorter — and the town takes note."},
		]}

func _client_leaves_to_rival(c: Dictionary, rival) -> void:
	Game.state.clients.erase(c)
	if rival != null:
		rival.clients.append(str(c.aid))
		Game.press_event("Client moves", "%s leaves %s for %s" % [Game.client_name(c), Game.state.agency.name, str(rival.name)])
	Game.log_msg("%s leaves the agency." % Game.client_name(c), "bad")

func rival_casting_block(studio_id: String) -> float:
	for rival in Game.state.get("rivals", []):
		if str(rival.style) == "studiotreu" and str(rival.get("studioId", "")) == studio_id and rival.clients.size():
			return clampf(8.0 + float(rival.grudge) / 12.0 - maxf(0.0, float(rival.rel)) / 20.0, 4.0, 16.0)
	return 0.0

