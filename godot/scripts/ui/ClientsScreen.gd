extends RefCounted
# =====================================================================
# Screen „Clients“ — das Roster: Klientenkarten mit Zustand, DNA,
# Narrativen, Aktionen und dem Karrierebrett.
# Aus Main.gd extrahiert (Chunk 09): bekommt die Main-Referenz für die
# UI-Bausteine und Handler; liest den Spielzustand über die Autoloads.
# =====================================================================

var main


func _init(main_ref) -> void:
	main = main_ref


# ---------- Tab: Clients (incl. career DNA & dossier) ----------
func _render_klienten() -> void:
	var st = Game.state
	if st.clients.is_empty():
		var cv = main._card("No clients yet", "👥")
		cv[1].add_child(main._lbl("Go to the talent pool and convince somebody that you will turn their career into gold.", 13, main.DIM))
		main.content_box.add_child(cv[0])
		return
	var grid = main._grid(640.0)
	main.content_box.add_child(grid)
	for c in st.clients:
		var a: Dictionary = Game.actor_by_id[c.aid]
		var busy := not Game.is_free(c)
		var cv = main._card("%s %s" % [a.name, "🏆".repeat(int(c.get("awards", 0)))])
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		var chips: Array = []
		chips.append(main._chip("🎬 On set until %s" % Game.mi_str(c.busyUntil), main.BLUE) if busy else main._chip("🟢 Available", main.GREEN))
		if c.heat >= 4:
			chips.append(main._chip("🔥 Hot +%d" % roundi(c.heat), main.RED))
		elif c.heat <= -4:
			chips.append(main._chip("❄ Cold %d" % roundi(c.heat), main.BLUE))
		if c.exhaustion > 60:
			chips.append(main._chip("⚠ Overworked", main.RED))
		if float(c.get("campaign", 0.0)) > 0.0:
			chips.append(main._chip("🏆 FYC %d" % roundi(float(c.campaign)), main.GOLD))
		if str(c.flags.get("coupleWith", "")) != "" and Game.actor_by_id.has(str(c.flags.coupleWith)):
			chips.append(main._chip("💞 %s" % Game.actor_by_id[str(c.flags.coupleWith)].name, main.GOLD))
		if str(c.flags.get("feudWith", "")) != "" and Game.actor_by_id.has(str(c.flags.feudWith)):
			chips.append(main._chip("⚡ Feud: %s" % Game.actor_by_id[str(c.flags.feudWith)].name, main.RED))
		if Game.voice_at_risk(c):
			chips.append(main._chip("🎙 Fragile voice", main.RED))
		elif c.flags.get("voiceTrained", false):
			chips.append(main._chip("🎙 Voice trained", main.GREEN))
		if c.flags.get("typecast", false):
			chips.append(main._chip("🎭 Typecast", main.AMBER))
		if c.flags.get("typecastRisk", false):
			chips.append(main._chip("⚠ Typecasting risk", main.AMBER))
		if c.flags.get("tvIncome") != null and int(c.flags.tvIncome.months) > 0:
			chips.append(main._chip("📺 TV series: %d mo." % int(c.flags.tvIncome.months), main.BLUE))
		if str(c.flags.get("powerFigure", "")) != "":
			chips.append(main._chip("🎬 Power player: %s" % ("directing" if str(c.flags.powerFigure) == "director" else "producing"), main.GOLD))
		chips.append(main._chip("📈 Rising", main.GREEN) if st.year < a.peak else main._chip("📉 Past the peak", main.DIM))
		box.add_child(main._chip_row(chips))
		box.add_child(main._lbl(main._actor_meta(a, st.year, c), 12, main.DIM))
		box.add_child(main._lbl("Talent %s · Charisma %s · Discipline %s · Presence %s" % [
			Game.grade_range(Game.eff_talent(c), 4, str(a.id) + "tal"), Game.grade_range(Util.attrs(a).charisma, 4, str(a.id) + "cha"),
			Game.grade_range(Util.attrs(a).discipline, 4, str(a.id) + "dis"), Game.grade_range(Util.attrs(a).presence, 4, str(a.id) + "pre")], 12, main.DIM))
		box.add_child(main._lbl("📄 %d%% commission · until %s · 💰 fee %s" % [int(c.commission), Game.mi_str(c.contractEnd), Util.fmt_money(Util.ask_fee(c.fame, st.year))], 12, main.DIM))
		if c.perks.size():
			box.add_child(main._lbl("🎁 " + ", ".join(c.perks.map(func(p): return Game.PERKS[p].name)), 12, main.GREEN))
		var row := GridContainer.new()
		row.columns = 5
		row.add_theme_constant_override("h_separation", 14)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(row)
		for stat in [["⭐ Fame", c.fame, main.ACC], ["❤ Loyalty", c.loyalty, main.RED if c.loyalty < 35 else main.GREEN], ["🔐 Trust", c.trust, main.RED if c.trust < 25 else main.GREEN], ["😊 Mood", c.mood, main.RED if c.mood < 35 else main.ACC_DIM], ["🔋 Exhaustion", c.exhaustion, main.RED if c.exhaustion > 60 else main.BLUE]]:
			var sv := VBoxContainer.new()
			sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sl = main._lbl("%s %d" % [stat[0], roundi(stat[1])], 11, main.DIM)
			sl.autowrap_mode = TextServer.AUTOWRAP_OFF
			sv.add_child(sl)
			sv.add_child(main._bar(stat[1], stat[2]))
			row.add_child(sv)
		# TV-/Streaming-Vertrag (Teil C3): der Serien-Chip auf der Karte
		var tv_flag = c.flags.get("tvIncome")
		if tv_flag != null and int(tv_flag.get("months", 0)) > 0:
			var tv_icon := "📱" if int(Game.state.year) >= Balance.STREAMING_YEAR else "📺"
			box.add_child(main._chip("%s Series contract · %d mo · %s/mo" % [tv_icon, int(tv_flag.months), Util.fmt_money(float(tv_flag.monthly))], main.BLUE))
		# Innenleben (Teil C1): „What drives them“ — Sichtbarkeit gestaffelt
		# über Menschenkenntnis; unter Stufe 1 fehlt die Zeile ganz.
		var drives_line := Needs.visible_line(c)
		if drives_line != "":
			box.add_child(main._lbl(drives_line, 12, main.AMBER))
		box.add_child(main._lbl("🧬 Career DNA — public image: “%s”" % CareerDNA.dna_label(c), 13, main.ACC))
		for ax in CareerDNA.DNA_AXES:
			box.add_child(main._dna_row(ax, c.dna[ax.key]))
		var narrative: Dictionary = c.get("narrative", {})
		if not narrative.is_empty():
			var narrative_info: Dictionary = Game.NARRATIVE_TYPES.get(str(narrative.type), {"label":str(narrative.type), "desc":""})
			var narrative_color = main.GREEN if str(narrative.status) == "abgeschlossen" else main.ACC
			box.add_child(main._lbl("📖 %s%s" % [narrative_info.label, " · completed" if str(narrative.status) == "abgeschlossen" else ""], 13, narrative_color))
			box.add_child(main._lbl(str(narrative_info.desc), 11, main.DIM))
			box.add_child(main._bar(float(narrative.get("progress", 0.0)), narrative_color, 8))
		elif Game.narrative_candidate_types(c).size():
			box.add_child(main._lbl("📖 Declare a possible career narrative (PR budget)", 13, main.ACC))
			var narrative_buttons := HFlowContainer.new()
			narrative_buttons.add_theme_constant_override("h_separation", 6)
			narrative_buttons.add_theme_constant_override("v_separation", 6)
			for type_s in Game.narrative_candidate_types(c):
				narrative_buttons.add_child(main._btn(str(Game.NARRATIVE_TYPES[type_s].label), main._on_narrative.bind(int(c.id), str(type_s))))
			box.add_child(narrative_buttons)
		# Award-Saison: FYC-Kampagnen für Klienten mit Hauptrolle im Klassenjahr
		if Game.fyc_eligible(c):
			var fyc_row := HFlowContainer.new()
			fyc_row.add_theme_constant_override("h_separation", 6)
			fyc_row.add_child(main._btn("🏆 Trade ads (−%s)" % Util.fmt_money(roundf(Balance.FYC_SMALL_COST * Util.infl(st.year))), main._on_fyc.bind(int(c.id), false)))
			fyc_row.add_child(main._btn("🏆 Full FYC circuit (−%s)" % Util.fmt_money(roundf(Balance.FYC_BIG_COST * Util.infl(st.year))), main._on_fyc.bind(int(c.id), true)))
			box.add_child(fyc_row)
		# Comeback (spätes Karriere-Kunststück): ein Versuch, wenn der Zenit
		# überschritten und der Ruhm tief genug gefallen ist.
		if Game.comeback_possible(c):
			box.add_child(main._btn("🌅 Stage a comeback (−%s)" % Util.fmt_money(Game.comeback_cost()), main._on_comeback.bind(int(c.id))))
		elif c.flags.get("comebackActive", false):
			box.add_child(main._lbl("🌅 Comeback in production — everything rides on the premiere.", 12, main.AMBER))
		for pr in c.promises:
			var icon := "✅" if pr.fulfilled else ("❌" if pr.get("broken", false) else "📜")
			var pcol = main.GREEN if pr.fulfilled else (main.RED if pr.get("broken", false) else main.DIM)
			box.add_child(main._lbl("%s %s" % [icon, pr.label], 12, pcol))
		if c.secrets.size():
			box.add_child(main._lbl("🔒 Confidential dossier", 13, main.ACC))
			for secret in c.secrets:
				var info: Dictionary = Scandal.SECRET_TYPES.get(str(secret.type), {"label": str(secret.type)})
				var status_text := {"geheim": "under wraps", "entschärft": "prepared", "publik": "public"}.get(str(secret.status), str(secret.status))
				var status_color = main.GREEN if str(secret.status) == "entschärft" else (main.RED if str(secret.status) == "publik" else main.DIM)
				var sicon: String = main.SECRET_ICONS.get(str(secret.type), "◆")
				var secret_row := HBoxContainer.new()
				var secret_label = main._lbl("%s %s · severity %d · %s (since %s)" % [sicon, info.label, int(secret.severity), status_text, Game.mi_str(secret.knownSince)], 12, status_color)
				secret_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				secret_row.add_child(secret_label)
				if str(secret.status) == "geheim":
					secret_row.add_child(main._btn("Prepare", main._on_secret_action.bind(int(c.id), str(secret.type), "prepare")))
				if str(secret.status) != "publik":
					secret_row.add_child(main._btn("Sell to the press …", main._on_secret_action.bind(int(c.id), str(secret.type), "sell")))
				box.add_child(secret_row)
		for f in c.films.slice(0, 3):
			var fcol = main.GREEN if f.verdict in ["Hit", "Blockbuster"] else (main.RED if f.verdict == "Flop" else main.DIM)
			box.add_child(main._lbl("🎞 “%s” (%d) — %s, Q %d" % [f.title, int(f.year), f.verdict, int(f.quality)], 12, fcol))
		_render_career_board(box, c)


# ---------- Career board: 3 plan slots with a DNA trajectory ----------
func _render_career_board(box: VBoxContainer, c: Dictionary) -> void:
	Game.ensure_board(c)
	var board: Dictionary = c.careerBoard
	var ana := Game.board_analysis(c)
	box.add_child(main._lbl("🎯 Career board — the next three projects%s" % (" · completed %d×" % int(board.get("completed", 0)) if int(board.get("completed", 0)) > 0 else ""), 13, main.ACC))
	# Ehrliche Vorschau der Folge: Bonus UND Risiko auf den Tisch
	if int(ana.planned) == Game.BOARD_SLOTS:
		if bool(ana.contrasting):
			box.add_child(main._lbl("✨ Transformation bonus: three genres in a row — the press will celebrate the versatility (Unique rises).", 11, main.GREEN))
		elif bool(ana.repetitive):
			box.add_child(main._lbl("⚠ Typecasting pull: the same profile three times — quick fame short-term, but the image hardens (risk from slot 3).", 11, main.AMBER))
		else:
			box.add_child(main._lbl("A balanced sequence — neither fireworks nor pull, but control over the image.", 11, main.DIM))
		var proj_label: String = CareerDNA.dna_label({"dna": ana.projected})
		box.add_child(main._lbl("Projection: “%s” → “%s” (under a normal run)" % [CareerDNA.dna_label(c), proj_label], 11, main.DIM))
	elif int(ana.planned) > 0:
		box.add_child(main._lbl("%d slot(s) still free — only the full sequence shows its effect." % (Game.BOARD_SLOTS - int(ana.planned)), 11, main.DIM))
	var next_open := Game.board_next_open(c)
	for i in board.slots.size():
		var slot: Dictionary = board.slots[i]
		var filled := int(slot.get("filledMi", -1)) >= 0
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 8)
		box.add_child(srow)
		if filled:
			var fl = main._lbl("✅ Slot %d: %s — fulfilled by “%s” (×1.5 imprint)" % [i + 1, Game.board_slot_label(slot), str(slot.get("filledTitle", ""))], 11, main.GREEN)
			fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			srow.add_child(fl)
		else:
			var sl2 = main._lbl("%s Slot %d: %s%s" % ["🎯" if i == next_open else "▫", i + 1, Game.board_slot_label(slot), " — up next" if i == next_open else ""], 11, main.TEXT_C if i == next_open else main.DIM)
			sl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			srow.add_child(sl2)
			srow.add_child(main._btn("✕", Game.board_slot_remove.bind(int(c.id), i)))
	if board.slots.size() < Game.BOARD_SLOTS:
		box.add_child(main._btn("＋ Plan a role profile", main._open_board_picker.bind(int(c.id))))
	# Narrativ-Integration: passende Profile per Ein-Klick-Übernahme
	var nar: Dictionary = c.get("narrative", {})
	if not nar.is_empty() and str(nar.get("status", "")) == "aktiv":
		var sug := Game.board_suggestions(c)
		var sug_labels: Array = []
		for s in sug:
			sug_labels.append(Game.board_slot_label({"genre": s[0], "roleType": s[1], "prestige": s[2]}))
		box.add_child(main._lbl("📖 Suggestion for the narrative: %s" % "  →  ".join(sug_labels), 11, main.ACC))
		box.add_child(main._btn("Adopt suggestion", main._on_board_adopt.bind(int(c.id))))



