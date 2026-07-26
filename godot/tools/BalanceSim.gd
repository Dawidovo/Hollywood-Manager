extends Node
# =====================================================================
# Balance-Simulation: spielt pro Epoche eine Kampagne mit einfachen
# Heuristiken (Signen, Pitchen, Post beantworten, Woche beenden) und
# protokolliert die Ökonomie als CSV-Zeilen ("SIM;...") für die Auswertung.
# Aufruf:  godot --headless --path . res://tools/BalanceSim.tscn
# Kein Spielinhalt — reines Analysewerkzeug. Achtung: end_week() speichert
# automatisch, der Lauf überschreibt also den Autosave (wie die Testsuite).
# =====================================================================

const WEEKS_PER_RUN := 104
const MAX_CLIENTS := 4
const MAX_PITCHES_PER_WEEK := 3


func _ready() -> void:
	print("=== Hollywood Manager Balance-Sim ===")
	print("SIM;year;week;cash;priv;stress;energy;clients;rep;inboxOpen;favors;debts;films")
	for year in [1925, 1950, 1980, 2010]:
		_run_era(int(year))
	get_tree().call_deferred("quit", 0)


func _run_era(year: int) -> void:
	seed(1000 + year)
	Game.new_game("Sim %d" % year, year)
	var stats := {"signTry": 0, "signOk": 0, "pitchTry": 0, "pitchOk": 0, "letters": 0, "overWeek": 0}
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
		Game.end_week()
		if week_no % 13 == 0 or week_no == WEEKS_PER_RUN - 1:
			_snapshot(year, week_no)
	_snapshot(year, WEEKS_PER_RUN)
	print("SUM;%d;signed %d/%d;pitched %d/%d;letters %d;gameOverWeek %d" % [year,
		stats.signOk, stats.signTry, stats.pitchOk, stats.pitchTry, stats.letters, stats.overWeek])
	_print_ledger(year)


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


func _snapshot(year: int, week_no: int) -> void:
	var st = Game.state
	var pl: Dictionary = st.player
	print("SIM;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d" % [year, week_no,
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
					Game.pitch_ctx = null
				else:
					Game.close_deal(float(Game.pitch_ctx.fee))
					stats.pitchOk += 1
