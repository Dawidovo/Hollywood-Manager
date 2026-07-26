extends Node
# =====================================================================
# Hollywood Herald — kompaktes, JSON-sicheres Gedächtnis der Simulation.
# Die Ausgabe speichert bewusst nur Monat, Zeitungstitel und Schlagzeilen.
# =====================================================================

const ARCHIVE_MAX := 24

func paper_name(year: int) -> String:
	if year < 1935:
		return "Hollywood Daily Illustrated"
	if year < 1965:
		return "Hollywood Herald"
	if year < 1995:
		return "Hollywood Reporter & Herald"
	if year < 2010:
		return "Hollywood Wire"
	return "HLYWD NOW"

func _headline(cat: String, text_s: String) -> Dictionary:
	return {"cat": cat, "text": text_s}

func _has_category(headlines: Array, cat: String) -> bool:
	return headlines.any(func(h): return str(h.get("cat", "")) == cat)

func _client_or_actor_label(rumor: Dictionary) -> String:
	var c = Game.rumor_subject_client(rumor)
	if c != null:
		return CareerDNA.dna_label(c)
	var aid := str(rumor.get("subject", ""))
	if Game.actor_by_id.has(aid):
		return CareerDNA.dna_label({"dna": CareerDNA.initial_dna(Game.actor_by_id[aid])})
	return "screen darling"

func blind_item(rumor: Dictionary, year: int) -> String:
	# Kein Klarname und kein Originaltext: Beides könnte die Person verraten.
	var image := _client_or_actor_label(rumor)
	var topic := str(rumor.get("topic", "skandal"))
	var hook := {
		"affäre": "be hiding late-night meetings from the morning paper",
		"wechsel": "already be knocking secretly on another agency's door",
		"gesundheit": "need more than a shooting break between two takes",
		"politik": "be backing a risky political cause in a back room",
		"skandal": "be playing a very different role on set than in front of the camera",
	}.get(topic, "be carrying a secret through the studio corridors")
	if year < 1940:
		return "BLIND RUMOR: Which %s is said to %s? The town holds its breath!" % [image, hook]
	if year >= 2010:
		return "Blind item: which %s is said to %s? 5 studio doors people are whispering behind right now" % [image, hook]
	return "Blind item: which %s is said to %s? We are not naming names — yet." % [image, hook]

func _release_headlines(headlines: Array) -> void:
	for film in Game.state.released:
		if int(film.get("releaseMi", -1)) != Game.mi():
			continue
		var quality := int(film.get("quality", 50))
		var title_s := str(film.get("title", "Untitled"))
		var verdict := str(film.get("verdict", "Premiere"))
		var review := "an impeccably crafted studio piece"
		if quality >= 85:
			review = "a triumph that brings even the jaded critics to their feet"
		elif quality >= 70:
			review = "elegant cinema with a real echo"
		elif quality < 45:
			review = "celluloid that had better stayed in the can"
		headlines.append(_headline("Reviews", "“%s”: %s (quality %d/100)" % [title_s, review, quality]))
		var ratio := float(film.get("ratio", 1.0))
		if ratio < 1.0 or ratio >= 2.0:
			headlines.append(_headline("Box office", "%s at the box office: “%s” earns %0.1f times its budget" % [verdict, title_s, ratio]))

func _blind_headline(headlines: Array) -> void:
	var candidates: Array = Game.state.rumors.filter(func(r):
		return float(r.get("belief", 0.0)) >= 30.0 and float(r.get("belief", 0.0)) <= 60.0)
	if candidates.size():
		headlines.append(_headline("Blind item", blind_item(candidates[0], int(Game.state.year))))

func _real_fallbacks(headlines: Array) -> void:
	# Auch in ruhigen Monaten erscheint eine echte Zeitung: Jeder Fallback liest
	# ausschließlich den aktuellen Simulationszustand.
	if not _has_category(headlines, "Agencies"):
		var labels := Game.identity_top_labels()
		var identity_s := "still without a fixed label" if labels.is_empty() else " & ".join(labels)
		headlines.append(_headline("Agencies", "%s: reputation %d, %d clients — around town the house is considered %s" % [Game.state.agency.name, int(Game.state.agency.rep), Game.state.clients.size(), identity_s]))
	if not _has_category(headlines, "Casting") and Game.state.castings.size():
		# Verdeckte Coverage-Castings sind noch kein öffentliches Casting
		var visible: Array = Game.state.castings.filter(func(cs): return not bool(cs.get("hidden", false)))
		if visible.size():
			var cs: Dictionary = visible[0]
			headlines.append(_headline("Casting", "%s is looking for faces for “%s” — %d roles are in play" % [Game._studio(str(cs.studioId)).name, cs.title, cs.roles.size()]))
	if not _has_category(headlines, "Market"):
		headlines.append(_headline("Market", "Dream factory barometer at %d percent — %d productions currently shooting" % [roundi(float(Game.state.market) * 100.0), Game.state.productions.size()]))
	if not _has_category(headlines, "Talent"):
		if Game.state.clients.size():
			var star: Dictionary = Game.state.clients[0]
			for c in Game.state.clients:
				if float(c.fame) > float(star.fame):
					star = c
			headlines.append(_headline("Talent", "%s tops the client list of %s with fame %d" % [Game.client_name(star), Game.state.agency.name, roundi(float(star.fame))]))
		else:
			var pool: Array = Game.available_actors()
			if pool.size():
				var actor: Dictionary = pool[0]
				headlines.append(_headline("Talent", "%s is, at fame %d, the most sought-after free name in town" % [actor.name, Util.fame_at(actor, Game.state.year)]))

func build_newspaper() -> Dictionary:
	if Game.state == null:
		return {}
	var headlines: Array = []
	_release_headlines(headlines)
	for item in Game.state.get("pressFeed", []):
		headlines.append(_headline(str(item.get("cat", "Talk of the town")), str(item.get("text", ""))))
	_blind_headline(headlines)
	_real_fallbacks(headlines)
	var issue := {
		"mi": Game.mi(),
		"name": paper_name(int(Game.state.year)),
		"headlines": headlines.slice(0, 12),
	}
	Game.state.newspaper.push_front(issue)
	while Game.state.newspaper.size() > ARCHIVE_MAX:
		Game.state.newspaper.pop_back()
	Game.state.pressFeed.clear()
	return issue
