extends RefCounted
# =====================================================================
# Screen „Contacts“ — Beziehungsarbeit: Kontaktzeit, Anlässe,
# Versprechensregister und das Kontaktbuch mit Kanälen.
# Aus Main.gd extrahiert (Chunk 09): bekommt die Main-Referenz für die
# UI-Bausteine und Handler; liest den Spielzustand über die Autoloads.
# =====================================================================

var main


func _init(main_ref) -> void:
	main = main_ref


func _render_kontakte() -> void:
	var st = Game.state
	var head = main._card("Relationship work", "📇")
	main.content_box.add_child(head[0])
	head[1].add_child(main._lbl("Contact time this week: %d/%d ⏱ — personal appointments cost more time than a phone call. All costs come out of your private account (currently %s)." % [int(st.contactAP), Persona.ap_per_week(), Util.fmt_money(st.player.cash)], 13))
	head[1].add_child(main._lbl("People remember: whether you came yourself or sent the assistant, what you promised — and how long you kept them waiting.", 12, main.DIM))
	# Kommunikationsbudget (Feature 29): wenige große Szenen pro Woche
	var scenes: int = int(st.get("weekScenes", 0))
	var scene_col = main.DIM if scenes <= Dialogs.SCENES_PER_WEEK else main.RED
	head[1].add_child(main._lbl("Big scenes this week: %d/%d — dinners, club nights, back rooms and galas take substance. More than that means something is burning." % [scenes, Dialogs.SCENES_PER_WEEK], 11, scene_col))
	# Gala nights (Feature 21): invitations become names, promises, debts
	if Game.has_favor("galaInvite"):
		var gala_b = main._btn("🎟 Attend the gala (uses an invitation · 1⏱)", main._on_attend_gala, true)
		gala_b.disabled = not Network.can_gala()
		gala_b.tooltip_text = "An evening among everyone who matters: new contacts, promises, favors, whispers — and the next invitation."
		head[1].add_child(gala_b)

	# Occasions (Feature 16): the small gestures that keep relationships alive
	var open_occ: Array = Network.open_occasions()
	if not open_occ.is_empty():
		var ov = main._card("Occasions", "💐")
		main.content_box.add_child(ov[0])
		ov[1].add_child(main._lbl("Callbacks, congratulations, a hand when it counts — respond in time, or people will remember that too.", 11, main.DIM))
		for occ in open_occ:
			var odef: Dictionary = Network.OCCASION_KINDS[str(occ.kind)]
			var orow := HBoxContainer.new()
			orow.add_theme_constant_override("separation", 8)
			ov[1].add_child(orow)
			orow.add_child(main._lbl_fill("%s %s — %s (respond by %s)" % [str(odef.icon), str(odef.name), str(occ.ctName), Game.mi_str(occ.dueMi)], 12, main.TEXT_C))
			var ocost := roundf(float(odef.cost) * Util.infl(st.year))
			var olabel := str(odef.act)
			if ocost > 0.0:
				olabel += " (−%s)" % Util.fmt_money(ocost)
			if int(odef.ap) > 0:
				olabel += " %d⏱" % int(odef.ap)
			var ob = main._btn(olabel, main._on_occasion.bind(int(occ.id)))
			ob.disabled = Network.occasion_blocked_reason(occ) != ""
			ob.tooltip_text = Network.occasion_blocked_reason(occ)
			orow.add_child(ob)

	# Promise register: your own commitments + favor debts
	var pv = main._card("Promise register", "🤞")
	main.content_box.add_child(pv[0])
	var pr_list: Array = st.promises.slice(maxi(0, st.promises.size() - 8))
	pr_list.reverse()
	if pr_list.is_empty() and st.debts.is_empty():
		pv[1].add_child(main._lbl("No open commitments. Nobody owes anybody anything yet — that rarely lasts.", 12, main.DIM))
	for pr in pr_list:
		var status := str(pr.status)
		var color = main.AMBER if status == "open" else (main.GREEN if status == "kept" else main.RED)
		var suffix := " — due by %s" % Game.mi_str(pr.dueMi) if status == "open" else " (%s)" % status
		# Register mit Substanz (Feature 30): Art, Zeugen, Schriftform
		var pk: Dictionary = Data.CONTACT_PROMISE_KINDS.get(str(pr.get("kind", "callback")), {})
		var meta := " · " + ("written" if bool(pr.get("written", false)) else "oral")
		if int(pr.get("witnesses", 0)) > 0:
			meta += " · %d👁" % int(pr.witnesses)
		var pl = main._lbl("%s %s %s%s%s" % ["⏳" if status == "open" else ("✔" if status == "kept" else "✖"), str(pk.get("icon", "🤞")), str(pr.text), suffix, meta], 12, color)
		pl.tooltip_text = "Kept: trust +%d%s. Broken: trust −%d, anger — and word spreads%s." % [5 + int(pr.get("witnesses", 0)) * 2, ", standing rises" if int(pr.get("witnesses", 0)) > 0 else "", 10 + int(pr.get("witnesses", 0)) * 2, "; a written promise can surface as evidence" if bool(pr.get("written", false)) else ""]
		pv[1].add_child(pl)
	for d in st.debts:
		pv[1].add_child(main._lbl("⚠ Favor owed to %s: %s" % [d["from"].get("name", "?"), str(d.get("note", ""))], 12, main.AMBER))

	# Backroom register (Feature 8): parties, promise, expiry, paper trail
	if not st.backroom.is_empty():
		var bv = main._card("Backroom register", "🥃")
		main.content_box.add_child(bv[0])
		bv[1].add_child(main._lbl("Arrangements no contract will ever mention. Witnesses and paper make them dangerous; broken words make them expensive.", 11, main.DIM))
		var deals: Array = st.backroom.duplicate()
		deals.reverse()
		for rec in deals.slice(0, 8):
			var def: Dictionary = Mogul.deal_def(str(rec.dealId))
			var status := str(rec.status)
			var color = main.AMBER if status == "open" else (main.GREEN if status == "honored" else main.RED)
			var icon := "⏳" if status == "open" else ("✔" if status == "honored" else "✖")
			var extra := ""
			if status == "open":
				var give: Dictionary = def.get("give", {})
				if not give.is_empty():
					extra = " — owed: %s (by %s)" % [str(give.get("label", "")), Game.mi_str(rec.dueMi)]
				if int(rec.witnesses) > 0:
					extra += " · %d👁" % int(rec.witnesses)
				if bool(rec.paper):
					extra += " · 📄 paper trail"
			bv[1].add_child(main._lbl("%s %s %s with %s (%s)%s" % [icon, str(def.get("icon", "🤝")), str(def.get("name", rec.dealId)), rec["with"].get("name", "?"), status, extra], 12, color))

	var grid = main._grid(560.0)
	main.content_box.add_child(grid)
	for ct in st.contacts:
		var cv = main._card(str(ct.name))
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		var chips: Array = [main._chip(str(Data.CONTACT_ROLES.get(str(ct.type), str(ct.type))), main.BLUE)]
		if Network.is_vip(ct):
			chips.append(main._chip("⭐ VIP", main.AMBER))
		for circle in ct.get("circles", []):
			chips.append(main._chip(str(Data.CONTACT_CIRCLE_NAMES.get(str(circle), circle)), main.DIM))
		box.add_child(main._chip_row(chips))
		main._stat_row(box, "💛 Relationship", float(ct.rel), main.ACC if float(ct.rel) >= 40.0 else main.DIM)
		# Six dimensions instead of one number (Feature 12)
		var d1 := ""
		var d2 := ""
		for dk in ["trust", "liking", "respect"]:
			d1 += "%s %s %d   " % [Network.DIM_INFO[dk].icon, Network.DIM_INFO[dk].name, roundi(Network.dim(ct, dk))]
		for dk in ["closeness", "dependence", "irritation"]:
			d2 += "%s %s %d   " % [Network.DIM_INFO[dk].icon, Network.DIM_INFO[dk].name, roundi(Network.dim(ct, dk))]
		box.add_child(main._lbl(d1.strip_edges(), 11, main.TEXT_C))
		box.add_child(main._lbl(d2.strip_edges(), 11, main.RED if Network.dim(ct, "irritation") >= 20.0 else main.TEXT_C))
		# The web (Feature 11): who they are connected to
		var links: Array = ct.get("links", [])
		if not links.is_empty():
			var link_parts: Array = []
			for l in links.slice(0, 3):
				link_parts.append("%s (%s)" % [str(l.to), str(Network.LINK_KINDS.get(str(l.kind), l.kind))])
			box.add_child(main._lbl("🕸 Connected: %s — how you treat one, the others hear about." % " · ".join(link_parts), 11, main.DIM))
		# Subjective reputation (Feature 18): their own picture of you
		box.add_child(main._lbl("👁 %s" % Network.opinion_label(ct), 11, main.ACC_DIM))
		# Social capital (Feature 13): what this contact is actually worth
		var cap_line := ""
		for cap in Network.capital_of(ct):
			cap_line += "%s %s%s   " % [str(cap.icon), str(cap.label), "" if bool(cap.active) else " (locked)"]
		var cap_l = main._lbl(cap_line.strip_edges(), 11, main.ACC_DIM)
		cap_l.tooltip_text = "\n".join(Network.capital_of(ct).map(func(c): return "%s %s: %s" % [str(c.icon), str(c.label), str(c.desc)]))
		box.add_child(cap_l)
		# Gatekeeper (Feature 14): the anteroom before the audience
		var gate: Dictionary = Network.gate_of(ct)
		if not gate.is_empty():
			var gate_col = main.GREEN if float(gate.rel) >= Network.GATE_BLOCK_REL else main.AMBER
			box.add_child(main._lbl("🚪 Anteroom: %s — disposition %d/100%s" % [str(gate.name), roundi(float(gate.rel)), "" if not Network.gate_blocks(ct) else " · blocks meetings & club nights"], 11, gate_col))
		box.add_child(main._lbl("Last spoken: %s" % main._months_ago(int(ct.lastMi)), 11, main.DIM))
		var mem: Array = ct.log.slice(0, 3)
		if not mem.is_empty():
			box.add_child(main._lbl("Remembers:", 11, main.DIM))
			for entry in mem:
				box.add_child(main._lbl("• %s (%s)" % [str(entry.text), Game.mi_str(entry.mi)], 11, main.TEXT_C))
		for pr in st.promises:
			if str(pr.status) == "open" and str(pr.to) == str(ct.name):
				box.add_child(main._lbl("⏳ Open promise — due by %s" % Game.mi_str(pr.dueMi), 11, main.AMBER))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		box.add_child(flow)
		for key in Data.CONTACT_CHANNELS:
			var ch: Dictionary = Data.CONTACT_CHANNELS[key]
			var cost := Persona.channel_cost(key)
			var label := "%s %s" % [str(ch.icon), str(ch.name)]
			if cost > 0.0:
				label += " (−%s)" % Util.fmt_money(cost)
			if int(ch.ap) > 0:
				label += " %d⏱" % int(ch.ap)
			var b = main._btn(label, main._on_contact_channel.bind(int(ct.id), str(key)))
			var reason: String = Persona.contact_blocked_reason(ct, key)
			b.disabled = reason != ""
			b.tooltip_text = str(ch.desc) + ("" if reason == "" else "\n⛔ " + reason)
			flow.add_child(b)
		# Berufsspezifischer Informationszugang (Feature 17)
		var info_b = main._btn("🔍 Ask for information (1⏱)", main._on_ask_info.bind(int(ct.id)))
		info_b.tooltip_text = "What they know comes with the job: press hears stories, producers see projects, lawyers see paper, financiers hear money."
		info_b.disabled = Network.info_blocked_reason(ct) != ""
		if Network.info_blocked_reason(ct) != "":
			info_b.tooltip_text += "\n⛔ " + Network.info_blocked_reason(ct)
		flow.add_child(info_b)
		# Wissen weitergeben (Feature 19): ein Scoop für die Presse
		if ["journalist", "kolumnist", "verleger"].has(str(ct.type)):
			var sh_b = main._btn("🗞 Share a story (1⏱)", main._on_share_story.bind(int(ct.id)))
			sh_b.tooltip_text = "Feed them a rumor from your notebook (never about your own clients): they owe you — and your fingerprints are on the story."
			sh_b.disabled = Network.share_story_blocked_reason(ct) != ""
			flow.add_child(sh_b)
		# Gatekeeper pflegen (Feature 14): Freundlichkeit zum Vorzimmer zahlt sich aus
		if not Network.gate_of(ct).is_empty():
			var gb = main._btn("🌷 Charm the anteroom (−%s)" % Util.fmt_money(Network.charm_cost()), main._on_charm_gate.bind(int(ct.id)))
			gb.tooltip_text = "Flowers, tickets, a remembered birthday. Cheap — and it decides whether your calls get through."
			gb.disabled = int(ct.get("gateWeek", -99)) == Game.wi() or float(st.player.cash) < Network.charm_cost()
			flow.add_child(gb)
		# Marker einlösen (Feature 13): Hebel wird zu einem konkreten Gefallen
		if Network.dim(ct, "dependence") >= 50.0:
			var mb = main._btn("🪝 Call in a marker", main._on_call_marker.bind(int(ct.id)))
			mb.tooltip_text = "They owe you enough. Convert leverage into a concrete favor — it will cost the warmth of the moment."
			mb.disabled = Network.marker_blocked_reason(ct) != ""
			flow.add_child(mb)
		# Backroom deals (Feature 8) grow out of good relationships
		var offers: Array = Mogul.deals_for_contact(ct)
		if not offers.is_empty():
			var db = main._btn("🥃 Backroom deal… (%d)" % offers.size(), main._open_backroom_picker.bind(int(ct.id)))
			db.tooltip_text = "Confidential arrangements: concrete promises, witnesses, expiry dates — and consequences."
			db.disabled = Persona.is_away() or int(st.contactAP) < 1
			flow.add_child(db)

	# Introductions (Feature 15): new doors open only through mutual friends
	var notables: Array = Network.notables_unmet()
	if not notables.is_empty():
		var iv = main._card("Beyond your circle", "🪜")
		main.content_box.add_child(iv[0])
		iv[1].add_child(main._lbl("These people do not take cold calls. A credible word from a mutual acquaintance opens the door — if someone likes and trusts you enough to vouch.", 11, main.DIM))
		for n in notables:
			var nbox := VBoxContainer.new()
			nbox.add_theme_constant_override("separation", 2)
			iv[1].add_child(nbox)
			nbox.add_child(main._lbl("%s (%s)" % [str(n.name), str(Data.CONTACT_ROLES.get(str(n.type), n.type))], 14, main.TEXT_C))
			nbox.add_child(main._lbl(str(n.desc), 11, main.DIM))
			var intros: Array = Network.introducers_for(n)
			if intros.is_empty():
				nbox.add_child(main._lbl("Nobody in your book can vouch for you yet (needs liking ≥ 55 and trust ≥ 45 in a shared circle).", 11, main.DIM))
			else:
				var irow := HFlowContainer.new()
				irow.add_theme_constant_override("h_separation", 6)
				nbox.add_child(irow)
				for intro in intros:
					var ib2 = main._btn("Ask %s for an introduction (1⏱)" % str(intro.name), main._on_introduce.bind(str(n.name), int(intro.id)))
					ib2.disabled = Network.introduce_blocked_reason(str(n.name)) != ""
					irow.add_child(ib2)


