extends Node
# =====================================================================
# Emotionsmodell (Gesamtpaket Teil A) — Autoload "Emotions".
#
# Acht Grundemotionen (data/emotions/core.json → Data.EMOTIONS) werden
# NIE gespeichert, sondern in jedem Moment aus vorhandenen Simulations-
# fakten ABGELEITET: Beziehungsdimensionen, Laune/Loyalität/Vertrauen,
# Versprechen, Schulden, Groll. Zwei Sichten:
#
#   true_state(subject_kind, ctx) -> {key, intensity 0–100, cause}
#     Die WAHRE Emotion des Gegenübers. subject_kind:
#       "contact" (ctx.ctid) · "client" (ctx.cid) · "rival" (ctx.rid)
#     cause benennt konkret die auslösende Regel (für UI ≥ Stufe 4).
#
#   perceived(subject_kind, ctx) -> {key, confidence, cause, wrong, valence}
#     Was der SPIELER liest — Präzision aus Game.attr("menschenkenntnis")
#     plus situativ state.instinct / 10 (Stufen in Balance.gd):
#       < EMO_TIER_LIKELY:  nur Valenz ("unreadable") ODER mit
#                           EMO_ERR_LOW % eine FALSCHE Nachbaremotion
#       bis EMO_TIER_CLEAR: Emotion korrekt, confidence "likely",
#                           keine Ursache; EMO_ERR_MID % Fehler
#       bis EMO_TIER_CAUSE: korrekt, confidence "clear"
#       ab  EMO_TIER_CAUSE: korrekt + cause-Zeile
#     Fehler sind deterministisch über Util.hashs(subjekt + wi()) —
#     pro Woche stabil, Neuladen würfelt nicht neu (kein Savescum).
#
# Nachgelagerte Nutzer: Dialogsystem (Emotions-Chip, requires_emotion),
# Presse-Szenen (Teil B), Klienten-Innenleben (Teil C, verfeinert die
# cause über Needs.grievance_cause).
# =====================================================================

# Ring der Emotionen nach Ähnlichkeit — Fehllesungen greifen daneben,
# aber nicht absurd (warm wird nie als resentful fehlgelesen).
const EMO_RING := ["warm", "hopeful", "calculating", "wary", "anxious", "irritated", "resentful", "resigned"]

# Ableitungs-Schwellen (Regel-Prioritäten siehe true_state)
const IRRITATION_HOT := 40.0
const TRUST_WARM := 60.0
const LIKING_WARM := 55.0
const TRUST_LOW := 30.0
const MOOD_GOOD := 60.0
const MOOD_BAD := 35.0
const LOYALTY_SHAKY := 35.0
const EXHAUSTION_WORN := 75.0


func defs() -> Dictionary:
	return Data.EMOTIONS


func def_of(key: String) -> Dictionary:
	return Data.EMOTIONS.get(key, {"name": key.capitalize(), "icon": "❔", "desc": "", "valence": 0})


func valence_of(key: String) -> int:
	return int(def_of(key).get("valence", 0))


# =====================================================================
# Wahre Emotion — reine Ableitung, kein Save-Feld.
# Regel-Priorität: konkrete Kränkungen (gebrochene Versprechen) vor
# akutem Ärger vor Rechenspielen vor Grundstimmung.
# =====================================================================
func true_state(subject_kind: String, ctx: Dictionary) -> Dictionary:
	match subject_kind:
		"contact":
			return _true_contact(Persona.contact_by_id(ctx.get("ctid", -1)))
		"client":
			var c = Game.client(ctx.get("cid", -1))
			return {} if c == null else _true_client(c)
		"rival":
			var rival = Rivals.rival_by_id(str(ctx.get("rid", "")))
			return {} if rival == null else _true_rival(rival)
	return {}


func _true_contact(ct: Dictionary) -> Dictionary:
	if ct.is_empty():
		return {}
	var st = Game.state
	# 1) Gebrochene Zusagen wiegen am schwersten.
	for pr in st.get("promises", []):
		if str(pr.status) == "broken" and str(pr.to) == str(ct.name):
			return _mk("resentful", 55.0 + Network.dim(ct, "irritation") * 0.5,
				"you broke your word in %s" % Game.mi_str(pr.madeMi))
	# 2) Aufgestauter Ärger.
	var irritation := Network.dim(ct, "irritation")
	if irritation >= IRRITATION_HOT:
		return _mk("irritated", irritation, "irritation has been building between you for a while")
	# 3) Offene Schulden: wer etwas von dir zu bekommen hat, rechnet.
	for debt in st.get("debts", []):
		if str(debt["from"].get("name", "")) == str(ct.name):
			return _mk("calculating", 45.0 + Network.dim(ct, "dependence") * 0.3,
				"you still owe them for %s" % Game.mi_str(debt.gainedMi))
	# 4) Groll aus dem Gedächtnis: verpasste Anlässe, schlechte Fakten.
	for occ in st.get("occasions", []):
		if str(occ.status) == "missed" and str(occ.ctName) == str(ct.name):
			return _mk("wary", 40.0 + irritation, "the call you never returned still sits between you")
	for f in ct.get("facts", []):
		if int(f.tone) < 0:
			return _mk("wary", 40.0 + float(f.get("weight", 1.0)) * 8.0,
				"they remember that you %s" % str(f.text))
	# 5) Grundstimmung aus den Dimensionen.
	var trust := Network.dim(ct, "trust")
	var liking := Network.dim(ct, "liking")
	if trust >= TRUST_WARM and liking >= LIKING_WARM:
		return _mk("warm", (trust + liking) / 2.0, "years of kept appointments and honest talk")
	if liking >= LIKING_WARM:
		return _mk("hopeful", liking, "they like you and expect this to go somewhere")
	if trust < TRUST_LOW:
		return _mk("wary", 60.0 - trust, "you have given them little reason to trust you")
	if liking < TRUST_LOW:
		return _mk("resigned", 55.0 - liking, "they stopped expecting warmth from this relationship")
	return _mk("calculating", 35.0, "so far this is strictly business")


func _true_client(c: Dictionary) -> Dictionary:
	# 1) Gebrochene Versprechen — der Klient vergisst das nicht.
	for pr in c.get("promises", []):
		if bool(pr.get("broken", false)) and not bool(pr.get("fulfilled", false)):
			return _mk("resentful", 60.0 + (100.0 - float(c.loyalty)) * 0.3,
				"you promised %s and broke your word" % str(pr.label))
	# 2) Feud im Raum: ein verhasster Name reicht.
	var feud := str(c.flags.get("feudWith", ""))
	if feud != "":
		var feud_actor: Dictionary = Game.actor_by_id.get(feud, {})
		return _mk("irritated", 55.0 + (100.0 - float(c.mood)) * 0.2,
			"the feud with %s poisons every room" % str(feud_actor.get("name", "a former co-star")))
	# 3) Alles hängt am Comeback.
	if bool(c.flags.get("comebackActive", false)):
		return _mk("anxious", 65.0, "everything hangs on the comeback attempt")
	# 4) Ausgebrannt.
	if float(c.exhaustion) >= EXHAUSTION_WORN:
		return _mk("resigned", float(c.exhaustion), "worn down by back-to-back productions")
	# 5) Ein frischer Hit trägt.
	var films: Array = c.get("films", [])
	if films.size() and str(films[0].get("verdict", "")) == "Hit" and int(films[0].get("year", 0)) >= int(Game.state.year) - 1:
		return _mk("hopeful", 55.0 + float(c.heat) * 3.0, "the hit \"%s\" is still ringing" % str(films[0].title))
	# 6) Miese Laune, wacklige Bindung, oder echtes Zutrauen. Der konkrete
	# Bedürfnis-Engpass (Teil C1) ersetzt die generische Stimmungsfloskel.
	var needs_cause := Needs.grievance_cause(c)
	if float(c.mood) < MOOD_BAD:
		return _mk("irritated", 70.0 - float(c.mood), needs_cause if needs_cause != "" else "the mood has curdled — too little has gone right lately")
	if float(c.loyalty) < LOYALTY_SHAKY:
		return _mk("wary", 60.0 - float(c.loyalty), needs_cause if needs_cause != "" else "they are quietly weighing their options elsewhere")
	if float(c.get("trust", 30.0)) >= TRUST_WARM and float(c.mood) >= MOOD_GOOD:
		return _mk("warm", (float(c.trust) + float(c.mood)) / 2.0, "trust built over kept appointments and honest counsel")
	if float(c.mood) >= MOOD_GOOD:
		return _mk("hopeful", float(c.mood), "things feel like they are moving in the right direction")
	return _mk("calculating", 40.0, "a professional appraisal of what you deliver")


func _true_rival(rival: Dictionary) -> Dictionary:
	var grudge := float(rival.get("grudge", 0.0))
	var rel := float(rival.get("rel", 0.0))
	if grudge >= 60.0:
		return _mk("resentful", grudge, "the war between your houses has a long ledger")
	if grudge >= 30.0:
		return _mk("irritated", grudge, "recent skirmishes over clients still sting")
	if rel >= 25.0:
		return _mk("warm", 40.0 + rel, "successful cooperation has thawed the rivalry")
	if rel <= -25.0:
		return _mk("wary", 40.0 - rel, "they expect a knife behind every offer of yours")
	return _mk("calculating", 40.0, "you are a competitor — nothing personal, all arithmetic")


func _mk(key: String, intensity: float, cause: String) -> Dictionary:
	return {"key": key, "intensity": clampi(roundi(intensity), 0, 100), "cause": cause}


# =====================================================================
# Wahrgenommene Emotion — Menschenkenntnis entscheidet, was du liest.
# =====================================================================
# Lese-Score: Attribut + situativer Instinkt-Bonus.
func read_score() -> float:
	return float(Game.attr("menschenkenntnis")) + float(Game.state.get("instinct", 0)) / Balance.EMO_INSTINCT_DIV


func perceived(subject_kind: String, ctx: Dictionary) -> Dictionary:
	var truth := true_state(subject_kind, ctx)
	if truth.is_empty():
		return {}
	var score := read_score()
	var true_key := str(truth.key)
	var valence := valence_of(true_key)
	# Deterministischer Wochenwurf: Subjekt + Woche → stabil bis zum
	# nächsten Zug, egal wie oft geladen wird.
	var roll := Util.hashs(_subject_key(subject_kind, ctx) + str(Game.wi())) % 100
	if score < Balance.EMO_TIER_LIKELY:
		if roll < Balance.EMO_ERR_LOW:
			return {"key": _neighbor(true_key, roll), "confidence": "guess", "cause": "", "wrong": true, "valence": valence}
		return {"key": "unreadable", "confidence": "unreadable", "cause": "", "wrong": false, "valence": valence}
	if score < Balance.EMO_TIER_CLEAR:
		if roll < Balance.EMO_ERR_MID:
			return {"key": _neighbor(true_key, roll), "confidence": "likely", "cause": "", "wrong": true, "valence": valence}
		return {"key": true_key, "confidence": "likely", "cause": "", "wrong": false, "valence": valence}
	if score < Balance.EMO_TIER_CAUSE:
		return {"key": true_key, "confidence": "clear", "cause": "", "wrong": false, "valence": valence}
	return {"key": true_key, "confidence": "certain", "cause": str(truth.cause), "wrong": false, "valence": valence}


# Falsche Nachbaremotion: greift im Ähnlichkeits-Ring daneben.
func _neighbor(key: String, roll: int) -> String:
	var idx := EMO_RING.find(key)
	if idx < 0:
		return key
	var dir := 1 if roll % 2 == 0 else -1
	return EMO_RING[(idx + dir + EMO_RING.size()) % EMO_RING.size()]


func _subject_key(subject_kind: String, ctx: Dictionary) -> String:
	match subject_kind:
		"contact":
			return "emo_ct_%s" % str(ctx.get("ctid", -1))
		"client":
			return "emo_cl_%s" % str(ctx.get("cid", -1))
		"rival":
			return "emo_rv_%s" % str(ctx.get("rid", ""))
	return "emo_%s" % subject_kind
