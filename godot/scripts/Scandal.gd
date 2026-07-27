extends Node
# =====================================================================
# Skandal-System (aus Game.gd extrahiert): Geheimnisse der Klienten und
# das Gerüchte-Netzwerk — Entstehen, Verbreitung über Träger-Gruppen,
# öffentliche und Branchen-Wirkung sowie alle Gegenmaßnahmen (dementieren,
# unterdrücken, Studio-Gespräche, Gegen-Gerücht, aussitzen, verkaufen).
# Autoload "Scandal"; liest den Spielzustand über Game.state.
# =====================================================================

const SECRET_TYPES := {
	"beziehung": {"label":"Secret relationship", "topic":"affäre", "prep":"Arrange discreet meetings and a plausible cover story"},
	"gesundheit": {"label":"Health problem", "topic":"gesundheit", "prep":"Coordinate treatment and shooting breaks discreetly"},
	"wechselabsicht": {"label":"Intention to leave", "topic":"wechsel", "prep":"Improve contract and career plan early"},
	"schwangerschaft": {"label":"Pregnancy", "topic":"gesundheit", "prep":"Align a plannable break with the studios"},
	"sucht": {"label":"Addiction problem", "topic":"skandal", "prep":"Arrange a discreet clinic before the collapse"},
	"politik": {"label":"Political activities", "topic":"politik", "prep":"Prepare lawyers, foreign contacts and a public line"},
	"setkonflikt": {"label":"On-set conflict", "topic":"skandal", "prep":"Set up confidential mediation with the production"},
}

# Reichweite wird als monatliche Weitergabechance gelesen. Zuverlässigkeit
# beeinflusst, wie stark ein Gerücht beim Weitertragen an Glauben gewinnt.
const RUMOR_CARRIERS := {
	"Actors": {"reliability":0.68, "reach":0.18, "industry":0.55, "public":0.55, "interest":["affäre","wechsel","skandal"]},
	"Assistants": {"reliability":0.82, "reach":0.12, "industry":1.00, "public":0.25, "interest":["gesundheit","affäre","wechsel","politik","skandal"]},
	"Journalists": {"reliability":0.58, "reach":0.34, "industry":0.20, "public":1.15, "interest":["affäre","skandal","gesundheit","politik"]},
	"Directors": {"reliability":0.76, "reach":0.16, "industry":1.10, "public":0.20, "interest":["gesundheit","wechsel","skandal"]},
	"Studios": {"reliability":0.84, "reach":0.22, "industry":1.25, "public":0.10, "interest":["wechsel","gesundheit","politik","skandal"]},
	"Party guests": {"reliability":0.38, "reach":0.28, "industry":0.10, "public":1.05, "interest":["affäre","skandal"]},
}


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
		"beziehung": "[i]“There is someone. If the columnists find out, love becomes a headline.”[/i]",
		"gesundheit": "[i]“The doctors say I have to slow down. The studio must not know yet.”[/i]",
		"wechselabsicht": "[i]“Another agency keeps calling. I haven't said yes — but I'm thinking about it.”[/i]",
		"schwangerschaft": "[i]“I'm pregnant. I want to keep working, just not at the cost of either of us.”[/i]",
		"sucht": "[i]“I can't get through the nights alone anymore. If nobody helps, this ends in front of a rolling camera.”[/i]",
		"politik": "[i]“I attended meetings people in Washington had better not talk about.”[/i]",
		"setkonflikt": "[i]“One more shooting day with this director — and one of us walks.”[/i]",
	}
	return "%s\n\n%s entrusts you with a personal secret. Knowing early gives you the chance to prepare for the crisis." % [lines.get(type_s, "[i]“This stays between us.”[/i]"), name_s]

func reveal_secret(c: Dictionary, type_s: String = "", severity: int = 0) -> Variant:
	if type_s == "":
		var possible: Array = SECRET_TYPES.keys().filter(func(candidate): return secret_of(c, str(candidate)) == null)
		if Game.actor_by_id[c.aid].g != "f":
			possible.erase("schwangerschaft")
		if possible.is_empty():
			return null
		if int(Game.state.year) >= 1947 and int(Game.state.year) <= 1956 and possible.has("politik"):
			possible.append_array(["politik", "politik"])
		type_s = str(Util.pick(possible))
	if not SECRET_TYPES.has(type_s) or secret_of(c, type_s) != null:
		return null
	var sev: int = clampi(severity if severity > 0 else Util.rndi(1, 3), 1, 3)
	var secret := {"type":type_s, "severity":sev, "knownSince":Game.mi(), "status":"geheim"}
	c.secrets.append(secret)
	var cid: int = int(c.id)
	var prep_cost: int = roundi((1800.0 + sev * 1700.0) * Util.infl(Game.state.year))
	return {"title":"In confidence: %s" % SECRET_TYPES[type_s].label,
		"text":_secret_text(type_s, Game.client_name(c)),
		"choices":[
			{"label":"Prepare: %s (%s)" % [SECRET_TYPES[type_s].prep, Util.fmt_money(prep_cost)], "fn":func(): return prepare_secret(cid, type_s, prep_cost)},
			{"label":"Listen and promise confidentiality", "fn":func():
				var cl = Game.client(cid)
				if cl == null: return "The conversation comes too late."
				Game.change_trust(cl, 3.0)
				return "You promise nothing but discretion. %s knows this office is a safe place. (Trust +3)" % Game.client_name(cl)},
			{"label":"Sell it to the press", "fn":func(): return sell_secret(cid, type_s)},
		]}

func prepare_secret(cid: int, type_s: String, cost: int = -1) -> String:
	var c = Game.client(cid)
	if c == null:
		return "The client is no longer with the agency."
	var secret = secret_of(c, type_s)
	if secret == null:
		return "You cannot prepare for this without solid information."
	var actual_cost: int = cost if cost >= 0 else roundi((1800.0 + int(secret.severity) * 1700.0) * Util.infl(Game.state.year))
	if float(Game.state.agency.cash) < actual_cost:
		return "The discreet preparation would cost %s. The till cannot cover that yet — the secret stays protected." % Util.fmt_money(actual_cost)
	Game.book(-float(actual_cost), "pr_recht", "Discreet preparation: %s (%s)" % [SECRET_TYPES[type_s].label, Game.client_name(c)])
	secret.status = "entschärft"
	Game.record_identity("diskret", 1.0)
	Game.record_identity("klientenorientiert", 0.5)
	Game.change_trust(c, 9.0)
	c.loyalty = clampf(float(c.loyalty) + 5.0, 0.0, 100.0)
	match type_s:
		"sucht", "gesundheit":
			c.exhaustion = clampf(float(c.exhaustion) - 35.0, 0.0, 100.0)
			c.mood = clampf(float(c.mood) + 6.0, 0.0, 100.0)
		"schwangerschaft":
			c.flags["plannedLeave"] = Game.mi() + 3
		"wechselabsicht":
			c.flags["poachPreparedUntil"] = Game.mi() + 18
		"politik":
			c.flags["blacklistPreparedUntil"] = Game.mi() + 24
		"setkonflikt":
			c.flags["setMediation"] = true
	Game.log_msg("%s discreetly prepares for %s's secret." % [Game.state.agency.name, Game.client_name(c)], "deal")
	return "Lawyers, doctors and calendars work silently in the background. The eventual crisis will be much milder. (Trust +9)"

func maybe_reveal_secret(c: Dictionary, events: Array, force: bool = false) -> bool:
	var used: Array = c.get("secretThresholds", [])
	for threshold in [45, 60, 75]:
		if float(c.get("trust", 30.0)) < threshold or used.has(threshold):
			continue
		var p: float = 0.18 + float(threshold - 45) / 150.0
		if force or Util.chance(p):
			used.append(threshold)
			c.secretThresholds = used
			var ev = reveal_secret(c)
			if ev != null:
				events.append(ev)
				return true
	return false

func add_rumor(subject, text_s: String, truth: bool, topic: String, holders: Array = [], belief: float = 10.0, known: bool = false, source_secret: String = "", industry_belief: float = -1.0) -> Dictionary:
	# Backstory-Trait (Kolumnist:in): neue Gerüchte erreichen dich sofort
	if not known and Game.backstory_mod("rumor_auto_known", 0.0) > 0.0 and Util.chance(Game.backstory_mod("rumor_auto_known", 0.0)):
		known = true
	var industry_start := belief if industry_belief < 0.0 else industry_belief
	var rumor := {"id":Game.next_id(), "subject":subject, "text":text_s, "truth":truth, "topic":topic,
		"holders":holders.duplicate(), "belief":clampf(belief, 0.0, 100.0), "industryBelief":clampf(industry_start, 0.0, 100.0),
		"knownToPlayer":known, "age":0, "impactApplied":false, "industryImpactApplied":false, "sourceSecret":source_secret}
	Game.state.rumors.append(rumor)
	return rumor

func rumor_by_id(rid: int) -> Variant:
	for rumor in Game.state.get("rumors", []):
		if int(rumor.id) == rid:
			return rumor
	return null

func rumor_subject_client(rumor: Dictionary) -> Variant:
	var direct = Game.client(rumor.subject) if (rumor.subject is int or rumor.subject is float) else null
	if direct != null:
		return direct
	for c in Game.state.clients:
		if str(c.aid) == str(rumor.subject):
			return c
	return null

func rumor_subject_name(rumor: Dictionary) -> String:
	if str(rumor.subject) == "agency":
		return str(Game.state.agency.name)
	var c = rumor_subject_client(rumor)
	if c != null:
		return Game.client_name(c)
	if Game.actor_by_id.has(str(rumor.subject)):
		return str(Game.actor_by_id[str(rumor.subject)].name)
	return "Unbekannt"

func player_knows_rumor_truth(rumor: Dictionary) -> bool:
	if str(rumor.get("sourceSecret", "")) == "":
		return false
	var c = rumor_subject_client(rumor)
	return c != null and secret_of(c, str(rumor.sourceSecret)) != null

func _leak_secret(c: Dictionary, secret: Dictionary, known: bool = false, initial_belief: float = 16.0) -> Dictionary:
	secret["leaked"] = true
	var info: Dictionary = SECRET_TYPES[str(secret.type)]
	var text_s := "Around town they say the story with %s is about: %s." % [Game.client_name(c), str(info.label).to_lower()]
	return add_rumor(int(c.id), text_s, true, str(info.topic), ["Assistants"], initial_belief, known, str(secret.type))

func sell_secret(cid: int, type_s: String) -> String:
	var c = Game.client(cid)
	if c == null:
		return "There is no story in this anymore."
	var secret = secret_of(c, type_s)
	if secret == null or str(secret.status) == "publik":
		return "This story is no longer exclusive."
	var payment: int = roundi((7000.0 + int(secret.severity) * 9000.0 + float(c.fame) * 300.0) * Util.infl(Game.state.year))
	Game.book(float(payment), "pr_recht", "Exclusive story sold to the press (%s)" % Game.client_name(c))
	Game.record_identity("skrupellos", 3.0)
	secret.status = "publik"
	c.trustCap = 20.0
	c.trust = 0.0
	c.loyalty = clampf(float(c.loyalty) - 45.0, 0.0, 100.0)
	for other in Game.state.clients:
		if int(other.id) != cid:
			other.heat = clampf(float(other.heat) + 1.5, -10.0, 10.0)
	var rumor := _leak_secret(c, secret, true, 46.0)
	rumor["soldByAgency"] = true
	Game.log_msg("An intimate story about %s lands in the press." % Game.client_name(c), "bad")
	var ending := ""
	if Util.chance(0.65):
		Game.state.clients.erase(c)
		ending = " %s quits that very evening." % Game.client_name(c)
	return "The column pays %s. The trust is destroyed and permanently capped.%s" % [Util.fmt_money(payment), ending]

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
		for cl in Game.state.clients:
			Game.change_trust(cl, -7.0)
		Game.log_msg("The rumor becomes a headline. Everyone at the agency wonders who talked.", "bad")
	else:
		Game.log_msg("A rumor about %s is suddenly treated as fact in Hollywood." % rumor_subject_name(rumor), "bad")

func _apply_industry_rumor_impact(rumor: Dictionary) -> void:
	rumor.industryImpactApplied = true
	Game.log_msg("The industry now treats the rumor about %s as inside truth — headline or not." % rumor_subject_name(rumor), "bad")

func tick_rumors(events: Array = [], force_spread: bool = false) -> void:
	# Wahre Geheimnisse können unbemerkt aus dem Büro sickern.
	for c in Game.state.clients:
		for secret in c.get("secrets", []):
			if str(secret.status) != "publik" and not secret.get("leaked", false) and (force_spread or Util.chance(0.025)):
				_leak_secret(c, secret)
	# Gelegentliche Erfindungen bevorzugen bekannte Namen.
	if not force_spread and Game.state.clients.size() and Util.chance(0.035):
		var stars: Array = Game.state.clients.duplicate()
		stars.sort_custom(func(a, b): return float(a.fame) > float(b.fame))
		var target: Dictionary = Util.pick(stars.slice(0, mini(3, stars.size())))
		var topic: String = str(Util.pick(["affäre", "skandal", "wechsel", "gesundheit"]))
		add_rumor(int(target.id), "At a party someone claims something is brewing with %s — nobody has proof." % Game.client_name(target), false, topic, ["Party guests"], 12.0)

	for rumor in Game.state.rumors.duplicate():
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
			if force_spread or Util.chance(max_reach):
				rumor.holders.append(str(Util.pick(candidates)))
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
			var contact_bonus: float = minf(0.2, Game.state.favors.size() * 0.025)
			for rel in Game.state.studioRel.values():
				contact_bonus += float(rel) / maxf(1.0, Game.state.studioRel.size() * 700.0)
			if (rumor.holders.has("Assistants") and Util.chance(0.45 + contact_bonus)) or Util.chance(contact_bonus * 0.35):
				rumor.knownToPlayer = true
				events.append({"title":"A whisper in the anteroom", "text":"[i]“It is only talk so far — but you should know what people are saying about %s.”[/i]\n\n%s" % [rumor_subject_name(rumor), rumor.text], "choices":[{"label":"To the rumor dossier"}]})
		# Schlüsselbegegnung (Teil A3): wird ein WAHRES Gerücht laut genug,
		# gesteht der Klient die Geschichte dahinter — einmal pro Geheimnis.
		if bool(rumor.truth) and str(rumor.get("sourceSecret", "")) != "" and bool(rumor.knownToPlayer) and float(rumor.belief) >= Balance.CONFESSION_BELIEF:
			var confessor = rumor_subject_client(rumor)
			if confessor != null:
				var conf_secret = secret_of(confessor, str(rumor.sourceSecret))
				if conf_secret != null and not bool(conf_secret.get("confessed", false)) and Dialogs.has_dialog("crisis_confession"):
					conf_secret["confessed"] = true
					var conf_cid: int = int(confessor.id)
					events.append({"title": "A confession: %s" % Game.client_name(confessor),
						"text": "[i]“Before you read it over breakfast like everyone else — sit down. You should hear it from me.”[/i]\n\nThe rumor is getting louder, and %s wants to tell you the story behind it. The whole story." % Game.client_name(confessor),
						"choices": [
							{"label": "Hear the whole story", "dialog": "crisis_confession", "ctx": {"cid": conf_cid}},
							{"label": "Not now — the columns are waiting", "fn": func():
								var conf_cl = Game.client(conf_cid)
								if conf_cl != null:
									Game.change_trust(conf_cl, -4.0)
								return "The door closes softly. Some conversations do not offer themselves twice."}]})
		if float(rumor.belief) >= 60.0 and not rumor.get("impactApplied", false):
			_apply_rumor_impact(rumor)
		if float(rumor.industryBelief) >= 60.0 and not rumor.get("industryImpactApplied", false):
			_apply_industry_rumor_impact(rumor)
		if int(rumor.age) > 6 and maxf(float(rumor.belief), float(rumor.industryBelief)) < 8.0:
			Game.state.rumors.erase(rumor)

func rumor_fit_penalty(c: Dictionary) -> float:
	var penalty := 0.0
	for rumor in Game.state.get("rumors", []):
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
		return "The rumor has already dried up."
	if bool(rumor.truth) and Util.chance(0.45):
		rumor.belief = clampf(float(rumor.belief) + 28.0, 0.0, 100.0)
		var c = rumor_subject_client(rumor)
		if c != null:
			c.mood = clampf(float(c.mood) - 8.0, 0.0, 100.0)
		return "The denial crumbles under questioning. Now the story looks twice as credible."
	# Medienstrategie (Feature 6): Freunde bei der Presse tragen Dementis weiter
	var extra := 10.0 if Mogul.has_ability("press_pal") else 0.0
	rumor.belief = maxf(0.0, float(rumor.belief) - (24.0 if not bool(rumor.truth) else 10.0) - extra)
	Mogul.grant_xp("media", 1.0, "Issued a denial")
	Mogul.grant_xp("crisis", 1.0, "Handled a story")
	return "The explanation lands. For the moment the rumor loses its pull."

func suppress_rumor(rid: int) -> String:
	var rumor = rumor_by_id(rid)
	if rumor == null:
		return "The story has already vanished."
	var used_favor := false
	used_favor = Game.consume_favor("suppressStory")
	# Krisenmanagement (Feature 6): der Spin-Doctor kennt die halbe Preisliste
	var cost: int = roundi(12000.0 * Util.infl(Game.state.year) * (0.5 if Mogul.has_ability("spin_doctor") else 1.0))
	if not used_favor:
		if float(Game.state.agency.cash) < cost:
			return "No matching favor — and the till is short the %s they ask for." % Util.fmt_money(cost)
		Game.book(-float(cost), "pr_recht", "Rumor suppressed: %s" % rumor_subject_name(rumor))
	Game.record_identity("diskret", 1.5)
	Game.attr_gain("diskretion", 0.5)
	Mogul.grant_xp("crisis", 2.0, "Buried a story")
	Mogul.grant_xp("media", 1.0, "Buried a story")
	rumor.belief = maxf(0.0, float(rumor.belief) - 38.0)
	rumor.holders = rumor.holders.filter(func(h): return str(h) not in ["Journalists", "Party guests"])
	if rumor.holders.is_empty():
		rumor.holders = ["Assistants"]
	return "One phone call, one favor returned, one drawer closed. The story loses almost all of its reach."

func studio_talk_rumor(rid: int) -> String:
	var rumor = rumor_by_id(rid)
	if rumor == null:
		return "Nobody at the studios remembers the story anymore."
	var paid_with_favor := Game.consume_any_favor()
	var cost := roundi(9000.0 * Util.infl(Game.state.year))
	if not paid_with_favor:
		if float(Game.state.agency.cash) < float(cost):
			return "Discreet studio talks require a favor or %s." % Util.fmt_money(cost)
		Game.book(-float(cost), "pr_recht", "Discreet studio talks: %s" % rumor_subject_name(rumor))
	rumor.industryBelief = maxf(0.0, float(rumor.get("industryBelief", 0.0)) - 34.0)
	rumor.holders = rumor.holders.filter(func(h): return str(h) not in ["Studios", "Directors"])
	if rumor.holders.is_empty():
		rumor.holders = ["Assistants"]
	Game.record_identity("diskret", 1.0)
	Game.record_identity("studiotreu", 0.5)
	Game.attr_gain("diskretion", 0.3)
	return "Behind closed doors, facts, guarantees and old debts get sorted. The industry becomes far more skeptical of the rumor."

func counter_rumor(rid: int) -> String:
	var rumor = rumor_by_id(rid)
	if rumor == null:
		return "It is too late for that."
	var cost: int = roundi(5000.0 * Util.infl(Game.state.year))
	if float(Game.state.agency.cash) < cost:
		return "The campaign would cost %s. The till will not cover it." % Util.fmt_money(cost)
	Game.book(-float(cost), "pr_recht", "Counter-rumor campaign: %s" % rumor_subject_name(rumor))
	# Medienstrategie (Feature 6): wer das Narrativ führt, trifft härter & bleibt unerkannt
	var control := Mogul.has_ability("narrative_control")
	rumor.belief = maxf(0.0, float(rumor.belief) - (32.0 if control else 20.0))
	Mogul.grant_xp("media", 2.0, "Ran a counter-campaign")
	if Util.chance(0.06 if control else 0.12):
		for c in Game.state.clients:
			Game.change_trust(c, -2.0)
		return "The counter-rumor works — but a reporter recognizes your handwriting. Trust in the house takes a scratch."
	return "A more interesting story takes over the cocktail parties. This rumor slips out of the limelight."

func wait_out_rumor(rid: int) -> String:
	var rumor = rumor_by_id(rid)
	if rumor == null:
		return "The rumor is already forgotten."
	rumor["waitingOut"] = true
	return "No press conference, no fuel. You bet on Hollywood finding a new obsession tomorrow."

func rumor_targets() -> Array:
	var targets: Array = Game.pool_actors().filter(func(a): return not Game.is_client(str(a.id)))
	targets.sort_custom(func(a, b):
		var ar := 1 if Rivals.is_rival_client(str(a.id)) else 0
		var br := 1 if Rivals.is_rival_client(str(b.id)) else 0
		return ar > br if ar != br else Util.fame_at(a, Game.state.year) > Util.fame_at(b, Game.state.year))
	return targets

func launch_rumor(actor_id: String, topic: String = "skandal") -> String:
	if not Game.actor_by_id.has(actor_id) or Game.is_client(actor_id):
		return "The target is no good for this campaign."
	var actor: Dictionary = Game.actor_by_id[actor_id]
	var owner = Rivals.rival_for_actor(actor_id)
	# Hinterzimmer (Feature 8): eine Schmutzkampagne gegen ein geschütztes Haus bricht den Pakt
	Mogul.on_launch_rumor(owner)
	var text_s := "In the anterooms they say there is a story about %s that nobody wants to print yet." % actor.name
	var rumor := add_rumor(actor_id, text_s, false, topic, ["Assistants", "Party guests"], 14.0, true, "", 20.0)
	rumor["launchedByAgency"] = true
	Game.record_identity("skrupellos", 2.0)
	var exposure: float = clampf(0.34 - Game.identity_strength("skrupellos") * 0.10, 0.12, 0.45)
	if Util.chance(exposure):
		rumor["agencyExposed"] = true
		Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 5, 0, 100)
		for c in Game.state.clients:
			Game.change_trust(c, -5.0)
		Game.record_identity("skrupellos", 2.0)
		if owner != null:
			owner.grudge = clampf(float(owner.grudge) + 18.0, 0.0, 100.0)
		Game.press_event("Scandal", "Smear campaign exposed: the trail leads to %s" % Game.state.agency.name)
		return "The rumor is out — but an assistant recognizes your handwriting. Reputation and client trust suffer."
	return "A subordinate clause here, an anonymous note there. The rumor is in the web, and for now nobody knows its author."

