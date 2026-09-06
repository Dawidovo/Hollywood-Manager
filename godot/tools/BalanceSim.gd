extends Node
# =====================================================================
# Balance-Simulation: spielt pro Epoche eine Kampagne mit einfachen
# Heuristiken (Signen, Pitchen, Post beantworten, Woche beenden) und
# protokolliert die Ökonomie als CSV-Zeilen ("SIM;...") für die Auswertung.
# Aufruf:  godot --headless --path . res://tools/BalanceSim.tscn
# Kein Spielinhalt — reines Analysewerkzeug. Saves laufen isoliert unter
# user://qa_test_sim/ (QA-09), der echte Autosave bleibt unberührt.
# Ereignisse und Dialoge werden beantwortet (erste verfügbare Wahl);
# Anzahl, blockierte Dialoge und Abbrüche stehen in den SUM-Zeilen.
# Abschlussmarker: SIM_DONE.
# =====================================================================

const WEEKS_PER_RUN := 104
const MAX_CLIENTS := 4
const MAX_PITCHES_PER_WEEK := 3
# Mehrere Seeds pro Epoche (Konfidenz statt Einzellauf) und zwei Profile:
# "solide" pitcht nur, "aggressiv" nachverhandelt jede Zusage und schnürt
# Package-Deals, wo möglich.
const SEED_OFFSETS := [0, 5000]
const PROFILES := ["solide", "aggressiv"]

var profile := "solide"


func _ready() -> void:
	print("=== Hollywood Manager Balance-Sim ===")
	Game.use_test_savedir("user://qa_test_sim")
	print("SIM;profile;seed;year;week;cash;priv;stress;energy;clients;rep;inboxOpen;favors;debts;films")
	for run_profile in PROFILES:
		profile = str(run_profile)
		for seed_off in SEED_OFFSETS:
			for year in [1925, 1950, 1980, 2010]:
				_run_era(int(year), int(seed_off))
	print("SIM_DONE")
	get_tree().call_deferred("quit", 0)


func _run_era(year: int, seed_off: int) -> void:
	seed(1000 + year + seed_off)
	Game.new_game("Sim %d" % year, year)
	var stats := {"signTry": 0, "signOk": 0, "pitchTry": 0, "pitchOk": 0,
		"tableSkips": 0, "haggleTry": 0, "haggleOk": 0, "letters": 0, "overWeek": 0,
		"events": 0, "eventsIgnored": 0, "dialogSteps": 0, "dialogsBlocked": 0}
	for week_no in WEEKS_PER_RUN:
		if Game.state.over:
			stats.overWeek = week_no
			break
		_answer_letters(stats)
		_sign_clients(stats)
		_pitch(stats)
		# Aktive Selbstsorge wie ein aufmerksamer Spieler (je 1×/Monat möglich):
		if float(Game.state.player.stress) > 50.0:
			Persona.vacation()
		if float(Game.state.player.health) < 70.0:
			Persona.checkup()
		Game.state.strikeMonths = int(Game.state.strikeMonths)
		# QA-09: die zurückgegebenen Entscheidungen werden beantwortet statt
		# verworfen — die Simulation spielt, was der Spieler auch sähe.
		_resolve_week(Game.end_week(), stats)
		if week_no % 13 == 0 or week_no == WEEKS_PER_RUN - 1:
			_snapshot(year, week_no, seed_off)
	_snapshot(year, WEEKS_PER_RUN, seed_off)
	print("SUM;%s;%d;%d;signed %d/%d;pitched %d/%d;tables %d;haggled %d/%d;letters %d;events %d (ignored %d, dialogSteps %d, blocked %d);gameOverWeek %d" % [
		profile, seed_off, year, stats.signOk, stats.signTry, stats.pitchOk, stats.pitchTry,
		stats.tableSkips, stats.haggleOk, stats.haggleTry, stats.letters,
		stats.events, stats.eventsIgnored, stats.dialogSteps, stats.dialogsBlocked, stats.overWeek])
	_print_ledger(year)


# Ereignisse der Woche: erste nicht gesperrte Wahl nehmen; öffnet die Wahl
# eine Dialogszene, wird sie mit derselben Strategie zu Ende gespielt.
# Blockierte Dialoge und ignorierte (wahl-lose) Ereignisse werden gezählt.
func _resolve_week(events: Array, stats: Dictionary) -> void:
	for ev in events:
		if not (ev is Dictionary):
			continue
		var answered := false
		for choice in ev.get("choices", []):
			if bool(choice.get("disabled", false)):
				continue
			if str(choice.get("action", "")) == "restart":
				continue  # Game-Over-Neustart ist Sache des Spielers, nicht der Sim
			if choice.has("dialog") and Dialogs.has_dialog(str(choice.dialog)):
				var view_data: Dictionary = Dialogs.start(str(choice.dialog), choice.get("ctx", {}))
				for step in 30:
					if bool(view_data.get("done", true)):
						break
					var picked := -1
					for i in view_data.get("choices", []).size():
						if not bool(view_data.choices[i].get("disabled", false)):
							picked = i
							break
					if picked < 0:
						stats.dialogsBlocked += 1
						print("SIM_DIALOG_BLOCKED;", choice.dialog)
						break
					stats.dialogSteps += 1
					view_data = Dialogs.choose(picked)
				Dialogs.run = null
			elif choice.has("fn"):
				choice.fn.call()
			Game.resolve_pending(ev)
			stats.events += 1
			answered = true
			break
		if not answered:
			stats.eventsIgnored += 1


# Agentur-Buchungen des gesamten Laufs nach Kategorie verdichtet —
# zeigt, wo eine Epoche ihr Geld verdient und verliert.
func _print_ledger(year: int) -> void:
	var by_cat := {}
	for m in Game.state.ledgerMonthly:
		for cat in m.byCat:
			by_cat[cat] = float(by_cat.get(cat, 0.0)) + float(m.byCat[cat])
	var live: Dictionary = Game.live_month(Game.mi())
	for cat in live.byCat:
		by_cat[cat] = float(by_cat.get(cat, 0.0)) + float(live.byCat[cat])
	for cat in by_cat:
		print("LEDGER;%d;%s;%d" % [year, str(cat), roundi(float(by_cat[cat]))])


func _snapshot(year: int, week_no: int, seed_off: int) -> void:
	var st = Game.state
	var pl: Dictionary = st.player
	print("SIM;%s;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d" % [profile, seed_off, year, week_no,
		roundi(float(st.agency.cash)), roundi(float(pl.cash)),
		roundi(float(pl.stress)), roundi(float(pl.energy)),
		st.clients.size(), int(st.agency.rep),
		Dialogs.open_letters().size(), st.favors.size(), st.debts.size(),
		st.released.size()])


# Post: pro Brief die erste Wahl nehmen, deren Voraussetzungen erfüllt sind.
func _answer_letters(stats: Dictionary) -> void:
	for letter in Dialogs.open_letters().duplicate():
		var def := Dialogs.letter_def(str(letter.tid))
		for idx in def.get("choices", []).size():
			if bool(Dialogs.letter_choose(letter.id, idx).get("ok", false)):
				stats.letters += 1
				break


# Signen: günstige, nicht gesperrte Talente bis zur Zielgröße des Rosters.
func _sign_clients(stats: Dictionary) -> void:
	while Game.state.clients.size() < MAX_CLIENTS:
		var pool := Game.available_actors().filter(func(a):
			return Util.fame_at(a, Game.state.year) <= 55)
		if pool.is_empty():
			return
		var n: Dictionary = Game.start_negotiation(str(pool[0].id))
		stats.signTry += 1
		if n.get("locked", false):
			return
		var res: Dictionary = Game.sign_client({"commission": 12, "bonus": 0, "years": 3, "perks": [], "promise": null})
		if not res.get("accepted", false):
			Game.nego = null
			return
		stats.signOk += 1


# Pitchen: beste Passung je offener Rolle, Mehrparteien-Tische überspringen.
func _pitch(stats: Dictionary) -> void:
	var attempts := 0
	for cs in Game.state.castings.duplicate():
		if bool(cs.get("hidden", false)) or attempts >= MAX_PITCHES_PER_WEEK:
			continue
		for role_idx in cs.roles.size():
			var role: Dictionary = cs.roles[role_idx]
			if role.filled != null or attempts >= MAX_PITCHES_PER_WEEK:
				continue
			var elig: Array = Game.eligible_clients(cs, role)
			if elig.is_empty() or int(elig[0].fit) < 45:
				continue
			attempts += 1
			stats.pitchTry += 1
			var res: Dictionary = Game.submit_pitch(cs.id, role_idx, int(elig[0].c.id))
			if res.get("success", false):
				if Game.pitch_ctx != null and Game.pitch_ctx.get("table", false):
					stats.tableSkips += 1
					Game.pitch_ctx = null
					continue
				# Aggressives Profil: jede Zusage nachverhandeln, Package anbieten
				if profile == "aggressiv":
					stats.haggleTry += 1
					var hg: Dictionary = Game.haggle()
					if hg.get("success", false):
						stats.haggleOk += 1
					elif hg.get("lost", false):
						continue
					var pk_opts: Array = Game.package_options()
					if pk_opts.size():
						Game.try_package(int(pk_opts[0].roleIdx), int(pk_opts[0].c.id))
						if Game.pitch_ctx == null:
							stats.pitchOk += 1
							continue
				Game.close_deal(float(Game.pitch_ctx.fee))
				stats.pitchOk += 1
