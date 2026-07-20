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
		{"id":"favor",        "cd":8,  "weight": _w_favor,        "build": _b_favor},
		{"id":"press",        "cd":8,  "weight": _w_press,        "build": _b_press},
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
	return Game.pick(hits) if hits.size() else null

func _nm(c) -> String:
	return Game.client_name(c)

func _fmt(v) -> String:
	return Game.fmt_money(v)

func _rel(sid: String, delta: int) -> void:
	Game.state.studioRel[sid] = clampi(int(Game.state.studioRel[sid]) + delta, 0, 100)

func _dna(c, key: String, delta: float) -> void:
	c.dna[key] = clampf(c.dna[key] + delta, -100.0, 100.0)

# ---------- 0. Der Anruf um drei Uhr morgens ----------
func _w_call3am() -> float:
	return 1.2 if _free_clients().any(func(c): return c.fame >= 30) else 0.0

func _b_call3am() -> Dictionary:
	var c = Game.pick(_free_clients().filter(func(x): return x.fame >= 30))
	var studio = Game.pick(Game.active_studios())
	var fee = roundi(Game.ask_fee(c.fame, Game.state.year) * 1.1)
	return {"title": "Der Anruf um drei Uhr morgens",
		"text": "[i]„Unser Hauptdarsteller liegt im Krankenhaus. Drehbeginn ist übermorgen. Kann %s einspringen? Ja oder nein — jetzt.“[/i]\n\n%s bietet eine Hauptrolle. Gage: ca. %s. Aber: keine Vorbereitung, sofortiger Drehbeginn." % [_nm(c), studio.name, _fmt(fee)],
		"choices": [
			{"label": "Sofort zusagen", "fn": func():
				var r = Game.quick_production(c, {"studio": studio, "feeMult": 1.1})
				c.exhaustion = clampf(c.exhaustion + 30.0, 0.0, 100.0)
				c.heat = clampf(c.heat + 4.0, -10.0, 10.0)
				_dna(c, "verlass", 6.0)
				if Game.chance(0.7):
					c.fame = clampf(c.fame + 3.0, 5.0, 100.0)
					return "%s steht 36 Stunden später vor der Kamera. Die Branche redet über diesen Einsatz. (+%s Provision, Erschöpfung steigt stark)" % [_nm(c), _fmt(r.income)]
				c.mood = clampf(c.mood - 6.0, 0.0, 100.0)
				return "%s springt ein, wirkt aber sichtlich unvorbereitet. Das Geld stimmt (%s Provision), der Glanz weniger." % [_nm(c), _fmt(r.income)]},
			{"label": "Höhere Gage verlangen", "fn": func():
				if Game.chance(0.55):
					var r = Game.quick_production(c, {"studio": studio, "feeMult": 1.6})
					c.exhaustion = clampf(c.exhaustion + 30.0, 0.0, 100.0)
					c.heat = clampf(c.heat + 5.0, -10.0, 10.0)
					c.fame = clampf(c.fame + 3.0, 5.0, 100.0)
					return "„In Ordnung, verdammt. Aber der Wagen steht in einer Stunde vor der Tür.“ — %s Gage, %s Provision. Ein Coup." % [_fmt(r.fee), _fmt(r.income)]
				_rel(studio.id, -2)
				return "Schweigen am anderen Ende. Dann: „Wir haben jemand anderen.“ Die Chance ist vertan."},
			{"label": "Ablehnen", "fn": func():
				_rel(studio.id, -4)
				c.mood = clampf(c.mood + 4.0, 0.0, 100.0)
				return "%s schläft weiter. %s vergisst so etwas nicht — aber dein Klient weiß, dass du ihn nicht verheizt." % [_nm(c), studio.name]},
		]}

# ---------- 1. Das geleakte Vorsprechen ----------
func _w_leak() -> float:
	return 1.0 if Game.state.clients.size() else 0.0

func _b_leak() -> Dictionary:
	var c = Game.random_client()
	var cost = roundi(12000.0 * Game.infl(Game.state.year))
	var has_pr: bool = c.perks.has("pr")
	var choices: Array = [
		{"label": "Juristisch vorgehen (%s)" % _fmt(cost), "fn": func():
			Game.book(-float(cost), "pr_recht", "Anwälte: Leak-Band einkassieren (%s)" % _nm(c))
			c.mood = clampf(c.mood + 5.0, 0.0, 100.0)
			return "Die Anwälte kassieren jede Kopie ein. Teuer, aber das Image ist geschützt."},
		{"label": "Selbstironisch veröffentlichen", "fn": func():
			if Game.chance(0.75 if has_pr else 0.55):
				c.heat = clampf(c.heat + 4.0, -10.0, 10.0)
				c.fame = clampf(c.fame + 2.0, 5.0, 100.0)
				_dna(c, "familie", 4.0)
				return "Der Gag zündet: %s gilt plötzlich als nahbar und humorvoll. Die Stadt liebt es." % _nm(c)
			c.fame = clampf(c.fame - (1.0 if has_pr else 3.0), 5.0, 100.0)
			return "Der Humor kommt nicht überall an. Ein paar Spötter bleiben — halb so wild, aber unschön."},
		{"label": "Ignorieren", "fn": func():
			if Game.chance(0.85 if has_pr else 0.65):
				return "Nach zwei Wochen redet niemand mehr darüber. Richtig gepokert."
			c.heat = clampf(c.heat - 2.0, -10.0, 10.0)
			return "Das Band hält sich hartnäckiger als gedacht. %s verliert etwas Momentum." % _nm(c)},
	]
	if Game.has_favor("suppressStory"):
		choices.insert(0, {"label": "Gefallen einlösen: Das Band verschwinden lassen", "fn": func():
			Game.consume_favor("suppressStory")
			c.mood = clampf(c.mood + 4.0, 0.0, 100.0)
			return "Ein Anruf bei einem alten Freund aus der Klatschspalte — und alle Kopien des Bands verschwinden. Die Stadt lacht schon über etwas anderes."})
	return {"title": "Das geleakte Vorsprechen",
		"text": "[i]„Haben Sie das Band gesehen? Ganz Hollywood lacht.“[/i]\n\nEine peinliche Aufnahme vom Vorsprechen von %s kursiert in der Branche.%s" % [_nm(c), " Deine PR-Betreuung dämpft den Schaden bereits." if has_pr else ""],
		"choices": choices}

# ---------- 2. Ein neuer Name für einen neuen Star ----------
func _w_rename() -> float:
	var cand = Game.state.clients.filter(func(c): return c.fame < 50)
	return (1.2 if Game.state.year < 1970 else 0.5) if cand.size() else 0.0

func _b_rename() -> Dictionary:
	var c = Game.random_client(func(x): return x.fame < 50)
	var cost = roundi(8000.0 * Game.infl(Game.state.year))
	return {"title": "Ein neuer Name für einen neuen Star",
		"text": "[i]„%s? Das kann doch kein Mensch aussprechen. Wir dachten an etwas … Verkäuflicheres.“[/i]\n\nDas Studio hält den Namen deines Klienten für schwer vermarktbar." % _nm(c),
		"choices": [
			{"label": "Umbenennung akzeptieren", "fn": func():
				c.fame = clampf(c.fame + 4.0, 5.0, 100.0)
				c.mood = clampf(c.mood - 10.0, 0.0, 100.0)
				_dna(c, "unikat", -6.0)
				return "Der neue Name prangt bald auf Plakaten. Die Vermarktung greift — aber %s fühlt sich wie eine Ware." % _nm(c)},
			{"label": "Den Namen verteidigen", "fn": func():
				c.loyalty = clampf(c.loyalty + 10.0, 0.0, 100.0)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 2, 0, 100)
				_dna(c, "unikat", 5.0)
				_rel(Game.pick(Game.active_studios()).id, -4)
				return "„Der Name bleibt.“ %s wird dir das nie vergessen — das Studio schon eher." % _nm(c)},
			{"label": "Kompromiss: Künstlername (%s PR)" % _fmt(cost), "fn": func():
				Game.book(-float(cost), "pr_recht", "PR-Kampagne: Künstlername für %s" % _nm(c))
				c.fame = clampf(c.fame + 2.0, 5.0, 100.0)
				c.mood = clampf(c.mood - 3.0, 0.0, 100.0)
				return "Ein Künstlername für die Plakate, der echte Name für die Freunde. Alle können damit leben."},
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
		{"label": "Klienten öffentlich verteidigen", "fn": func():
			c.loyalty = clampf(c.loyalty + 12.0, 0.0, 100.0)
			_rel(prod.studioId, -6)
			prod.qualityMod = prod.get("qualityMod", 0.0) - 3.0
			_dna(c, "verlass", -4.0)
			return "Du stellst dich vor die Presse und hinter deinen Klienten. %s bleibt — die Stimmung am Set bleibt frostig." % _nm(c)},
		{"label": "Hinter verschlossenen Türen vermitteln", "fn": func():
			var p = clampf(0.35 + Game.state.agency.rep / 200.0 + minf(0.15, Game.state.favors.size() * 0.03), 0.2, 0.9)
			if Game.chance(p):
				c.loyalty = clampf(c.loyalty + 5.0, 0.0, 100.0)
				prod.qualityMod = prod.get("qualityMod", 0.0) + 3.0
				Game.grant_favor("scriptAccess", {"type": "regisseur", "name": str(Game.pick(Game.FAVOR_CONTACTS.regisseur))})
				return "Zwei Stunden, eine Flasche Whiskey, ein Handschlag. Der Dreh geht weiter — besser als zuvor. Und der Regisseur schuldet dir jetzt etwas."
			c.mood = clampf(c.mood - 5.0, 0.0, 100.0)
			return "Der Waffenstillstand hält, aber die Atmosphäre bleibt vergiftet. Immerhin: Der Film wird fertig."},
		{"label": "Vertragsauflösung zustimmen", "fn": func():
			var sev = roundi(fee * 0.5)
			Game.book(float(roundi(sev * c.commission / 100.0)), "abfindung", "Abfindung Vertragsauflösung: %s („%s“)" % [_nm(c), prod.title])
			c.fame = clampf(c.fame - 4.0, 5.0, 100.0)
			c.busyUntil = Game.mi()
			c.mood = clampf(c.mood - 8.0, 0.0, 100.0)
			_dna(c, "verlass", -8.0)
			for r in prod.roles:
				if r.filled != null and r.filled.get("clientId") != null and int(r.filled.clientId) == int(c.id):
					r.filled = {"npc": true, "name": "Ersatzbesetzung", "talent": 55, "fame": 30}
			return "Abfindung: %s (deine Provision: %s). %s ist wieder frei — aber die Branche registriert den Rauswurf." % [_fmt(sev), _fmt(sev * c.commission / 100.0), _nm(c)]},
	]
	if Game.has_favor("extraAudition") or Game.has_favor("scriptAccess"):
		choices.insert(1, {"label": "Gefallen einfordern: Der Regisseur lenkt ein", "fn": func():
			if Game.consume_favor("scriptAccess") or Game.consume_favor("extraAudition"):
				c.loyalty = clampf(c.loyalty + 6.0, 0.0, 100.0)
				prod.qualityMod = prod.get("qualityMod", 0.0) + 3.0
				return "Eine gemeinsame Vergangenheit ist in dieser Stadt eine stolze Währung. Der Regisseur lächelt, entschuldigt sich bei %s — der Dreh läuft weiter." % _nm(c)
			return "Der passende Gefallen war bereits verbraucht."})
	return {"title": "Der Regisseur will deinen Klienten loswerden",
		"text": "[i]„Entweder %s verlässt mein Set, oder ich.“[/i]\n\nNach einem heftigen Streit bei „%s“ fordert der Regisseur eine Neubesetzung." % [_nm(c), prod.title],
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
	var rival_name := str(rival.name) if rival != null else "eine große Konkurrenz-Agentur"
	var prepared := Game.has_mitigated_secret(c, "wechselabsicht")
	var cost = roundi(c.fame * (540.0 if prepared else 900.0) * Game.infl(Game.state.year))
	return {"title": "Die Abwerbung",
		"text": "[i]„Bei uns wären Sie kein Klient. Sie wären DER Klient.“[/i]\n\n%s umgarnt deinen wertvollsten Namen: %s (Loyalität %d/100).%s" % [rival_name, _nm(c), roundi(c.loyalty), "\n\n[color=#7da05c]Du wusstest von den Wechselgedanken. Vertrag, Argumente und Budget liegen bereits bereit.[/color]" if prepared else ""],
		"choices": [
			{"label": "Finanziell übertreffen (%s)" % _fmt(cost), "fn": func():
				Game.book(-float(cost), "bonus", "Loyalitäts-Prämie: %s" % _nm(c))
				c.loyalty = clampf(c.loyalty + 15.0, 0.0, 100.0)
				c.mood = clampf(c.mood + 5.0, 0.0, 100.0)
				Game.change_trust(c, 6.0 if prepared else 3.0)
				if rival != null:
					rival.grudge = clampf(float(rival.grudge) + 14.0, 0.0, 100.0)
					rival.rel = clampf(float(rival.rel) - 8.0, -100.0, 100.0)
				return "Ein besseres Auto, eine bessere Suite, ein besserer Vertrag. %s bleibt – Loyalität kann man mieten." % _nm(c)},
			{"label": "Mit Erfolgen und Loyalität argumentieren", "fn": func():
				var wins = c.films.filter(func(f): return f.verdict == "Hit" or f.verdict == "Blockbuster").size()
				var p = clampf(c.loyalty / 100.0 + wins * 0.08 + Game.state.agency.rep / 300.0 + (0.28 if prepared else 0.0), 0.2, 0.98)
				if Game.chance(p):
					c.loyalty = clampf(c.loyalty + 8.0, 0.0, 100.0)
					Game.change_trust(c, 8.0 if prepared else 3.0)
					if rival != null:
						rival.grudge = clampf(float(rival.grudge) + 18.0, 0.0, 100.0)
						rival.rel = clampf(float(rival.rel) - 10.0, -100.0, 100.0)
					return "„Ich weiß, wem ich meine Karriere verdanke.“ %s sagt ab — aus Überzeugung." % _nm(c)
				if rival_id != "":
					Game.rival_poach_client(rival_id, c)
				else:
					Game.state.clients.erase(c)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 4, 0, 100)
				Game.log_msg("%s wechselt zu %s." % [_nm(c), rival_name], "bad")
				return "Die Argumente reichen nicht. %s unterschreibt woanders — ein schwerer Schlag." % _nm(c)},
			{"label": "Ziehen lassen", "fn": func():
				if rival_id != "":
					Game.rival_poach_client(rival_id, c)
				else:
					Game.state.clients.erase(c)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 3, 0, 100)
				Game.log_msg("%s verlässt die Agentur Richtung %s." % [_nm(c), rival_name], "info")
				return "Kein Bieterkrieg. Man trennt sich höflich — der Ruf leidet ein wenig, die Kasse nicht."},
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
	return {"title": "Zwei Klienten, eine Rolle",
		"text": "Ein Studio sucht die Hauptrolle für einen großen Film — und sowohl %s (Ruhm %d) als auch %s (Ruhm %d) sind im Gespräch. Beide erwarten deine volle Unterstützung." % [_nm(star), roundi(star.fame), _nm(up), roundi(up.fame)],
		"choices": [
			{"label": "%s unterstützen (sicher)" % _nm(star), "fn": func():
				var r = Game.quick_production(star, {})
				up.loyalty = clampf(up.loyalty - 8.0, 0.0, 100.0)
				up.mood = clampf(up.mood - 8.0, 0.0, 100.0)
				return "%s bekommt die Rolle (%s Provision). %s lächelt beim nächsten Treffen etwas dünner." % [_nm(star), _fmt(r.income), _nm(up)]},
			{"label": "%s fördern (riskant)" % _nm(up), "fn": func():
				star.mood = clampf(star.mood - 6.0, 0.0, 100.0)
				if Game.chance(0.6):
					var r = Game.quick_production(up, {})
					up.fame = clampf(up.fame + 5.0, 5.0, 100.0)
					up.loyalty = clampf(up.loyalty + 14.0, 0.0, 100.0)
					return "Du kämpfst für den Nachwuchs — und gewinnst. %s bekommt die Rolle (%s Provision) und wird dir das nie vergessen." % [_nm(up), _fmt(r.income)]
				up.loyalty = clampf(up.loyalty + 6.0, 0.0, 100.0)
				return "Das Studio besetzt am Ende extern. Kein Deal — aber %s hat gesehen, dass du an ihn glaubst." % _nm(up)},
			{"label": "Neutral bleiben", "fn": func():
				star.mood = clampf(star.mood - 4.0, 0.0, 100.0)
				up.mood = clampf(up.mood - 4.0, 0.0, 100.0)
				return "Du hältst dich raus, das Studio entscheidet extern. Fair — aber beide hätten sich mehr Einsatz gewünscht."},
		]}

# ---------- 6. Die Rolle wurde herausgeschnitten ----------
func _w_cutrole() -> float:
	return 0.8 if _in_production() != null else 0.0

func _b_cutrole() -> Dictionary:
	var hit = _in_production()
	var c = hit.c
	var prod = hit.prod
	var fee = hit.role.filled.get("fee", 100000)
	return {"title": "Die Rolle wurde herausgeschnitten",
		"text": "Nach einer desaströsen Testvorführung von „%s“ fällt fast die gesamte Rolle von %s der Schere zum Opfer." % [prod.title, _nm(c)],
		"choices": [
			{"label": "Nachdrehs verlangen", "fn": func():
				var p = clampf(c.fame / 120.0 + int(c.get("awards", 0)) * 0.1 + Game.state.studioRel[prod.studioId] / 250.0, 0.15, 0.85)
				if Game.chance(p):
					prod.qualityMod = prod.get("qualityMod", 0.0) + 4.0
					prod.monthsLeft = int(prod.monthsLeft) + 1
					return "Das Studio knickt ein: Nachdrehs werden angesetzt. Die Rolle bleibt — der Film wird sogar besser."
				c.mood = clampf(c.mood - 5.0, 0.0, 100.0)
				return "„Der Schnitt steht.“ Immerhin hast du es versucht — %s weiß das." % _nm(c)},
			{"label": "Zusätzliche Vergütung aushandeln", "fn": func():
				var extra = roundi(fee * 0.3)
				Game.book(float(roundi(extra * c.commission / 100.0)), "provision", "Nachschlag Schnitt-Konflikt: %s („%s“)" % [_nm(c), prod.title])
				c.mood = clampf(c.mood - 3.0, 0.0, 100.0)
				return "Geld statt Sichtbarkeit: %s Nachschlag (%s Provision). Kein Ruhm, aber Ruhe." % [_fmt(extra), _fmt(extra * c.commission / 100.0)]},
			{"label": "Den Konflikt öffentlich machen", "fn": func():
				c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
				_rel(prod.studioId, -8)
				_dna(c, "familie", -4.0)
				return "„Studio verstümmelt Film!“ — Die Presse liebt den Streit, %s ist Stadtgespräch. Das Studio tobt." % _nm(c)},
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
	return {"title": "Der gefährliche Stunt",
		"text": "[i]„Das Publikum merkt den Unterschied. Wir wollen, dass %s selbst springt.“[/i]\n\nDie Produktion von „%s“ verlangt einen riskanten Stunt ohne Double." % [_nm(c), prod.title],
		"choices": [
			{"label": "Zustimmen", "fn": func():
				if Game.chance(0.7):
					c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
					c.fame = clampf(c.fame + 2.0, 5.0, 100.0)
					prod.qualityMod = prod.get("qualityMod", 0.0) + 2.0
					return "Der Stunt sitzt beim ersten Take. Die Set-Fotos gehen um die Welt."
				c.exhaustion = clampf(c.exhaustion + 25.0, 0.0, 100.0)
				prod.monthsLeft = int(prod.monthsLeft) + 1
				return "Der Sprung geht schief — Prellungen, Drehpause, Schrecken. %s erholt sich, aber der Plan wackelt." % _nm(c)},
			{"label": "Stuntdouble verlangen", "fn": func():
				_rel(prod.studioId, -2)
				Game.record_identity("klientenorientiert", 2.0)
				return "Das Double übernimmt. Der Regisseur murrt, dein Klient bleibt heil. Genau dafür wirst du bezahlt."},
			{"label": "Gefahrenzulage & Versicherung aushandeln", "fn": func():
				var extra = roundi(Game.ask_fee(c.fame, Game.state.year) * 0.2)
				Game.book(float(roundi(extra * c.commission / 100.0)), "provision", "Gefahrenzulage: %s („%s“)" % [_nm(c), prod.title])
				c.exhaustion = clampf(c.exhaustion + 10.0, 0.0, 100.0)
				if Game.consume_favor("billing") or Game.consume_favor("extraAudition"):
					return "%s springt — gegen %s Zulage. Ein eingelöster Gefallen beim Produktionsleiter glättet die Wogen." % [_nm(c), _fmt(extra)]
				_rel(prod.studioId, -2)
				return "%s springt — gegen %s Zulage. Das harte Feilschen hinterlässt beim Studio einen säuerlichen Nachgeschmack." % [_nm(c), _fmt(extra)]},
		]}

# ---------- 8. Die Franchise-Falle ----------
func _w_franchise() -> float:
	var cand = _free_clients().filter(func(c): return c.fame >= 55 and not c.flags.get("typecast", false))
	return (1.1 if Game.state.year >= 1977 else 0.5) if cand.size() else 0.0

func _b_franchise() -> Dictionary:
	var c = Game.pick(_free_clients().filter(func(x): return x.fame >= 55 and not x.flags.get("typecast", false)))
	var fee = roundi(Game.ask_fee(c.fame, Game.state.year) * 2.0)
	return {"title": "Die Franchise-Falle",
		"text": "[i]„Fünf Filme. Eine Figur. Ihr Klient wird unsterblich — als genau diese eine Rolle.“[/i]\n\nEin Studio bietet %s einen Vertrag über fünf Fortsetzungen. Vorab-Garantie: %s." % [_nm(c), _fmt(fee)],
		"choices": [
			{"label": "Sofort unterschreiben", "fn": func():
				Game.book(float(roundi(fee * c.commission / 100.0)), "provision", "Franchise-Vorabgarantie: %s" % _nm(c))
				c.fame = clampf(c.fame + 6.0, 5.0, 100.0)
				c.heat = clampf(c.heat + 4.0, -10.0, 10.0)
				c.flags["typecast"] = true
				c.busyUntil = Game.mi() + 4
				_dna(c, "unikat", -12.0)
				_dna(c, "popular", 8.0)
				Game.record_identity("kommerziell", 2.0)
				return "Unterschrift, Scheck, Schlagzeile: %s Provision sofort. Aber von nun an sehen alle nur noch die eine Figur (Typecasting)." % _fmt(fee * c.commission / 100.0)},
			{"label": "Weniger Filme, höhere Gage fordern", "fn": func():
				if Game.chance(0.5):
					var f2 = roundi(fee * 0.75)
					Game.book(float(roundi(f2 * c.commission / 100.0)), "provision", "Franchise-Deal (3 Filme): %s" % _nm(c))
					c.fame = clampf(c.fame + 5.0, 5.0, 100.0)
					c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
					c.busyUntil = Game.mi() + 4
					_dna(c, "popular", 5.0)
					return "Drei Filme statt fünf, dafür fürstlich bezahlt: %s (%s Provision) — ohne Typecasting-Klausel. Meisterhaft verhandelt." % [_fmt(f2), _fmt(f2 * c.commission / 100.0)]
				return "Das Studio winkt ab: „Fünf oder keiner.“ Der Deal platzt — aber niemand verliert das Gesicht."},
			{"label": "Ablehnen", "fn": func():
				c.loyalty = clampf(c.loyalty + 6.0, 0.0, 100.0)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 2, 0, 100)
				_dna(c, "unikat", 4.0)
				return "„Mein Klient ist Schauspieler, keine Actionfigur.“ Die Branche nickt anerkennend."},
		]}

# ---------- 9. Das Herzensprojekt ----------
func _w_passion() -> float:
	return 0.9 if _free_clients().size() else 0.0

func _b_passion() -> Dictionary:
	var c = Game.pick(_free_clients())
	var invest = roundi(30000.0 * Game.infl(Game.state.year))
	return {"title": "Das Herzensprojekt",
		"text": "[i]„Es zahlt fast nichts, ich weiß. Aber dieses Drehbuch — so etwas kommt einmal im Leben.“[/i]\n\n%s will unbedingt in einem kleinen, künstlerischen Film mitspielen." % _nm(c),
		"choices": [
			{"label": "Unterstützen", "fn": func():
				Game.quick_production(c, {"feeMult": 0.15, "prestige": 3, "genre": "drama"})
				c.loyalty = clampf(c.loyalty + 12.0, 0.0, 100.0)
				c.mood = clampf(c.mood + 10.0, 0.0, 100.0)
				Game.record_identity("kuenstlerisch", 2.0)
				Game.record_identity("klientenorientiert", 1.0)
				return "Kaum Gage, viel Herz. %s strahlt — und Prestige-Filme haben schon manche Karriere neu erfunden." % _nm(c)},
			{"label": "Davon abraten", "fn": func():
				c.mood = clampf(c.mood - 8.0, 0.0, 100.0)
				return "„Kunst zahlt keine Provision.“ %s fügt sich — mit hörbarem Zähneknirschen." % _nm(c)},
			{"label": "Als Agentur mitfinanzieren (%s)" % _fmt(invest), "fn": func():
				Game.book(-float(invest), "investition", "Beteiligung Herzensprojekt: %s" % _nm(c))
				Game.quick_production(c, {"feeMult": 0.15, "prestige": 3, "genre": "drama", "qualityMod": 5.0})
				Game.record_identity("kuenstlerisch", 3.0)
				c.loyalty = clampf(c.loyalty + 15.0, 0.0, 100.0)
				if Game.chance(0.35):
					Game.book(float(invest * 4), "investition", "Rückfluss Herzensprojekt: %s" % _nm(c))
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 4, 0, 100)
					return "Du steigst als Produzent ein — und der Film wird ein Phänomen: %s Rückfluss plus Prestige." % _fmt(invest * 4)
				return "Du steigst als Produzent ein. Ob sich das rechnet, zeigt die Premiere — %s jedenfalls ist dir treu ergeben." % _nm(c)},
		]}

# ---------- 11. Der Paketdeal ----------
func _w_package() -> float:
	var stars = _free_clients().filter(func(c): return c.fame >= 60)
	var ups = _free_clients().filter(func(c): return c.fame < 40)
	return 0.9 if (stars.size() and ups.size()) else 0.0

func _b_package() -> Dictionary:
	var star = Game.pick(_free_clients().filter(func(c): return c.fame >= 60))
	var up = Game.pick(_free_clients().filter(func(c): return c.fame < 40))
	var studio = Game.pick(Game.active_studios())
	return {"title": "Der Paketdeal",
		"text": "%s will unbedingt %s für einen großen Film. Deine Chance, auch den unbekannten %s im Gepäck unterzubringen — oder mehr zu fordern." % [studio.name, _nm(star), _nm(up)],
		"choices": [
			{"label": "Beide als Paket anbieten", "fn": func():
				_rel(studio.id, -3)
				if Game.chance(0.7):
					var r1 = Game.quick_production(star, {"studio": studio})
					var r2 = Game.quick_production(up, {"studio": studio, "roleType": "support"})
					up.fame = clampf(up.fame + 6.0, 5.0, 100.0)
					return "Das Studio schluckt die Kröte: beide sind besetzt (%s Provision gesamt). %s bekommt die Bühne seines Lebens." % [_fmt(r1.income + r2.income), _nm(up)]
				var r1 = Game.quick_production(star, {"studio": studio})
				return "„Den Star nehmen wir. Den Anhang nicht.“ Immerhin: %s ist besetzt (%s Provision)." % [_nm(star), _fmt(r1.income)]},
			{"label": "Nur den Star vermitteln", "fn": func():
				var r = Game.quick_production(star, {"studio": studio})
				return "Sauberer, sicherer Abschluss: %s Gage, %s Provision. Kein Risiko, kein Bonus." % [_fmt(r.fee), _fmt(r.income)]},
			{"label": "Zusätzlich kreative Kontrolle fordern", "fn": func():
				if Game.chance(0.35):
					var r = Game.quick_production(star, {"studio": studio, "feeMult": 1.7, "qualityMod": 5.0})
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 5, 0, 100)
					Game.grant_favor("billing", {"type": "studio", "name": str(studio.name), "studioId": str(studio.id)})
					return "Final Cut, Casting-Veto, %s Gage — ein Jahrhundert-Deal. Die Branche spricht mit neuem Respekt über deine Agentur, und %s schuldet dir etwas." % [_fmt(r.fee), studio.name]
				_rel(studio.id, -3)
				return "„Kreative Kontrolle? Für einen Agenten?“ Das Studio legt auf. Der Deal ist geplatzt."},
		]}

# ---------- 12. Die vorgetäuschte Romanze ----------
func _w_romance() -> float:
	return 0.8 if Game.state.clients.size() else 0.0

func _b_romance() -> Dictionary:
	var c = Game.random_client()
	return {"title": "Die vorgetäuschte Romanze",
		"text": "[i]„Zwei Stars, ein Restaurant, ein zufällig anwesender Fotograf. Die Schlagzeilen schreiben sich von selbst.“[/i]\n\nEin PR-Berater schlägt eine inszenierte Beziehung zwischen %s und einem Co-Star vor." % _nm(c),
		"choices": [
			{"label": "Kampagne akzeptieren", "fn": func():
				c.heat = clampf(c.heat + 5.0, -10.0, 10.0)
				c.fame = clampf(c.fame + 2.0, 5.0, 100.0)
				_dna(c, "romantik", 5.0)
				if Game.chance(0.25):
					Game.state.followups.append({"type": "romanceLeak", "cid": int(c.id), "due": Game.mi() + Game.rndi(3, 7)})
				return "Die „Beziehung“ dominiert die Klatschspalten. %s ist überall — solange niemand nachfragt, wie echt das alles ist." % _nm(c)},
			{"label": "Ablehnen", "fn": func():
				c.loyalty = clampf(c.loyalty + 4.0, 0.0, 100.0)
				return "Kein Theater. %s schätzt, dass du das Privatleben nicht verkaufst." % _nm(c)},
			{"label": "Vorschlag an die Presse leaken", "fn": func():
				c.heat = clampf(c.heat + 2.0, -10.0, 10.0)
				for s in Game.active_studios().slice(0, 2):
					_rel(s.id, -3)
				return "„PR-Berater wollte Romanze faken!“ — Ein kurzer Lacher auf Kosten der Studios. Die merken sich das."},
		]}

# ---------- 13. Fotos aus der Vergangenheit ----------
func _w_photos() -> float:
	return 0.9 if Game.state.clients.any(func(c): return c.fame >= 40) else 0.0

func _b_photos() -> Dictionary:
	var c = Game.random_client(func(x): return x.fame >= 40)
	var cost = roundi((20000.0 + c.fame * 400.0) * Game.infl(Game.state.year))
	var choices: Array = [
		{"label": "Exklusivrechte kaufen (%s)" % _fmt(cost), "fn": func():
			Game.book(-float(cost), "pr_recht", "Exklusivrechte: alte Fotos von %s" % _nm(c))
			c.flags["photosSecured"] = true
			c.loyalty = clampf(c.loyalty + 8.0, 0.0, 100.0)
			return "Die Negative wandern in deinen Safe. Teuer — aber Kontrolle ist unbezahlbar."},
		{"label": "Mit ehrlichem Interview vorwegnehmen", "fn": func():
			c.flags["photosSecured"] = true
			if Game.chance(0.55):
				c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
				c.fame = clampf(c.fame + 1.0, 5.0, 100.0)
				_dna(c, "unikat", 3.0)
				return "„Ja, das war ich. Und?“ — Die Offenheit entwaffnet alle. Die Fotos sind wertlos geworden."
			c.fame = clampf(c.fame - 3.0, 5.0, 100.0)
			_dna(c, "familie", -4.0)
			return "Das Interview gerät holprig, ein paar Schlagzeilen bleiben hässlich. Aber das Thema ist durch — endgültig."},
		{"label": "Gerichtliche Verfügung beantragen", "fn": func():
			var p = clampf(0.3 + Game.state.agency.rep / 200.0 + minf(0.12, Game.state.favors.size() * 0.04), 0.2, 0.85)
			if Game.chance(p):
				c.flags["photosSecured"] = true
				return "Der Richter untersagt die Veröffentlichung. Deine Anwälte sind die besten der Stadt."
			Game.state.followups.append({"type": "photosReturn", "cid": int(c.id), "due": Game.mi() + Game.rndi(3, 8)})
			return "Der Antrag wird abgewiesen. Die Zeitung wartet ab — die Fotos schweben weiter wie ein Damoklesschwert."},
		{"label": "Aufschub erbitten (du schuldest danach einen Gefallen)", "fn": func():
			Game.owe_favor("suppressStory", Game.favor_contact_for("suppressStory"))
			c.flags["photosSecured"] = true
			return "Die Zeitung legt die Fotos auf Eis — als Investition in eure künftige Freundschaft. Irgendwann wird der Gefallen eingefordert."},
	]
	if Game.has_favor("suppressStory"):
		choices.insert(0, {"label": "Gefallen einlösen: Die Redaktion beerdigt die Story", "fn": func():
			Game.consume_favor("suppressStory")
			c.flags["photosSecured"] = true
			c.loyalty = clampf(c.loyalty + 6.0, 0.0, 100.0)
			return "Ein Anruf bei einem alten Freund im Verlag. Die Negative bleiben in der Schublade — für immer."})
	return {"title": "Fotos aus der Vergangenheit",
		"text": "[i]„Diese Aufnahmen passen nicht zum sauberen Image Ihres Klienten. Wir dachten, Sie wollen sie zuerst sehen.“[/i]\n\nEine Zeitung besitzt kompromittierende alte Fotos von %s." % _nm(c),
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
	var cost = roundi(50000.0 * Game.infl(Game.state.year))
	var choices: Array = [
		{"label": "Große Kampagne finanzieren (%s)" % _fmt(cost), "fn": func():
			Game.book(-float(cost), "pr_recht", "Oscar-Kampagne: %s" % _nm(c))
			c.campaign = 25.0
			return "Anzeigen, Screenings, Galas: Ganz Hollywood weiß jetzt, wen es zu nominieren gilt."},
		{"label": "Gefallen einfordern (Academy-Kontakte)", "fn": func():
			if Game.consume_favor("galaInvite") or Game.consume_favor("billing"):
				c.campaign = 18.0
				return "Ein paar Anrufe bei alten Freunden in der Academy. Keine Rechnung — nur ein gelöschter Gefallen."
			return "Niemand Passendes schuldet dir (mehr) etwas. Vielleicht reicht der Film ja für sich."},
		{"label": "Auf Kredit kampagnen (du schuldest danach einen Gefallen)", "fn": func():
			Game.owe_favor("galaInvite", Game.favor_contact_for("suppressStory"))
			c.campaign = 12.0
			return "Eine PR-Legende spannt ihre Kontakte an — auf Kredit. Irgendwann klingelt das Telefon, und jemand fordert eine Gegenleistung."},
		{"label": "Auf den Film vertrauen", "fn": func():
			c.campaign = 5.0
			return "Qualität setzt sich durch — manchmal. Im Februar weißt du mehr."},
	]
	if Game.state.favors.size() > 0:
		var sid: String = str(Game.state.released[0].studioId) if Game.state.released.size() else str(Game.pick(Game.active_studios()).id)
		choices.insert(2, {"label": "Gefallen dem Studio überlassen (Beziehung +)", "fn": func():
			if Game.pass_any_favor_to_studio(sid):
				c.campaign = 8.0
				return "Du überlässt deine Kontakte dem Studio — ganz Hollywood sieht, wer hier wen kennt. Die Beziehung wächst spürbar."
			return "Du hast keine offenen Gefallen, die du weitergeben könntest."})
	return {"title": "Die Oscar-Kampagne",
		"text": "%s hat mit der letzten Leistung echte Chancen auf eine Nominierung — aber ohne Kampagne sieht die Academy gern woanders hin." % _nm(c),
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
	var hit = Game.pick(candidates)
	var c = hit.c
	var prod = hit.prod
	var cost = roundi(15000.0 * Game.infl(Game.state.year))
	return {"title": "Der Zusammenbruch",
		"text": "[i]„%s ist heute nicht am Set erschienen. Das Hotel sagt, die Tür bleibt zu.“[/i]\n\nDein Klient ist am Ende der Kräfte (Erschöpfung %d/100). Die Produktion von „%s“ steht still." % [_nm(c), roundi(c.exhaustion), prod.title],
		"choices": [
			{"label": "Produktion unterbrechen lassen", "fn": func():
				prod.monthsLeft = int(prod.monthsLeft) + 1
				_rel(prod.studioId, -4)
				c.exhaustion = clampf(c.exhaustion - 35.0, 0.0, 100.0)
				c.loyalty = clampf(c.loyalty + 10.0, 0.0, 100.0)
				Game.change_trust(c, 6.0)
				Game.record_identity("klientenorientiert", 2.0)
				return "Du stellst dich vor deinen Klienten: zwei Wochen Pause, keine Diskussion. Das Studio zürnt, %s atmet auf." % _nm(c)},
			{"label": "Diskreten Arzt organisieren (%s)" % _fmt(cost), "fn": func():
				Game.record_identity("diskret", 1.5)
				Game.book(-float(cost), "events", "Diskreter Arzt: %s" % _nm(c))
				c.exhaustion = clampf(c.exhaustion - 45.0, 0.0, 100.0)
				c.mood = clampf(c.mood + 6.0, 0.0, 100.0)
				return "Ein Arzt, der keine Fragen stellt. Nach drei Tagen steht %s wieder am Set — erholt." % _nm(c)},
			{"label": "Zur Arbeit drängen", "fn": func():
				c.exhaustion = clampf(c.exhaustion + 10.0, 0.0, 100.0)
				c.loyalty = clampf(c.loyalty - 12.0, 0.0, 100.0)
				_dna(c, "verlass", -8.0)
				if Game.chance(0.35):
					prod.monthsLeft = int(prod.monthsLeft) + 2
					return "%s schleppt sich ans Set — und bricht dort erst recht zusammen. Jetzt steht alles still, und du bist schuld." % _nm(c)
				return "Die Show geht weiter. Der Zeitplan hält — aber %s wird dir diesen Anruf lange übelnehmen." % _nm(c)},
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
	Game.state.strikeMonths = Game.rndi(2, 3)
	return {"title": "Streik in Hollywood",
		"text": "Ein Arbeitskampf legt die Traumfabrik lahm: Für %d Monate ruhen Castings und Drehs. Wie positioniert sich deine Agentur?" % int(Game.state.strikeMonths),
		"choices": [
			{"label": "Streikende öffentlich unterstützen", "fn": func():
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 4, 0, 100)
				for s in Game.active_studios():
					_rel(s.id, -4)
				for c in Game.state.clients:
					c.loyalty = clampf(c.loyalty + 5.0, 0.0, 100.0)
				return "Du stellst dich an die Seite der Kreativen. Die Studios kochen — deine Klienten applaudieren."},
			{"label": "Neutral bleiben", "fn": func():
				return "Kein Statement, keine Feinde. Du wartest ab, bis sich der Staub legt."},
			{"label": "Ausnahmeregelungen für eigene Produktionen suchen", "fn": func():
				Game.state.strikeExempt = true
				Game.record_identity("studiotreu", 2.0)
				if Game.chance(0.4):
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 3, 0, 100)
					return "Deine Drehs laufen weiter — aber „Streikbrecher-Agentur“ steht trotzdem in einer Kolumne."
				return "Diskrete Anwälte, wasserdichte Alt-Verträge: Deine Produktionen laufen weiter, und niemand schreibt darüber."},
		]}

# ---------- 17. Der Tonfilm-Test (1927–1932) ----------
func _w_talkie() -> float:
	var y = int(Game.state.year)
	if y < 1927 or y > 1932:
		return 0.0
	return 2.5 if Game.state.clients.any(func(c): return Game.actor_by_id[c.aid].debut <= 1926) else 0.0

func _b_talkie() -> Dictionary:
	var c = Game.random_client(func(x): return Game.actor_by_id[x.aid].debut <= 1926)
	var cost = roundi(8000.0 * Game.infl(Game.state.year))
	return {"title": "Der Tonfilm-Test",
		"text": "[i]„Das Gesicht kennen wir. Jetzt wollen wir die Stimme hören.“[/i]\n\nDas Studio verlangt einen Sprach- und Stimmtest von %s — der Tonfilm sortiert gerade ganz Hollywood neu." % _nm(c),
		"choices": [
			{"label": "Intensives Sprachtraining buchen (%s)" % _fmt(cost), "fn": func():
				Game.book(-float(cost), "events", "Sprachtraining Tonfilm: %s" % _nm(c))
				if Game.chance(0.85):
					c.fame = clampf(c.fame + 4.0, 5.0, 100.0)
					return "Wochen mit dem besten Sprachlehrer der Westküste zahlen sich aus: Die Stimme trägt."
				c.fame = clampf(c.fame - 3.0, 5.0, 100.0)
				return "Trotz allem Training bleibt der Test durchwachsen. Aber der Wille wurde registriert."},
			{"label": "Den Test sofort absolvieren", "fn": func():
				if Game.chance(0.55):
					c.fame = clampf(c.fame + 4.0, 5.0, 100.0)
					return "Volltreffer: Die Stimme sitzt, das Studio jubelt. %s gehört zu den Gewinnern der Ton-Revolution." % _nm(c)
				c.fame = clampf(c.fame - 7.0, 5.0, 100.0)
				c.mood = clampf(c.mood - 8.0, 0.0, 100.0)
				return "Die Aufnahme ist ein Desaster. „Vielleicht … mit Untertiteln?“, spottet ein Techniker."},
			{"label": "Auf Stummfilm & Auslandsmärkte setzen", "fn": func():
				c.fame = clampf(c.fame - 3.0, 5.0, 100.0)
				c.mood = clampf(c.mood + 3.0, 0.0, 100.0)
				return "Keine Blamage, aber ein Rückzugsgefecht: In Europa gibt es noch Arbeit — die Frage ist, wie lange."},
		]}

# ---------- 18. Die Zensurbehörde (1934–1954) ----------
func _w_censor() -> float:
	var y = int(Game.state.year)
	return 1.0 if (y >= 1934 and y <= 1954 and _in_production() != null) else 0.0

func _b_censor() -> Dictionary:
	var hit = _in_production()
	var c = hit.c
	var prod = hit.prod
	var cost = roundi(25000.0 * Game.infl(Game.state.year))
	return {"title": "Die Zensurbehörde beanstandet das Drehbuch",
		"text": "Das Hays Office verlangt Änderungen an „%s“ — mehrere Szenen mit %s dürfen so nicht gezeigt werden." % [prod.title, _nm(c)],
		"choices": [
			{"label": "Drehbuch entschärfen", "fn": func():
				prod.qualityMod = prod.get("qualityMod", 0.0) - 5.0
				return "Die Schere schneidet alles Anstößige heraus. Der Film wird glatter — und ein Stück belangloser."},
			{"label": "Mit Andeutungen und Umschreibungen arbeiten", "fn": func():
				var p = clampf(0.35 + Game.state.agency.rep / 150.0, 0.25, 0.8)
				if Game.chance(p):
					prod.qualityMod = prod.get("qualityMod", 0.0) + 5.0
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 2, 0, 100)
					return "Ein Blick, ein Schatten, eine geschlossene Tür: Die Zensoren finden nichts, das Publikum versteht alles."
				prod.qualityMod = prod.get("qualityMod", 0.0) - 2.0
				return "Ein paar Andeutungen überleben, andere fallen doch der Schere zum Opfer. Ein Teilerfolg."},
			{"label": "Unabhängige Veröffentlichung versuchen (%s)" % _fmt(cost), "fn": func():
				Game.book(-float(cost), "events", "Unabhängige Veröffentlichung „%s“" % prod.title)
				if Game.chance(0.3):
					prod.qualityMod = prod.get("qualityMod", 0.0) + 10.0
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 4, 0, 100)
					_dna(c, "unikat", 5.0)
					return "Ohne Code-Siegel in ausgewählte Häuser — und die Kritiker feiern den Mut. Ein Skandalerfolg im besten Sinne."
				prod.qualityMod = prod.get("qualityMod", 0.0) - 6.0
				_rel(prod.studioId, -5)
				return "Viele Kinos weigern sich, den Film ohne Siegel zu zeigen. Ein teures, riskantes Experiment."},
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
	var c = Game.pick(warned if warned.size() else candidates)
	return {"title": "Verdacht auf unamerikanische Umtriebe",
		"text": "[i]„Das Komitee lädt %s vor. Man interessiert sich für … frühere Bekanntschaften.“[/i]\n\nDie Schwarze Liste greift um sich. Wie du jetzt handelst, definiert deine Agentur für Jahre." % _nm(c),
		"choices": [
			{"label": "Klienten öffentlich verteidigen", "fn": func():
				c.loyalty = clampf(c.loyalty + 18.0, 0.0, 100.0)
				Game.change_trust(c, 12.0)
				for cl in Game.state.clients:
					cl.loyalty = clampf(cl.loyalty + 5.0, 0.0, 100.0)
				_dna(c, "unikat", 5.0)
				_dna(c, "familie", -5.0)
				if Game.chance(0.35):
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 8, 0, 100)
					for s in Game.active_studios():
						_rel(s.id, -8)
					return "Deine Erklärung ist mutig — und teuer. Studios legen auf. Aber jeder Klient weiß jetzt, dass du niemanden opferst."
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 5, 0, 100)
				return "Du sprichst als Einziger Klartext — und kommst durch. In dunklen Zeiten ist Rückgrat die seltenste Währung."},
			{"label": "Unter Pseudonym im Ausland arbeiten lassen", "fn": func():
				c.busyUntil = Game.mi() + 6
				c.fame = clampf(c.fame - 5.0, 5.0, 100.0)
				c.loyalty = clampf(c.loyalty + 8.0, 0.0, 100.0)
				Game.change_trust(c, 7.0)
				return "%s dreht unter falschem Namen in Europa. Die Karriere friert ein, aber sie stirbt nicht." % _nm(c)},
			{"label": "Vertrag beenden", "fn": func():
				Game.state.clients.erase(c)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 5, 0, 100)
				for cl in Game.state.clients:
					cl.loyalty = clampf(cl.loyalty - 12.0, 0.0, 100.0)
				for s in Game.active_studios():
					_rel(s.id, 4)
				Game.log_msg("%s wurde in der Blacklist-Ära fallen gelassen." % _nm(c), "bad")
				return "Die Agentur ist sicher, die Studios sind zufrieden. Aber in den Augen deiner übrigen Klienten liest du eine Frage: „Wäre ich der Nächste gewesen?“"},
		]}

# ---------- 20. Das Fernsehen klopft an (1948–1965) ----------
func _w_tv() -> float:
	var y = int(Game.state.year)
	if y < 1948 or y > 1965:
		return 0.0
	return 1.2 if _free_clients().any(func(c): return c.fame >= 40 and c.fame <= 75) else 0.0

func _b_tv() -> Dictionary:
	var c = Game.pick(_free_clients().filter(func(x): return x.fame >= 40 and x.fame <= 75))
	var monthly = roundi(9000.0 * Game.infl(Game.state.year) * (c.fame / 50.0) * c.commission / 100.0)
	return {"title": "Das Fernsehen klopft an",
		"text": "[i]„Vergessen Sie das Kino. In fünf Jahren steht in jedem Wohnzimmer ein Apparat — und wir brauchen Gesichter.“[/i]\n\nEin Sender bietet %s eine eigene Serie: 12 Monate garantiertes Einkommen (%s/Monat Provision), aber das Film-Establishment rümpft die Nase." % [_nm(c), _fmt(monthly)],
		"choices": [
			{"label": "Angebot annehmen", "fn": func():
				c.flags["tvIncome"] = {"monthly": monthly, "months": 12}
				c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
				c.busyUntil = Game.mi() + 3
				_dna(c, "popular", 8.0)
				_dna(c, "unikat", -4.0)
				return "%s wird Fernsehstar: verlässliches Geld jeden Monat. Das Kino-Prestige bröckelt etwas — aber Millionen kennen jetzt dieses Gesicht." % _nm(c)},
			{"label": "Nur Gastauftritte aushandeln", "fn": func():
				if Game.chance(0.5):
					Game.book(float(monthly * 3), "tv", "TV-Gastauftritte: %s" % _nm(c))
					c.heat = clampf(c.heat + 2.0, -10.0, 10.0)
					return "Der Kompromiss gelingt: einzelne Auftritte, volle Gage (%s), kein Exklusivvertrag." % _fmt(monthly * 3)
				return "Der Sender will alles oder nichts. Der Deal zerschlägt sich — aber die Tür bleibt einen Spalt offen."},
			{"label": "Fernsehen grundsätzlich zurückweisen", "fn": func():
				c.mood = clampf(c.mood + 2.0, 0.0, 100.0)
				c.loyalty = clampf(c.loyalty + 3.0, 0.0, 100.0)
				_dna(c, "unikat", 2.0)
				return "„Mein Klient ist ein Filmstar.“ Das klassische Image bleibt makellos — ob das in zehn Jahren noch klug aussieht, weiß niemand."},
		]}

# ---------- Bonus: Ein Gefallen ----------
func _w_favor() -> float:
	return 0.7

func _b_favor() -> Dictionary:
	var studio = Game.pick(Game.active_studios())
	return {"title": "Ein Gefallen",
		"text": "%s bittet um einen Gefallen: ein Klient soll unbezahlt bei einer Galapremiere auftreten." % studio.name,
		"choices": [
			{"label": "Einwilligen", "fn": func():
				_rel(studio.id, 8)
				var kind_s: String = Game.pick(["extraAudition", "billing", "scriptAccess"])
				Game.grant_favor(kind_s, {"type": "studio", "name": str(studio.name), "studioId": str(studio.id)})
				return "%s wird sich erinnern — und steht jetzt offiziell in deiner Schuld. Beziehungen sind die harte Währung dieser Stadt." % studio.name},
			{"label": "Ablehnen", "fn": func():
				_rel(studio.id, -3)
				return "Man verzichtet höflich. Das Studio nimmt es zur Kenntnis."},
		]}

# ---------- Bonus: Presse-Coup ----------
func _w_press() -> float:
	return 0.7 if Game.state.clients.size() else 0.0

func _b_press() -> Dictionary:
	var c = Game.random_client()
	return {"title": "Presse-Coup",
		"text": "Ein großes Magazin bietet eine Titelgeschichte über %s an — gegen exklusiven Zugang." % _nm(c),
		"choices": [
			{"label": "Zusagen", "fn": func():
				c.heat = clampf(c.heat + 4.0, -10.0, 10.0)
				c.fame = clampf(c.fame + 2.0, 5.0, 100.0)
				_dna(c, "popular", 3.0)
				return "Die Ausgabe verkauft sich glänzend. %s ist heißer denn je." % _nm(c)},
			{"label": "Ablehnen", "fn": func():
				return "Man verzichtet. Privatsphäre ist auch etwas wert."},
		]}

# ---------- Folge-Ereignisse ----------
func build_followup(fu: Dictionary) -> Variant:
	match fu.type:
		"photosReturn":
			var c = Game.client(fu.cid)
			if c == null or c.flags.get("photosSecured", false):
				return null
			var cost = roundi((12000.0 + c.fame * 200.0) * Game.infl(Game.state.year))
			var choices: Array = [
				{"label": "Jetzt kaufen (%s)" % _fmt(cost), "fn": func():
					Game.book(-float(cost), "pr_recht", "Boulevard-Fotos gekauft: %s" % _nm(c))
					c.flags["photosSecured"] = true
					return "Diesmal zögerst du nicht. Die Sache ist endgültig vom Tisch."},
				{"label": "Aussitzen", "fn": func():
					c.fame = clampf(c.fame - 3.0, 5.0, 100.0)
					c.flags["photosSecured"] = true
					_dna(c, "familie", -5.0)
					return "Drei unangenehme Wochen, dann ist die Empörung verraucht. Narben bleiben."},
			]
			if Game.has_favor("suppressStory"):
				choices.insert(0, {"label": "Gefallen einlösen: Die Story killen", "fn": func():
					Game.consume_favor("suppressStory")
					c.flags["photosSecured"] = true
					return "Ein Wort beim Herausgeber genügt. Das Boulevardblatt druckt stattdessen etwas über einen Kongressabgeordneten."})
			return {"title": "Die Fotos tauchen wieder auf",
				"text": "Wie befürchtet: Die alten Aufnahmen von %s sind wieder im Umlauf — diesmal bei einem Boulevardblatt." % _nm(c),
				"choices": choices}
		"romanceLeak":
			var c2 = Game.client(fu.cid)
			if c2 == null:
				return null
			var choices2: Array = [
				{"label": "Zugeben und lachen", "fn": func():
					if Game.chance(0.6):
						c2.heat = clampf(c2.heat + 2.0, -10.0, 10.0)
						return "„Natürlich war das Show — willkommen in Hollywood.“ Die Stadt lacht mit. Glück gehabt."
					c2.fame = clampf(c2.fame - 3.0, 5.0, 100.0)
					_dna(c2, "familie", -4.0)
					return "Ein Teil des Publikums fühlt sich betrogen. Der Glanz bekommt Kratzer."},
				{"label": "Dementieren", "fn": func():
					c2.heat = clampf(c2.heat - 2.0, -10.0, 10.0)
					return "Das Dementi glaubt niemand so recht, aber die Geschichte verliert an Fahrt."},
			]
			if Game.has_favor("suppressStory"):
				choices2.insert(0, {"label": "Gefallen einlösen: Die Kolumne verschwinden lassen", "fn": func():
					Game.consume_favor("suppressStory")
					return "Der Kolumnist findet die Geschichte plötzlich „nicht mehr druckreif“. Was in Hollywood zählt, ist, was gedruckt wird — oder eben nicht."})
			return {"title": "Die Romanze fliegt auf",
				"text": "Ein Kolumnist enthüllt: Die große Liebesgeschichte von %s war eine PR-Inszenierung." % _nm(c2),
				"choices": choices2}
		"homevideo":
			# Heimvideo-Ära (1980+): Flops können nachträglich Geld einspielen (Feature 14)
			var income := roundi(float(fu.get("budget", 0)) * Game.rndf(0.08, 0.16) * float(Game.state.market))
			var hvsid := str(fu.get("studioId", ""))
			var hv_studio := "Das Studio"
			if hvsid != "" and Game.state.studioRel.has(hvsid):
				hv_studio = Game._studio(hvsid).name
			return {"title": "Zweites Leben auf Video",
				"text": "„%s“ — damals ein Flop — führt auf Heimvideo ein stilles Eigenleben: Videotheken bestellen nach, Mitternachtsvorstellungen füllen sich, eine kleine Fangemeinde schreibt Briefe. %s bietet eine nachträgliche Beteiligung an." % [str(fu.get("title", "Der Film")), hv_studio],
				"choices": [
					{"label": "Beteiligung annehmen (+%s)" % _fmt(income), "fn": func():
						Game.book(float(income), "sonstiges", "Heimvideo-Zweitauswertung: „%s“" % str(fu.get("title", "")))
						if hvsid != "" and Game.state.studioRel.has(hvsid):
							_rel(hvsid, 2)
						return "Die Videotheken-Schecks trudeln ein. Manche Filme brauchen einfach ein zweites Leben. (+%s)" % _fmt(income)},
					{"label": "Auf Kultstatus pokern", "fn": func():
						if Game.chance(0.5):
							var more := roundi(income * 1.7)
							Game.book(float(more), "sonstiges", "Heimvideo-Kultstatus: „%s“" % str(fu.get("title", "")))
							return "Guter Instinkt: Der Film wird zum Mitternachts-Kult — die spätere Einigung fällt deutlich besser aus. (+%s)" % _fmt(more)
						return "Du wartest auf bessere Konditionen — doch der Moment verfliegt. Die Videotheken räumen das Regal um."},
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
	var director_cost := roundi(20000.0 * Game.infl(Game.state.year))
	var producer_cost := roundi(35000.0 * Game.infl(Game.state.year))
	var choices: Array = [
		{"label":"Den Regiestuhl vorbereiten (%s)" % _fmt(director_cost), "fn":func():
			if float(Game.state.agency.cash) < float(director_cost):
				return "Die Finanzierung steht nicht. Der Regiestuhl muss warten."
			Game.book(-float(director_cost), "investition", "Regiedebüt: %s" % _nm(c))
			Game.record_identity("kuenstlerisch", 2.0)
			Game.record_identity("klientenorientiert", 1.0)
			return Game.become_power_figure(cid, "director", true)},
		{"label":"Eine Produktionsfirma aufbauen (%s)" % _fmt(producer_cost), "fn":func():
			if float(Game.state.agency.cash) < float(producer_cost):
				return "Ohne Kapital gibt es keine Produktionsfirma. Noch nicht."
			Game.book(-float(producer_cost), "investition", "Produktionsdebüt: %s" % _nm(c))
			Game.record_identity("kommerziell", 1.0)
			Game.record_identity("klientenorientiert", 1.0)
			return Game.become_power_figure(cid, "producer", true)},
	]
	if fractured:
		choices.append({"label":"Ohne Beteiligung ziehen lassen", "fn":func(): return Game.become_power_figure(cid, "producer", false, true)})
	else:
		choices.append({"label":"Noch vor der Kamera bleiben", "fn":func(): return "[i]„Noch habe ich Rollen zu spielen.“[/i] Der Machtwechsel wird vertagt — ohne Nachteil."})
	return {"title":"Die andere Seite der Kamera",
		"text":"[i]„Ich habe lange genug auf Markierungen gestanden. Vielleicht ist es Zeit, selbst ‚Action‘ zu rufen.“[/i]\n\n%s ist bereit für den nächsten Machtkreis Hollywoods.%s" % [_nm(c), " Die Beziehung ist allerdings so zerrüttet, dass bereits von einem eigenen Konkurrenzhaus die Rede ist." if fractured else ""],
		"choices":choices}

# ---------- 21. Der Gefallen wird eingefordert ----------
func _w_favor_called() -> float:
	return 1.3 if Game.state.debts.size() else 0.0

func _b_favor_called() -> Dictionary:
	var debt = Game.pick(Game.state.debts)
	var did = int(debt.id)
	var creditor: String = str(debt["from"].get("name", "Ein alter Bekannter"))
	var sid: String = str(debt["from"].get("studioId", ""))
	var demand: String = Game.pick(["gala", "pitch", "cameo"])
	var demands := {
		"gala": "einen deiner Klienten als Star-Gast für eine Charity-Gala — unbezahlt, aber sehr öffentlich",
		"pitch": "deinen Verzicht, einen deiner Klienten für eine begehrte Rolle ins Rennen zu schicken",
		"cameo": "einen Gratis-Cameo-Auftritt in einem Freundschaftsprojekt",
	}
	var choices: Array = [
		{"label": "Einlösen und erfüllen", "fn": func():
			Game.remove_debt(did)
			var msg := ""
			match demand:
				"gala":
					var c = Game.random_client()
					if c != null:
						c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
						c.exhaustion = clampf(c.exhaustion + 10.0, 0.0, 100.0)
						c.mood = clampf(c.mood - 4.0, 0.0, 100.0)
						msg = "%s strahlt für die gute Sache in die Blitzlichter (+Heat, etwas Erschöpfung)." % _nm(c)
					else:
						msg = "Du persönlich schneidest das Band durch — immerhin ein Foto in der Lokalzeitung."
				"pitch":
					Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 1, 0, 100)
					msg = "Du hältst dich beim Casting zurück. Die Branche registriert deinen Anstand (Ruf +1)."
				"cameo":
					var c2 = Game.random_client()
					if c2 != null:
						c2.exhaustion = clampf(c2.exhaustion + 8.0, 0.0, 100.0)
						c2.fame = clampf(c2.fame + 1.0, 5.0, 100.0)
						msg = "%s liefert einen charmanten Kurzauftritt ab — unbezahlt, aber nicht unbemerkt." % _nm(c2)
					else:
						msg = "Du organisierst den Cameo über Umwege. Es kostet Nerven, aber keinen Ruhm."
			if Game.chance(0.3):
				var kind_s: String = Game.pick(["extraAudition", "billing", "scriptAccess"])
				Game.grant_favor(kind_s, debt["from"])
				msg += " Und weil du so unkompliziert warst, steht %s nun selbst in deiner Schuld." % creditor
			return "Die Schuld ist beglichen — %s ist quitt mit dir. %s" % [creditor, msg]},
		{"label": "Ablehnen (kostet Ansehen)", "fn": func():
			Game.remove_debt(did)
			if sid != "" and Game.state.studioRel.has(sid):
				_rel(sid, -6)
				return "%s vermerkt die Absage kühl. Die Beziehung zu %s leidet." % [creditor, Game._studio(sid).name]
			Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 2, 0, 100)
			return "Die Absage macht die Runde. Manche nicken verständnisvoll — andere nicht. (Ruf −2)"},
	]
	if Game.state.favors.size() > 0:
		choices.insert(1, {"label": "Einen eigenen Gefallen dagegenhalten (verbraucht 1 Gefallen)", "fn": func():
			Game.consume_any_favor()
			Game.remove_debt(did)
			return "Ein Gefallen gegen einen Gefallen — die klassische Währung dieser Stadt. Ihr seid quitt, und niemand hat das Gesicht verloren."})
	return {"title": "Der Gefallen wird eingefordert",
		"text": "[i]„Sie erinnern sich doch — damals habe ich Ihnen einen Gefallen getan. Jetzt brauche ich etwas.“[/i]\n\n%s fordert ein: %s." % [creditor, demands[demand]],
		"choices": choices}

# ---------- 22. Die exklusive Einladung ----------
func _w_gala() -> float:
	return 1.0 if Game.has_favor("galaInvite") else 0.0

func _b_gala() -> Dictionary:
	Game.consume_favor("galaInvite")
	var studio = Game.pick(Game.active_studios())
	var c = Game.random_client(func(x): return Game.is_free(x))
	var choices: Array = [
		{"label": "Kontakte knüpfen", "fn": func():
			var f1 = Game.grant_favor(Game.pick(["extraAudition", "billing", "scriptAccess", "suppressStory"]))
			var msg := "Zwei Stunden, drei Handschläge, ein versprochenes Mittagessen: %s schuldet dir jetzt etwas." % str(f1["from"].get("name", "Jemand Wichtiges"))
			if Game.chance(0.5):
				var f2 = Game.grant_favor(Game.pick(["galaInvite", "extraAudition", "billing"]))
				msg += " Und %s lässt ebenfalls etwas für dich liegen." % str(f2["from"].get("name", "ein Produzent"))
			return msg},
		{"label": "Einen Gefallen dem Hausherrn überlassen", "fn": func():
			Game.record_identity("studiotreu", 1.5)
			if Game.pass_any_favor_to_studio(studio.id):
				return "Du lässt %s spüren, dass du auf deine Trümpfe verzichten kannst. Die Beziehung vertieft sich sichtbar." % studio.name
			_rel(studio.id, 2)
			return "Du hast keine Gefallen auf der Hand — aber der Abend selbst wirkt als Geste."},
	]
	if c != null:
		choices.insert(1, {"label": "Deal anbahnen: %s in Szene setzen" % _nm(c), "fn": func():
			var r = Game.quick_production(c, {"studio": studio, "feeMult": 1.2})
			c.heat = clampf(c.heat + 3.0, -10.0, 10.0)
			return "Zwischen Champagner und Zedernholz wird gehandelt: %s unterschreibt für „%s“ (%s Provision)." % [_nm(c), r.title, _fmt(r.income)]})
	return {"title": "Die exklusive Einladung",
		"text": "Die eingelöste Einladung führt dich auf eine geschlossene Veranstaltung bei %s — Smoking, Gelächter, und in jeder Ecke jemand, der etwas zu vergeben hat." % studio.name,
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
	var c = Game.pick(Game.state.clients.filter(func(x): return x.flags.get("sequelDue") != null))
	var due: Dictionary = c.flags["sequelDue"]
	var sid := str(due.get("studioId", ""))
	var old_fee := int(due.get("fee", 0))
	var fair_fee := roundi(Game.ask_fee(c.fame, Game.state.year) * 1.4)
	var studio_name := "Das Studio"
	if sid != "" and Game.state.studioRel.has(sid):
		studio_name = Game._studio(sid).name
	var film_t := str(due.get("title", "Der Film"))
	var bonus := roundi(fair_fee * 0.35 * float(c.commission) / 100.0)
	var lawyer := roundi(25000.0 * Game.infl(Game.state.year))
	return {"title": "Die Fortsetzungs-Falle",
		"text": "„%s“ wurde ein Blockbuster — und prompt holt %s die alte sequelOption-Klausel aus der Schublade: %s soll die Fortsetzung zur Gage des ersten Films drehen (%s statt marktüblicher %s).\n\n[i]„Das ist Diebstahl mit Unterschrift!“[/i] tobt %s am Telefon." % [film_t, studio_name, _nm(c), _fmt(old_fee), _fmt(fair_fee), _nm(c)],
		"choices": [
			{"label": "Hart neu verhandeln", "fn": func():
				c.flags.erase("sequelDue")
				if Game.chance(0.55):
					Game.book(float(bonus), "provision", "Sequel-Sonderbonus: %s („%s II“)" % [_nm(c), film_t])
					Game.change_trust(c, 4.0)
					if sid != "" and Game.state.studioRel.has(sid):
						_rel(sid, -4)
					return "Nach zwei zähen Wochen knickt das Studio ein: Sonderbonus statt Alt-Gage. %s atmet auf — bei %s hat man sich das gemerkt. (+%s Provision)" % [_nm(c), studio_name, _fmt(bonus)]
				c.mood = clampf(c.mood - 8.0, 0.0, 100.0)
				if sid != "" and Game.state.studioRel.has(sid):
					_rel(sid, -8)
				return "Das Studio bleibt stur und beruft sich auf den Vertrag. %s wird die Fortsetzung zur Alt-Gage drehen müssen — mit entsprechender Laune." % _nm(c)},
			{"label": "Klienten zur Vertragstreue überreden", "fn": func():
				c.flags.erase("sequelDue")
				Game.change_trust(c, -6.0)
				Game.record_identity("studiotreu", 1.0)
				if sid != "" and Game.state.studioRel.has(sid):
					_rel(sid, 4)
				return "„Ein Vertrag ist ein Vertrag.“ %s schluckt es — schweigend. %s registriert deine Loyalität wohlwollend." % [_nm(c), studio_name]},
			{"label": "Klage androhen (%s Anwaltskosten)" % _fmt(lawyer), "fn": func():
				c.flags.erase("sequelDue")
				Game.book(-float(lawyer), "pr_recht", "Anwälte: sequelOption angefochten (%s)" % _nm(c))
				if Game.chance(0.5):
					var win := roundi(fair_fee * 0.5 * float(c.commission) / 100.0)
					Game.book(float(win), "provision", "Vergleich „%s II“: %s" % [film_t, _nm(c)])
					Game.change_trust(c, 6.0)
					return "Vergleich vor den Toren des Gerichtssaals: saftige Abfindung, neue Gage. %s triumphiert. (−%s Anwalt, +%s Vergleich)" % [_nm(c), _fmt(lawyer), _fmt(win)]
				if sid != "" and Game.state.studioRel.has(sid):
					_rel(sid, -10)
				c.fame = clampf(c.fame - 3.0, 5.0, 100.0)
				return "Die Klage verpufft — und die Presse liebt die Geschichte vom „undankbaren Star“. %s dreht zur Alt-Gage, mit Demut." % _nm(c)},
		]}

# ---------- escalator: Zögern an der Gagen-Leiter ----------
func _w_escalator_balk() -> float:
	return 0.9 if _clients_with_clause("escalator").size() > 0 else 0.0

func _b_escalator_balk() -> Dictionary:
	var c = Game.pick(_clients_with_clause("escalator"))
	var studio = Game.pick(Game.active_studios())
	var buyout := roundi(Game.ask_fee(c.fame, Game.state.year) * 0.8 * float(c.commission) / 100.0)
	return {"title": "Zögern an der Gagen-Leiter",
		"text": "%s will %s erneut besetzen — doch die escalator-Klausel treibt die Gage mit jedem Film nach oben. Die Buchhaltung schlägt Alarm: Entweder fällt die Klausel, oder die Rolle geht an ein billigeres Gesicht.\n\nMan bietet dir einen Klausel-Buy-out: einmalig %s." % [studio.name, _nm(c), _fmt(buyout)],
		"choices": [
			{"label": "Buy-out annehmen (+%s, Klausel fällt weg)" % _fmt(buyout), "fn": func():
				c.clauses.erase("escalator")
				Game.book(float(buyout), "provision", "Escalator-Buy-out: %s" % _nm(c))
				Game.change_trust(c, -3.0)
				return "Das Geld stimmt, die Geste nicht: %s verliert die Gagen-Leiter — und wird sich daran erinnern. (+%s)" % [_nm(c), _fmt(buyout)]},
			{"label": "Klausel verteidigen", "fn": func():
				Game.change_trust(c, 3.0)
				_rel(studio.id, -3)
				if Game.chance(0.6):
					return "%s schluckt die Leiter — der Star ist die Sorge wert. %s strahlt: Genau dafür zahlt er dir Provision." % [studio.name, _nm(c)]
				c.heat = clampf(c.heat - 2.0, -10.0, 10.0)
				return "%s zieht zurück und besetzt billiger. Die Klausel bleibt — aber sie hängt nun wie ein Preisschild an %s." % [studio.name, _nm(c)]},
		]}

# ---------- creativeApproval: Der Klient sagt Nein ----------
func _w_creative_veto() -> float:
	return 1.0 if _clients_with_clause("creativeApproval").any(func(c): return Game.is_free(c)) else 0.0

func _b_creative_veto() -> Dictionary:
	var c = Game.pick(_clients_with_clause("creativeApproval").filter(func(x): return Game.is_free(x)))
	var studio = Game.pick(Game.active_studios())
	var genre: String = Game.pick(Data.GENRES.keys())
	var proj := Game.project_title(genre)
	var fee := roundi(Game.ask_fee(c.fame, Game.state.year))
	return {"title": "Das kreative Veto",
		"text": "%s bietet %s die Hauptrolle in „%s“ (%s) — ein solider Zahltag (%s). Doch die creativeApproval-Klausel gibt %s ein Mitspracherecht, und das Urteil fällt vernichtend aus:\n\n[i]„Dieses Drehbuch beerdigt meine Karriere. Ich mache das nicht.“[/i]" % [studio.name, _nm(c), proj, Data.GENRES[genre]["de"], _fmt(fee), _nm(c)],
		"choices": [
			{"label": "Das Veto respektieren", "fn": func():
				Game.change_trust(c, 4.0)
				_rel(studio.id, -2)
				_dna(c, "unikat", 4.0)
				return "Du stellst dich hinter deinen Klienten. %s verlässt das Gespräch aufrecht — %s streicht dich vorerst von der Weihnachtsliste." % [_nm(c), studio.name]},
			{"label": "Umstimmen — das Geld ist zu gut", "fn": func():
				if Game.chance(0.6):
					var r = Game.quick_production(c, {"studio": studio, "feeMult": 1.0})
					Game.change_trust(c, -5.0)
					c.mood = clampf(c.mood - 6.0, 0.0, 100.0)
					return "%s lässt sich breitschlagen und unterschreibt für „%s“ (%s Provision). Im Spiegel des Anhängers herrscht fortan Funkstille." % [_nm(c), r.title, _fmt(r.income)]
				Game.change_trust(c, -3.0)
				_rel(studio.id, -4)
				return "Ein Streit, zwei aufgebrachte Parteien — und am Ende kein Vertrag. %s ist beleidigt, %s ebenfalls." % [_nm(c), studio.name]},
			{"label": "Drehbuch-Nachbesserung aushandeln", "fn": func():
				if Game.chance(0.55):
					var r2 = Game.quick_production(c, {"studio": studio, "feeMult": 0.9})
					Game.change_trust(c, 3.0)
					_dna(c, "unikat", 2.0)
					return "Drei neue Autoren, zwei Wochen Überarbeitung: „%s“ wird tragbar. Alle retten das Gesicht (%s Provision)." % [r2.title, _fmt(r2.income)]
				_rel(studio.id, -3)
				return "%s ist nicht bereit, noch einmal ins Drehbuch zu investieren. Das Projekt verstaubt in der Schublade." % studio.name},
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
	var studio_name := "Ein Studio"
	if Game.state.studioRel.has(sid):
		studio_name = Game._studio(sid).name
	var lawyer := roundi(30000.0 * Game.infl(Game.state.year))
	var kick := func():
		role.filled = {"npc": true, "name": "Neubesetzung", "talent": 55, "fame": 30}
		c.busyUntil = Game.mi()
	return {"title": "Der Sittenparagraph",
		"text": "Das Gerücht über %s hat die Glaubensschwelle geknackt — und %s zückt die moralClause aus dem Vertrag von „%s“: Der Vertrag wird per Sittenparagraph aufgelöst, straffrei, sofort. Eine Neubesetzung wird schon angefragt.\n\n[i]„%s“[/i]" % [_nm(c), studio_name, str(prod.title), str(rumor.get("text", ""))],
		"choices": [
			{"label": "Anwälte einschalten (%s)" % _fmt(lawyer), "fn": func():
				Game.book(-float(lawyer), "pr_recht", "moralClause-Prozess: %s" % _nm(c))
				if Game.chance(0.5):
					_rel(sid, -3)
					return "Die Anwälte zerpflücken die Klausel: „Skandal“ sei nicht bewiesen, nur Gerede. Der Vertrag hält — knapp. (−%s)" % _fmt(lawyer)
				kick.call()
				c.fame = clampf(c.fame - 2.0, 5.0, 100.0)
				return "Das Gericht sieht es anders. %s ist raus aus dem Film — und der Prozess hat die Geschichte erst richtig groß gemacht. (−%s)" % [_nm(c), _fmt(lawyer)]},
			{"label": "Hinnehmen und Schaden begrenzen", "fn": func():
				kick.call()
				c.fame = clampf(c.fame - 4.0, 5.0, 100.0)
				Game.change_trust(c, 2.0)
				return "Du ziehst %s ruhig aus der Schusslinie. Der Film geht weiter — ohne deinen Star, aber ohne Schlammschlacht." % _nm(c)},
			{"label": "Gegendarstellung in der Presse", "fn": func():
				var cost := roundi(15000.0 * Game.infl(Game.state.year))
				Game.book(-float(cost), "pr_recht", "Gegendarstellung: %s" % _nm(c))
				rumor["belief"] = clampf(float(rumor.belief) - 25.0, 0.0, 100.0)
				Game.state.agency.rep = clampi(int(Game.state.agency.rep) - 1, 0, 100)
				if float(rumor.belief) < 60.0 and Game.chance(0.7):
					return "Die Gegendarstellung läuft überall. Der Glaube an das Gerücht bröckelt — %s lässt die Kündigung erst einmal ruhen." % studio_name
				kick.call()
				return "Die Gegendarstellung verpufft. Am Ende steht nur eine Schlagzeile mehr — und eine Neubesetzung. (−%s)" % _fmt(cost)},
		]}

# ---------- likenessRights: Das digitale Abbild (ab 2015) ----------
func _w_likeness() -> float:
	if int(Game.state.year) < 2015:
		return 0.0
	return 1.0 if _clients_with_clause("likenessRights").size() > 0 else 0.0

func _b_likeness() -> Dictionary:
	var c = Game.pick(_clients_with_clause("likenessRights"))
	var studio = Game.pick(Game.active_studios())
	var payment := roundi(Game.ask_fee(c.fame, Game.state.year) * 0.9 * float(c.commission) / 100.0)
	if Game.chance(0.5):
		return {"title": "Das digitale Double",
			"text": "Ein aufmerksamer Fan entdeckt es zuerst: In „%s“ läuft %s durchs Bild — obwohl %s nie vor dieser Kamera stand. %s hat das digitale Abbild aus dem Archiv geholt und weiterverwendet. Die likenessRights-Klausel verlangt Zustimmung. Es gab keine." % [Game.project_title(Game.pick(Data.GENRES.keys())), _nm(c), _nm(c), studio.name],
			"choices": [
				{"label": "Klage einreichen", "fn": func():
					var cost := roundi(40000.0 * Game.infl(Game.state.year))
					Game.book(-float(cost), "pr_recht", "Likeness-Klage: %s" % _nm(c))
					if Game.chance(0.6):
						var win := roundi(float(payment) * 2.5)
						Game.book(float(win), "provision", "Likeness-Vergleich: %s" % _nm(c))
						_rel(studio.id, -6)
						Game.change_trust(c, 5.0)
						return "Der Vergleich setzt einen Präzedenzfall für ganz Hollywood: Das Abbild gehört dem Menschen. (−%s Anwalt, +%s Vergleich)" % [_fmt(cost), _fmt(win)]
					_rel(studio.id, -8)
					return "Jahrelange Gutachten, Experten, Pixelzählerei — am Ende weist man die Klage ab. Das Gesetz hinkt der Technik hinterher. (−%s)" % _fmt(cost)},
				{"label": "Lizenz nachträglich verkaufen (+%s)" % _fmt(payment), "fn": func():
					Game.book(float(payment), "provision", "Likeness-Lizenz: %s" % _nm(c))
					Game.change_trust(c, -4.0)
					return "Statt Ärger ein Scheck. %s ist nicht begeistert, dass du sein Gesicht nachträglich vermietest — aber die Provision stimmt. (+%s)" % [_nm(c), _fmt(payment)]},
			]}
	return {"title": "Das Angebot aus dem Computer",
		"text": "%s will das digitale Abbild von %s lizenzieren: Werbung, Games, virtuelle Auftritte — %s muss nie wieder vor einer Kamera stehen und kassiert trotzdem. Angebot für die Agentur: %s.\n\n[i]„Also ich finde das gruselig“[/i], sagt %s." % [studio.name, _nm(c), _nm(c), _fmt(payment), _nm(c)],
		"choices": [
			{"label": "Verkaufen (+%s)" % _fmt(payment), "fn": func():
				Game.book(float(payment), "provision", "Digital-Double-Lizenz: %s" % _nm(c))
				Game.change_trust(c, -3.0)
				c.heat = clampf(c.heat + 2.0, -10.0, 10.0)
				return "Das Double arbeitet ab jetzt rund um die Uhr — der Mensch dazu hat plötzlich viel freie Zeit und gemischte Gefühle. (+%s)" % _fmt(payment)},
			{"label": "Ablehnen — der Klient hat Vetorecht", "fn": func():
				Game.change_trust(c, 4.0)
				_dna(c, "unikat", 2.0)
				return "Du respektierst das Unbehagen. %s bleibt aus Fleisch und Blut — und vertraut dir ein Stück mehr." % _nm(c)},
		]}

# ---------- endorsement: Werbe-Pflichttermin ----------
func _w_endorsement() -> float:
	return 0.8 if _clients_with_clause("endorsement").size() > 0 else 0.0

func _b_endorsement() -> Dictionary:
	var c = Game.pick(_clients_with_clause("endorsement"))
	var pay := roundi((1200.0 + float(c.fame) * 45.0) * Game.infl(Game.state.year) * float(c.commission) / 100.0)
	var product: String = Game.pick(["einen Rasierwasser-Spot", "eine Uhren-Kampagne", "einen Softdrink-Werbefilm", "eine Zigaretten-Anzeige", "eine Auto-Werbeserie"])
	return {"title": "Der Werbe-Pflichttermin",
		"text": "Die endorsement-Klausel ruft: %s soll %s drehen — drei Tage Studio, ein breites Grinsen, null künstlerischer Ehrgeiz. Die Agentur verdient mit, aber %s verdreht trotzdem die Augen." % [_nm(c), product, _nm(c)],
		"choices": [
			{"label": "Termin quetschen (+%s)" % _fmt(pay), "fn": func():
				Game.book(float(pay), "provision", "Werbeverpflichtung: %s" % _nm(c))
				c.exhaustion = clampf(c.exhaustion + 8.0, 0.0, 100.0)
				Game.change_trust(c, -2.0)
				_dna(c, "familie", 2.0)
				return "Drei Tage Lächeln auf Knopfdruck. Das Konto freut sich, %s weniger. (+%s, Erschöpfung steigt)" % [_nm(c), _fmt(pay)]},
			{"label": "Termin absagen (Strafe)", "fn": func():
				var fine := roundi(float(pay) * 0.5)
				Game.book(-float(fine), "sonstiges", "Vertragsstrafe Werbetermin: %s" % _nm(c))
				Game.change_trust(c, 2.0)
				return "Du zahlst die Konventionalstrafe und schenkst deinem Klienten drei freie Tage. Manchmal ist das die bessere Investition. (−%s)" % _fmt(fine)},
			{"label": "PR-Geschichte daraus machen", "fn": func():
				var pr_pay := roundi(float(pay) * 0.7)
				Game.book(float(pr_pay), "provision", "Werbeverpflichtung: %s" % _nm(c))
				c.heat = clampf(c.heat + 2.0, -10.0, 10.0)
				_dna(c, "popular", 2.0)
				return "Du lässt die Kamera hinter der Kamera laufen: Der Spot wird zur Story, die Story zur Schlagzeile. Aus Pflicht wird PR. (+%s)" % _fmt(pr_pay)},
		]}
