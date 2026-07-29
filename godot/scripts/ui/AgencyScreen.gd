extends RefCounted
# =====================================================================
# Screen „Agency“ — die Zentrale: Agentur-Karte, Stärken, Gefallen &
# Schulden, Studio-Beziehungen, Identität, Agentur-Rennen, Machtfiguren.
# Aus Main.gd extrahiert (Chunk 09): bekommt die Main-Referenz für die
# UI-Bausteine und Handler; liest den Spielzustand über die Autoloads.
# =====================================================================

var main


func _init(main_ref) -> void:
	main = main_ref


# ---------- Tab: Agency ----------
func _render_buero() -> void:
	var st = Game.state
	var grid = main._grid(560.0)
	grid.columns = clampi(grid.columns, 1, 3)
	main.content_box.add_child(grid)

	var c1 = main._card(st.agency.name, "🏢")
	grid.add_child(c1[0])
	c1[1].add_child(main._lbl("Founded %d · %s" % [int(st.startYear), Game.date_str()], 12, main.DIM))
	c1[1].add_child(main._lbl("💰 Capital: %s" % Util.fmt_money(st.agency.cash), 14, main.RED if st.agency.cash < 0 else main.TEXT_C))
	c1[1].add_child(main._lbl("⭐ Reputation: %d/100 — decides which stars will talk to you" % int(st.agency.rep), 14))
	c1[1].add_child(main._bar(st.agency.rep, main.ACC))
	c1[1].add_child(main._lbl("Office costs/month: %s (of which perks: %s)" % [Util.fmt_money(Game.overhead()), Util.fmt_money(Game.perk_costs())], 13, main.DIM))
	var bs_def := Game.backstory_def()
	if not bs_def.is_empty():
		c1[1].add_child(main._lbl("%s Backstory: %s" % [str(bs_def.get("icon", "🎬")), str(bs_def.name)], 13, main.ACC))
		var bs_trait := str(bs_def.get("trait", {}).get("de", ""))
		if bs_trait != "":
			c1[1].add_child(main._lbl("✔ " + bs_trait, 12, main.GREEN))
		var bs_weak := str(bs_def.get("weakness", {}).get("de", ""))
		if bs_weak != "":
			c1[1].add_child(main._lbl("✖ " + bs_weak, 12, main.RED))

	# RPG-Attribute (Chunk 15): die Stärken des Managers, gewachsen durch Benutzung
	var ac = main._card("Your strengths", "🎯")
	grid.add_child(ac[0])
	ac[1].add_child(main._lbl("Grow through use — every deal, every buried story, every favor leaves its mark.", 11, main.DIM))
	for attr_key in Data.ATTRIBUTES:
		var adef: Dictionary = Data.ATTRIBUTES[attr_key]
		var aval := Game.attr(str(attr_key))
		var albl = main._lbl("%s %s: %d" % [str(adef.get("icon", "")), str(adef.get("name", attr_key)), aval], 13, main.TEXT_C)
		albl.tooltip_text = str(adef.get("desc", ""))
		ac[1].add_child(albl)
		ac[1].add_child(main._bar(aval, main.ACC))

	# Konkrete Gefallen & Schulden statt eines abstrakten Netzwerk-Werts
	var cg = main._card("Favors & debts", "🤝")
	grid.add_child(cg[0])
	if st.favors.is_empty() and st.debts.is_empty():
		cg[1].add_child(main._lbl("Nobody owes you anything — and you owe nobody. In this town that is almost suspicious.", 13, main.DIM))
	for f in st.favors:
		var exp_s: String = (" · expires %s" % Game.mi_str(f.expiresMi)) if int(f.expiresMi) >= 0 else ""
		cg[1].add_child(main._lbl("🤝 %s — %s%s" % [f["from"].get("name", "?"), Game.FAVOR_KINDS.get(str(f.kind), {}).get("name", str(f.kind)), exp_s], 12, main.GREEN))
	for d in st.debts:
		cg[1].add_child(main._lbl("⚠ You owe %s: %s" % [d["from"].get("name", "?"), Game.FAVOR_KINDS.get(str(d.kind), {}).get("name", str(d.kind))], 12, main.AMBER))
	# Aktive Verwendungen: Gefallen sind Kapital, kein Sammelalbum.
	if st.favors.size():
		cg[1].add_child(main._lbl("Call one in — favors expire, doors do not wait:", 11, main.DIM))
		var cold_sid := ""
		var cold_rel := 101
		for s in Game.active_studios():
			if int(st.studioRel[s.id]) < cold_rel:
				cold_rel = int(st.studioRel[s.id])
				cold_sid = str(s.id)
		var frow := HBoxContainer.new()
		frow.add_theme_constant_override("separation", 8)
		cg[1].add_child(frow)
		if cold_sid != "":
			var door_sid := cold_sid
			var door_b = main._btn("🚪 Open a door: %s (+%d)" % [Game._studio(cold_sid).name, Balance.FAVOR_DOOR_REL], func():
				Game.pass_any_favor_to_studio(door_sid)
				main.render())
			door_b.tooltip_text = "Pass a favor along to the studio you are coldest with — relations +%d." % Balance.FAVOR_DOOR_REL
			frow.add_child(door_b)
		var reveal_b = main._btn("📞 What is not on the market yet?", func():
			var msg: String = Game.favor_reveal_casting()
			main.render()
			main._show_simple_modal("A favor, called in", msg))
		reveal_b.tooltip_text = "Spend a favor: a hidden project lands on your desk — or you hear of a new one first."
		frow.add_child(reveal_b)

	var c2 = main._card("Market %d%%" % roundi(st.market * 100.0), "📈")
	grid.add_child(c2[0])
	if int(st.strikeMonths) > 0:
		c2[1].add_child(main._chip("⚠ Strike: %d month(s) left" % int(st.strikeMonths), main.RED))
	c2[1].add_child(main._bar(clampf(st.market * 60.0, 0.0, 100.0), main.RED if st.market < 0.85 else (main.GREEN if st.market > 1.1 else main.ACC_DIM)))
	c2[1].add_child(main._lbl("👥 Clients: %d · 🎥 Productions: %d · 🎞 Brokered films: %d" % [st.clients.size(), st.productions.size(), st.released.size()], 13, main.DIM))
	var awards := 0
	for c in st.clients:
		awards += int(c.get("awards", 0))
	c2[1].add_child(main._lbl("🏆 Awards won: %d" % awards, 13, main.DIM))
	var gw = Game.genre_weights()
	var keys := gw.keys()
	keys.sort_custom(func(a, b): return gw[a] > gw[b])
	var demand: Array = []
	for k in keys.slice(0, 5):
		demand.append(main._genre_de(k))
	c2[1].add_child(main._lbl("In demand: " + " · ".join(demand), 13, main.DIM))

	var c3 = main._card("Studio relations", "🏛")
	grid.add_child(c3[0])
	for s in Game.active_studios():
		var row := HBoxContainer.new()
		var style_icon: String = {"prestige": "🎩", "indie": "🎨", "commercial": "🏭"}[s.style]
		var nm = main._lbl("%s %s" % [style_icon, s.name], 13, main.DIM)
		nm.custom_minimum_size = Vector2(250 * main.font_scale, 0)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(nm)
		var rel: float = st.studioRel[s.id]
		var pb = main._bar(rel, main.GREEN if rel >= 60 else (main.RED if rel < 30 else main.ACC_DIM))
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pb)
		c3[1].add_child(row)

	var c4 = main._card("Open promises", "📜")
	grid.add_child(c4[0])
	var any_pr := false
	for c in st.clients:
		for pr in c.promises:
			if not pr.fulfilled and not pr.get("broken", false):
				var urgent: bool = int(pr.due) - Game.mi() <= 3
				c4[1].add_child(main._lbl("📜 %s: %s — due %s" % [Game.client_name(c), pr.label, Game.mi_str(pr.due)], 13, main.RED if urgent else main.DIM))
				any_pr = true
	if not any_pr:
		c4[1].add_child(main._lbl("None. An agent without promises is an agent without clients.", 13, main.DIM))

	var ci = main._card("Moral identity", "🪞")
	grid.add_child(ci[0])
	var top_labels := Game.identity_top_labels()
	ci[1].add_child(main._lbl("Your agency is considered: %s" % ("still unwritten" if top_labels.is_empty() else " & ".join(top_labels)), 14, main.ACC))
	var identity_max := 1.0
	for key in Game.IDENTITY_KEYS:
		identity_max = maxf(identity_max, float(st.identity.get(key, 0.0)))
	for key in Game.IDENTITY_KEYS:
		var identity_row := HBoxContainer.new()
		var identity_name = main._lbl(Game.IDENTITY_LABELS[key].capitalize(), 12, main.DIM)
		identity_name.custom_minimum_size = Vector2(150 * main.font_scale, 0)
		identity_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		identity_row.add_child(identity_name)
		var identity_bar = main._bar(float(st.identity.get(key, 0.0)) / identity_max * 100.0, main.ACC_DIM, 7)
		identity_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		identity_row.add_child(identity_bar)
		ci[1].add_child(identity_row)

	var cr = main._card("The agency race", "⚔")
	grid.add_child(cr[0])
	# Marktanteils-Ranking: Star-Power aller Häuser, die eigene Agentur markiert
	var ranking: Array = Rivals.agency_ranking()
	var top_score: float = maxf(1.0, float(ranking[0].score))
	for i in ranking.size():
		var entry: Dictionary = ranking[i]
		var is_player: bool = bool(entry.isPlayer)
		var rank_row := HBoxContainer.new()
		var rank_lbl = main._lbl("#%d %s" % [i + 1, str(entry.name)], 12, main.ACC if is_player else main.DIM)
		rank_lbl.custom_minimum_size = Vector2(240 * main.font_scale, 0)
		rank_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		rank_row.add_child(rank_lbl)
		var rank_bar = main._bar(float(entry.score) / top_score * 100.0, main.GOLD if is_player else main.ACC_DIM, 7)
		rank_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rank_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rank_row.add_child(rank_bar)
		cr[1].add_child(rank_row)
	cr[1].add_child(main._lbl("Star power: combined fame of each house's roster. Unhappy clients get offers — expect counter-bids.", 11, main.DIM))
	for rival in st.rivals:
		var info: Dictionary = Rivals.RIVAL_STYLE_INFO.get(str(rival.style), {"label":str(rival.style), "icon":"◆"})
		var rr := HBoxContainer.new()
		var rival_text = main._lbl("%s %s · %s · %d clients" % [info.icon, rival.name, info.label, rival.clients.size()], 12, main.DIM)
		rival_text.custom_minimum_size = Vector2(280 * main.font_scale, 0)
		rival_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		rr.add_child(rival_text)
		var rel_value := (float(rival.rel) + 100.0) * 0.5
		var rel_bar = main._bar(rel_value, main.GREEN if float(rival.rel) >= 20.0 else (main.RED if float(rival.grudge) >= 60.0 else main.ACC_DIM), 8)
		rel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rr.add_child(rel_bar)
		cr[1].add_child(rr)
		cr[1].add_child(main._lbl("Relations %+d · Grudge %d/100%s" % [roundi(float(rival.rel)), roundi(float(rival.grudge)), (" · House studio: " + Game._studio(str(rival.studioId)).name) if str(rival.get("studioId", "")) != "" else ""], 11, main.RED if float(rival.grudge) >= 60.0 else main.DIM))

	var cp = main._card("Power players", "🎬")
	grid.add_child(cp[0])
	if st.powerFigures.is_empty():
		cp[1].add_child(main._lbl("None of your stars directs or produces yet.", 12, main.DIM))
	for figure in st.powerFigures:
		var role_label := "directing" if str(figure.role) == "director" else "producing"
		var figure_rival = Rivals.rival_by_id(str(figure.rivalId))
		var allegiance := "close to your house" if bool(figure.agencyFriendly) else ("with %s" % figure_rival.name if figure_rival != null else "independent")
		cp[1].add_child(main._lbl("🎥 %s · %s · %d Credits · %s" % [figure.name, role_label, int(figure.credits), allegiance], 12, main.GREEN if bool(figure.agencyFriendly) else main.RED))

	# Instinkt & Prognosen (Feature 6): wächst nur durch richtige Vorhersagen
	var ci2 = main._card("Instinct %d/100" % int(st.get("instinct", 20)), "🧠")
	grid.add_child(ci2[0])
	ci2[1].add_child(main._bar(float(st.get("instinct", 20)), main.GREEN if int(st.get("instinct", 20)) >= 55 else main.ACC_DIM))
	ci2[1].add_child(main._lbl("Grows only through correct predictions. Sharpens talent pool grades (spread ±%d), script insights and gut feelings." % roundi(Game.pool_spread()), 12, main.DIM))
	var open_preds: Array = st.get("predictions", []).filter(func(pr): return not pr.get("resolved", false))
	var done_preds: Array = st.get("predictions", []).filter(func(pr): return pr.get("resolved", false))
	var hits := done_preds.filter(func(pr): return pr.get("correct", false)).size()
	if done_preds.size():
		ci2[1].add_child(main._lbl("Track record: %d/%d correct" % [hits, done_preds.size()], 13, main.GREEN if hits * 2 >= done_preds.size() else main.AMBER))
	if open_preds.is_empty():
		ci2[1].add_child(main._lbl("No open predictions. Shooting starts and signings will ask for your gut call.", 12, main.DIM))
	for pr in open_preds.slice(0, 5):
		ci2[1].add_child(main._lbl("🔮 %s — resolves ~%s" % [str(pr.get("note", "prediction")), Game.mi_str(int(pr.get("dueMi", 0)))], 12, main.ACC))

	# Script Coverage: das Lektorats-Blatt auf dem Schreibtisch
	var cc = main._card("Script Coverage", "📋")
	grid.add_child(cc[0])
	var cov_stats := Coverage.coverage_stats()
	if int(cov_stats.done) > 0:
		cc[1].add_child(main._lbl("Hit rate: %d/%d correct%s" % [int(cov_stats.hits), int(cov_stats.done), (" · %d open" % int(cov_stats.open)) if int(cov_stats.open) > 0 else ""], 12, main.GREEN if int(cov_stats.hits) * 2 >= int(cov_stats.done) else main.AMBER))
	var cov_cur = st.coverage.get("current") if st.has("coverage") else null
	if cov_cur != null:
		cc[1].add_child(main._lbl("“%s” — %s casts next month. The sheet expires at the end of the month." % [str(cov_cur.title), Game._studio(str(cov_cur.studioId)).name], 13, main.TEXT_C))
		var used_marks := 0
		for sttm in cov_cur.statements:
			if str(sttm.get("marked", "")) != "":
				used_marks += 1
		cc[1].add_child(main._lbl("Markers: %d/%d set · %d statements" % [used_marks, int(cov_cur.markersMax), cov_cur.statements.size()], 12, main.AMBER if used_marks < int(cov_cur.markersMax) else main.DIM))
		cc[1].add_child(main._btn("📋 Read coverage", main._open_coverage, true))
	else:
		cc[1].add_child(main._lbl("No sheet on the desk. The story department delivers an assessment of an upcoming casting roughly once a month — optional, but often worth gold.", 12, main.DIM))
		var cov_hist: Array = st.coverage.get("history", []) if st.has("coverage") else []
		if cov_hist.size():
			cc[1].add_child(main._btn("📚 Archive (%d sheets)" % cov_hist.size(), main._open_coverage))

# ---------- Script Coverage: Lektorats-Blatt & Archiv ----------


