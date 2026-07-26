extends Node
# =====================================================================
# Hollywood Manager — Datengetriebene Event-Engine (Autoload "EvEngine")
# Interpretiert Events aus res://data/events/*.json (siehe data/README.md).
# Liefert dieselbe Form wie Ev.all_events(): {id, cd, weight: Callable,
# build: Callable} — läuft hybrid neben den geskripteten Events.
#
# Schema-Kurzfassung:
#   conditions: min_year/max_year, min_rep/max_rep, min_cash, min_clients,
#     requires_client (true oder {min_fame, max_fame, free, weight_dev_min}),
#     requires_studio, has_favor, backstory, chance
#   weight: Zahl oder {base, mods:[{if:<conditions>, add, mult}]}
#   choices: [{label, requirements, success_chance,
#     effects/effects_fail:[{op,...}], outcome/outcome_fail}]
#   Ketten: Effekt {"op":"followup","event":"<id>","delay_weeks":N};
#   Kettenglieder mit "followup_only": true bleiben aus dem Zufallspool.
#   Geldwerte (money-Effekte mit "inflate", min_cash, {money_fmt:N}) sind
#   Basisjahr-Dollar (1925) und wachsen mit der Inflation mit.
# =====================================================================


func all_events() -> Array:
	var out: Array = []
	for def in Data.EVENTS:
		if bool(def.get("followup_only", false)):
			continue
		out.append({
			"id": str(def.id),
			"cd": int(def.get("cd", 6)),
			"weight": _weight_fn(def),
			"build": _build_fn(def),
		})
	return out


func _weight_fn(def: Dictionary) -> Callable:
	return func() -> float: return eval_weight(def)


func _build_fn(def: Dictionary) -> Callable:
	return func(): return build_event(def)


func def_by_id(id_s: String) -> Dictionary:
	for def in Data.EVENTS:
		if str(def.id) == id_s:
			return def
	return {}


# Ketten-Einstieg: Followup {"type":"json","event":id,"ctx":{...}} auflösen
func build_by_id(id_s: String, ctx: Dictionary = {}) -> Variant:
	var def := def_by_id(id_s)
	if def.is_empty():
		push_warning("EvEngine: Followup-Event „%s“ nicht gefunden." % id_s)
		return null
	return build_event(def, ctx)


# ---------- Bedingungen ----------
# Zahlenfenster: Jahr, Ruf, Kasse, Klientenzahl
func _limits_ok(conds: Dictionary) -> bool:
	var st = Game.state
	if int(st.year) < int(conds.get("min_year", -9999)) or int(st.year) > int(conds.get("max_year", 9999)):
		return false
	if int(st.agency.rep) < int(conds.get("min_rep", -9999)) or int(st.agency.rep) > int(conds.get("max_rep", 9999)):
		return false
	if conds.has("min_cash") and float(st.agency.cash) < _money(float(conds.min_cash)):
		return false
	return st.clients.size() >= int(conds.get("min_clients", 0))


func check_conditions(conds: Dictionary, ctx: Dictionary = {}) -> bool:
	if conds.is_empty():
		return true
	if not _limits_ok(conds):
		return false
	if conds.has("min_attr") and not _min_attr_ok(conds.min_attr):
		return false
	var fav := str(conds.get("has_favor", ""))
	if fav != "" and not Game.has_favor(fav):
		return false
	var bs := str(conds.get("backstory", ""))
	if bs != "" and str(Game.state.get("backstory", "")) != bs:
		return false
	if conds.get("requires_client") != null and not ctx.has("cid"):
		if _client_candidates(conds.requires_client).is_empty():
			return false
	if bool(conds.get("requires_studio", false)) and Game.active_studios().is_empty():
		return false
	if conds.has("chance") and not Util.chance(float(conds.chance)):
		return false
	return true


# Mindest-Attribute: {"verhandlung": 40, ...} — alle müssen erfüllt sein.
func _min_attr_ok(req) -> bool:
	if not (req is Dictionary):
		return true
	for key in req:
		if Game.attr(str(key)) < int(req[key]):
			return false
	return true


# ---------- Sichtbare Proben (RPG-Chunk 16) ----------
# Chance: Attribut = DC ⇒ 50 %, jeder Punkt Differenz ±1 %; optionale
# Identitäts-Achse wirkt situativ (±5 % je Stärkegrad). Clamp 5–95 %.
func check_chance(check: Dictionary) -> float:
	var chance_v := 0.5 + float(Game.attr(str(check.get("attr", ""))) - int(check.get("dc", 50))) / 100.0
	var idk := str(check.get("identity", ""))
	if idk != "":
		chance_v += Game.identity_strength(idk) * 0.05
	return clampf(chance_v, 0.05, 0.95)


# „[👁 Insight · 62 %] …“ — Proben sind immer sichtbar, nie versteckt:
# eine schlechte Chance ist eine Spielerentscheidung, kein Geheimnis.
func check_label(check: Dictionary) -> String:
	var adef: Dictionary = Data.ATTRIBUTES.get(str(check.get("attr", "")), {})
	return "[%s %s · %d %%]" % [str(adef.get("icon", "🎲")), str(adef.get("name", check.get("attr", "?"))), roundi(check_chance(check) * 100.0)]


func _client_candidates(req) -> Array:
	var r: Dictionary = req if req is Dictionary else {}
	return Game.state.clients.filter(func(c):
		if float(c.fame) < float(r.get("min_fame", -1)):
			return false
		if float(c.fame) > float(r.get("max_fame", 101)):
			return false
		if bool(r.get("free", false)) and not Game.is_free(c):
			return false
		var weight_dev_min := float(r.get("weight_dev_min", 0.0))
		if weight_dev_min > 0.0 and absf(float(c.get("weightKg", Game.client_base_weight(c))) - Game.client_base_weight(c)) < weight_dev_min:
			return false
		return true)


func eval_weight(def: Dictionary) -> float:
	if not check_conditions(def.get("conditions", {})):
		return 0.0
	var wd = def.get("weight", {})
	if not (wd is Dictionary):
		return maxf(float(wd), 0.0)
	var w := float(wd.get("base", 1.0))
	for m in wd.get("mods", []):
		if check_conditions(m.get("if", {})):
			w += float(m.get("add", 0.0))
			w *= float(m.get("mult", 1.0))
	return maxf(w, 0.0)


# ---------- Aufbau des Modals ----------
func build_event(def: Dictionary, ctx: Dictionary = {}) -> Variant:
	ctx = ctx.duplicate(true)
	var conds: Dictionary = def.get("conditions", {})
	# Kontext binden: Klient und Studio wählen bzw. aus der Kette übernehmen
	if ctx.has("cid"):
		if Game.client(ctx.cid) == null:
			return null
	elif conds.get("requires_client") != null:
		var cands := _client_candidates(conds.requires_client)
		if cands.is_empty():
			return null
		ctx["cid"] = int(Util.pick(cands).id)
	if not ctx.has("sid") and bool(conds.get("requires_studio", false)):
		var studios: Array = Game.active_studios()
		if studios.is_empty():
			return null
		ctx["sid"] = str(Util.pick(studios).id)
	var choices_out: Array = []
	for ch in def.get("choices", []):
		var reqs: Dictionary = ch.get("requirements", {})
		var fav := str(reqs.get("has_favor", ""))
		if fav != "" and not Game.has_favor(fav):
			continue
		var bs := str(reqs.get("backstory", ""))
		if bs != "" and str(Game.state.get("backstory", "")) != bs:
			continue
		var label_s := subst(str(ch.get("label", "Weiter")), ctx)
		if ch.has("check"):
			label_s = "%s %s" % [check_label(ch.check), label_s]
		var entry := {"label": label_s, "fn": _choice_fn(ch, ctx)}
		# Geld-/Attributs-Anforderungen bleiben sichtbar, sind aber ausgegraut
		if reqs.has("min_cash") and float(Game.state.agency.cash) < _money(float(reqs.min_cash)):
			entry["disabled"] = true
		if reqs.has("min_attr") and not _min_attr_ok(reqs.min_attr):
			entry["disabled"] = true
		choices_out.append(entry)
	if choices_out.is_empty():
		choices_out.append({"label": "Zur Kenntnis genommen", "fn": func(): return ""})
	return {"title": subst(str(def.title), ctx), "text": subst(str(def.text), ctx), "choices": choices_out}


func _choice_fn(ch: Dictionary, ctx: Dictionary) -> Callable:
	return func() -> String:
		var ok := true
		if ch.has("check"):
			if ch.has("success_chance"):
				push_warning("EvEngine: Choice trägt check UND success_chance — check gewinnt.")
			ok = Util.chance(check_chance(ch.check))
			# Aus Proben lernt man — aus Fehlschlägen etwas weniger.
			Game.attr_gain(str(ch.check.get("attr", "")), 0.4 if ok else 0.15)
		elif ch.has("success_chance"):
			ok = Util.chance(float(ch.success_chance))
		var effects: Array = ch.get("effects", []) if ok else ch.get("effects_fail", ch.get("effects", []))
		apply_effects(effects, ctx)
		var out := str(ch.get("outcome", "")) if ok else str(ch.get("outcome_fail", ch.get("outcome", "")))
		return subst(out, ctx)


# ---------- Platzhalter ----------
var _money_re := RegEx.create_from_string("\\{money_fmt:(\\d+)\\}")


func subst(s: String, ctx: Dictionary) -> String:
	var st = Game.state
	if s.contains("{client}") and ctx.has("cid"):
		var c = Game.client(ctx.cid)
		if c != null:
			s = s.replace("{client}", Game.client_name(c))
	if s.contains("{studio}") and ctx.has("sid"):
		s = s.replace("{studio}", str(Game._studio(str(ctx.sid)).name))
	# Dialog-/Brief-Kontext (Feature: Dialogsystem): {contact} & {sender}
	if s.contains("{contact}") and ctx.has("ctid"):
		var ct: Dictionary = Persona.contact_by_id(ctx.ctid)
		if not ct.is_empty():
			s = s.replace("{contact}", str(ct.name))
	if s.contains("{sender}"):
		s = s.replace("{sender}", str(ctx.get("sender", "an unknown hand")))
	s = s.replace("{agency}", str(st.agency.name)).replace("{year}", str(int(st.year)))
	for m in _money_re.search_all(s):
		s = s.replace(m.get_string(0), Util.fmt_money(_money(float(m.get_string(1)))))
	return s


func _money(base: float) -> float:
	return roundf(base * Util.infl(Game.state.year))


# ---------- Effekt-Interpreter ----------
# lines sammelt menschenlesbare Rückmeldungen einzelner Ops — das
# Dialogsystem leert und liest den Puffer rund um apply_effects().
var lines: Array = []


func _say(text_s: String, ctx: Dictionary) -> void:
	lines.append(subst(text_s, ctx))


func apply_effects(effects: Array, ctx: Dictionary) -> void:
	for ef in effects:
		if ef is Dictionary:
			_apply_effect(ef, ctx)


func _apply_effect(ef: Dictionary, ctx: Dictionary) -> void:
	var st = Game.state
	var c = Game.client(ctx.cid) if ctx.has("cid") else null
	var amount := float(ef.get("amount", 0.0))
	match str(ef.get("op", "")):
		"money":
			var v := _money(amount) if bool(ef.get("inflate", false)) else amount
			Game.book(v, str(ef.get("cat", "events")), subst(str(ef.get("label", "Ereignis")), ctx))
		"rep":
			st.agency.rep = clampi(int(st.agency.rep) + int(amount), 0, 100)
		"instinct":
			st.instinct = clampf(float(st.get("instinct", 0)) + amount, 0.0, 100.0)
		"fame":
			if c != null:
				c.fame = clampf(float(c.fame) + amount, 5.0, 100.0)
		"mood":
			if c != null:
				c.mood = clampf(float(c.mood) + amount, 0.0, 100.0)
		"heat":
			if c != null:
				c.heat = clampf(float(c.heat) + amount, -10.0, 10.0)
		"exhaustion":
			if c != null:
				c.exhaustion = clampf(float(c.exhaustion) + amount, 0.0, 100.0)
		"weight":
			if c != null:
				Game.change_client_weight(c, amount)
		"loyalty":
			if c != null:
				c.loyalty = clampf(float(c.loyalty) + amount, 0.0, 100.0)
		"trust":
			if c != null:
				Game.change_trust(c, amount)
		"dna":
			if c != null and c.dna.has(str(ef.get("key", ""))):
				var k := str(ef.key)
				c.dna[k] = clampf(float(c.dna[k]) + amount, -100.0, 100.0)
		"flag_set":
			if c != null:
				c.flags[str(ef.get("key", "flag"))] = ef.get("value", true)
		"studio_rel":
			var sid := str(ef.get("studio", ctx.get("sid", "")))
			if sid != "" and st.studioRel.has(sid):
				st.studioRel[sid] = clampi(int(st.studioRel[sid]) + int(amount), 0, 100)
		"favor_grant":
			Game.grant_favor(_pick_kind(str(ef.get("kind", "extraAudition"))), _favor_from(ef, ctx))
		"favor_consume":
			Game.consume_favor(str(ef.get("kind", "")))
		"favor_owe":
			Game.owe_favor(_pick_kind(str(ef.get("kind", "extraAudition"))), _favor_from(ef, ctx))
		"rumor":
			if c != null:
				Game.add_rumor(int(c.id), subst(str(ef.get("text", "")), ctx), bool(ef.get("truth", false)),
					str(ef.get("topic", "skandal")), ef.get("holders", ["Journalisten"]),
					float(ef.get("belief", 20.0)), bool(ef.get("known", true)))
		"identity":
			Game.record_identity(str(ef.get("key", "")), amount)
		"log":
			Game.log_msg(subst(str(ef.get("text", "")), ctx), str(ef.get("type", "info")))
		"followup":
			# Eventkette: delay_weeks bleibt das Datenformat; intern derzeit
			# Monatsauflösung (aufgerundet), Umstellung auf Wochen folgt.
			var delay_w := int(ef.get("delay_weeks", 4))
			st.followups.append({"type": "json", "event": str(ef.get("event", "")),
				"ctx": {"cid": ctx.get("cid"), "sid": ctx.get("sid")},
				"due": Game.mi() + maxi(1, roundi(delay_w / 4.0))})
		# ---------- Dialog-/Brief-Ops (Feature: Dialogsystem, alle moddbar) ----------
		"chance":
			# Zufallszweig: {"op":"chance","p":0.3,"effects":[...],"else":[...]}
			if Util.chance(float(ef.get("p", 0.5))):
				apply_effects(ef.get("effects", []), ctx)
			else:
				apply_effects(ef.get("else", []), ctx)
		"dims":
			# Beziehungsdimensionen des Kontakts im Kontext: {"op":"dims","trust":2,"liking":-1}
			var ct: Dictionary = Persona.contact_by_id(ctx.get("ctid", -1))
			if not ct.is_empty():
				var deltas := {}
				for key in Network.DIMS:
					if ef.has(key):
						deltas[key] = float(ef[key])
				Network.adjust(ct, deltas, bool(ef.get("spill", true)))
		"fact":
			var ct2: Dictionary = Persona.contact_by_id(ctx.get("ctid", -1))
			if not ct2.is_empty():
				Network.add_fact(ct2, subst(str(ef.get("text", "")), ctx), int(ef.get("tone", 1)), float(ef.get("weight", 1.0)))
		"memory":
			var ct3: Dictionary = Persona.contact_by_id(ctx.get("ctid", -1))
			if not ct3.is_empty():
				Persona._memory(ct3, subst(str(ef.get("text", "")), ctx))
		"promise":
			var ct4: Dictionary = Persona.contact_by_id(ctx.get("ctid", -1))
			if not ct4.is_empty():
				_say(Persona._make_promise(ct4, str(ef.get("kind", "")), int(ef.get("witnesses", 0)), bool(ef.get("written", false))), ctx)
		"xp":
			Mogul.grant_xp(str(ef.get("field", "networking")), amount if amount > 0.0 else 1.0, subst(str(ef.get("why", "Learned by doing")), ctx))
		"player":
			# Spielfigur-Werte: {"op":"player","energy":-3,"stress":-5,"discretion":2,...}
			var p: Dictionary = st.player
			for key in ["energy", "stress", "health", "pubRep", "indRep", "discretion", "influence"]:
				if ef.has(key):
					p[key] = clampf(float(p[key]) + float(ef[key]), 5.0 if key == "health" else 0.0, 100.0)
		"money_private":
			var v2 := _money(amount) if bool(ef.get("inflate", false)) else amount
			Persona.book(v2, subst(str(ef.get("label", "Correspondence")), ctx))
		"tip":
			var src: Dictionary = Persona.contact_by_id(ctx.get("ctid", -1))
			if src.is_empty() and Game.state.contacts.size():
				src = Util.pick(Game.state.contacts)
			var tip_line: String = Mogul.maybe_market_tip(src) if not src.is_empty() else ""
			_say(tip_line if tip_line != "" else "The money talk stays vague tonight.", ctx)
		"rumor_reveal":
			var found := false
			for rumor in st.rumors:
				if not bool(rumor.knownToPlayer):
					rumor.knownToPlayer = true
					found = true
					_say("A name is dropped — a story reaches you that you would never have heard otherwise.", ctx)
					break
			if not found:
				_say("The town is quiet this week — even the gossips have nothing.", ctx)
		"casting_spawn":
			Game.spawn_castings(maxi(int(amount), 1))
			_say("A project lands on your desk that was not public knowledge.", ctx)
		"meet_someone":
			var met: Dictionary = Network._meet_someone(subst(str(ef.get("origin", "at an evening among people")), ctx))
			if not met.is_empty():
				_say("A handshake becomes a name in your book: [b]%s[/b]." % str(met.name), ctx)
			else:
				_say("Familiar faces everywhere — no new names tonight.", ctx)
		"seal_deal":
			var ct5: Dictionary = Persona.contact_by_id(ctx.get("ctid", -1))
			var deal_def: Dictionary = Mogul.deal_def(str(ctx.get("dealId", "")))
			if not ct5.is_empty() and not deal_def.is_empty():
				_say(Mogul._accept_deal(ct5, deal_def), ctx)
		"gate_rel":
			var ct6: Dictionary = Persona.contact_by_id(ctx.get("ctid", -1))
			if not ct6.is_empty() and not Network.gate_of(ct6).is_empty():
				var gate: Dictionary = Network.gate_of(ct6)
				gate.rel = clampf(float(gate.rel) + amount, 0.0, 100.0)
		"memoir":
			Network.memoir(subst(str(ef.get("text", "")), ctx))
		# Privatleben (Feature 44): Partnerschaft, Freundschaften, Familie
		"private_life":
			var line := Persona.private_action(str(ef.get("action", "")), amount, str(ctx.get("sender", "")))
			if line != "":
				_say(line, ctx)
		# Gefallen als Verpflichtungen (Feature 31): eingeforderte Schulden
		"settle_debt":
			var debt := _debt_from_sender(ctx)
			if not debt.is_empty():
				if str(ef.get("pay", "favor")) == "cash":
					Persona.book(-_money(float(ef.get("amount", 120))), "An old debt, settled")
				else:
					Game.consume_any_favor()
				Game.remove_debt(debt.id)
				var ct7: Dictionary = Persona.contact_by_id(ctx.get("ctid", -1))
				if not ct7.is_empty():
					Network.adjust(ct7, {"trust": 5.0, "liking": 3.0}, false)
					Network.add_fact(ct7, "honors their debts", 1, 1.5)
				_say("The ledger between you is even again — and everyone involved knows it.", ctx)
		"refuse_debt":
			var debt2 := _debt_from_sender(ctx)
			if not debt2.is_empty():
				Game.remove_debt(debt2.id)
			var ct8: Dictionary = Persona.contact_by_id(ctx.get("ctid", -1))
			if not ct8.is_empty():
				Network.adjust(ct8, {"trust": -6.0, "irritation": 8.0})
				Network.add_fact(ct8, "does not honor their debts", -1, 2.0)
			Game.record_identity("skrupellos", 1.0)
			if Util.chance(0.4):
				Game.add_rumor("agency", "They say %s takes help gladly — and forgets it just as gladly." % st.agency.name, true, "skandal", ["Party guests"], 20.0, true)
			_say("Refused debts do not disappear in this town. They compound — in whispers.", ctx)
		_:
			push_warning("EvEngine: Unbekannte Effekt-Op „%s“ — übersprungen." % str(ef.get("op", "")))


# Älteste Schuld gegenüber dem Brief-Absender im Kontext finden.
func _debt_from_sender(ctx: Dictionary) -> Dictionary:
	var best := {}
	for d in Game.state.debts:
		if str(d["from"].get("name", "")) == str(ctx.get("sender", "")):
			if best.is_empty() or int(d.gainedMi) < int(best.gainedMi):
				best = d
	return best


# "a|b|c" ⇒ zufällige Auswahl, sonst der Wert selbst
func _pick_kind(kind: String) -> String:
	if kind.contains("|"):
		return str(Util.pick(kind.split("|")))
	return kind


func _favor_from(ef: Dictionary, ctx: Dictionary) -> Dictionary:
	if str(ef.get("from", "")) == "studio" and ctx.has("sid"):
		var s = Game._studio(str(ctx.sid))
		return {"type": "studio", "name": str(s.name), "studioId": str(ctx.sid)}
	return {}
