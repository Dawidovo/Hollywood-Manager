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
func check_conditions(conds: Dictionary, ctx: Dictionary = {}) -> bool:
	var st = Game.state
	if conds.is_empty():
		return true
	if int(st.year) < int(conds.get("min_year", -9999)):
		return false
	if int(st.year) > int(conds.get("max_year", 9999)):
		return false
	if int(st.agency.rep) < int(conds.get("min_rep", -9999)):
		return false
	if int(st.agency.rep) > int(conds.get("max_rep", 9999)):
		return false
	if conds.has("min_cash") and float(st.agency.cash) < _money(float(conds.min_cash)):
		return false
	if st.clients.size() < int(conds.get("min_clients", 0)):
		return false
	var fav := str(conds.get("has_favor", ""))
	if fav != "" and not Game.has_favor(fav):
		return false
	var bs := str(conds.get("backstory", ""))
	if bs != "" and str(st.get("backstory", "")) != bs:
		return false
	if conds.get("requires_client") != null and not ctx.has("cid"):
		if _client_candidates(conds.requires_client).is_empty():
			return false
	if bool(conds.get("requires_studio", false)) and Game.active_studios().is_empty():
		return false
	if conds.has("chance") and not Game.chance(float(conds.chance)):
		return false
	return true


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
		ctx["cid"] = int(Game.pick(cands).id)
	if not ctx.has("sid") and bool(conds.get("requires_studio", false)):
		var studios: Array = Game.active_studios()
		if studios.is_empty():
			return null
		ctx["sid"] = str(Game.pick(studios).id)
	var choices_out: Array = []
	for ch in def.get("choices", []):
		var reqs: Dictionary = ch.get("requirements", {})
		var fav := str(reqs.get("has_favor", ""))
		if fav != "" and not Game.has_favor(fav):
			continue
		var bs := str(reqs.get("backstory", ""))
		if bs != "" and str(Game.state.get("backstory", "")) != bs:
			continue
		var entry := {"label": subst(str(ch.get("label", "Weiter")), ctx), "fn": _choice_fn(ch, ctx)}
		# Geld-Anforderungen bleiben sichtbar, sind aber ausgegraut
		if reqs.has("min_cash") and float(Game.state.agency.cash) < _money(float(reqs.min_cash)):
			entry["disabled"] = true
		choices_out.append(entry)
	if choices_out.is_empty():
		choices_out.append({"label": "Zur Kenntnis genommen", "fn": func(): return ""})
	return {"title": subst(str(def.title), ctx), "text": subst(str(def.text), ctx), "choices": choices_out}


func _choice_fn(ch: Dictionary, ctx: Dictionary) -> Callable:
	return func() -> String:
		var ok := true
		if ch.has("success_chance"):
			ok = Game.chance(float(ch.success_chance))
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
	s = s.replace("{agency}", str(st.agency.name)).replace("{year}", str(int(st.year)))
	for m in _money_re.search_all(s):
		s = s.replace(m.get_string(0), Game.fmt_money(_money(float(m.get_string(1)))))
	return s


func _money(base: float) -> float:
	return roundf(base * Game.infl(Game.state.year))


# ---------- Effekt-Interpreter ----------
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
		_:
			push_warning("EvEngine: Unbekannte Effekt-Op „%s“ — übersprungen." % str(ef.get("op", "")))


# "a|b|c" ⇒ zufällige Auswahl, sonst der Wert selbst
func _pick_kind(kind: String) -> String:
	if kind.contains("|"):
		return str(Game.pick(kind.split("|")))
	return kind


func _favor_from(ef: Dictionary, ctx: Dictionary) -> Dictionary:
	if str(ef.get("from", "")) == "studio" and ctx.has("sid"):
		var s = Game._studio(str(ctx.sid))
		return {"type": "studio", "name": str(s.name), "studioId": str(ctx.sid)}
	return {}
