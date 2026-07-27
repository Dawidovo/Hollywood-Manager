extends RefCounted
# =====================================================================
# Screen „Personal“ — der Manager als Person: Karriere, Privatfinanzen,
# Zustand, Ruf & Einfluss, Privatleben.
# Aus Main.gd extrahiert (Chunk 09): bekommt die Main-Referenz für die
# UI-Bausteine und Handler; liest den Spielzustand über die Autoloads.
# =====================================================================

var main


func _init(main_ref) -> void:
	main = main_ref


func _render_privat() -> void:
	var st = Game.state
	var p: Dictionary = st.player
	var grid = main._grid(520.0)
	main.content_box.add_child(grid)

	# Career & earned reputation title
	var cv = main._card("Career", "🎩")
	grid.add_child(cv[0])
	cv[1].add_child(main._lbl(str(Persona.career_def().name), 24, main.ACC))
	# Spezialisierung (Feature 42): wozu die Erfahrung dich gemacht hat
	var spec: Dictionary = Mogul.specialization()
	if not spec.is_empty():
		cv[1].add_child(main._lbl("Known as: %s (from your %s, level %d)" % [str(spec.label), str(Data.SKILL_FIELDS[spec.field].name).to_lower(), int(spec.level)], 13, main.GOLD))
	cv[1].add_child(main._lbl("Reputation profile: %s — earned, not chosen. How you behave decides who calls and which deals reach you." % Persona.title(), 12, main.DIM))
	var reqs: Array = Persona.promotion_requirements()
	if reqs.is_empty():
		cv[1].add_child(main._lbl("Top of the ladder — Hollywood knows no bigger name.", 13, main.GREEN))
	else:
		cv[1].add_child(main._lbl("Next level: %s" % str(Data.CAREER_LEVELS[int(p.career) + 1].name), 14, main.TEXT_C))
		for r in reqs:
			cv[1].add_child(main._lbl(("✔ " if r.met else "✖ ") + str(r.label), 12, main.GREEN if r.met else main.DIM))
		cv[1].add_child(main._lbl("Promotion happens automatically at the end of the month once everything is met.", 11, main.DIM))

	# Private finances — strictly separate from the agency till
	var fv = main._card("Private finances", "💼")
	grid.add_child(fv[0])
	var cash := float(p.cash)
	fv[1].add_child(main._lbl(("Private wealth: %s" if cash >= 0.0 else "Private debt: %s") % Util.fmt_money(absf(cash)), 17, main.GREEN if cash >= 0.0 else main.RED))
	fv[1].add_child(main._lbl("Salary: %s/month + %d%% royalty on commissions" % [Util.fmt_money(Persona.salary()), roundi(Persona.ROYALTY * 100.0)], 12, main.DIM))
	fv[1].add_child(main._lbl("Living costs: %s/month — the lifestyle grows with the title" % Util.fmt_money(Persona.living_cost()), 12, main.DIM))
	if cash < 0.0:
		fv[1].add_child(main._lbl("⚠ Private debt accrues 2% interest per month.", 12, main.RED))
	var draw = main._btn("Private draw: +%s to your own account" % Util.fmt_money(Persona.salary()), main._player_action.bind(Persona.draw), true)
	draw.disabled = not Persona.can_act("draw") or float(st.agency.cash) < Persona.salary()
	fv[1].add_child(draw)
	fv[1].add_child(main._lbl("Private injection into the agency:", 12, main.DIM))
	var inj_row := HBoxContainer.new()
	inj_row.add_theme_constant_override("separation", 6)
	fv[1].add_child(inj_row)
	for mult in [1, 3, 10]:
		var amount: float = Persona.salary() * float(mult)
		var ib = main._btn(Util.fmt_money(amount), main._player_action.bind(Persona.inject.bind(amount)))
		ib.disabled = cash < amount
		inj_row.add_child(ib)
	var entries: Array = p.ledger.slice(maxi(0, p.ledger.size() - 6))
	if not entries.is_empty():
		fv[1].add_child(main._lbl("Recent bookings:", 12, main.DIM))
		entries.reverse()
		for e in entries:
			var amt := float(e.amount)
			fv[1].add_child(main._lbl("%s%s — %s" % ["+" if amt >= 0.0 else "−", Util.fmt_money(absf(amt)), str(e.text)], 11, main.GREEN if amt >= 0.0 else main.RED))

	# Condition: energy, stress, health + recovery actions
	var zv = main._card("Condition", "🧘")
	grid.add_child(zv[0])
	main._stat_row(zv[1], "🔋 Energy", float(p.energy), main.GREEN if float(p.energy) >= 25.0 else main.RED)
	main._stat_row(zv[1], "😰 Stress", float(p.stress), main.RED if float(p.stress) > 70.0 else main.AMBER)
	main._stat_row(zv[1], "❤ Health", float(p.health), main.GREEN if float(p.health) >= 40.0 else main.RED)
	zv[1].add_child(main._lbl("Workload drains energy, crises build stress. Chronic stress eats your health — all the way to the clinic.", 11, main.DIM))
	var vac = main._btn("🌴 Time off in Palm Springs (−%s)" % Util.fmt_money(roundf(220.0 * Util.infl(st.year))), main._player_action.bind(Persona.vacation))
	vac.disabled = not Persona.can_act("vacation")
	zv[1].add_child(vac)
	var doc = main._btn("🩺 Doctor's checkup (−%s)" % Util.fmt_money(roundf(150.0 * Util.infl(st.year))), main._player_action.bind(Persona.checkup))
	doc.disabled = not Persona.can_act("checkup")
	zv[1].add_child(doc)
	zv[1].add_child(main._lbl("Once per month each.", 11, main.DIM))

	# Reputation & influence — the manager has a standing of their own
	var rv = main._card("Reputation & influence", "🌟")
	grid.add_child(rv[0])
	main._stat_row(rv[1], "📰 Public reputation", float(p.pubRep), main.BLUE)
	main._stat_row(rv[1], "🏛 Industry standing", float(p.indRep), main.ACC)
	main._stat_row(rv[1], "🤫 Discretion", float(p.discretion), main.BLUE)
	main._stat_row(rv[1], "🧲 Influence", float(p.influence), main.AMBER)
	rv[1].add_child(main._lbl("Industry standing follows the agency's reputation, influence grows with career level and open favors. Scandals hit your public reputation first.", 11, main.DIM))

	# Assistant & delegation (Feature 4): from doing to managing
	var av = main._card("Assistant & delegation", "🧑‍💼")
	grid.add_child(av[0])
	if not Persona.has_assistant():
		av[1].add_child(main._lbl("Nobody covers the front desk. An assistant relieves stress, keeps neglected contacts warm and puts a morning note on your desk.", 12, main.DIM))
		av[1].add_child(main._btn("Hire an assistant (wages ≈ %s/month)" % Util.fmt_money(roundf((Persona.ASSISTANT_BASE_WAGE + 75.0) * Util.infl(st.year))), main._player_action.bind(Persona.hire_assistant), true))
	else:
		var a: Dictionary = Persona.assistant()
		av[1].add_child(main._lbl("%s — skill %d/100 · wages %s/month (agency)" % [str(a.name), int(a.skill), Util.fmt_money(Persona.assistant_wage())], 13, main.TEXT_C))
		av[1].add_child(main._lbl("Delegation rules — what may be handled without you:", 12, main.DIM))
		var up = main._btn(("☑ " if Persona.rule("upkeep") else "☐ ") + "Relationship upkeep: check in on neglected contacts weekly", main._player_action.bind(Persona.set_rule.bind("upkeep", not Persona.rule("upkeep"))))
		av[1].add_child(up)
		var br = main._btn(("☑ " if Persona.rule("briefing") else "☐ ") + "Morning note: weekly decision brief on promises, contacts & crises", main._player_action.bind(Persona.set_rule.bind("briefing", not Persona.rule("briefing"))))
		av[1].add_child(br)
		var oc = main._btn(("☑ " if Persona.rule("occasions") else "☐ ") + "Small gestures: handle birthdays & callbacks you let slip (weaker effect)", main._player_action.bind(Persona.set_rule.bind("occasions", not Persona.rule("occasions"))))
		av[1].add_child(oc)
		var mf = main._btn(("☑ " if Persona.rule("mailfilter") else "☐ ") + "Mail filter: answer routine correspondence without you", main._player_action.bind(Persona.set_rule.bind("mailfilter", not Persona.rule("mailfilter"))))
		av[1].add_child(mf)
		var tv = main._btn(("☑ " if Persona.rule("travel") else "☐ ") + "Travel desk: book trips — arrivals cost less energy and keep 1⏱", main._player_action.bind(Persona.set_rule.bind("travel", not Persona.rule("travel"))))
		av[1].add_child(tv)
		av[1].add_child(main._lbl("The “Send assistant” contact channel is only available while someone holds this desk.", 11, main.DIM))
		av[1].add_child(main._btn("Let %s go" % str(a.name), main._player_action.bind(Persona.fire_assistant)))

	# Staff & delegation (Features 33–36): from doing to managing people
	var sf = main._card("Staff & delegation rules", "🗂")
	grid.add_child(sf[0])
	if st.staff.is_empty():
		sf[1].add_child(main._lbl("Nobody but you works the files. Staffers take over deals, research, contact care or crises — proposing first, acting autonomously once you trust them.", 12, main.DIM))
	for s in st.staff:
		var fdef: Dictionary = Data.STAFF_FOCI.get(str(s.focus), {})
		var srow := VBoxContainer.new()
		srow.add_theme_constant_override("separation", 2)
		sf[1].add_child(srow)
		var skill_s := str(int(s.skill)) if Mogul.level("leadership") >= 2 else Game.grade_range(float(s.skill), 8.0, "staff" + str(s.id))
		var trait_s: String = str(Data.STAFF_TRAITS.get(str(s.trait), {}).get("name", "?")) if Staff.bias_visible() else "character: unclear"
		srow.add_child(main._lbl("%s %s — %s · skill %s · %s · wages %s/mo" % [str(fdef.get("icon", "🗂")), str(s.name), str(fdef.get("name", s.focus)), skill_s, trait_s, Util.fmt_money(Staff.wage(s))], 13, main.TEXT_C))
		# Qualität & Bindung (Feature 33): Loyalität und Auslastung zählen
		var loy := float(s.get("loyalty", 55.0))
		var load := float(s.get("load", 0.0))
		var loy_s := "loyalty %d · load %d" % [roundi(loy), roundi(load)] if Staff.bias_visible() else ("%s · %s" % ["restless" if loy < 40.0 else "settled", "overloaded" if load >= 70.0 else "coping"])
		srow.add_child(main._lbl("%s — overloaded or disloyal staff botch work; the best ones leave, and take clients with them." % loy_s, 11, main.RED if loy < 40.0 or load >= 70.0 else main.DIM))
		if Staff.bias_visible():
			srow.add_child(main._lbl("Your read: %s." % str(Data.STAFF_TRAITS.get(str(s.trait), {}).get("hint", "")), 11, main.DIM))
		var brow := HBoxContainer.new()
		brow.add_theme_constant_override("separation", 6)
		srow.add_child(brow)
		brow.add_child(main._btn("Mode: %s" % str(Staff.MODE_LABELS.get(str(s.mode), s.mode)), main._player_action.bind(Staff.cycle_mode.bind(int(s.id)))))
		var rb = main._btn("Give a raise (+20% wages)", main._player_action.bind(Staff.give_raise.bind(int(s.id))))
		rb.disabled = Staff.raise_blocked_reason(int(s.id)) != ""
		rb.tooltip_text = "Loyalty +15." + ("" if Staff.raise_blocked_reason(int(s.id)) == "" else "\n⛔ " + Staff.raise_blocked_reason(int(s.id)))
		brow.add_child(rb)
		brow.add_child(main._btn("Let go", main._player_action.bind(Staff.fire.bind(int(s.id)))))
	var hire_flow := HFlowContainer.new()
	hire_flow.add_theme_constant_override("h_separation", 6)
	hire_flow.add_theme_constant_override("v_separation", 6)
	sf[1].add_child(hire_flow)
	for focus in Data.STAFF_FOCI:
		var hb2 = main._btn("Hire: %s %s" % [str(Data.STAFF_FOCI[focus].icon), str(Data.STAFF_FOCI[focus].name)], main._player_action.bind(Staff.hire.bind(str(focus))))
		var hreason: String = Staff.hire_blocked_reason(str(focus))
		hb2.disabled = hreason != ""
		hb2.tooltip_text = str(Data.STAFF_FOCI[focus].desc) + ("" if hreason == "" else "\n⛔ " + hreason)
		hire_flow.add_child(hb2)
	# Delegationsregeln (Feature 35): was automatisch läuft, was vorgelegt wird
	sf[1].add_child(main._lbl("Standing rules — what autonomous staff may decide, and what always reaches your desk:", 12, main.DIM))
	var cap_row := HBoxContainer.new()
	cap_row.add_theme_constant_override("separation", 6)
	sf[1].add_child(cap_row)
	var cap_l = main._lbl("Approval cap:", 12, main.TEXT_C)
	cap_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	cap_row.add_child(cap_l)
	for cap in [5000, 15000, 50000]:
		var cb2 = main._btn(("● " if int(st.delegation.feeCap) == cap else "○ ") + Util.fmt_money(roundf(cap * Util.infl(st.year))), main._set_delegation.bind("feeCap", cap))
		cap_row.add_child(cb2)
	var vip_row := HBoxContainer.new()
	vip_row.add_theme_constant_override("separation", 6)
	sf[1].add_child(vip_row)
	var vip_l = main._lbl("Always my call: clients from fame", 12, main.TEXT_C)
	vip_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	vip_row.add_child(vip_l)
	for vf in [50, 70, 90]:
		var vb2 = main._btn(("● " if int(st.delegation.vipFame) == vf else "○ ") + str(vf), main._set_delegation.bind("vipFame", vf))
		vip_row.add_child(vb2)
	var sc_btn = main._btn(("☑ " if bool(st.delegation.escalateScandal) else "☐ ") + "Loud scandals always escalate to me", main._set_delegation.bind("escalateScandal", not bool(st.delegation.escalateScandal)))
	sf[1].add_child(sc_btn)

	# Experience & specializations (Feature 6): abilities, not % boni
	var sk = main._card("Experience & abilities", "🎓")
	grid.add_child(sk[0])
	sk[1].add_child(main._lbl("Doing teaches — failing teaches too. Levels unlock new ways to see and act, not percent boni.", 11, main.DIM))
	for field in Data.SKILL_FIELDS:
		var fd: Dictionary = Data.SKILL_FIELDS[field]
		var lvl: int = Mogul.level(field)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_l = main._lbl("%s %s" % [str(fd.icon), str(fd.name)], 12, main.TEXT_C)
		name_l.custom_minimum_size = Vector2(180 * main.font_scale, 0)
		name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_l.tooltip_text = str(fd.desc)
		row.add_child(name_l)
		var dots := ""
		for i in 5:
			dots += "●" if i < lvl else "○"
		var dots_l = main._lbl("%s  L%d" % [dots, lvl], 12, main.ACC if lvl > 0 else main.DIM)
		dots_l.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(dots_l)
		var next: Dictionary = Mogul.next_ability(field)
		if not next.is_empty():
			var nl = main._lbl("→ L%d: %s" % [int(next.level), str(next.name)], 11, main.DIM)
			nl.autowrap_mode = TextServer.AUTOWRAP_OFF
			nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nl.tooltip_text = str(next.desc)
			row.add_child(nl)
		sk[1].add_child(row)
	var unlocked: Array = Data.SKILL_ABILITIES.filter(func(ab): return Mogul.has_ability(str(ab.id)))
	if not unlocked.is_empty():
		sk[1].add_child(main._lbl("Unlocked abilities:", 12, main.DIM))
		for ab in unlocked:
			sk[1].add_child(main._lbl("✔ %s — %s" % [str(ab.name), str(ab.desc)], 11, main.GREEN))

	# Privatleben (Feature 44): abstrahiert, aber mit echten Ansprüchen
	var pv2 = main._card("Private life", "🏡")
	grid.add_child(pv2[0])
	var pl2: Dictionary = p.privateLife
	if pl2.partner == null:
		pv2[1].add_child(main._lbl("The work is your life — for now. Every so often, life writes back: watch the mail.", 12, main.DIM))
	else:
		var status_s := "Married to" if Persona.is_married() else "Seeing"
		pv2[1].add_child(main._lbl("%s %s — since %s" % [status_s, str(pl2.partner.name), Game.mi_str(pl2.partner.sinceMi)], 14, main.ACC))
		main._stat_row(pv2[1], "💞 Closeness", float(pl2.partner.rel), main.GREEN if float(pl2.partner.rel) >= 50.0 else main.RED)
		pv2[1].add_child(main._lbl("A good partnership carries you (stress −2, health + each month) — but it wants evenings, answered letters and shared vacations. Below 20 it ends, publicly.", 11, main.DIM))
		if Persona.is_married():
			pv2[1].add_child(main._lbl("The household lives larger: living costs +12%.", 11, main.DIM))
	pv2[1].add_child(main._lbl("Friendships outside the business: %d/3 — each one quietly takes a point of stress off your month. They starve without shared time off." % int(pl2.friends), 12, main.TEXT_C))
	pv2[1].add_child(main._lbl("Vacations feed both: your partner joins, and friendships stay alive.", 11, main.DIM))

	# Empire & legacy (Feature 9): partner share, takeovers, mogul goals
	var em = main._card("Empire & legacy", "👑")
	grid.add_child(em[0])
	if int(p.career) < 3:
		em[1].add_child(main._lbl("Partnership, takeovers and studio stakes open up from the Partner level onward. For now, the ladder is the work.", 12, main.DIM))
	else:
		if Mogul.is_partner():
			em[1].add_child(main._lbl("✔ Name partner: 10% of every profitable month flows into your own account.", 12, main.GREEN))
		else:
			em[1].add_child(main._lbl("You carry the title, not the equity — the buy-in offer comes with the promotion.", 12, main.DIM))
		if int(p.career) >= 4:
			em[1].add_child(main._lbl("Rival agencies can be bought outright — see the Investments tab.", 12, main.TEXT_C))
		var eg: Dictionary = st.endgame
		if not eg.takeovers.is_empty():
			em[1].add_child(main._lbl("Swallowed: %s" % ", ".join(eg.takeovers), 12, main.ACC))
		for sid in eg.studioStakes:
			em[1].add_child(main._lbl("🎬 Studio stake: %s — dividends on every release, doors always open." % str(Game._studio(str(sid)).name), 12, main.ACC))
		var honored: int = st.backroom.filter(func(d): return str(d.status) == "honored").size()
		var broken: int = st.backroom.filter(func(d): return str(d.status) in ["broken", "exposed"]).size()
		em[1].add_child(main._lbl("Your word in the back rooms: %d kept · %d broken or exposed." % [honored, broken], 11, main.DIM))


