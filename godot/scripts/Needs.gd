extends Node
# =====================================================================
# Klienten-Innenleben (Gesamtpaket Teil C1) — Autoload "Needs".
#
# Fünf Bedürfnisse (data/needs/core.json → Data.NEEDS). Zwei Ebenen:
#  · PROFIL — was diesen Menschen antreibt: deterministisch aus der
#    Actor-Id abgeleitet (Util.hashs) plus Nudges (hohes Ego →
#    Anerkennung, kleiner Zenit-Ruhm → Sicherheit, Prestige-Genres →
#    Kunst). Kein Save-Feld, profile(actor) ist jederzeit reproduzierbar.
#  · SÄTTIGUNG — c.needsSat = {need: 0–100}: Spielstand (Migration über
#    ensure_client, Start Balance.NEEDS_START). tick_client() driftet
#    monatlich aus Game.tick_clients: Rollen/Releases füttern
#    Anerkennung/Kunst/Geld, Lücken zehren Sicherheit, PR/Galas zehren
#    Ruhe, Erholung füllt sie (on_planner_week, Planner-Kopplung).
#
# Wirkung NUR über bestehende Mechanik (keine Parallelwelt): das
# schlechteste Bedürfnis unter NEEDS_LOW drückt die Laune, unter
# NEEDS_CRITICAL zusätzlich die Loyalität. grievance_cause() verfeinert
# die Klienten-Ursache in Emotions.true_state; visible_line() liefert
# die „What drives them“-Zeile der Klientenkarte, gestaffelt über die
# Menschenkenntnis-Stufen des Emotionsmodells.
# =====================================================================

const PRESTIGE_GENRES := ["drama", "history", "war"]

# Welche Zusage welches Bedürfnis bedient (Erwartungsgespräch, Teil C2).
const PROMISE_NEED := {"lead12": "anerkennung", "prestige": "kunst",
	"oscar": "anerkennung", "auszeit": "ruhe", "gage": "geld"}

# Monatliche Driftraten (Sättigung)
const FEED_LEAD := 4.0
const FEED_SUPPORT := 1.5
const FEED_ART_PRESTIGE := 4.0
const DRAIN_ART_ROUTINE := 1.0
const FEED_MONEY_GOOD_FEE := 3.0
const DRAIN_MONEY_CHEAP := 1.0
const FEED_SECURITY_WORK := 2.0
const DRAIN_SECURITY_GAP := 3.0
const DRAIN_PEACE_SET := 3.0
const FEED_PEACE_GAP := 3.0
const DRAIN_RECOGNITION_GAP := 2.0


func profile(actor: Dictionary) -> Dictionary:
	var out := {}
	for need in Data.NEEDS:
		out[need] = 30.0 + float(Util.hashs(str(actor.get("id", "")) + "need" + str(need)) % 41)
	out["anerkennung"] = float(out.get("anerkennung", 30.0)) + float(actor.get("ego", 50)) * 0.30
	out["sicherheit"] = float(out.get("sicherheit", 30.0)) + maxf(0.0, 60.0 - float(actor.get("peakFame", 60))) * 0.5
	for genre in actor.get("genres", []):
		if PRESTIGE_GENRES.has(str(genre)):
			out["kunst"] = float(out.get("kunst", 30.0)) + 18.0
			break
	for need in out:
		out[need] = clampf(float(out[need]), 5.0, 100.0)
	return out


func top_need(actor: Dictionary) -> String:
	var prof := profile(actor)
	var best := ""
	for need in prof:
		if best == "" or float(prof[need]) > float(prof[best]):
			best = str(need)
	return best


# Migration: fehlende Sättigung mit dem Startwert nachrüsten.
func ensure_client(c: Dictionary) -> void:
	if not c.has("needsSat") or not (c.needsSat is Dictionary):
		c["needsSat"] = {}
	for need in Data.NEEDS:
		if not c.needsSat.has(need):
			c.needsSat[need] = Balance.NEEDS_START


func worst_need(c: Dictionary) -> String:
	ensure_client(c)
	var worst := ""
	for need in c.needsSat:
		if worst == "" or float(c.needsSat[need]) < float(c.needsSat[worst]):
			worst = str(need)
	return worst


func _shift(c: Dictionary, need: String, amount: float) -> void:
	c.needsSat[need] = clampf(float(c.needsSat[need]) + amount, 0.0, 100.0)


# Die aktuelle Rolle des Klienten in einer laufenden Produktion.
func _current_role(c: Dictionary) -> Dictionary:
	for prod in Game.state.get("productions", []):
		for role in prod.get("roles", []):
			if role.get("filled") != null and role.filled.get("clientId") != null and int(role.filled.clientId) == int(c.id):
				return {"type": str(role.get("type", "support")), "prestige": int(prod.get("prestige", 1)),
					"fee": float(role.filled.get("fee", 0.0))}
	return {}


# Monatlich aus Game.tick_clients: die Arbeit (oder ihr Fehlen) bewegt
# die Sättigung; der Engpass wirkt über Laune und Loyalität zurück.
func tick_client(c: Dictionary) -> void:
	ensure_client(c)
	var role := _current_role(c)
	if not role.is_empty():
		_shift(c, "anerkennung", FEED_LEAD if str(role.type) == "lead" else FEED_SUPPORT)
		_shift(c, "kunst", FEED_ART_PRESTIGE if int(role.prestige) >= 2 else -DRAIN_ART_ROUTINE)
		var expectation := Util.ask_fee(float(c.fame), Game.state.year)
		_shift(c, "geld", FEED_MONEY_GOOD_FEE if float(role.fee) >= expectation * 0.9 else -DRAIN_MONEY_CHEAP)
		_shift(c, "sicherheit", FEED_SECURITY_WORK)
		_shift(c, "ruhe", -DRAIN_PEACE_SET)
	else:
		_shift(c, "sicherheit", -DRAIN_SECURITY_GAP)
		_shift(c, "ruhe", FEED_PEACE_GAP)
		_shift(c, "anerkennung", -DRAIN_RECOGNITION_GAP)
	# Nebeneinkommen beruhigt das Konto — und damit zwei Bedürfnisse.
	if c.flags.get("tvIncome") != null or c.get("clauses", []).has("endorsement"):
		_shift(c, "geld", 2.0)
		_shift(c, "sicherheit", 1.0)
	# Der PR-Apparat schmeichelt der Anerkennung und frisst die Ruhe.
	if c.perks.has("pr"):
		_shift(c, "anerkennung", 1.0)
		_shift(c, "ruhe", -1.0)
	# Engpass-Wirkung über die bestehende Mechanik
	var worst := worst_need(c)
	if float(c.needsSat[worst]) < Balance.NEEDS_LOW:
		c.mood = clampf(float(c.mood) - Balance.NEEDS_MOOD_MALUS, 0.0, 100.0)
	if float(c.needsSat[worst]) < Balance.NEEDS_CRITICAL:
		c.loyalty = clampf(float(c.loyalty) - Balance.NEEDS_LOYALTY_MALUS, 0.0, 100.0)
	_maybe_expectation_talk(c, worst)


# Erwartungsgespräch (Teil C2): halbjährlich — oder sobald ein Bedürfnis
# unter NEEDS_URGENT fällt — bittet der Klient um das Grundsatzgespräch;
# höchstens eines pro Halbjahr und Klient. Der Brief kommt vom Klienten
# selbst, mit cid im Kontext für den Baum (data/dialogs/erwartung.json).
func _maybe_expectation_talk(c: Dictionary, worst: String) -> void:
	if not Dialogs.has_dialog("erwartung"):
		return
	var last := int(c.flags.get("expectTalkMi", int(c.get("signedAt", Game.mi()))))
	# 1× pro Halbjahr und Klient — das Halbjahres-Ritual selbst und der
	# dringende Engpass (< NEEDS_URGENT) teilen sich diese Sperre.
	if Game.mi() - last < Balance.NEEDS_TALK_COOLDOWN_MONTHS:
		return
	if Game.mi() - last < Balance.NEEDS_TALK_RITUAL_MONTHS and float(c.needsSat[worst]) >= Balance.NEEDS_URGENT:
		return
	var cid := int(c.id)
	if Game.state.inbox.any(func(l): return str(l.tid) == "erwartung_invite" and str(l.status) == "open" and int(l.get("ctx", {}).get("cid", -1)) == cid):
		return
	c.flags["expectTalkMi"] = Game.mi()
	Dialogs.spawn_letter_named("erwartung_invite", Game.client_name(c), {"cid": cid})


func on_promise(c: Dictionary, promise_type: String, kept: bool) -> void:
	var need := str(PROMISE_NEED.get(promise_type, ""))
	if need == "":
		return
	ensure_client(c)
	_shift(c, need, Balance.NEEDS_PROMISE_KEPT if kept else -Balance.NEEDS_PROMISE_BROKEN)


# Wöchentliche Planner-Kopplung: Erholung füllt die Ruhe, PR und Galas
# zehren sie (und schmeicheln dafür der Anerkennung).
func on_planner_week(c: Dictionary, counts: Dictionary) -> void:
	ensure_client(c)
	var n_rest := int(counts.get("erholung", 0))
	if n_rest > 0:
		_shift(c, "ruhe", 0.8 * n_rest)
	var n_pr := int(counts.get("pr", 0))
	if n_pr > 0:
		_shift(c, "ruhe", -0.4 * n_pr)
		_shift(c, "anerkennung", 0.2 * n_pr)
	var n_gala := int(counts.get("gala", 0))
	if n_gala > 0:
		_shift(c, "ruhe", -0.6 * n_gala)
		_shift(c, "anerkennung", 0.3 * n_gala)


# Verfeinert die Klienten-Ursache im Emotionsmodell: benennt den
# konkreten Engpass statt einer generischen Stimmungsfloskel.
func grievance_cause(c: Dictionary) -> String:
	ensure_client(c)
	var worst := worst_need(c)
	if float(c.needsSat[worst]) >= Balance.NEEDS_LOW:
		return ""
	match worst:
		"anerkennung":
			return "they feel invisible — nobody has applauded in too long"
		"sicherheit":
			return "the calendar has gaps and the gaps have teeth — they crave certainty"
		"kunst":
			return "the work has stopped meaning anything to them"
		"geld":
			return "the money does not match what they think they are worth"
		"ruhe":
			return "they are worn thin — no private hour has survived the schedule"
	return ""


# „What drives them“-Zeile der Klientenkarte, gestaffelt nach der
# Menschenkenntnis (gleiche Stufen wie die Emotions-Wahrnehmung).
func visible_line(c: Dictionary) -> String:
	var score := Emotions.read_score()
	if score < Balance.EMO_TIER_LIKELY:
		return ""
	ensure_client(c)
	var actor: Dictionary = Game.actor_by_id.get(str(c.aid), {})
	var top := top_need(actor)
	var top_def: Dictionary = Data.NEEDS.get(top, {})
	if score < Balance.EMO_TIER_CLEAR:
		return "🧭 What drives them: %s" % str(top_def.get("icon", "?"))
	var line := "🧭 What drives them: %s %s" % [str(top_def.get("icon", "")), str(top_def.get("name", top))]
	var worst := worst_need(c)
	if score < Balance.EMO_TIER_CAUSE:
		if float(c.needsSat[worst]) < Balance.NEEDS_LOW:
			var worst_def: Dictionary = Data.NEEDS.get(worst, {})
			line += " · starving: %s %s" % [str(worst_def.get("icon", "")), str(worst_def.get("name", worst))]
		return line
	# Volle Stufe: das Mini-Profil mit allen Sättigungen
	var prof := profile(actor)
	var keys: Array = prof.keys()
	keys.sort_custom(func(a, b): return float(prof[a]) > float(prof[b]))
	var parts: Array = []
	for need in keys:
		parts.append("%s %d" % [str(Data.NEEDS.get(need, {}).get("icon", "?")), roundi(float(c.needsSat[need]))])
	return line + "  ·  " + " ".join(parts)
