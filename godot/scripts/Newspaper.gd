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
		return Game.dna_label(c)
	var aid := str(rumor.get("subject", ""))
	if Game.actor_by_id.has(aid):
		return Game.dna_label({"dna": Game.initial_dna(Game.actor_by_id[aid])})
	return "Leinwandliebling"

func blind_item(rumor: Dictionary, year: int) -> String:
	# Kein Klarname und kein Originaltext: Beides könnte die Person verraten.
	var image := _client_or_actor_label(rumor)
	var topic := str(rumor.get("topic", "skandal"))
	var hook := {
		"affäre": "nächtliche Treffen lieber vor dem Morgenblatt verbergen",
		"wechsel": "bereits heimlich an der Tür einer anderen Agentur klopfen",
		"gesundheit": "zwischen zwei Takes mehr als nur eine Drehpause brauchen",
		"politik": "im Hinterzimmer eine riskante politische Sache unterstützen",
		"skandal": "am Set eine ganz andere Rolle spielen als vor der Kamera",
	}.get(topic, "ein Geheimnis durch die Studiokorridore tragen")
	if year < 1940:
		return "BLINDES GERÜCHT: Welcher %s soll %s? Die Stadt hält den Atem an!" % [image, hook]
	if year >= 2010:
		return "Blind Item: Welcher %s soll %s? 5 Studiotüren, hinter denen gerade getuschelt wird" % [image, hook]
	return "Blind Item: Welcher %s soll %s? Namen nennen wir — noch — nicht." % [image, hook]

func _release_headlines(headlines: Array) -> void:
	for film in Game.state.released:
		if int(film.get("releaseMi", -1)) != Game.mi():
			continue
		var quality := int(film.get("quality", 50))
		var title_s := str(film.get("title", "Ohne Titel"))
		var verdict := str(film.get("verdict", "Premiere"))
		var review := "ein tadellos gearbeitetes Studiostück"
		if quality >= 85:
			review = "ein Triumph, der selbst die abgebrühten Kritiker aufstehen lässt"
		elif quality >= 70:
			review = "elegantes Kino mit echtem Nachhall"
		elif quality < 45:
			review = "Zelluloid, das besser in der Dose geblieben wäre"
		headlines.append(_headline("Kritik", "„%s“: %s (Qualität %d/100)" % [title_s, review, quality]))
		var ratio := float(film.get("ratio", 1.0))
		if ratio < 1.0 or ratio >= 2.0:
			headlines.append(_headline("Kasse", "%s an den Kinokassen: „%s“ spielt das %0.1f-Fache seines Budgets ein" % [verdict, title_s, ratio]))

func _blind_headline(headlines: Array) -> void:
	var candidates: Array = Game.state.rumors.filter(func(r):
		return float(r.get("belief", 0.0)) >= 30.0 and float(r.get("belief", 0.0)) <= 60.0)
	if candidates.size():
		headlines.append(_headline("Blind Item", blind_item(candidates[0], int(Game.state.year))))

func _real_fallbacks(headlines: Array) -> void:
	# Auch in ruhigen Monaten erscheint eine echte Zeitung: Jeder Fallback liest
	# ausschließlich den aktuellen Simulationszustand.
	if not _has_category(headlines, "Agenturen"):
		var labels := Game.identity_top_labels()
		var identity_s := "noch ohne festes Etikett" if labels.is_empty() else " & ".join(labels)
		headlines.append(_headline("Agenturen", "%s: Ruf %d, %d Klienten — in der Stadt gilt das Haus als %s" % [Game.state.agency.name, int(Game.state.agency.rep), Game.state.clients.size(), identity_s]))
	if not _has_category(headlines, "Casting") and Game.state.castings.size():
		# Verdeckte Coverage-Castings sind noch kein öffentliches Casting
		var visible: Array = Game.state.castings.filter(func(cs): return not bool(cs.get("hidden", false)))
		if visible.size():
			var cs: Dictionary = visible[0]
			headlines.append(_headline("Casting", "%s sucht Gesichter für „%s“ — %d Rollen sind im Rennen" % [Game._studio(str(cs.studioId)).name, cs.title, cs.roles.size()]))
	if not _has_category(headlines, "Markt"):
		headlines.append(_headline("Markt", "Traumfabrik-Barometer bei %d Prozent — %d Produktionen drehen derzeit" % [roundi(float(Game.state.market) * 100.0), Game.state.productions.size()]))
	if not _has_category(headlines, "Talente"):
		if Game.state.clients.size():
			var star: Dictionary = Game.state.clients[0]
			for c in Game.state.clients:
				if float(c.fame) > float(star.fame):
					star = c
			headlines.append(_headline("Talente", "%s führt die Klientenliste von %s mit Ruhm %d an" % [Game.client_name(star), Game.state.agency.name, roundi(float(star.fame))]))
		else:
			var pool: Array = Game.available_actors()
			if pool.size():
				var actor: Dictionary = pool[0]
				headlines.append(_headline("Talente", "%s ist mit Ruhm %d der begehrteste freie Name der Stadt" % [actor.name, Game.fame_at(actor, Game.state.year)]))

func build_newspaper() -> Dictionary:
	if Game.state == null:
		return {}
	var headlines: Array = []
	_release_headlines(headlines)
	for item in Game.state.get("pressFeed", []):
		headlines.append(_headline(str(item.get("cat", "Stadtgespräch")), str(item.get("text", ""))))
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
