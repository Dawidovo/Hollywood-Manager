extends RefCounted
# =====================================================================
# Markt-Screens — Talentpool, Castings, Gerüchte und Filme.
# Aus Main.gd extrahiert (Chunk 09): bekommt die Main-Referenz für die
# UI-Bausteine und Handler; liest den Spielzustand über die Autoloads.
# =====================================================================

var main


func _init(main_ref) -> void:
	main = main_ref


# ---------- Tab: Rumors ----------
func _render_rumors() -> void:
	main.content_box.add_child(main._lbl("🗣 The whisper of the town", 22, main.ACC))
	main.content_box.add_child(main._lbl("The public and the industry don't believe the same things. A lie can fizzle at the box office and still end a career behind studio doors.", 13, main.DIM))
	var launch_card = main._card("Launch a rumor", "🕸")
	main.content_box.add_child(launch_card[0])
	launch_card[1].add_child(main._lbl("Deliberately seed a rumor about free or rival-represented talent. Risky: if the agency is exposed, reputation, trust and moral identity suffer.", 12, main.DIM))
	var target_buttons := HFlowContainer.new()
	target_buttons.add_theme_constant_override("h_separation", 6)
	target_buttons.add_theme_constant_override("v_separation", 6)
	for actor in Scandal.rumor_targets().slice(0, 6):
		var owner = Rivals.rival_for_actor(str(actor.id))
		var suffix := " · %s" % owner.name if owner != null else ""
		target_buttons.add_child(main._btn("🕸 %s%s" % [actor.name, suffix], main._on_rumor_launch.bind(str(actor.id))))
	launch_card[1].add_child(target_buttons)
	var known: Array = Game.state.rumors.filter(func(r): return r.knownToPlayer)
	known.sort_custom(func(a, b): return maxf(float(a.belief), float(a.get("industryBelief", 0.0))) > maxf(float(b.belief), float(b.get("industryBelief", 0.0))))
	if known.is_empty():
		var empty = main._card("The anteroom is still quiet", "🤫")
		empty[1].add_child(main._lbl("Good assistants, studio contacts and a strong network let you hear earlier what the town is saying.", 13, main.DIM))
		main.content_box.add_child(empty[0])
		return
	var grid = main._grid(620.0)
	main.content_box.add_child(grid)
	for rumor in known:
		var cv = main._card(Scandal.rumor_subject_name(rumor), "🗣")
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		box.add_child(main._rich("[i]“%s”[/i]" % rumor.text, 14))
		var chips: Array = [main._chip("Topic: %s" % str(rumor.topic).capitalize(), main.BLUE), main._chip("⏳ %d month(s) in circulation" % int(rumor.age), main.DIM)]
		if Scandal.player_knows_rumor_truth(rumor):
			chips.append(main._chip("🔒 Confirmed by your dossier", main.GREEN))
		if rumor.belief >= 60:
			chips.append(main._chip("⚠ Publicly effective", main.RED))
		if float(rumor.get("industryBelief", 0.0)) >= 60:
			chips.append(main._chip("🏛 Effective inside the industry", main.AMBER))
		box.add_child(main._chip_row(chips))
		box.add_child(main._lbl("Public %d/100" % roundi(rumor.belief), 12, main.RED if rumor.belief >= 60 else main.DIM))
		box.add_child(main._bar(rumor.belief, main.RED if rumor.belief >= 60 else main.ACC_DIM, 10))
		box.add_child(main._lbl("Industry %d/100" % roundi(float(rumor.get("industryBelief", 0.0))), 12, main.AMBER if float(rumor.get("industryBelief", 0.0)) >= 60 else main.DIM))
		box.add_child(main._bar(float(rumor.get("industryBelief", 0.0)), main.AMBER if float(rumor.get("industryBelief", 0.0)) >= 60 else main.BLUE, 10))
		box.add_child(main._lbl("👥 Known carriers: %s" % ", ".join(rumor.holders), 12, main.DIM))
		var actions := HFlowContainer.new()
		actions.add_theme_constant_override("h_separation", 6)
		actions.add_theme_constant_override("v_separation", 6)
		box.add_child(actions)
		actions.add_child(main._btn("📢 Deny", main._on_rumor_action.bind(int(rumor.id), "deny")))
		actions.add_child(main._btn("🏛 Studio talks", main._on_rumor_action.bind(int(rumor.id), "studio")))
		actions.add_child(main._btn("🤫 Suppress", main._on_rumor_action.bind(int(rumor.id), "suppress"), true))
		actions.add_child(main._btn("🌀 Counter-rumor", main._on_rumor_action.bind(int(rumor.id), "counter")))
		actions.add_child(main._btn("⏳ Wait it out", main._on_rumor_action.bind(int(rumor.id), "wait")))


# ---------- Tab: Talent pool ----------
func _render_pool() -> void:
	var st = Game.state
	var filter_row := HBoxContainer.new()
	main.content_box.add_child(filter_row)
	var fe := LineEdit.new()
	fe.placeholder_text = "🔍 Search name …"
	fe.text = main.pool_filter
	fe.custom_minimum_size = Vector2(240, 32)
	fe.text_changed.connect(func(t): main.pool_filter = t; main._refresh_pool_list())
	filter_row.add_child(fe)
	filter_row.add_child(main._lbl_fill("  Big names only negotiate with agencies of standing. Values = industry assessment (spread).", 12, main.DIM))
	var list := VBoxContainer.new()
	list.name = "PoolList"
	list.add_theme_constant_override("separation", 8)
	main.content_box.add_child(list)
	main._fill_pool_list(list)


# ---------- Tab: Castings ----------
func _render_castings() -> void:
	var st = Game.state
	if int(st.strikeMonths) > 0:
		var cv0 = main._card("Strike!", "⚠")
		cv0[1].add_child(main._lbl("All castings rest for %d more month(s)." % int(st.strikeMonths), 13, main.DIM))
		main.content_box.add_child(cv0[0])
		return
	# Coverage-Castings bleiben bis nächsten Monat verdeckt
	var visible_castings: Array = st.castings.filter(func(cs): return not bool(cs.get("hidden", false)))
	if visible_castings.is_empty():
		var cv1 = main._card("No open castings", "🎬")
		cv1[1].add_child(main._lbl("Next month the studios will announce new projects.", 13, main.DIM))
		main.content_box.add_child(cv1[0])
		return
	var grid = main._grid(620.0)
	main.content_box.add_child(grid)
	for cs in visible_castings:
		var studio = Game._studio(cs.studioId)
		var cv = main._card("“%s”" % cs.title, main.GENRE_ICONS.get(cs.genre, "🎬"))
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		var rel: float = st.studioRel[cs.studioId]
		box.add_child(main._chip_row([
			main._chip(main._genre_de(cs.genre), main.BLUE),
			main._chip("★".repeat(int(cs.prestige)) + "☆".repeat(3 - int(cs.prestige)), main.ACC),
			main._chip("⏳ %d wk" % int(cs.deadline), main.RED if int(cs.deadline) <= 4 else main.DIM),
			main._chip("🏛 Relations %d" % int(rel), main.GREEN if rel >= 60 else (main.RED if rel < 30 else main.DIM)),
		]))
		box.add_child(main._lbl("%s · Budget %s" % [studio.name, Util.fmt_money(cs.budget)], 12, main.DIM))
		if cs.has("director"):
			box.add_child(main._lbl("🎬 Director: %s%s" % [cs.director.name, " · favors your agency" if bool(cs.director.agencyFriendly) else " · from a rival house"], 12, main.GREEN if bool(cs.director.agencyFriendly) else main.RED))
		if cs.has("producer"):
			box.add_child(main._lbl("💼 Producer: %s%s" % [cs.producer.name, " · favors your agency" if bool(cs.producer.agencyFriendly) else " · from a rival house"], 12, main.GREEN if bool(cs.producer.agencyFriendly) else main.RED))
		if Game.chem_read_available(cs):
			box.add_child(main._btn("🧪 Arrange a chemistry read", main._start_chem_read_ui.bind(int(cs.id)), true))
			box.add_child(main._lbl("Two open roles, two pairings of your own — plus the studio's suggestion. Skippable at any time.", 11, main.DIM))
		for i in cs.roles.size():
			var r: Dictionary = cs.roles[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			box.add_child(row)
			var desc := "%s %s (%s, %d–%d yrs) · from ⭐ %d · ca. %s" % ["🎯" if r.type == "lead" else "▫", "Lead" if r.type == "lead" else "Supporting role", "♂" if r.gender == "m" else "♀", int(r.ageMin), int(r.ageMax), int(r.minFame), Util.fmt_money(r.fee)]
			var dl = main._lbl(desc, 12, main.TEXT_C if r.type == "lead" else main.DIM)
			dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dl.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(dl)
			if r.filled == null:
				row.add_child(main._btn("Pitch a client", main._open_pitch.bind(int(cs.id), i)))
			elif r.filled.get("clientId") != null:
				var cl = Game.client(r.filled.clientId)
				var st_lbl = main._lbl("✅ %s (%s)" % [Game.client_name(cl) if cl else "?", Util.fmt_money(r.filled.fee)], 12, main.GREEN)
				st_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF  # sonst Buchstaben-Umbruch neben Expand-Label
				row.add_child(st_lbl)
			else:
				var npc_lbl = main._lbl(r.filled.get("name", "?"), 12, main.DIM)
				npc_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
				row.add_child(npc_lbl)


# ---------- Tab: Films ----------
func _render_filme() -> void:
	var st = Game.state
	if st.productions.size():
		main.content_box.add_child(main._lbl("🎥 In production", 18, main.ACC))
		var grid = main._grid(560.0)
		main.content_box.add_child(grid)
		for p in st.productions:
			var cv = main._card("“%s”" % p.title, main.GENRE_ICONS.get(p.genre, "🎥"))
			grid.add_child(cv[0])
			var names: Array = []
			for r in p.roles:
				if r.filled != null:
					if r.filled.get("clientId") != null:
						var cl = Game.client(r.filled.clientId)
						names.append("👤 " + (Game.client_name(cl) if cl else "?"))
					else:
						names.append(r.filled.get("name", "?"))
			cv[1].add_child(main._lbl("%s · %s · Budget %s" % [Game._studio(p.studioId).name, main._genre_de(p.genre), Util.fmt_money(p.budget)], 12, main.DIM))
			cv[1].add_child(main._lbl("Cast: " + ", ".join(names), 12, main.DIM))
			Game.ensure_prod_fields(p)
			cv[1].add_child(main._chip_row([main._chip("🎬 Release in ~%d wk" % int(p.weeksLeft), main.BLUE)]))
			# Produktions-Signale (Feature 13): Set-Gerede statt Fakten
			if p.signals.size():
				var srow := HFlowContainer.new()
				srow.add_theme_constant_override("h_separation", 6)
				cv[1].add_child(srow)
				for sig in p.signals:
					srow.add_child(main._chip(("🟢 " if bool(sig.get("pos", true)) else "🔴 ") + str(sig.get("t", "")), main.GREEN if bool(sig.get("pos", true)) else main.RED))
				cv[1].add_child(main._lbl("Signals are set talk — the hit rate rises with your instinct.", 10, main.DIM))
				var has_client_here := false
				for r in p.roles:
					if r.filled != null and r.filled.get("clientId") != null and Game.client(r.filled.clientId) != null:
						has_client_here = true
				if has_client_here:
					var pid := int(p.id)
					cv[1].add_child(main._nego_actions({
						"label": "Renegotiate", "cb": main._run_production_negotiation.bind(pid, "reneg"), "disabled": bool(p.reactions.get("reneg", false)),
					}, [
						{"label": "Pull the client", "cb": main._run_production_negotiation.bind(pid, "pull"), "disabled": bool(p.reactions.get("pull", false))},
						{"label": "Demand participation", "cb": main._run_production_negotiation.bind(pid, "share"), "disabled": bool(p.reactions.get("share", false))},
					], null))
	if st.released.size():
		main.content_box.add_child(main._lbl("🎞 Released", 18, main.ACC))
		var txt := ""
		for f in st.released.slice(0, 30):
			var col := "#c0504d" if f.ratio < 1.0 else ("#7da05c" if f.ratio >= 2.0 else "#a89b7e")
			var vicon := "💥" if f.verdict == "Blockbuster" else ("✅" if f.ratio >= 2.0 else ("❌" if f.ratio < 1.0 else "▫"))
			txt += "%d  %s “%s” (%s) — Q %d · %s · [color=%s]%s %s[/color]\n" % [int(f.year), main.GENRE_ICONS.get(f.genre, ""), f.title, Game._studio(f.studioId).name, int(f.quality), Util.fmt_money(f.revenue), col, vicon, f.verdict]
		main.content_box.add_child(main._rich(txt, 13))
	if st.productions.is_empty() and st.released.is_empty():
		var cv = main._card("No films yet", "🎞")
		cv[1].add_child(main._lbl("Place clients in castings — once a film wraps, it appears here.", 13, main.DIM))
		main.content_box.add_child(cv[0])


