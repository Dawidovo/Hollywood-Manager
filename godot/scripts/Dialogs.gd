extends Node
# =====================================================================
# Hollywood Manager — Dialogsystem & Korrespondenz (Autoload "Dialogs").
# 1) Datengetriebene Gesprächs-Engine: data/dialogs/*.json definiert
#    Dialogbäume (nodes → choices → goto) für die wichtigen Interaktionen
#    (Dinner, Clubabend, Hinterzimmer, Gala, …). Bedingungen, Würfe und
#    Effekte sind deklarativ; die Effekt-Ops teilt sich das System mit
#    der Event-Engine (EvEngine) — Mods erweitern beide mit einer Sprache.
# 2) Zentraler Posteingang: data/letters/*.json definiert die Briefe
#    (bzw. E-Mails, je nach Epoche) der Woche; jeder Brief bietet
#    Auswahlmöglichkeiten im selben Effekt-Format.
# Beides ist über user://data/ voll modbar (siehe data/README.md).
# =====================================================================

const INBOX_MAX_OPEN := 4
const INBOX_ARCHIVE_MAX := 16
const LETTER_COOLDOWN_WEEKS := 10

# Laufender Dialog (nur zur Laufzeit, wird nie gespeichert).
var run = null


func _st() -> Dictionary:
	return Game.state


# =====================================================================
# State & Migration
# =====================================================================
func init_state() -> void:
	var st := _st()
	st["inbox"] = []
	st["inboxSeen"] = {}


func ensure_inbox() -> void:
	var st := _st()
	if st == null:
		return
	if not st.has("inbox") or not (st.inbox is Array):
		st["inbox"] = []
	if not st.has("inboxSeen") or not (st.inboxSeen is Dictionary):
		st["inboxSeen"] = {}


# Epochengefühl: Briefpost bis in die Neunziger, danach E-Mail.
func mail_word() -> String:
	return "Letters" if int(_st().year) < 1995 else "E-mail"


func mail_icon() -> String:
	return "📬" if int(_st().year) < 1995 else "📧"


# =====================================================================
# Dialog-Engine
# =====================================================================
func dialog_def(id_s: String) -> Dictionary:
	for d in Data.DIALOGS:
		if str(d.id) == id_s:
			return d
	return {}


func has_dialog(id_s: String) -> bool:
	return not dialog_def(id_s).is_empty()


func start(id_s: String, ctx: Dictionary = {}) -> Dictionary:
	var def := dialog_def(id_s)
	if def.is_empty():
		return {"done": true, "title": "…", "text": "Silence.", "lines": [], "choices": []}
	run = {"def": def, "node": str(def.get("start", "opening")), "ctx": ctx.duplicate(true), "lines": []}
	_enter_node()
	return view()


func _node() -> Dictionary:
	return run.def.get("nodes", {}).get(str(run.node), {})


func _enter_node() -> void:
	var node := _node()
	EvEngine.lines.clear()
	EvEngine.apply_effects(node.get("effects", []), run.ctx)
	run.lines.append_array(EvEngine.lines)
	EvEngine.lines.clear()


# Warum eine Antwort gerade nicht wählbar ist ("" = frei).
func choice_blocked_reason(ch: Dictionary) -> String:
	var conds: Dictionary = ch.get("conditions", {})
	if conds.is_empty():
		return ""
	var ct: Dictionary = Persona.contact_by_id(run.ctx.get("ctid", -1)) if run != null else {}
	for key in conds.get("dims", {}):
		if ct.is_empty() or Network.dim(ct, str(key)) < float(conds.dims[key]):
			return "Needs %s %d with them" % [str(Network.DIM_INFO.get(str(key), {}).get("name", key)), int(conds.dims[key])]
	for field in conds.get("skill_level", {}):
		if Mogul.level(str(field)) < int(conds.skill_level[field]):
			return "Needs %s level %d" % [str(Data.SKILL_FIELDS.get(str(field), {}).get("name", field)), int(conds.skill_level[field])]
	if conds.has("min_cash_private") and float(_st().player.cash) < roundf(float(conds.min_cash_private) * Game.infl(_st().year)):
		return "Privately short on cash"
	var fav := str(conds.get("has_favor", ""))
	if fav != "" and not Game.has_favor(fav):
		return "You hold no such favor"
	return ""


# Erfolgswahrscheinlichkeit eines Würfelwurfs: Basis + Fähigkeit + Beziehung.
func check_p(check: Dictionary) -> float:
	var p := float(check.get("base", 0.5))
	if check.has("skill"):
		p += float(Mogul.level(str(check.skill))) * 0.06
	if check.has("dim") and run != null:
		var ct: Dictionary = Persona.contact_by_id(run.ctx.get("ctid", -1))
		if not ct.is_empty():
			p += Network.dim(ct, str(check.dim)) / 300.0
	return clampf(p, 0.05, 0.95)


func choose(idx: int) -> Dictionary:
	if run == null:
		return {"done": true, "title": "…", "text": "", "lines": [], "choices": []}
	var choices: Array = _node().get("choices", [])
	if idx < 0 or idx >= choices.size():
		return view()
	var ch: Dictionary = choices[idx]
	if choice_blocked_reason(ch) != "":
		return view()
	EvEngine.lines.clear()
	EvEngine.apply_effects(ch.get("effects", []), run.ctx)
	var next := str(ch.get("goto", "end"))
	# Würfe: Fähigkeit und Beziehung entscheiden, wohin das Gespräch kippt.
	if ch.has("check"):
		var check: Dictionary = ch.check
		if check.has("skill"):
			Mogul.grant_xp(str(check.skill), 0.5, "Tried, in conversation")
		next = str(check.get("success", "end")) if Game.chance(check_p(check)) else str(check.get("fail", "end"))
	run.lines.append_array(EvEngine.lines)
	EvEngine.lines.clear()
	if next == "end" or not run.def.get("nodes", {}).has(next):
		run.node = "end"
		return view()
	run.node = next
	_enter_node()
	if bool(_node().get("end", false)) and _node().get("choices", []).is_empty():
		# Endknoten ohne eigene Antworten: Text zeigen, dann ist Schluss.
		pass
	return view()


func view() -> Dictionary:
	if run == null:
		return {"done": true, "title": "…", "text": "", "lines": [], "choices": []}
	var node := _node()
	var done: bool = run.node == "end" or (bool(node.get("end", false)) and node.get("choices", []).is_empty())
	var texts: Array = node.get("text", []) if node.get("text") is Array else [node.get("text", "")]
	var text_s := EvEngine.subst(str(Game.pick(texts)) if texts.size() else "", run.ctx)
	var out := {"done": done, "title": EvEngine.subst(str(run.def.get("title", "Conversation")), run.ctx),
		"text": text_s, "lines": run.lines.duplicate(), "choices": []}
	if not done:
		for ch in node.get("choices", []):
			var reason := choice_blocked_reason(ch)
			out.choices.append({"label": EvEngine.subst(str(ch.get("label", "…")), run.ctx),
				"disabled": reason != "", "reason": reason})
	if done:
		run = null
	return out


# =====================================================================
# Posteingang: die Briefe/E-Mails der Woche
# =====================================================================
func letter_def(id_s: String) -> Dictionary:
	for d in Data.LETTERS:
		if str(d.id) == id_s:
			return d
	return {}


func open_letters() -> Array:
	return _st().get("inbox", []).filter(func(l): return str(l.status) == "open")


# Absender auflösen: passender Kontakt aus dem Buch (dann wirken
# dims-Effekte auf ihn), sonst ein Name aus den Pools.
func _resolve_sender(def: Dictionary) -> Dictionary:
	var from_type := str(def.get("from_type", "stranger"))
	for ct in _st().contacts:
		if str(ct.type) == from_type:
			return {"name": str(ct.name), "type": from_type, "ctid": int(ct.id)}
	if Data.CONTACT_PERSONS.has(from_type):
		return {"name": str(Game.pick(Data.CONTACT_PERSONS[from_type])), "type": from_type}
	var first: String = Game.pick(Data.NPC_FIRST_F if Game.chance(0.5) else Data.NPC_FIRST_M)
	return {"name": "%s %s" % [first, Game.pick(Data.NPC_LAST)], "type": "stranger"}


func _letter_conditions_ok(def: Dictionary) -> bool:
	var conds: Dictionary = def.get("conditions", {})
	if int(_st().year) < int(conds.get("min_year", 0)) or int(_st().year) > int(conds.get("max_year", 9999)):
		return false
	if int(_st().player.career) < int(conds.get("min_career", 0)):
		return false
	var req_type := str(conds.get("requires_contact_type", ""))
	if req_type != "" and not _st().contacts.any(func(ct): return str(ct.type) == req_type):
		return false
	if conds.has("chance") and not Game.chance(float(conds.chance)):
		return false
	return true


func spawn_letter(template_id: String, force: bool = false) -> Dictionary:
	var st := _st()
	var def := letter_def(template_id)
	if def.is_empty():
		return {}
	if not force and not _letter_conditions_ok(def):
		return {}
	var sender := _resolve_sender(def)
	var ctx := {"sender": str(sender.name)}
	if sender.has("ctid"):
		ctx["ctid"] = int(sender.ctid)
	var letter := {"id": Game.next_id(), "tid": template_id, "mi": Game.mi(), "wi": Game.wi(),
		"from": sender, "subject": EvEngine.subst(str(def.get("subject", "…")), ctx),
		"body": EvEngine.subst(str(def.get("body", "")), ctx),
		"status": "open", "expireWi": Game.wi() + int(def.get("expire_weeks", 3)), "outcome": ""}
	st.inbox.append(letter)
	st.inboxSeen[template_id] = Game.wi()
	return letter


# Wöchentliche Zustellung: 1–2 Briefe, gewichtete Vorlagen, Cooldowns.
func tick_week() -> void:
	var st := _st()
	if st == null or not st.has("inbox"):
		return
	# Ablauf: Liegengebliebenes verfällt — manchmal mit Konsequenzen.
	for letter in st.inbox:
		if str(letter.status) == "open" and Game.wi() > int(letter.expireWi):
			letter.status = "expired"
			var def := letter_def(str(letter.tid))
			var ctx := _letter_ctx(letter)
			EvEngine.apply_effects(def.get("expire_effects", []), ctx)
			EvEngine.lines.clear()
	# Zustellung
	if open_letters().size() < INBOX_MAX_OPEN:
		var want := 1 + (1 if Game.chance(0.4) else 0)
		for i in want:
			var pool: Array = []
			for def in Data.LETTERS:
				if Game.wi() - int(st.inboxSeen.get(str(def.id), -999)) < LETTER_COOLDOWN_WEEKS:
					continue
				if st.inbox.any(func(l): return str(l.tid) == str(def.id) and str(l.status) == "open"):
					continue
				if not _letter_conditions_ok(def):
					continue
				for w in maxi(int(def.get("weight", 1)), 1):
					pool.append(def)
			if pool.is_empty():
				break
			spawn_letter(str(Game.pick(pool).id), true)
	# Archiv kompakt halten
	while st.inbox.size() > INBOX_MAX_OPEN + INBOX_ARCHIVE_MAX:
		var oldest = null
		for letter in st.inbox:
			if str(letter.status) != "open" and (oldest == null or int(letter.wi) < int(oldest.wi)):
				oldest = letter
		if oldest == null:
			break
		st.inbox.erase(oldest)


func _letter_ctx(letter: Dictionary) -> Dictionary:
	var ctx := {"sender": str(letter["from"].get("name", "?"))}
	if letter["from"].has("ctid"):
		ctx["ctid"] = int(letter["from"].ctid)
	return ctx


func letter_by_id(lid) -> Dictionary:
	for letter in _st().inbox:
		if int(letter.id) == int(lid):
			return letter
	return {}


# Warum eine Brief-Option gerade nicht wählbar ist ("" = frei).
func letter_choice_blocked(_letter: Dictionary, ch: Dictionary) -> String:
	var reqs: Dictionary = ch.get("requirements", {})
	if int(reqs.get("ap", 0)) > int(_st().contactAP):
		return "No contact time left this week"
	if reqs.has("min_cash_private") and float(_st().player.cash) < roundf(float(reqs.min_cash_private) * Game.infl(_st().year)):
		return "Privately short on cash"
	if bool(reqs.get("requires_assistant", false)) and not Persona.has_assistant():
		return "You employ no assistant"
	return ""


# Eine Brief-Option ausführen: Effekte (ggf. mit Erfolgswurf) anwenden.
func letter_choose(lid, idx: int) -> Dictionary:
	var letter := letter_by_id(lid)
	if letter.is_empty() or str(letter.status) != "open":
		return {"ok": false, "text": "That page has already been turned."}
	var def := letter_def(str(letter.tid))
	var choices: Array = def.get("choices", [])
	if idx < 0 or idx >= choices.size():
		return {"ok": false, "text": "…"}
	var ch: Dictionary = choices[idx]
	var reason := letter_choice_blocked(letter, ch)
	if reason != "":
		return {"ok": false, "text": reason}
	var ctx := _letter_ctx(letter)
	var reqs: Dictionary = ch.get("requirements", {})
	if int(reqs.get("ap", 0)) > 0:
		_st().contactAP = int(_st().contactAP) - int(reqs.ap)
	# Brief kann auch ein Gespräch eröffnen (op-frei, per "dialog"-Feld)
	if ch.has("dialog") and has_dialog(str(ch.dialog)):
		letter.status = "done"
		letter.outcome = "You follow up in person."
		return {"ok": true, "dialog": str(ch.dialog), "ctx": ctx}
	var ok := true
	if ch.has("success_chance"):
		ok = Game.chance(float(ch.success_chance))
	EvEngine.lines.clear()
	EvEngine.apply_effects(ch.get("effects", []) if ok else ch.get("effects_fail", ch.get("effects", [])), ctx)
	var extra: Array = EvEngine.lines.duplicate()
	EvEngine.lines.clear()
	letter.status = "done"
	var out := EvEngine.subst(str(ch.get("outcome", "Done.")) if ok else str(ch.get("outcome_fail", ch.get("outcome", "Done."))), ctx)
	if extra.size():
		out += "\n\n" + "\n".join(extra)
	letter.outcome = out
	return {"ok": true, "text": out}
