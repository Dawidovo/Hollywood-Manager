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

# Strikte Trennung von Simulation und Text (Feature 26): Text darf nur
# über bekannte Ops und Platzhalter auf die Simulation zugreifen —
# nichts erfinden, nichts direkt verändern. Alles andere wird beim
# Laden angemeckert.
const KNOWN_OPS := ["money", "rep", "instinct", "fame", "mood", "heat", "exhaustion", "weight",
	"loyalty", "trust", "dna", "flag_set", "studio_rel", "favor_grant", "favor_consume",
	"favor_owe", "rumor", "identity", "log", "followup", "chance", "dims", "fact", "memory",
	"promise", "xp", "player", "money_private", "tip", "rumor_reveal", "casting_spawn",
	"meet_someone", "seal_deal", "gate_rel", "memoir", "settle_debt", "refuse_debt", "private_life",
	"client_promise", "press_event", "rumor_belief"]
const KNOWN_PLACEHOLDERS := ["contact", "sender", "agency", "year", "client", "studio", "need"]

# Laufender Dialog (nur zur Laufzeit, wird nie gespeichert).
var run = null


func _ready() -> void:
	for warning in validate_defs():
		push_warning("Dialogs: %s" % warning)


func _st() -> Dictionary:
	return Game.state


# =====================================================================
# State & Migration
# =====================================================================
func init_state() -> void:
	var st := _st()
	st["inbox"] = []
	st["inboxSeen"] = {}
	st["weekDigest"] = []
	st["seenKinds"] = {}
	st["outMail"] = []
	st["usedLines"] = []
	st["weekScenes"] = 0
	st["weekScenesNoted"] = false


func ensure_inbox() -> void:
	var st := _st()
	if st == null:
		return
	if not st.has("inbox") or not (st.inbox is Array):
		st["inbox"] = []
	if not st.has("inboxSeen") or not (st.inboxSeen is Dictionary):
		st["inboxSeen"] = {}
	if not st.has("weekDigest") or not (st.weekDigest is Array):
		st["weekDigest"] = []
	if not st.has("seenKinds") or not (st.seenKinds is Dictionary):
		st["seenKinds"] = {}
	if not st.has("outMail") or not (st.outMail is Array):
		st["outMail"] = []
	if not st.has("usedLines") or not (st.usedLines is Array):
		st["usedLines"] = []
	if not st.has("weekScenes"):
		st["weekScenes"] = 0
	if not st.has("weekScenesNoted"):
		st["weekScenesNoted"] = false


# =====================================================================
# Bedeutungsstaffelung (Feature 24/25): Routine wird zusammengefasst,
# Wichtiges wird zur Nachricht, Entscheidungen zum Kurzdialog, Wende-
# punkte zur vollen Szene. Die Relevanz bewertet Person, Konsequenz,
# Zeitdruck und Neuigkeitswert — automatisch.
# =====================================================================
# Wie groß muss diese Interaktion sein? (öffentlich, auch für Tests/Mods)
func relevance(kind: String, ctx: Dictionary) -> float:
	var st := _st()
	var score := float(ctx.get("impact", 0.0))
	var ct: Dictionary = Persona.contact_by_id(ctx.get("ctid", -1))
	if not ct.is_empty():
		if Network.is_vip(ct):
			score += 2.0
		if float(ct.rel) >= 60.0:
			score += 1.0
		elif float(ct.rel) >= 40.0:
			score += 0.5
	if ctx.has("dueMi") and int(ctx.dueMi) - Game.mi() <= 1:
		score += 1.0
	var seen := int(st.seenKinds.get(kind, 0))
	score += 2.0 if seen == 0 else (1.0 if seen < 3 else 0.0)
	st.seenKinds[kind] = seen + 1
	return score


# Zentrale Weiche: entscheidet, WIE eine Meldung den Spieler erreicht.
# ctx: impact (0–3), ctid?, dueMi?, text (Digest-Zeile), subject/body
# (Nachricht), scene_letter (Briefvorlage für Kurzdialog/Szene).
func dispatch(kind: String, ctx: Dictionary) -> String:
	var score := relevance(kind, ctx)
	if score < 2.5:
		if str(ctx.get("text", "")) != "":
			_st().weekDigest.append(str(ctx.text))
		return "digest"
	# Szene/Kurzdialog: eine Briefvorlage mit echten Antworten
	if ctx.has("scene_letter") and score >= 4.0 and not letter_def(str(ctx.scene_letter)).is_empty():
		var ct: Dictionary = Persona.contact_by_id(ctx.get("ctid", -1))
		spawn_letter_for(str(ctx.scene_letter), ct)
		return "scene" if score >= 6.0 else "event"
	add_notice(str(ctx.get("subject", "A note")), str(ctx.get("body", ctx.get("text", ""))), Persona.contact_by_id(ctx.get("ctid", -1)))
	return "notice"


# Routine der Woche: eine Zeile im Ticker statt fünf Unterbrechungen.
func flush_digest() -> void:
	var st := _st()
	if st == null or not st.has("weekDigest") or st.weekDigest.is_empty():
		return
	Game.log_msg("In passing: %s" % " · ".join(st.weekDigest.slice(0, 5)), "info")
	st.weekDigest = []


# Eine einfache Nachricht im Posteingang (ohne Vorlage): nur ablegen.
func add_notice(subject: String, body: String, sender_ct: Dictionary = {}) -> Dictionary:
	var st := _st()
	var from := {"name": str(sender_ct.get("name", "Your desk")), "type": str(sender_ct.get("type", "notiz"))}
	if not sender_ct.is_empty():
		from["ctid"] = int(sender_ct.id)
	var letter := {"id": Game.next_id(), "tid": "", "mi": Game.mi(), "wi": Game.wi(),
		"from": from, "subject": subject, "body": body,
		"status": "open", "expireWi": Game.wi() + 4, "outcome": ""}
	st.inbox.append(letter)
	return letter


func dismiss_letter(lid) -> void:
	var letter := letter_by_id(lid)
	if not letter.is_empty() and str(letter.status) == "open":
		letter.status = "done"
		letter.outcome = "Noted."


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
	# Gesprächserinnerung (Feature 27): das Gegenüber spricht Vergangenes
	# konkret an — Hilfe, Vernachlässigung, gebrochene Zusagen.
	var recall := recall_for(Persona.contact_by_id(ctx.get("ctid", -1)))
	if not recall.is_empty():
		run.lines.append(str(recall.text))
		Network.adjust(Persona.contact_by_id(ctx.get("ctid", -1)), recall.get("dims", {}), false)
	_enter_node()
	return view()


# =====================================================================
# Feature 27 — Gesprächserinnerungen: Menschen sprechen Dinge an.
# Feature 28 — jede Erinnerung hat eine Abklingzeit, nichts wird zweimal
# in derselben Tonlage vorgehalten.
# =====================================================================
const RECALL_COOLDOWN_WEEKS := 12


func recall_for(ct: Dictionary) -> Dictionary:
	if ct.is_empty():
		return {}
	var st := _st()
	# 1) Gebrochene Zusagen wiegen am schwersten — und werden genau einmal
	#    ins Gesicht gesagt.
	for pr in st.promises:
		if str(pr.status) == "broken" and str(pr.to) == str(ct.name) and not bool(pr.get("recalled", false)):
			pr["recalled"] = true
			return {"text": "»You gave me your word, back in %s,« says %s — not angry, just precise. The sentence stays at the table for a while." % [Game.mi_str(pr.madeMi), str(ct.name)],
				"dims": {"irritation": 2.0}}
	# 2) Verpasste Anlässe: das Schweigen über den nie erfolgten Rückruf.
	for occ in st.get("occasions", []):
		if str(occ.status) == "missed" and str(occ.ctName) == str(ct.name) and not bool(occ.get("recalled", false)):
			occ["recalled"] = true
			return {"text": "There is half a beat of silence — the call you never returned sits between you like a third guest.",
				"dims": {"irritation": 1.0}}
	# 3) Fakten, gute wie schlechte — mit Abklingzeit pro Formulierung.
	for f in ct.get("facts", []):
		if Game.wi() - int(f.get("recalledWi", -999)) < RECALL_COOLDOWN_WEEKS:
			continue
		f["recalledWi"] = Game.wi()
		if int(f.tone) < 0:
			return {"text": "%s brings up, almost casually, that you %s. Almost casually." % [str(ct.name), str(f.text)],
				"dims": {"irritation": 1.0}}
		return {"text": "»I haven't forgotten that you %s,« says %s, and raises the glass an inch." % [str(f.text), str(ct.name)],
			"dims": {"liking": 1.0, "trust": 1.0}}
	return {}


# =====================================================================
# Feature 29 — Kommunikationsbudget: nur wenige große Szenen pro Woche.
# Wer mehr führt, ist im Krisenmodus — und zahlt mit Substanz.
# =====================================================================
const SCENES_PER_WEEK := 2


func note_scene() -> void:
	var st := _st()
	if st == null or not st.has("weekScenes"):
		return
	st.weekScenes = int(st.weekScenes) + 1
	if int(st.weekScenes) > SCENES_PER_WEEK and not bool(st.weekScenesNoted):
		st.weekScenesNoted = true
		st.player.stress = clampf(float(st.player.stress) + 3.0, 0.0, 100.0)
		Game.log_msg("A week of wall-to-wall meetings — weeks like this mean something is burning (stress +3).", "bad")


func _node() -> Dictionary:
	return run.def.get("nodes", {}).get(str(run.node), {})


func _enter_node() -> void:
	var node := _node()
	EvEngine.lines.clear()
	EvEngine.apply_effects(node.get("effects", []), run.ctx)
	run.lines.append_array(EvEngine.lines)
	EvEngine.lines.clear()


# Wiederholungskontrolle (Feature 28): schon verwendete Formulierungen
# bekommen eine Abklingzeit — erst wenn alle Varianten durch sind, darf
# sich ein Satz wiederholen.
func _pick_text(texts: Array) -> String:
	if texts.is_empty():
		return ""
	var st := _st()
	var used: Array = st.get("usedLines", [])
	var fresh: Array = texts.filter(func(t): return not used.has(Util.hashs(str(t))))
	var chosen := str(Util.pick(fresh if fresh.size() else texts))
	used.append(Util.hashs(chosen))
	while used.size() > 60:
		used.pop_front()
	return chosen


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
	if conds.has("min_cash_private") and float(_st().player.cash) < roundf(float(conds.min_cash_private) * Util.infl(_st().year)):
		return "Privately short on cash"
	var fav := str(conds.get("has_favor", ""))
	if fav != "" and not Game.has_favor(fav):
		return "You hold no such favor"
	# Fähigkeits-Auswege (Teil B2): manche Antworten kann nur, wer das
	# Handwerk dafür gelernt hat (z. B. der Spin-Doctor am Podium).
	var ability := str(conds.get("has_ability", ""))
	if ability != "" and not Mogul.has_ability(ability):
		var ability_name := ability
		for adef in Data.SKILL_ABILITIES:
			if str(adef.get("id", "")) == ability:
				ability_name = str(adef.get("name", ability))
		return "Needs the ability: %s" % ability_name
	return ""


# Erfolgswahrscheinlichkeit eines Würfelwurfs: Basis + Fähigkeit + Beziehung.
# Attributs-Proben ("attr"/"dc") nutzen DIE Formel der Event-Engine —
# eine Chance-Rechnung im ganzen Spiel, keine Kopie (Teil A2).
func check_p(check: Dictionary) -> float:
	if check.has("attr"):
		return EvEngine.check_chance(check)
	var p := float(check.get("base", 0.5))
	if check.has("skill"):
		p += float(Mogul.level(str(check.skill))) * 0.06
	if check.has("dim") and run != null:
		var ct: Dictionary = Persona.contact_by_id(run.ctx.get("ctid", -1))
		if not ct.is_empty():
			p += Network.dim(ct, str(check.dim)) / 300.0
	return clampf(p, 0.05, 0.95)


# =====================================================================
# Emotionen im Gespräch (Teil A2): Chip, Wahrnehmungszeile und
# Emotions-Gates. Bedingungen prüfen die WAHRE Emotion; der Spieler
# sieht nur die wahrgenommene — bei schlechter Menschenkenntnis fehlen
# oder erscheinen Antworten darum „unerklärlich". Diese Lücke ist gewollt.
# =====================================================================
func _emotion_kind(ctx: Dictionary) -> String:
	# Ein Baum kann sein Emotions-Subjekt festlegen (z. B. Interviews lesen
	# den JOURNALISTEN, obwohl auch ein Klient im Kontext steckt).
	if run != null and str(run.def.get("emotion_subject", "")) != "":
		return str(run.def.emotion_subject)
	if ctx.has("cid"):
		return "client"
	if ctx.has("ctid"):
		return "contact"
	if ctx.has("rid"):
		return "rival"
	return ""


func true_emotion_key(ctx: Dictionary) -> String:
	var kind := _emotion_kind(ctx)
	if kind == "":
		return ""
	return str(Emotions.true_state(kind, ctx).get("key", ""))


# Chip-Inhalt für den Dialog-Header: wahrgenommene Emotion + Konfidenz.
func emotion_view(ctx: Dictionary) -> Dictionary:
	var kind := _emotion_kind(ctx)
	if kind == "":
		return {}
	var p := Emotions.perceived(kind, ctx)
	if p.is_empty():
		return {}
	if str(p.key) == "unreadable":
		return {"text": "🎭 Hard to read", "confidence": "unreadable"}
	var d := Emotions.def_of(str(p.key))
	var text_s := "%s %s" % [str(d.icon), str(d.name)]
	match str(p.confidence):
		"guess":
			text_s += " · just a hunch"
		"likely":
			text_s += " · you're fairly sure"
		"clear":
			text_s += " · unmistakable"
		"certain":
			text_s += " — because %s" % str(p.cause) if str(p.cause) != "" else " · unmistakable"
	return {"text": text_s, "confidence": str(p.confidence)}


# Nur Antworten, deren Emotions-Gate zur WAHREN Emotion passt, sind
# überhaupt sichtbar — view() und choose() teilen sich diese Liste,
# damit die Indizes zusammenpassen.
func _visible_choices(node: Dictionary) -> Array:
	var all: Array = node.get("choices", [])
	var gated: Array = all.filter(func(ch): return ch is Dictionary and ch.has("requires_emotion"))
	if gated.is_empty() or run == null:
		return all
	var true_key := true_emotion_key(run.ctx)
	return all.filter(func(ch):
		if not (ch is Dictionary) or not ch.has("requires_emotion"):
			return true
		return (ch.requires_emotion as Array).has(true_key))


# Wahrnehmungszeile eines Knotens ("reads"): je Präzisionsstufe ein
# anderer Text; Fehllesungen ("guess") sehen die vage Variante.
func _read_line(node: Dictionary) -> String:
	if not node.has("reads") or run == null:
		return ""
	var view_conf := str(emotion_view(run.ctx).get("confidence", ""))
	if view_conf == "guess":
		view_conf = "unreadable"
	return str(node.reads.get(view_conf, ""))


func choose(idx: int) -> Dictionary:
	if run == null:
		return {"done": true, "title": "…", "text": "", "lines": [], "choices": []}
	var choices: Array = _visible_choices(_node())
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
		var ok := Util.chance(check_p(check))
		# Attributs-Probe: aus Proben lernt man — wie bei den Events.
		if check.has("attr"):
			Game.attr_gain(str(check.attr), 0.4 if ok else 0.15)
		next = str(check.get("success", "end")) if ok else str(check.get("fail", "end"))
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
	var text_s := EvEngine.subst(_pick_text(texts), run.ctx)
	var out := {"done": done, "title": EvEngine.subst(str(run.def.get("title", "Conversation")), run.ctx),
		"text": text_s, "lines": run.lines.duplicate(), "choices": [],
		"emotion": emotion_view(run.ctx), "read": EvEngine.subst(_read_line(node), run.ctx)}
	if not done:
		for ch in _visible_choices(node):
			var reason := choice_blocked_reason(ch)
			var label_s := EvEngine.subst(str(ch.get("label", "…")), run.ctx)
			# Sichtbare Attributs-Probe: gleiche Label-Optik wie bei Events.
			if ch.get("check", {}).has("attr"):
				label_s = "%s %s" % [EvEngine.check_label(ch.check), label_s]
			out.choices.append({"label": label_s, "disabled": reason != "", "reason": reason})
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
		return {"name": str(Util.pick(Data.CONTACT_PERSONS[from_type])), "type": from_type}
	var first: String = Util.pick(Data.NPC_FIRST_F if Util.chance(0.5) else Data.NPC_FIRST_M)
	return {"name": "%s %s" % [first, Util.pick(Data.NPC_LAST)], "type": "stranger"}


func _letter_conditions_ok(def: Dictionary) -> bool:
	var conds: Dictionary = def.get("conditions", {})
	if int(_st().year) < int(conds.get("min_year", 0)) or int(_st().year) > int(conds.get("max_year", 9999)):
		return false
	if int(_st().player.career) < int(conds.get("min_career", 0)):
		return false
	var req_type := str(conds.get("requires_contact_type", ""))
	if req_type != "" and not _st().contacts.any(func(ct): return str(ct.type) == req_type):
		return false
	# Interviews (Teil B1): Briefe können einen passenden Klienten fordern
	# (gleiche Filter wie Events) oder ein dem Spieler bekanntes Gerücht.
	if conds.get("requires_client") != null and EvEngine._client_candidates(conds.requires_client).is_empty():
		return false
	if bool(conds.get("requires_rumor_known", false)) and not _st().rumors.any(func(r): return bool(r.knownToPlayer)):
		return false
	if bool(conds.get("requires_studio", false)) and Game.active_studios().is_empty():
		return false
	if conds.has("chance") and not Util.chance(float(conds.chance)):
		return false
	return true


func spawn_letter(template_id: String, force: bool = false) -> Dictionary:
	var def := letter_def(template_id)
	if def.is_empty():
		return {}
	if not force and not _letter_conditions_ok(def):
		return {}
	return _spawn_letter_with(def, _resolve_sender(def))


# Wie spawn_letter, aber mit festem Absender aus dem Kontaktbuch —
# für den Dispatcher (npc_rise, summons & Co.).
func spawn_letter_for(template_id: String, ct: Dictionary) -> Dictionary:
	var def := letter_def(template_id)
	if def.is_empty():
		return {}
	var sender := _resolve_sender(def)
	if not ct.is_empty():
		sender = {"name": str(ct.name), "type": str(ct.type), "ctid": int(ct.id)}
	return _spawn_letter_with(def, sender)


# Brief mit frei benanntem Absender (Privatleben: Partner sind keine
# Kontakte; Erwartungsgespräch: der Absender ist der Klient selbst).
func spawn_letter_named(template_id: String, sender_name: String, extra_ctx: Dictionary = {}) -> Dictionary:
	var def := letter_def(template_id)
	if def.is_empty():
		return {}
	return _spawn_letter_with(def, {"name": sender_name, "type": "privat"}, extra_ctx)


# Brief mit zusätzlichem Effekt-Kontext (z. B. sid für Studio-Gespräche,
# cid für Interviews über einen Klienten): der Kontext wird am Brief
# gespeichert und wirkt in Platzhaltern wie in allen Choice-Effekten.
func spawn_letter_ctx(template_id: String, extra_ctx: Dictionary, force: bool = true) -> Dictionary:
	var def := letter_def(template_id)
	if def.is_empty():
		return {}
	if not force and not _letter_conditions_ok(def):
		return {}
	return _spawn_letter_with(def, _resolve_sender(def), extra_ctx)


func _spawn_letter_with(def: Dictionary, sender: Dictionary, extra_ctx: Dictionary = {}) -> Dictionary:
	var st := _st()
	var template_id := str(def.id)
	var ctx := {"sender": str(sender.name)}
	if sender.has("ctid"):
		ctx["ctid"] = int(sender.ctid)
	for key in extra_ctx:
		ctx[key] = extra_ctx[key]
	# requires_client bindet einen konkreten Klienten an den Brief — für
	# {client}-Platzhalter und alle Effekte des späteren Gesprächs.
	if def.get("conditions", {}).get("requires_client") != null and not ctx.has("cid"):
		var cands: Array = EvEngine._client_candidates(def.conditions.requires_client)
		if cands.is_empty():
			return {}
		ctx["cid"] = int(Util.pick(cands).id)
		extra_ctx = extra_ctx.duplicate()
		extra_ctx["cid"] = int(ctx.cid)
	# requires_studio bindet analog ein aktives Studio (für studio_rel-Ops).
	if bool(def.get("conditions", {}).get("requires_studio", false)) and not ctx.has("sid"):
		var studios: Array = Game.active_studios()
		if studios.is_empty():
			return {}
		ctx["sid"] = str(Util.pick(studios).id)
		extra_ctx = extra_ctx.duplicate()
		extra_ctx["sid"] = str(ctx.sid)
	var letter := {"id": Game.next_id(), "tid": template_id, "mi": Game.mi(), "wi": Game.wi(),
		"from": sender, "subject": EvEngine.subst(str(def.get("subject", "…")), ctx),
		"body": EvEngine.subst(str(def.get("body", "")), ctx),
		"status": "open", "expireWi": Game.wi() + int(def.get("expire_weeks", 3)), "outcome": ""}
	if not extra_ctx.is_empty():
		letter["ctx"] = extra_ctx.duplicate(true)
	st.inbox.append(letter)
	st.inboxSeen[template_id] = Game.wi()
	return letter


# Wöchentliche Zustellung: 1–2 Briefe, gewichtete Vorlagen, Cooldowns.
func tick_week() -> void:
	var st := _st()
	if st == null or not st.has("inbox"):
		return
	# Neues Kommunikationsbudget (Feature 29): die Woche beginnt ruhig.
	st.weekScenes = 0
	st.weekScenesNoted = false
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
		var want := 1 + (1 if Util.chance(0.4) else 0)
		for i in want:
			var pool: Array = []
			for def in Data.LETTERS:
				# Manuelle Vorlagen (Dispatcher-Briefe) nie zufällig zustellen
				if bool(def.get("manual", false)) or int(def.get("weight", 1)) <= 0:
					continue
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
			spawn_letter(str(Util.pick(pool).id), true)
	# Postfilter (Feature 32): der Assistent beantwortet Routinepost selbst —
	# alles, wofür eine Vorlage eine Assistenten-Option vorsieht.
	if Persona.has_assistant() and Persona.rule("mailfilter"):
		for letter in open_letters():
			var def := letter_def(str(letter.tid))
			for i in def.get("choices", []).size():
				var ch: Dictionary = def.choices[i]
				if bool(ch.get("requirements", {}).get("requires_assistant", false)) and letter_choice_blocked(letter, ch) == "":
					letter_choose(int(letter.id), i)
					Game.log_msg("%s answered the %s from %s — routine, handled." % [str(Persona.assistant().name), mail_word().to_lower(), letter["from"].get("name", "?")], "info")
					break
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
	# Am Brief gespeicherter Zusatzkontext (sid/cid) wirkt in den Effekten mit.
	for key in letter.get("ctx", {}):
		ctx[key] = letter.ctx[key]
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
	if reqs.has("min_cash_private") and float(_st().player.cash) < roundf(float(reqs.min_cash_private) * Util.infl(_st().year)):
		return "Privately short on cash"
	if bool(reqs.get("requires_assistant", false)) and not Persona.has_assistant():
		return "You employ no assistant"
	if bool(reqs.get("has_favor", false)) and _st().favors.is_empty():
		return "Nobody owes you anything right now"
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
		ok = Util.chance(float(ch.success_chance))
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


# =====================================================================
# Feature 26 — Datenvalidierung: Dialoge & Briefe dürfen nur über
# bekannte Ops wirken und nur bekannte Platzhalter referenzieren.
# =====================================================================
var _ph_re := RegEx.create_from_string("\\{([a-z_]+)(:\\d+)?\\}")


func _check_effects(effects: Array, where: String, out: Array) -> void:
	for ef in effects:
		if not (ef is Dictionary):
			continue
		var op := str(ef.get("op", ""))
		if not KNOWN_OPS.has(op):
			out.append("%s: unknown effect op \"%s\" — text must not invent mechanics" % [where, op])
		if op == "chance":
			_check_effects(ef.get("effects", []), where, out)
			_check_effects(ef.get("else", []), where, out)


func _check_text(text_s: String, where: String, out: Array) -> void:
	for m in _ph_re.search_all(text_s):
		var ph := str(m.get_string(1))
		if not KNOWN_PLACEHOLDERS.has(ph) and ph != "money_fmt":
			out.append("%s: unknown placeholder {%s} — text may only reference simulation facts" % [where, ph])


func validate_defs() -> Array:
	var out: Array = []
	for def in Data.DIALOGS:
		var nodes: Dictionary = def.get("nodes", {})
		if not nodes.has(str(def.get("start", "opening"))):
			out.append("dialog %s: start node \"%s\" missing" % [str(def.id), str(def.get("start", "opening"))])
		for node_id in nodes:
			var node: Dictionary = nodes[node_id]
			var where := "dialog %s/%s" % [str(def.id), str(node_id)]
			_check_effects(node.get("effects", []), where, out)
			var texts: Array = node.get("text", []) if node.get("text") is Array else [str(node.get("text", ""))]
			for t in texts:
				_check_text(str(t), where, out)
			# Wahrnehmungszeilen: nur bekannte Präzisionsstufen als Schlüssel
			for read_key in node.get("reads", {}):
				if not ["unreadable", "likely", "clear", "certain"].has(str(read_key)):
					out.append("%s: reads has unknown tier \"%s\"" % [where, str(read_key)])
				else:
					_check_text(str(node.reads[read_key]), where, out)
			for ch in node.get("choices", []):
				_check_effects(ch.get("effects", []), where, out)
				# Emotions-Gates: nur echte Emotionen aus data/emotions
				for emo_key in ch.get("requires_emotion", []):
					if not Data.EMOTIONS.has(str(emo_key)):
						out.append("%s: requires_emotion names unknown emotion \"%s\"" % [where, str(emo_key)])
				# Attributs-Proben: nur echte Attribute aus data/attributes
				if ch.get("check", {}).has("attr") and not Data.ATTRIBUTES.has(str(ch.check.attr)):
					out.append("%s: check.attr names unknown attribute \"%s\"" % [where, str(ch.check.attr)])
				for target_key in [["goto", ch.get("goto")], ["check.success", ch.get("check", {}).get("success")], ["check.fail", ch.get("check", {}).get("fail")]]:
					var target = target_key[1]
					if target != null and str(target) != "end" and not nodes.has(str(target)):
						out.append("%s: %s → \"%s\" does not exist" % [where, str(target_key[0]), str(target)])
	for def in Data.LETTERS:
		var where2 := "letter %s" % str(def.id)
		_check_text(str(def.get("subject", "")) + " " + str(def.get("body", "")), where2, out)
		_check_effects(def.get("expire_effects", []), where2, out)
		for ch in def.get("choices", []):
			_check_effects(ch.get("effects", []), where2, out)
			_check_effects(ch.get("effects_fail", []), where2, out)
			if ch.has("dialog") and not has_dialog(str(ch.dialog)):
				out.append("%s: choice opens unknown dialog \"%s\"" % [where2, str(ch.dialog)])
	return out
