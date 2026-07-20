extends Node
# Headless-Logiktest: kompletter Spieldurchlauf ohne UI.
# Aufruf: godot --headless --path . res://tests/Test.tscn

var fails := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)

func _ready() -> void:
	print("=== Hollywood Manager Logiktest ===")

	# 1. Epochen & Pool
	Game.new_game("Testagentur", 1950)
	var pool = Game.available_actors()
	check(pool.size() > 20, "Talentpool 1950: %d Schauspieler" % pool.size())
	check(pool.any(func(a): return a.id == "bogart"), "Bogart 1950 verfügbar")
	check(not pool.any(func(a): return a.id == "chalamet"), "Chalamet 1950 nicht verfügbar")
	var wayne_fame = Game.fame_at(Game.actor_by_id["wayne"], 1950)
	check(Game.start_negotiation("wayne").get("locked", false), "Ruf-Schranke: Wayne (Ruhm %d) gesperrt" % wayne_fame)

	# 2. Verhandlung + DNA-Startprofil
	var n = Game.start_negotiation("monroe")
	check(not n.get("locked", false), "Monroe verhandelbar (Ruhm %d)" % n.fame)
	check(n.demands.has("commission") and n.demands.perks.size() >= 1, "Verdeckte Forderungen generiert")
	var res = Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": ["assistant"], "promise": "lead12"})
	check(res.get("accepted", false), "Monroe unterschrieben")
	var c = Game.state.clients[0]
	check(c.dna.size() == 5, "Karriere-DNA initialisiert (5 Achsen)")
	var dna_before = c.dna.duplicate()
	print("  DNA-Start Monroe: ", c.dna)

	# 3. Gegenvorschlag (deterministisch niedriges Angebot)
	Game.start_negotiation("gkelly")
	var counter = Game.build_counter({"commission": 12, "bonus": 0, "years": 2, "perks": [], "promise": null})
	check(counter != null and counter.has("text"), "Gegenvorschlag erzeugt: " + str(counter.text if counter else ""))
	Game.nego = null

	# 4. Sofort-Deal + DNA-Prägung über Release
	var r = Game.quick_production(c, {"genre": "romance", "prestige": 1})
	check(Game.state.productions.size() == 1, "Quick-Production angelegt: " + r.title)
	check(Game.state.agency.cash > 0, "Provision eingegangen")
	var prod = Game.state.productions[0]
	prod.monthsLeft = 1
	var ev = Game.release_film(prod)
	Game.state.productions.clear()
	check(ev.has("title"), "Release abgerechnet: " + ev.title)
	check(c.dna.romantik > dna_before.romantik, "DNA-Prägung: Romantik %0.1f → %0.1f" % [dna_before.romantik, c.dna.romantik])
	check(c.films.size() == 1, "Filmografie aktualisiert")

	# 5. DNA-Casting-Effekt: Romantiker vs. Horror
	c.dna = {"romantik": 80.0, "popular": 40.0, "verlass": 20.0, "unikat": 0.0, "familie": 50.0}
	var fit_rom = Game.dna_fit(c, "romance", "commercial")
	var fit_hor = Game.dna_fit(c, "horror", "commercial")
	check(fit_rom > 5.0 and fit_hor < 0.0, "DNA-Fit: Romanze %+0.1f vs. Horror %+0.1f" % [fit_rom, fit_hor])

	# 6. Monatsschleife mit Event-Auflösung (immer Option 0)
	c.busyUntil = 0
	# Im reinen Logiktest keine Audiospur synthetisieren.
	Jukebox._current_key = Jukebox.key_for_year(int(Game.state.year))
	var event_titles: Array = []
	for i in 18:
		var events = Game.end_month()
		for e in events:
			if e.choices[0].get("action", "") == "restart":
				event_titles.append("GAME OVER")
				continue
			event_titles.append(e.title)
			if e.choices[0].has("fn"):
				e.choices[0].fn.call()
	check(true, "18 Monate simuliert bis %s, Kasse %s" % [Game.date_str(), Game.fmt_money(Game.state.agency.cash)])
	print("  Events: ", ", ".join(event_titles.slice(0, 12)))

	# 7. Save/Load-Roundtrip inkl. DNA
	Game.save_game()
	var cash_before = Game.state.agency.cash
	var dna_saved = null
	if Game.state.clients.size():
		dna_saved = Game.state.clients[0].dna.duplicate()
	Game.state = null
	check(Game.load_game(), "Spielstand geladen")
	check(int(Game.state.agency.cash) == int(cash_before), "Kasse identisch nach Load")
	if dna_saved != null and Game.state.clients.size():
		check(absf(Game.state.clients[0].dna.romantik - dna_saved.romantik) < 0.01, "DNA überlebt Save/Load")

	# 8. Vertrauen, Geheimnisse und vorbereitete Krisen
	Game.new_game("Diskretion & Partner", 1950)
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": ["assistant"], "promise": null})
	var confidante: Dictionary = Game.state.clients[0]
	confidante.trust = 30.0
	var trust_events: Array = []
	Game.tick_clients(trust_events)
	check(confidante.trust > 30.0, "Vertrauen wächst monatlich")
	confidante.trustCap = 40.0
	confidante.trust = 39.0
	Game.change_trust(confidante, 20.0)
	check(absf(confidante.trust - 40.0) < 0.01, "Vertrauen respektiert dauerhaften Deckel")
	confidante.trustCap = 100.0
	confidante.trust = 60.0
	var reveal_events: Array = []
	check(Game.maybe_reveal_secret(confidante, reveal_events, true) and reveal_events.size() == 1, "Geheimnis wird an Vertrauensschwelle offenbart")
	var addiction_modal = Game.reveal_secret(confidante, "sucht", 3)
	check(addiction_modal != null or Game.secret_of(confidante, "sucht") != null, "Sucht-Geheimnis mit Folgepotenzial angelegt")
	Game.prepare_secret(int(confidante.id), "sucht", 0)
	Game.quick_production(confidante, {"genre":"drama"})
	confidante.exhaustion = 82.0
	check(Ev._w_breakdown() == 0.0, "Vorbereitete Sucht ersetzt den harten Zusammenbruch")

	# 9. Gerüchte wandern; Wahrheit und Lüge wirken ab derselben Schwelle
	var fame_before_rumor: float = confidante.fame
	var false_rumor := Game.add_rumor(int(confidante.id), "Man behauptet, Monroe wolle die Agentur verlassen.", false, "wechsel", ["Journalisten"], 59.0, true)
	var rumor_events: Array = []
	Game.tick_rumors(rumor_events, true)
	check(false_rumor.holders.size() > 1, "Gerücht wandert zu einem weiteren Trägertyp")
	check(false_rumor.impactApplied and false_rumor.belief >= 60.0, "Gerücht wirkt ab Glaubensschwelle")
	check(confidante.fame < fame_before_rumor, "Auch ein falsches Gerücht schadet")
	check(Game.rumor_fit_penalty(confidante) > 0.0, "Wechsel-Gerücht erzeugt Studio-Skepsis")

	# 10. Save/Load-Roundtrip mit Geheimnissen und Gerüchten
	var secret_count: int = confidante.secrets.size()
	var rumor_count: int = Game.state.rumors.size()
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Feature-Spielstand geladen")
	check(Game.state.clients[0].secrets.size() == secret_count, "Geheimnisse überleben Save/Load")
	check(Game.state.rumors.size() == rumor_count and Game.state.rumors[0].has("holders"), "Gerüchtenetzwerk überlebt Save/Load")

	# 11. Gefallen & Schulden: grant / consume / expire / remove_debt
	Game.new_game("Gefallen & Co", 1950)
	var f0: int = Game.state.favors.size()
	Game.grant_favor("suppressStory", {"type": "kolumnist", "name": "Kolumnistin R. Hopper"})
	check(Game.state.favors.size() == f0 + 1, "Gefallen vergeben (grant_favor)")
	check(Game.has_favor("suppressStory"), "has_favor findet die Art")
	check(Game.consume_favor("suppressStory"), "consume_favor löst ältesten passenden Gefallen ein")
	check(not Game.consume_favor("suppressStory"), "consume_favor ohne passenden Gefallen → false")
	Game.grant_favor("billing", {"type": "produzent", "name": "Produzent H. Barrow"})
	Game.state.favors[Game.state.favors.size() - 1].expiresMi = Game.mi() - 1
	var f_before: int = Game.state.favors.size()
	Game._expire_favors()
	check(Game.state.favors.size() == f_before - 1, "Verfallener Gefallen wird entfernt (Verjährung)")
	Game.owe_favor("galaInvite", {"type": "studio", "name": "Teststudio", "studioId": "test"})
	check(Game.state.debts.size() == 1, "Schuld angelegt (owe_favor)")
	Game.remove_debt(Game.state.debts[0].id)
	check(Game.state.debts.is_empty(), "Schuld beglichen (remove_debt)")

	# 12. extraAudition hebt eine Rollen-Ablehnung auf
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
	var cl: Dictionary = Game.state.clients[0]
	var casting: Dictionary = Game.state.castings[0]
	var role: Dictionary = casting.roles[0]
	role.rejected.append(int(cl.id))
	check(not Game.use_extra_audition(role, int(cl.id)), "extraAudition ohne Gefallen → false")
	check(role.rejected.has(int(cl.id)), "Ablehnung bleibt ohne Gefallen bestehen")
	Game.grant_favor("extraAudition", {"type": "produzent", "name": "Produzent H. Barrow"})
	check(Game.use_extra_audition(role, int(cl.id)), "extraAudition hebt Ablehnung auf")
	check(role.rejected.is_empty(), "Ablehnungs-Eintrag entfernt")

	# 13. Migration: alter Netzwerk-Wert → konkrete Gefallen
	Game.state["network"] = 45
	Game.state.erase("favors")
	Game.state.erase("debts")
	Game.state.erase("ledger")
	Game.state.erase("ledgerMonthly")
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Migration: alter Spielstand geladen")
	check(not Game.state.has("network"), "network-Feld entfernt")
	check(Game.state.favors.size() == 3, "45 Netzwerk → 3 Gefallen (%d)" % Game.state.favors.size())
	check(Game.state.has("ledger") and Game.state.has("ledgerMonthly") and Game.state.has("debts"), "Ledger/Schulden-Felder migriert")

	# 14. Ledger: jede Geldbewegung erzeugt einen Eintrag
	Game.new_game("Bilanz AG", 1950)
	check(Game.state.ledger.size() == 1 and str(Game.state.ledger[0].cat) == "sonstiges", "Eröffnungsbuchung im Ledger")
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 2000, "years": 5, "perks": ["assistant"], "promise": null})
	check(Game.state.ledger.any(func(e): return str(e.cat) == "bonus"), "Signing-Bonus gebucht")
	var cl2: Dictionary = Game.state.clients[0]
	var led_n: int = Game.state.ledger.size()
	var cash0: float = float(Game.state.agency.cash)
	Game.quick_production(cl2, {"genre": "romance", "prestige": 1})
	check(Game.state.ledger.size() == led_n + 1, "Provision gebucht")
	var last: Dictionary = Game.state.ledger[Game.state.ledger.size() - 1]
	check(str(last.cat) == "provision" and float(last.amount) > 0.0, "Provision positiv & richtig kategorisiert")
	check(absf(float(Game.state.agency.cash) - (cash0 + float(last.amount))) < 1.0, "Kasse entspricht der Buchung")

	# 15. Monatsaggregat stimmt mit Cash-Delta und Einzelbuchungen überein
	var mi0: int = Game.mi()
	var c0: float = float(Game.state.agency.cash)
	var led_before: int = Game.state.ledger.size()
	cl2.busyUntil = 0
	Game.end_month()
	var c1: float = float(Game.state.agency.cash)
	var sum := 0.0
	for i in range(led_before, Game.state.ledger.size()):
		sum += float(Game.state.ledger[i].amount)
	check(absf((c1 - c0) - sum) < 1.0, "Cash-Delta == Summe der Buchungen (%0.0f)" % (c1 - c0))
	var agg = null
	for m in Game.state.ledgerMonthly:
		if int(m.mi) == mi0:
			agg = m
	check(agg != null, "Monatsaggregat fortgeschrieben")
	var inc := 0.0
	var exp := 0.0
	for e in Game.state.ledger:
		if int(e.mi) == mi0:
			if float(e.amount) >= 0:
				inc += float(e.amount)
			else:
				exp -= float(e.amount)
	check(agg != null and absf(float(agg.income) - inc) < 1.0 and absf(float(agg.expenses) - exp) < 1.0, "Aggregat stimmt mit Einzelbuchungen überein")
	check(Game.avg_burn(6) > 0.0, "Burn-Rate berechnet: %s/Mon." % Game.fmt_money(Game.avg_burn(6)))

	# 16. Ledger-Kappung + Save/Load-Roundtrip von Gefallen & Aggregaten
	for i in 700:
		Game.book(1.0, "sonstiges", "Fülltest")
	check(Game.state.ledger.size() == 600, "Ledger auf 600 Einträge begrenzt")
	Game.save_game()
	var fav_n: int = Game.state.favors.size()
	Game.state = null
	check(Game.load_game(), "Bilanz-Spielstand geladen")
	check(Game.state.favors.size() == fav_n and Game.state.ledgerMonthly.size() >= 1, "Gefallen & Monatsaggregate überleben Save/Load")

	# 17. Noten & Titel
	check(Game.grade(95) == "A+" and Game.grade(30) == "F", "Notenskala")
	check(Data.REAL_TITLES.size() > 150, "Echte Titel geladen: %d" % Data.REAL_TITLES.size())
	check(Data.ACTORS.size() == 200, "Schauspieler: %d" % Data.ACTORS.size())
	# Modals enthalten absichtlich Callables, gehören aber nie in den Save-State.
	# Vor dem sofortigen Testprozess-Ende Referenzen lösen, damit Godot sauber aufräumt.
	trust_events.clear()
	reveal_events.clear()
	addiction_modal = null
	rumor_events.clear()
	Jukebox.player.stop()
	Jukebox.player.stream = null
	Jukebox._cache.clear()
	await get_tree().process_frame

	print("=== FERTIG: %d Fehler ===" % fails)
	get_tree().call_deferred("quit", 1 if fails > 0 else 0)
