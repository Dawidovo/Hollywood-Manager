extends RefCounted
# =====================================================================
# Welt-Screens — Post & Dialogansicht, Orte, Lifestyle, Investments,
# Zeitung, Journal, Chronik und Wochenplaner.
# Aus Main.gd extrahiert (Chunk 09): bekommt die Main-Referenz für die
# UI-Bausteine und Handler; liest den Spielzustand über die Autoloads.
# =====================================================================

var main


func _init(main_ref) -> void:
	main = main_ref


func _render_dialog_view(view: Dictionary) -> void:
	main._open_modal()
	main.modal_box.add_child(main._lbl(str(view.title), 22, main.ACC))
	main.modal_box.add_child(main._rich(str(view.text), 14))
	for line in view.get("lines", []):
		main.modal_box.add_child(main._rich("[color=#%s]▸ %s[/color]" % [main.AMBER.to_html(false), str(line)], 13))
	if bool(view.get("done", false)):
		main.modal_box.add_child(main._btn("Continue", main._modal_done, true))
		return
	for i in view.choices.size():
		var ch: Dictionary = view.choices[i]
		var b = main._btn(str(ch.label), main._dialog_choose.bind(i))
		b.disabled = bool(ch.disabled)
		if str(ch.get("reason", "")) != "":
			b.tooltip_text = "⛔ " + str(ch.reason)
		main.modal_box.add_child(b)


func _render_post() -> void:
	var st = Game.state
	var head = main._card("This week's %s" % Dialogs.mail_word().to_lower(), Dialogs.mail_icon())
	main.content_box.add_child(head[0])
	head[1].add_child(main._lbl("Everything that reaches your desk lands here: invitations, requests, demands, opportunities. Most of it can wait — none of it forever.", 12, main.DIM))
	head[1].add_child(main._lbl("Contact time this week: %d⏱ — some replies cost time, all of them say something about you." % int(st.contactAP), 11, main.DIM))
	var letters: Array = Dialogs.open_letters()
	if letters.is_empty():
		head[1].add_child(main._lbl("The tray is empty. Enjoy it — it never lasts.", 13, main.DIM))
	for letter in letters:
		var lv = main._card("%s — %s" % [letter["from"].get("name", "?"), str(letter.subject)], Dialogs.mail_icon())
		main.content_box.add_child(lv[0])
		lv[1].add_child(main._lbl("Received %s · expires %s" % [Game.mi_str(letter.mi), "soon" if Game.wi() >= int(letter.expireWi) else "in %d week(s)" % (int(letter.expireWi) - Game.wi())], 11, main.DIM))
		lv[1].add_child(main._rich(str(letter.body), 14))
		var def: Dictionary = Dialogs.letter_def(str(letter.tid))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		lv[1].add_child(flow)
		var choices: Array = def.get("choices", [])
		for i in choices.size():
			var ch: Dictionary = choices[i]
			var b = main._btn(EvEngine.subst(str(ch.get("label", "…")), Dialogs._letter_ctx(letter)), main._on_letter_choice.bind(int(letter.id), i))
			var reason: String = Dialogs.letter_choice_blocked(letter, ch)
			b.disabled = reason != ""
			if reason != "":
				b.tooltip_text = "⛔ " + reason
			flow.add_child(b)
		# Notizen (Bedeutungsstaffelung): nur zur Kenntnis nehmen
		if choices.is_empty():
			flow.add_child(main._btn("File away", main._player_action.bind(Dialogs.dismiss_letter.bind(int(letter.id)))))
	# Archiv: erledigte & verfallene Post der letzten Wochen
	var archive: Array = st.inbox.filter(func(l): return str(l.status) != "open")
	if not archive.is_empty():
		var av = main._card("Filed away", "🗄")
		main.content_box.add_child(av[0])
		archive.reverse()
		for letter in archive.slice(0, 8):
			var status := str(letter.status)
			var color = main.GREEN if status == "done" else main.DIM
			var line := "%s · %s — %s" % [Game.mi_str(letter.mi), letter["from"].get("name", "?"), str(letter.subject)]
			if status == "expired":
				line += "  (went unanswered)"
			var al = main._lbl(line, 12, color)
			if str(letter.get("outcome", "")) != "":
				al.tooltip_text = str(letter.outcome)
			av[1].add_child(al)


func _render_orte() -> void:
	var st = Game.state
	var cur: Dictionary = Persona.location_def()
	var head = main._card("Presence", "🗺")
	main.content_box.add_child(head[0])
	head[1].add_child(main._lbl("You are in: %s %s" % [str(cur.icon), str(cur.name)], 16, main.ACC))
	if Persona.is_away():
		head[1].add_child(main._lbl("⚠ Without you in L.A.: clients lose trust and mood every week, and meetings or club nights with your contacts are impossible.", 12, main.AMBER))
	else:
		head[1].add_child(main._lbl("Traveling costs the week's contact time, energy and agency expenses. Whoever is away misses what happens at home — and finds doors elsewhere that L.A. does not have.", 12, main.DIM))

	var grid = main._grid(520.0)
	main.content_box.add_child(grid)
	for loc in Data.LOCATIONS:
		var id_s := str(loc.id)
		var cv = main._card("%s %s" % [str(loc.icon), str(loc.name)])
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		box.add_child(main._lbl(str(loc.desc), 12, main.DIM))
		if loc.has("months"):
			box.add_child(main._chip("📅 Season: %s" % Game.MONTHS[int(loc.months[0]) - 1], main.AMBER))
		if id_s == Persona.location_id():
			box.add_child(main._chip("📍 You are here", main.GREEN))
			if loc.get("action") != null:
				box.add_child(main._lbl(str(loc.action.desc), 11, main.DIM))
				var ab = main._btn("★ %s" % str(loc.action.name), main._on_location_action, true)
				ab.disabled = not Persona.location_action_available()
				ab.tooltip_text = str(loc.action.desc) + ("" if not ab.disabled else "\n⛔ Already done this week")
				box.add_child(ab)
		else:
			var cost := Persona.travel_cost(id_s)
			var label := "✈ Travel there" if id_s != "la" else "✈ Back to Los Angeles"
			if cost > 0.0:
				label += " (−%s)" % Util.fmt_money(cost)
			var tb = main._btn(label, main._on_travel.bind(id_s), id_s == "la")
			var reason: String = Persona.travel_blocked_reason(id_s)
			tb.disabled = reason != ""
			tb.tooltip_text = "Costs the week's contact time and %d energy." % roundi(float(loc.energy)) + ("" if reason == "" else "\n⛔ " + reason)
			box.add_child(tb)


func _render_lifestyle() -> void:
	var st = Game.state
	var home: Dictionary = Mogul.home_def()
	var head = main._card("Lifestyle", "🏠")
	main.content_box.add_child(head[0])
	head[1].add_child(main._lbl("You live at: %s %s (tier %d)" % [str(home.icon), str(home.name), int(home.tier)], 16, main.ACC))
	head[1].add_child(main._lbl("Running lifestyle costs: %s/month (home & purchases, paid privately). Private account: %s." % [Util.fmt_money(Mogul.upkeep_total()), Util.fmt_money(st.player.cash)], 12, main.DIM))
	head[1].add_child(main._lbl("An address is a statement: prestige lifts your public name, privacy protects secrets, capacity lets you host — and whoever lives beneath their title pays for it in standing. Moving down is noticed.", 11, main.DIM))
	if Mogul.can_host():
		head[1].add_child(main._btn("🥂 Host a reception (−%s, once a month)" % Util.fmt_money(Mogul.reception_cost()), main._on_host_reception, true))
	elif int(home.get("capacity", 0)) >= 3:
		head[1].add_child(main._lbl("A reception has already filled this month's calendar.", 11, main.DIM))

	var grid = main._grid(520.0)
	main.content_box.add_child(grid)
	var hv = main._card("Residences", "🔑")
	grid.add_child(hv[0])
	for h in Data.ESTATE_HOMES:
		var id_s := str(h.id)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		hv[1].add_child(box)
		var current := id_s == Mogul.home_id()
		box.add_child(main._lbl("%s %s%s" % [str(h.icon), str(h.name), "  ← you live here" if current else ""], 14, main.ACC if current else main.TEXT_C))
		box.add_child(main._lbl(str(h.desc), 11, main.DIM))
		var stats := "Prestige %d · Privacy %d · Guests %d · Upkeep %s/mo" % [int(h.prestige), int(h.privacy), int(h.capacity), Util.fmt_money(roundf(float(h.upkeep) * Util.infl(st.year)))]
		if float(h.get("paparazzi", 0.0)) > 0.0:
			stats += " · 📸 risk"
		box.add_child(main._lbl(stats, 11, main.DIM))
		if not current:
			var price := Mogul.home_price(id_s)
			var label := "Move in (−%s" % Util.fmt_money(price)
			if Mogul.home_value() > 0.0:
				label += ", old home sells for %s" % Util.fmt_money(Mogul.home_value())
			label += ")"
			if int(h.tier) < int(home.get("tier", 0)):
				label += " ⚠ downgrade"
			var b = main._btn(label, main._estate_action.bind(Mogul.buy_home.bind(id_s)))
			var reason := Mogul.home_blocked_reason(id_s)
			b.disabled = reason != ""
			b.tooltip_text = reason
			box.add_child(b)

	var pv = main._card("Status purchases", "🛍")
	grid.add_child(pv[0])
	pv[1].add_child(main._lbl("Every purchase buys access, time or protection — and adds to the monthly bill.", 11, main.DIM))
	for pdef in Data.ESTATE_PURCHASES:
		var pid := str(pdef.id)
		var box2 := VBoxContainer.new()
		box2.add_theme_constant_override("separation", 2)
		pv[1].add_child(box2)
		var owned := Mogul.owns(pid)
		box2.add_child(main._lbl("%s %s%s" % [str(pdef.icon), str(pdef.name), "  ✔ yours" if owned else ""], 14, main.ACC if owned else main.TEXT_C))
		box2.add_child(main._lbl("%s Upkeep %s/mo." % [str(pdef.desc), Util.fmt_money(roundf(float(pdef.upkeep) * Util.infl(st.year)))], 11, main.DIM))
		if owned:
			var value := Mogul.purchase_value(pid)
			var sell_label := "Sell (+%s)" % Util.fmt_money(value) if value > 0.0 else "Cancel"
			box2.add_child(main._btn(sell_label, main._player_action.bind(Mogul.sell_purchase.bind(pid))))
		else:
			var b2 = main._btn("Buy (−%s private)" % Util.fmt_money(Mogul.purchase_price(pid)), main._estate_action.bind(Mogul.buy_purchase.bind(pid)))
			var reason2 := Mogul.purchase_blocked_reason(pid)
			b2.disabled = reason2 != ""
			b2.tooltip_text = reason2
			box2.add_child(b2)


func _render_invest() -> void:
	var st = Game.state
	Mogul.ensure_prices()
	var p: Dictionary = st.player
	var head = main._card("Your money", "📈")
	main.content_box.add_child(head[0])
	head[1].add_child(main._lbl("Private account: %s · Portfolio: %s" % [Util.fmt_money(p.cash), Util.fmt_money(Mogul.portfolio_value())], 16, main.ACC))
	head[1].add_child(main._lbl("Everything here runs on private money — the agency till stays untouched. The interesting part is never the ticker itself: it is who whispers to you, and whom you owe when it pays off.", 11, main.DIM))
	if Mogul.has_advisor():
		var adv: Dictionary = st.invest.advisor
		head[1].add_child(main._lbl("💼 %s manages the portfolio (skill %d, fee %s/mo): acts on open tips — but their judgement is not always yours." % [str(adv.name), int(adv.skill), Util.fmt_money(Mogul.advisor_fee())], 12, main.TEXT_C))
		head[1].add_child(main._btn("Dismiss the financial manager", main._player_action.bind(Mogul.fire_advisor)))
	else:
		head[1].add_child(main._btn("💼 Hire a financial manager (fee ≈ %s/mo)" % Util.fmt_money(roundf(140.0 * Util.infl(st.year))), main._player_action.bind(Mogul.hire_advisor)))

	# Open tips
	var open_tips: Array = st.invest.tips.filter(func(t): return not bool(t.resolved))
	if not open_tips.is_empty():
		var tv = main._card("Whispers", "💹")
		main.content_box.add_child(tv[0])
		for tip in open_tips:
			var def: Dictionary = Mogul.stock_def(str(tip.companyId))
			tv[1].add_child(main._lbl("%s %s: %s expects the stock to go %s (by %s).%s" % [str(def.get("icon", "📈")), str(def.get("name", tip.companyId)), str(tip.source), "up" if int(tip.dir) > 0 else "down", Game.mi_str(tip.dueMi), "  🤫 insider" if bool(tip.insider) else ""], 12, main.AMBER if bool(tip.insider) else main.TEXT_C))
		tv[1].add_child(main._lbl("Trading on insider whispers works — until the timing of your trades starts asking questions.", 11, main.DIM))

	# Ticker
	var sv = main._card("The ticker", "🗠")
	main.content_box.add_child(sv[0])
	for def in Mogul.stock_defs():
		var id_s := str(def.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		sv[1].add_child(row)
		var tr := Mogul.trend(id_s)
		var arrow := "→"
		if tr > 1.0:
			arrow = "↗"
		if tr < -1.0:
			arrow = "↘"
		var name_l = main._lbl("%s %s" % [str(def.icon), str(def.name)], 12, main.TEXT_C)
		name_l.custom_minimum_size = Vector2(230 * main.font_scale, 0)
		name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_l.tooltip_text = "%s — %s" % [str(def.sector), str(def.get("desc", ""))]
		row.add_child(name_l)
		var price_l = main._lbl("$%.2f %s %+.1f%%" % [Mogul.price(id_s), arrow, tr], 12, main.GREEN if tr > 1.0 else (main.RED if tr < -1.0 else main.DIM))
		price_l.custom_minimum_size = Vector2(130 * main.font_scale, 0)
		price_l.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(price_l)
		if Mogul.has_ability("market_nose"):
			var drift_l = main._lbl("nose: %s" % ("solid" if float(def.drift) >= 0.004 else "sluggish"), 11, main.DIM)
			drift_l.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(drift_l)
		var held := Mogul.shares_of(id_s)
		if held > 0:
			var held_l = main._lbl("%d× (%s)" % [held, Util.fmt_money(held * Mogul.price(id_s))], 12, main.ACC)
			held_l.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(held_l)
		for budget in [500, 2500]:
			var amount := roundf(float(budget) * Util.infl(st.year))
			var bb = main._btn("Buy %s" % Util.fmt_money(amount), main._on_trade.bind(id_s, "buy", amount))
			bb.disabled = float(p.cash) < amount
			row.add_child(bb)
		if held > 0:
			row.add_child(main._btn("Sell all", main._on_trade.bind(id_s, "sell", 0.0)))

	# Film stakes
	var fv = main._card("Film stakes", "🎬")
	main.content_box.add_child(fv[0])
	fv[1].add_child(main._lbl("Equity (5% of budget) pays out with the box office. Profit points cost less (2%) but only pay on a real hit. Putting your own client into a picture you financed is lucrative — and a conflict of interest someone may notice.", 11, main.DIM))
	for stk in st.filmStakes:
		fv[1].add_child(main._lbl("💼 “%s”: %s as %s%s%s" % [str(stk.title), Util.fmt_money(float(stk.amount)), "equity" if str(stk.type) == "equity" else "profit points", "  ⚠ conflict of interest" if bool(stk.conflict) else "", "  📣 boosted" if bool(stk.boosted) else ""], 12, main.AMBER if bool(stk.conflict) else main.TEXT_C))
	for target in Mogul.stake_targets():
		var ref: Dictionary = target.ref
		var have: Dictionary = Mogul.stake_for(int(ref.id))
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 8)
		fv[1].add_child(row2)
		var t_l = main._lbl("“%s” (%s, budget %s)" % [str(ref.title), "casting" if str(target.phase) == "casting" else "shooting", Util.fmt_money(float(ref.get("budget", 0)))], 12, main.TEXT_C)
		t_l.custom_minimum_size = Vector2(300 * main.font_scale, 0)
		row2.add_child(t_l)
		if have.is_empty():
			for type_s in [["equity", "Equity"], ["points", "Points"]]:
				var cost := Mogul.stake_cost(ref, str(type_s[0]))
				var b3 = main._btn("%s (−%s)" % [str(type_s[1]), Util.fmt_money(cost)], main._on_stake.bind(int(ref.id), str(type_s[0])))
				b3.disabled = Mogul.stake_blocked_reason(int(ref.id), str(type_s[0])) != ""
				row2.add_child(b3)
		elif str(target.phase) == "production" and not bool(have.boosted):
			row2.add_child(main._btn("📣 Marketing push (−%s)" % Util.fmt_money(roundf(2000.0 * Util.infl(st.year))), main._estate_action.bind(Mogul.boost_marketing.bind(int(ref.id)))))

	# Empire: takeovers & studio stakes (Feature 9)
	if int(p.career) >= 4:
		var ev = main._card("Empire", "👑")
		main.content_box.add_child(ev[0])
		if st.rivals.is_empty():
			ev[1].add_child(main._lbl("No rival houses left standing. The market is yours.", 12, main.GREEN))
		for rival in st.rivals:
			var row3 := HBoxContainer.new()
			row3.add_theme_constant_override("separation", 8)
			ev[1].add_child(row3)
			row3.add_child(main._lbl_fill("%s — %d clients, grudge %d" % [str(rival.name), rival.clients.size(), roundi(float(rival.grudge))], 12, main.TEXT_C))
			var cost4 := Mogul.takeover_cost(rival)
			var tb = main._btn("Buy them out (−%s private)" % Util.fmt_money(cost4), main._estate_action.bind(Mogul.takeover.bind(str(rival.id))))
			tb.disabled = Mogul.takeover_blocked_reason(str(rival.id)) != ""
			tb.tooltip_text = Mogul.takeover_blocked_reason(str(rival.id))
			row3.add_child(tb)
		if int(p.career) >= 5:
			ev[1].add_child(main._lbl("A studio stake (10%%) costs %s: dividends on every release, permanent open doors — and a conflict of interest the whole town knows about." % Util.fmt_money(Mogul.studio_stake_cost()), 11, main.DIM))
			for studio in Game.active_studios():
				var sid := str(studio.id)
				if st.endgame.studioStakes.has(sid):
					ev[1].add_child(main._lbl("✔ %s — you sit at their table." % str(studio.name), 12, main.GREEN))
					continue
				var sb = main._btn("Buy into %s (−%s)" % [str(studio.name), Util.fmt_money(Mogul.studio_stake_cost())], main._estate_action.bind(Mogul.buy_studio_stake.bind(sid)))
				sb.disabled = Mogul.studio_stake_blocked_reason(sid) != ""
				sb.tooltip_text = Mogul.studio_stake_blocked_reason(sid)
				ev[1].add_child(sb)


# ---------- Tab: Hollywood newspaper ----------
func _render_zeitung() -> void:
	main.content_box.add_child(main._lbl("🗞 The alternate history of Hollywood", 22, main.ACC))
	main.content_box.add_child(main._lbl("Every issue grows out of real premieres, castings, rumors, client moves and power struggles of your simulation.", 13, main.DIM))
	if Game.state.newspaper.is_empty():
		var empty = main._card("The presses are waiting", "📰")
		empty[1].add_child(main._lbl("Finish the first month. After that the current issue appears here — and stays in the archive.", 13, main.DIM))
		main.content_box.add_child(empty[0])
		return
	var issue: Dictionary = Game.state.newspaper[0]
	var front = main._card(str(issue.name), "🗞")
	main.content_box.add_child(front[0])
	front[1].add_child(main._lbl(Game.mi_str(issue.mi).to_upper(), 11, main.ACC))
	for i in issue.headlines.size():
		var h: Dictionary = issue.headlines[i]
		var cat := str(h.get("cat", "Talk of the town"))
		var col: Color = {"Reviews":main.ACC, "Box office":main.GREEN, "Blind item":main.AMBER, "Scandal":main.RED, "Cover story":main.GOLD, "Awards":main.GOLD, "Rival deals":main.BLUE, "Casting":main.BLUE}.get(cat, main.TEXT_C)
		front[1].add_child(main._lbl("%s  %s" % [cat.to_upper(), h.get("text", "")], 17 if i == 0 else 14, col))

	main.content_box.add_child(main._lbl("Archive · %d older issues" % mini(23, maxi(0, Game.state.newspaper.size() - 1)), 17, main.ACC))
	var archive_grid = main._grid(520.0)
	main.content_box.add_child(archive_grid)
	for old_issue in Game.state.newspaper.slice(1, 24):
		var archive_card = main._card("%s · %s" % [old_issue.name, Game.mi_str(old_issue.mi)], "▤")
		archive_grid.add_child(archive_card[0])
		for headline in old_issue.headlines.slice(0, 5):
			archive_card[1].add_child(main._lbl("%s · %s" % [str(headline.cat), str(headline.text)], 12, main.DIM))


# ---------- Tab: Quest-Journal (RPG-Chunk 17) ----------
func _render_quests() -> void:
	var st = Game.state
	main.content_box.add_child(main._lbl("📜 Open stories", 22, main.ACC))
	main.content_box.add_child(main._lbl("Event chains you are part of — what has started will play out, one way or another.", 13, main.DIM))
	var active: Array = st.get("quests", []).filter(func(q): return str(q.status) == "aktiv")
	var done: Array = st.get("quests", []).filter(func(q): return str(q.status) == "abgeschlossen")
	if active.is_empty():
		var ec = main._card("All quiet", "🌙")
		main.content_box.add_child(ec[0])
		ec[1].add_child(main._lbl("No open stories — yet. This town rarely leaves it that way.", 13, main.DIM))
	var qgrid = main._grid(520.0)
	main.content_box.add_child(qgrid)
	for q in active:
		var qc = main._card(str(q.title), str(q.get("icon", "📜")))
		qgrid.add_child(qc[0])
		qc[1].add_child(main._lbl(str(q.step), 13, main.TEXT_C))
		var meta_s := "since %s" % Game.mi_str(int(q.startedMi))
		if int(q.get("dueMi", -1)) > Game.mi():
			meta_s += " · next beat in ~%d wk" % maxi(1, (int(q.dueMi) - Game.mi()) * 4)
		qc[1].add_child(main._lbl(meta_s, 11, main.DIM))
	if done.size():
		main.content_box.add_child(main._lbl("Archive · %d closed" % done.size(), 17, main.ACC))
		var agrid = main._grid(520.0)
		main.content_box.add_child(agrid)
		for q in done.slice(maxi(0, done.size() - 10)):
			var arch = main._card(str(q.title), str(q.get("icon", "📜")))
			agrid.add_child(arch[0])
			arch[1].add_child(main._lbl(str(q.step), 12, main.DIM))
			arch[1].add_child(main._lbl("closed %s" % Game.mi_str(int(q.get("doneMi", q.startedMi))), 11, main.DIM))


# ---------- Tab: Chronicle ----------
func _render_chronik() -> void:
	# Career memoir (Feature 10): the decisions and relationships that
	# defined this career — kept forever, unlike the rolling log below.
	var memoirs: Array = Game.state.get("memoirs", [])
	var mv = main._card("Career memoir (%d entries)" % memoirs.size(), "📖")
	main.content_box.add_child(mv[0])
	if memoirs.is_empty():
		mv[1].add_child(main._lbl("Nothing worth remembering yet. Careers are written one decision at a time.", 12, main.DIM))
	else:
		mv[1].add_child(main._lbl("What this career will be remembered for — promises broken, doors opened, empires bought. This record never fades.", 11, main.DIM))
		var mtxt := ""
		var shown: Array = memoirs.slice(maxi(0, memoirs.size() - 30))
		shown.reverse()
		var last_year := -1
		for m in shown:
			var y := int(m.mi) / 12
			if y != last_year:
				last_year = y
				mtxt += "[color=%s][b]— %d —[/b][/color]\n" % [main.ACC.to_html(false), y]
			mtxt += "[color=#a89b7e]%s[/color]  %s\n" % [Game.mi_str(m.mi), str(m.text)]
		if memoirs.size() > 30:
			mtxt += "[color=#6b6152](%d earlier entries rest in the archive.)[/color]\n" % (memoirs.size() - 30)
		mv[1].add_child(main._rich(mtxt, 13))

	var lv = main._card("The rolling log", "📰")
	main.content_box.add_child(lv[0])
	var txt := ""
	for l in Game.state.log:
		var col := {"deal": "#7da05c", "bad": "#c0504d", "history": main.ACC.to_html(false)}.get(l.type, "#a89b7e")
		txt += "[color=#6b6152]%s %d[/color]  [color=%s]%s %s[/color]\n" % [Game.MONTHS[int(l.m) - 1], int(l.y), col, main.LOG_ICONS.get(l.type, "•"), l.text]
	lv[1].add_child(main._rich(txt if txt != "" else "Nothing has happened yet.", 13))


# =====================================================================
# Weekly Planner (UI)
# =====================================================================
func _render_planer() -> void:
	var st = Game.state
	Planner.ensure_planner()
	var hv = main._card("Weekly planner — %s" % Game.date_str(), "🗓")
	main.content_box.add_child(hv[0])
	hv[1].add_child(main._lbl("The coming week in detail: 7 days with morning, afternoon and evening — for you and every free client. Shooting weeks are booked automatically. Empty slots go to the autopilot: rest when exhaustion is above 50, PR otherwise. Galas happen in the evening.", 12, main.DIM))
	var pcard = main._card("🕴 You (agency)", "")
	main.content_box.add_child(pcard[0])
	main._planner_grid(pcard[1], "player", 0, st.planner.player)
	main._planner_fill_row(pcard[1], "player", 0, Planner.PLANNER_PLAYER)
	for c in st.clients:
		var ccard = main._card("⭐ %s" % Game.client_name(c), "")
		main.content_box.add_child(ccard[0])
		if not Game.is_free(c):
			ccard[1].add_child(main._lbl("🎬 Shooting this week — the calendar belongs to the studio.", 12, main.DIM))
			continue
		main._planner_grid(ccard[1], "client", int(c.id), st.planner.clients.get(str(int(c.id)), []))
		main._planner_fill_row(ccard[1], "client", int(c.id), Planner.PLANNER_CLIENT)
	# Legende
	var leg = main._card("What the actions do", "ℹ")
	main.content_box.add_child(leg[0])
	var lt := "[b]Your slots:[/b] "
	for k in Planner.PLANNER_PLAYER:
		var i1: Dictionary = Planner.PLANNER_PLAYER[k]
		lt += "%s %s (%s) · " % [i1.icon, i1.name, i1.desc]
	lt = lt.trim_suffix(" · ") + "\n[b]Client slots:[/b] "
	for k2 in Planner.PLANNER_CLIENT:
		var i2: Dictionary = Planner.PLANNER_CLIENT[k2]
		lt += "%s %s (%s) · " % [i2.icon, i2.name, i2.desc]
	leg[1].add_child(main._rich(lt.trim_suffix(" · "), 12))


