extends Node
# =====================================================================
# Pressekonferenz-Auslöser (Gesamtpaket Teil B2) — Autoload "Press".
# Bewusst klein: NUR Trigger und Cooldowns. Die Szene selbst ist Daten
# (data/dialogs/pressekonferenz.json), das Angebot ein Brief
# (data/letters/presse.json → pressekonferenz_invite).
#
# Auslöser: ein dem Spieler bekanntes Gerücht über einen EIGENEN
# Klienten erreicht belief ≥ Balance.PRESSCONF_BELIEF — einmal pro
# Gerücht (Flag am Gerücht selbst, überlebt Save/Load), dazu ein
# globaler Cooldown in state.press.lastConfMi.
# =====================================================================


func init_state() -> void:
	Game.state["press"] = {"lastConfMi": -999}


# Migration: state.press für ältere Spielstände nachrüsten.
func ensure_press() -> void:
	var st = Game.state
	if st == null:
		return
	if not st.has("press") or not (st.press is Dictionary):
		st["press"] = {"lastConfMi": -999}
	if not st.press.has("lastConfMi"):
		st.press["lastConfMi"] = -999


# Monatlich (nach Scandal.tick_rumors): wird ein Gerücht laut genug,
# liegt am Montag das Podium-Angebot in der Post.
func tick_month() -> void:
	var st = Game.state
	if st == null or not st.has("press"):
		return
	if Game.mi() - int(st.press.lastConfMi) < Balance.PRESSCONF_COOLDOWN_MONTHS:
		return
	if not Dialogs.has_dialog("pressekonferenz"):
		return
	for rumor in st.get("rumors", []):
		if bool(rumor.get("pressConfOffered", false)) or not bool(rumor.knownToPlayer):
			continue
		if float(rumor.belief) < Balance.PRESSCONF_BELIEF:
			continue
		var c = Scandal.rumor_subject_client(rumor)
		if c == null:
			continue
		rumor["pressConfOffered"] = true
		st.press.lastConfMi = Game.mi()
		Dialogs.spawn_letter_ctx("pressekonferenz_invite", {"cid": int(c.id)})
		Game.log_msg("The story about %s is loud enough for a podium. Your office weighs a press conference." % Game.client_name(c), "bad")
		return
