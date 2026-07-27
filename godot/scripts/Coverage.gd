extends Node
# =====================================================================
# Script-Coverage (aus Game.gd extrahiert): das Lektorats-Blatt auf dem
# Schreibtisch — verdeckte Castings, Statements, Marker, Schnitt-Rollen
# und die Auswertung beim Release. Autoload "Coverage".
# =====================================================================

const COVERAGE_CATS = {
	"sicher":        {"name": "Safe role", "icon": "🛡", "desc": "The film won't flop: box office ≥ budget and quality ≥ 45."},
	"prestige":      {"name": "Prestige chance", "icon": "🎩", "desc": "Quality ≥ 62 — the critics will take notice. Marker grants +5 fit at the pitch."},
	"schwach":       {"name": "Weak script", "icon": "📉", "desc": "The box office stays below the budget (ratio < 1)."},
	"sleeper":       {"name": "Possible sleeper hit", "icon": "🌟", "desc": "A hit (≥ 2× budget) even though the script looks weak."},
	"schnitt":       {"name": "Danger: role gets cut", "icon": "✂", "desc": "The marked role falls victim to the final cut."},
	"problematisch": {"name": "Troubled production", "icon": "🌪", "desc": "Set friction and bad signals prevail."},
}

func _tick_coverage(_events: Array, strike: bool = false) -> void:
	if not Game.state.has("coverage") or not (Game.state.coverage is Dictionary):
		Game.state["coverage"] = {"current": null, "history": []}
	# 1. Das aktuelle Blatt verfällt zum Monatsende → ins Archiv
	var cur = Game.state.coverage.get("current")
	if cur != null and Game.mi() >= int(cur.get("dueMi", 0)):
		Coverage._archive_coverage(cur)
		Game.state.coverage["current"] = null
	# 2. Das verdeckte Coverage-Casting des Vormonats wird regulär sichtbar
	for cs in Game.state.castings:
		if bool(cs.get("hidden", false)):
			cs["hidden"] = false
	if strike:
		return
	# 3. Neues Blatt? ~60 % pro Monat, garantiert mindestens einmal pro Quartal
	Game.state["coverageQueue"] = int(Game.state.get("coverageQueue", 0)) + 1
	if Game.state.coverage.get("current") == null and (Util.chance(0.6) or int(Game.state.coverageQueue) >= 3):
		Coverage._issue_coverage()


func _issue_coverage() -> void:
	Game.state["coverageQueue"] = 0
	var casting := Game._make_casting()
	casting["hidden"] = true
	Game.state.castings.append(casting)
	var role_idx := Coverage._coverage_role_idx(casting)
	var sheet := {
		"id": Game.next_id(),
		"castingRef": int(casting.id),
		"title": str(casting.title), "genre": str(casting.genre),
		"studioId": str(casting.studioId), "prestige": int(casting.prestige),
		"logline": Coverage._coverage_logline(casting),
		"statements": Coverage._coverage_statements(casting, role_idx),
		"roleIdx": role_idx,
		"markersMax": 3 if int(Game.state.get("instinct", 20)) >= 60 else 2,
		"createdMi": Game.mi(), "dueMi": Game.mi() + 1,
	}
	Game.state.coverage["current"] = sheet
	Game.log_msg("Coverage on your desk: “%s” (%s) — assessment until the end of the month, %d markers." % [sheet.title, Game._studio(str(casting.studioId)).name, int(sheet.markersMax)], "info")


# Referenzierte Rolle bestimmen (bevorzugt eine Nebenrolle) und das verdeckte
# Rollengrößen-Flag würfeln: klein geschriebene Parts landen eher im Schnitt.
func _coverage_role_idx(casting: Dictionary) -> int:
	var idx := 0
	for i in casting.roles.size():
		if str(casting.roles[i].type) == "support":
			idx = i
			break
	var role: Dictionary = casting.roles[idx]
	var risk := 0.15
	if str(role.type) == "support":
		risk += 0.2
	if int(role.minFame) <= 18:
		risk += 0.15
	role["cutRisk"] = Util.chance(risk)
	return idx


func _coverage_logline(casting: Dictionary) -> String:
	var studio: Dictionary = Game._studio(str(casting.studioId))
	var genre_label: String = Data.GENRES[str(casting.genre)].label
	var style_phrase := {"prestige": "with clear awards ambitions", "indie": "with modest risk and a big heart", "commercial": "built for the broad audience"}.get(str(studio.get("style", "commercial")), "built for the broad audience")
	var y := int(Game.state.year)
	if y < 1970:
		return "LOGLINE: “%s” — a %s from the house of %s, %s." % [casting.title, genre_label, studio.name, style_phrase]
	if y >= 2010:
		return "Quick take: “%s” is the new %s from %s — %s, and everyone is already talking about it." % [casting.title, genre_label, studio.name, style_phrase]
	return "Logline: “%s” — a %s from %s, %s." % [casting.title, genre_label, studio.name, style_phrase]


# 4–6 kurze Aussagen: echte Indikatoren (Skriptbasis, Budget vs. Genre,
# Regie-Historie, geplante Klauseln, Rollengröße) plus Rauschen.
# Zuverlässigkeit ~70 %, steigt mit Instinkt (wie script_insight).
func _coverage_statements(casting: Dictionary, role_idx: int) -> Array:
	var rel := 0.7 + float(Game.state.get("instinct", 20)) / 1000.0
	var pool: Array = []
	# 1. Verdeckte Skriptbasis (dieselbe Formel wie script_insight / release_film)
	var script_base := 35 + int(casting.prestige) * 8 + (Util.hashs(str(casting.id) + "scr") % 21)
	var script_band := 1  # 0 schwach, 1 mittel, 2 stark
	if script_base <= 47:
		script_band = 0
	elif script_base >= 60:
		script_band = 2
	pool.append(_band_statement("scriptQ", script_band, [
		"The script stumbles from act two on — the story department sets it aside skeptically.",
		"Solid craftsmanship without big surprises, page after page.",
		"The script bears the signature of an awards contender — structure, dialogue, everything lands.",
	], rel))
	# 2. Budget vs. Genre-Anspruch
	var fee_sum := 0.0
	for r in casting.roles:
		fee_sum += float(r.fee)
	var typical := fee_sum * 3.75 + 400000.0 * Util.infl(Game.state.year) * (1.0 + int(casting.prestige) * 0.3)
	var budget_band := 1
	if float(casting.budget) > typical * 1.15:
		budget_band = 2
	elif float(casting.budget) < typical * 0.75:
		budget_band = 0
	pool.append(_band_statement("budget", budget_band, [
		"The budget looks tightly calculated — even by the genre's standards.",
		"The budget sits within the expected range for a project like this.",
		"The budget is unusually high for this genre — the studio is betting everything on one card.",
	], rel))
	# 3. Regie-Historie (deterministisch aus dem Namen abgeleitet)
	var dir_name := Game._director_name_for(casting)
	var track := Util.hashs("track:" + dir_name) % 100
	var dir_band := 1
	if track <= 40:
		dir_band = 0
	elif track >= 55:
		dir_band = 2
	pool.append(_band_statement("regie", dir_band, [
		"%s has delivered two flops in a row — internally, doubts are voiced." % dir_name,
		"On %s, studio leadership keeps its cards close." % dir_name,
		"%s is coming off a success — the studio lets things run." % dir_name,
	], rel))
	# 4. Geplante Klauseln: Hardliner-Flag des Studios
	var hardliner := Util.hashs(str(casting.id) + "hard") % 100 < 35
	pool.append(_bool_statement("klauseln", hardliner,
		"The studio internally insists on far-reaching options — sequel clauses and morality paragraphs are ready.",
		"The studio is traditionally relaxed about contract language.", rel))
	# 5. Rollengröße der referenzierten Rolle
	var role: Dictionary = casting.roles[role_idx]
	pool.append(_bool_statement("rollengroesse", bool(role.get("cutRisk", false)),
		"The role reads thin — the studio's first cut lists already mention it.",
		"The role is firmly anchored in the plot — no editor will shake it loose.", rel))
	# Mischen und auf 4–5 kürzen (mindestens 4, mit Füller auffüllen)
	pool.shuffle()
	var out: Array = pool.slice(0, mini(5, maxi(4, pool.size())))
	while out.size() < 4:
		out.append({"text": "Schedule pressure: the studio wants to hold the release date at any cost.", "truthKey": "fueller", "truth": true, "marked": ""})
	return out


# Marker setzen: eine Aussage einer Kategorie zuordnen → Prognose.
func coverage_mark(stmt_idx: int, cat: String) -> String:
	var cur = Game.state.coverage.get("current") if Game.state.has("coverage") else null
	if cur == null:
		return "No coverage sheet on the desk."
	if not COVERAGE_CATS.has(cat):
		return "Unknown category."
	var stmts: Array = cur.get("statements", [])
	if stmt_idx < 0 or stmt_idx >= stmts.size():
		return "That statement does not exist."
	var st: Dictionary = stmts[stmt_idx]
	if str(st.get("marked", "")) != "":
		return "This statement is already marked — ink dries fast."
	var used := 0
	for s in stmts:
		if str(s.get("marked", "")) != "":
			used += 1
	if used >= int(cur.get("markersMax", 2)):
		return "No markers left — only a few clear bets per sheet."
	st["marked"] = cat
	var cs = Game._casting(cur.get("castingRef", -1))
	var due := Game.mi() + (ceili(float(cs.deadline) / 4.0) if cs != null else 2) + 7
	Predictions.add_prediction("coverage",
		{"castingId": int(cur.get("castingRef", -1)), "cat": cat, "roleIdx": int(cur.get("roleIdx", 0)), "sheetId": int(cur.get("id", 0))},
		true, due, "Coverage “%s”: %s" % [str(cur.get("title", "?")), COVERAGE_CATS[cat].name])
	# Prestigechance: Die Überzeugung des Lektorats trägt durch den Pitch (+5 Passung)
	if cat == "prestige" and cs != null:
		cs["agencyBoost"] = float(cs.get("agencyBoost", 0.0)) + 5.0
	return "Marker set: %s. It resolves when “%s” hits the theaters." % [COVERAGE_CATS[cat].name, str(cur.get("title", "?"))]


# Der Schnitt-Wurf beim Release — Wahrscheinlichkeit hängt am Rollengrößen-Flag.
func _coverage_cut_roll(_prod: Dictionary, role: Dictionary) -> bool:
	return Util.chance(0.75 if bool(role.get("cutRisk", false)) else 0.12)


func _resolve_coverage_prediction(pr: Dictionary, prod: Dictionary, ratio: float, quality: int) -> void:
	var cat := str(pr.subject.get("cat", ""))
	var q := quality if quality >= 0 else 50
	var script_base := 35.0 + int(prod.prestige) * 8.0 + float(Util.hashs(str(prod.id) + "scr") % 21)
	var pos := 0
	var neg := 0
	for sg in prod.get("signals", []):
		if bool(sg.get("pos", false)):
			pos += 1
		else:
			neg += 1
	var troubled := float(prod.get("qualityMod", 0.0)) < 0.0 or neg > pos
	var ok := false
	match cat:
		"sicher":
			ok = ratio >= 1.0 and q >= 45
		"prestige":
			ok = q >= 62
		"schwach":
			ok = ratio < 1.0
		"sleeper":
			ok = ratio >= 2.0 and script_base < 62.0
		"schnitt":
			var ridx := clampi(int(pr.subject.get("roleIdx", 0)), 0, maxi(0, prod.roles.size() - 1))
			ok = prod.roles.size() > 0 and bool(prod.roles[ridx].get("_coverageCut", false))
		"problematisch":
			ok = troubled
	Predictions._resolve_prediction(pr, ok, "Coverage “%s”: %s" % [str(prod.get("title", "?")), COVERAGE_CATS.get(cat, {}).get("name", cat)])


# Abgelaufenes Blatt ins Archiv (max. 8) — inkl. der Wahrheit hinter den Aussagen.
func _archive_coverage(cur: Dictionary) -> void:
	var hist: Array = Game.state.coverage.get("history", [])
	var stmts: Array = []
	for st in cur.get("statements", []):
		stmts.append({"text": str(st.get("text", "")), "truthKey": str(st.get("truthKey", "")),
			"truth": bool(st.get("truth", false)), "marked": str(st.get("marked", ""))})
	hist.push_front({
		"id": int(cur.get("id", 0)), "title": str(cur.get("title", "")),
		"genre": str(cur.get("genre", "")), "studioId": str(cur.get("studioId", "")),
		"mi": int(cur.get("createdMi", Game.mi())), "castingRef": int(cur.get("castingRef", -1)),
		"roleIdx": int(cur.get("roleIdx", 0)), "statements": stmts,
	})
	while hist.size() > 8:
		hist.pop_back()
	Game.state.coverage["history"] = hist


# Trefferquote aller Coverage-Prognosen (für Karte & Archiv).
func coverage_stats() -> Dictionary:
	var done := 0
	var hits := 0
	var open_n := 0
	for pr in Game.state.get("predictions", []):
		if str(pr.get("type", "")) != "coverage":
			continue
		if pr.get("resolved", false):
			done += 1
			if pr.get("correct", false):
				hits += 1
		else:
			open_n += 1
	return {"done": done, "hits": hits, "open": open_n}


# ---------- Feature D: Das perfekte Rollen-Karrierebrett ----------
# Drei Plan-Slots pro Klient: Genre + Rollentyp + Prestige-Stufe als Absicht,
# kein konkreter Film. Die Folge prägt die DNA-Trajektorie — Kontrast bringt
# den Transformations-Bonus, Wiederholung den Typecasting-Sog.




# Band-Aussage (0/1/2). Mit Wahrscheinlichkeit rel stimmt die Behauptung,
# sonst wird eine andere Band-Behauptung gezeigt (Rauschen).
func _band_statement(key: String, band: int, texts: Array, rel: float) -> Dictionary:
	var shown := band
	if not Util.chance(rel):
		var others := [0, 1, 2]
		others.erase(band)
		shown = int(Util.pick(others))
	return {"text": str(texts[shown]), "truthKey": key, "truth": shown == band, "marked": ""}

func _bool_statement(key: String, fact: bool, true_text: String, false_text: String, rel: float) -> Dictionary:
	var shown := fact
	if not Util.chance(rel):
		shown = not fact
	return {"text": true_text if shown else false_text, "truthKey": key, "truth": shown == fact, "marked": ""}

