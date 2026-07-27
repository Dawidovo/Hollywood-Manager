extends Node
# =====================================================================
# Instinkt-Prognosen (aus Game.gd extrahiert): Wetten auf Hits, Stars
# und Besetzungen — anlegen, auflösen, Instinkt- und Attributs-Wachstum.
# Autoload "Predictions"; liest den Spielzustand über Game.state.
# =====================================================================

# ---------- Feature 6: Instinkt & Prognosen ----------
# Game.state.instinct wächst NUR durch richtige Spieler-Prognosen.
func add_prediction(type_s: String, subject, guess, due_mi: int, note_s: String = "") -> Dictionary:
	var pr := {"id": Game.next_id(), "type": type_s, "subject": subject, "guess": guess,
		"dueMi": due_mi, "resolved": false, "correct": false, "note": note_s, "madeMi": Game.mi()}
	Game.state.predictions.append(pr)
	Game.log_msg("Prediction noted: %s" % note_s, "info")
	return pr


# (a) Drehbeginn: „Wird das ein Hit (ratio ≥ 2)?“
func hit_prediction_event(prod: Dictionary, c: Dictionary) -> Dictionary:
	var pid := int(prod.id)
	var title_s := str(prod.title)
	var name_s := Game.client_name(c)
	return {"title": "Gut check: “%s”" % title_s,
		"text": "[i]“On the first day of shooting everyone pretends to know what this will become. Nobody knows.”[/i]\n\n“%s” with %s goes into production. Your call: will the film be a hit (box office ≥ 2× budget)?\n\nCorrect predictions sharpen your instinct (%d/100). Staying silent costs nothing." % [title_s, name_s, int(Game.state.get("instinct", 20))],
		"choices": [
			{"label": "Yes, this will be a hit", "fn": func():
				Predictions.add_prediction("hit", pid, true, Game.mi() + 30, "“%s” will be a hit" % title_s)
				return "Noted. At the premiere we'll see whether your gut was right."},
			{"label": "No, more likely a flop", "fn": func():
				Predictions.add_prediction("hit", pid, false, Game.mi() + 30, "“%s” will not be a hit" % title_s)
				return "Noted. At the premiere we'll see whether your gut was right."},
			{"label": "No call", "fn": func(): return "You keep your cards close — not every premiere needs a bet."},
		]}


# (b) Signing unter Ruhm 40: „Zukünftiger Star (Ruhm 70 in 8 Jahren)?“
func star_prediction_event(c: Dictionary) -> Dictionary:
	var cid := int(c.id)
	var name_s := Game.client_name(c)
	return {"title": "Gut check: %s" % name_s,
		"text": "[i]“That one might become something — or not.”[/i]\n\nYou signed %s at fame %d. Your call: does %s reach fame 70 within 8 years?\n\nCorrect predictions sharpen your instinct (%d/100). Staying silent costs nothing." % [name_s, roundi(c.fame), name_s, int(Game.state.get("instinct", 20))],
		"choices": [
			{"label": "Yes, a future star", "fn": func():
				Predictions.add_prediction("star", cid, true, Game.mi() + 96, "%s reaches fame 70" % name_s)
				return "Noted. In eight years at the latest, we'll know."},
			{"label": "No, probably not", "fn": func():
				Predictions.add_prediction("star", cid, false, Game.mi() + 96, "%s stays below fame 70" % name_s)
				return "Noted. In eight years at the latest, we'll know."},
			{"label": "No call", "fn": func(): return "You keep your cards close."},
		]}


func pop_pending_star_prediction() -> Variant:
	if not Game.state.has("pendingStarPrediction"):
		return null
	var cid = Game.state.pendingStarPrediction
	Game.state.erase("pendingStarPrediction")
	var c = Game.client(cid)
	return Predictions.star_prediction_event(c) if c != null else null


# (c) Casting mit 2+ passenden Klienten: „Wer passt besser?“
func note_betterfit_prediction(chosen_c: Dictionary, alt_c: Dictionary, casting_id: int) -> void:
	Predictions.add_prediction("betterfit",
		{"prodId": casting_id, "chosen": int(chosen_c.id), "other": int(alt_c.id), "otherFame": float(alt_c.fame)},
		true, Game.mi() + 30, "%s fits better than %s" % [Game.client_name(chosen_c), Game.client_name(alt_c)])


func _resolve_prediction(pr: Dictionary, correct: bool, label: String) -> void:
	pr["resolved"] = true
	pr["correct"] = correct
	if correct:
		Game.state.instinct = clampi(int(Game.state.instinct) + 3, 0, 100)
		Game.attr_gain("menschenkenntnis", 0.5)
		Game.state.agency.rep = clampi(int(Game.state.agency.rep) + 1, 0, 100)
		Game.log_msg("Prediction confirmed: %s — instinct +3, reputation +1." % label, "deal")
	else:
		Game.state.instinct = maxi(5, int(Game.state.instinct) - 1)
		Game.log_msg("Prediction missed: %s — instinct −1." % label, "info")


# Auflösung beim Release (Hit-Wette, „Wer passt besser?“, Coverage-Marker)
func _resolve_release_predictions(prod: Dictionary, ratio: float, fame_deltas: Dictionary, quality: int = -1) -> void:
	for pr in Game.state.get("predictions", []):
		if pr.get("resolved", false):
			continue
		if str(pr.type) == "hit" and int(pr.subject) == int(prod.id):
			Predictions._resolve_prediction(pr, (ratio >= 2.0) == bool(pr.guess), "“%s” (%s)" % [prod.title, "hit" if ratio >= 2.0 else "no hit"])
		elif str(pr.type) == "betterfit" and int(pr.subject.get("prodId", -1)) == int(prod.id):
			var chosen_delta := float(fame_deltas.get(int(pr.subject.get("chosen", -1)), 0.0))
			var other_c = Game.client(pr.subject.get("other", -1))
			var other_delta := (float(other_c.fame) - float(pr.subject.get("otherFame", 0.0))) if other_c != null else -99.0
			Predictions._resolve_prediction(pr, (chosen_delta >= other_delta) == bool(pr.guess), str(pr.get("note", "casting prediction")))
		elif str(pr.type) == "coverage" and int(pr.subject.get("castingId", -1)) == int(prod.id):
			Coverage._resolve_coverage_prediction(pr, prod, ratio, quality)


# Monatstakt: Star-Prognosen verfallen nach 8 Jahren; Sicherheits-Verfall ohne Strafe
func tick_predictions(_events: Array) -> void:
	for pr in Game.state.get("predictions", []):
		if pr.get("resolved", false):
			continue
		match str(pr.type):
			"star":
				if Game.mi() >= int(pr.dueMi):
					var c = Game.client(pr.subject)
					var fame_now := float(c.fame) if c != null else 0.0
					Predictions._resolve_prediction(pr, (fame_now >= 70.0) == bool(pr.guess), str(pr.get("note", "star prediction")))
			"hit", "betterfit", "coverage":
				if Game.mi() >= int(pr.dueMi) + 12:
					pr["resolved"] = true


