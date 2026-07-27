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
	var body_m_actor := {"id": "body_test_m", "g": "m", "height_cm": 0, "weight_kg": 0}
	var body_m_a := Util.body_of(body_m_actor)
	var body_m_b := Util.body_of(body_m_actor)
	var body_f := Util.body_of({"id": "body_test_f", "g": "f", "height_cm": 0, "weight_kg": 0})
	check(body_m_a == body_m_b, "Körperdaten sind je Schauspieler deterministisch")
	check(int(body_m_a.height) >= 168 and int(body_m_a.height) <= 193, "Prozedurale Männergröße liegt im plausiblen Bereich")
	check(int(body_f.height) >= 155 and int(body_f.height) <= 180, "Prozedurale Frauengröße liegt im plausiblen Bereich")
	var body_m_bmi := float(body_m_a.weight) / pow(float(body_m_a.height) / 100.0, 2.0)
	var body_f_bmi := float(body_f.weight) / pow(float(body_f.height) / 100.0, 2.0)
	check(body_m_bmi >= 18.5 and body_m_bmi <= 26.5 and body_f_bmi >= 18.5 and body_f_bmi <= 26.5, "Prozedurale Gewichte entsprechen einem plausiblen BMI")
	var bogart_body := Util.body_of(Game.actor_by_id["bogart"])
	check(int(bogart_body.height) == 173 and int(bogart_body.weight) == 70, "JSON-Körperdaten überschreiben prozedurale Werte (Bogart)")
	check(Data.ACTORS.any(func(a): return str(a.id) == "bogart" and int(a.height_cm) > 0 and int(a.weight_kg) > 0), "DataLoader: body_core-Paket an Bogart gemergt")
	var wayne_fame = Util.fame_at(Game.actor_by_id["wayne"], 1950)
	check(Game.start_negotiation("wayne").get("locked", false), "Ruf-Schranke: Wayne (Ruhm %d) gesperrt" % wayne_fame)

	# 2. Verhandlung + DNA-Startprofil
	var n = Game.start_negotiation("monroe")
	check(not n.get("locked", false), "Monroe verhandelbar (Ruhm %d)" % n.fame)
	check(n.demands.has("commission") and n.demands.perks.size() >= 1, "Verdeckte Forderungen generiert")
	var res = Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": ["assistant"], "promise": "lead12"})
	check(res.get("accepted", false), "Monroe unterschrieben")
	var c = Game.state.clients[0]
	check(c.dna.size() == 5, "Karriere-DNA initialisiert (5 Achsen)")
	check(c.has("weightKg") and c.has("weightTrend") and absf(float(c.weightKg) - float(Util.body_of(Game.actor_by_id["monroe"]).weight)) < 0.01, "Signing initialisiert aktuelles Gewicht und Trend")
	var dna_before = c.dna.duplicate()
	print("  DNA-Start Monroe: ", c.dna)

	# 3. Gegenvorschlag (deterministisch niedriges Angebot) — ein wirklich
	# verfügbarer Kandidat; gesperrte Anbahnungen nullen die Verhandlung.
	var counter_actor: Dictionary = Game.available_actors().filter(func(a): return Util.fame_at(a, Game.state.year) <= 55)[0]
	check(not Game.start_negotiation(str(counter_actor.id)).get("locked", false), "Kandidat für den Gegenvorschlag ist verhandelbar")
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
	var fit_rom = CareerDNA.dna_fit(c, "romance", "commercial")
	var fit_hor = CareerDNA.dna_fit(c, "horror", "commercial")
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
	check(true, "18 Monate simuliert bis %s, Kasse %s" % [Game.date_str(), Util.fmt_money(Game.state.agency.cash)])
	print("  Events: ", ", ".join(event_titles.slice(0, 12)))

	# 7. Save/Load-Roundtrip inkl. DNA
	Game.save_game()
	var cash_before = Game.state.agency.cash
	var dna_saved = null
	var weight_saved = null
	if Game.state.clients.size():
		dna_saved = Game.state.clients[0].dna.duplicate()
		weight_saved = float(Game.state.clients[0].weightKg)
	Game.state = null
	check(Game.load_game(), "Spielstand geladen")
	check(int(Game.state.agency.cash) == int(cash_before), "Kasse identisch nach Load")
	if dna_saved != null and Game.state.clients.size():
		check(absf(Game.state.clients[0].dna.romantik - dna_saved.romantik) < 0.01, "DNA überlebt Save/Load")
		check(absf(float(Game.state.clients[0].weightKg) - float(weight_saved)) < 0.01, "Klientengewicht überlebt Save/Load")

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
	check(Scandal.maybe_reveal_secret(confidante, reveal_events, true) and reveal_events.size() == 1, "Geheimnis wird an Vertrauensschwelle offenbart")
	var addiction_modal = Scandal.reveal_secret(confidante, "sucht", 3)
	check(addiction_modal != null or Scandal.secret_of(confidante, "sucht") != null, "Sucht-Geheimnis mit Folgepotenzial angelegt")
	Scandal.prepare_secret(int(confidante.id), "sucht", 0)
	Game.quick_production(confidante, {"genre":"drama"})
	confidante.exhaustion = 82.0
	check(Ev._w_breakdown() == 0.0, "Vorbereitete Sucht ersetzt den harten Zusammenbruch")

	# 9. Gerüchte wandern; Wahrheit und Lüge wirken ab derselben Schwelle
	var fame_before_rumor: float = confidante.fame
	var false_rumor := Scandal.add_rumor(int(confidante.id), "Man behauptet, Monroe wolle die Agentur verlassen.", false, "wechsel", ["Journalists"], 59.0, true)
	var rumor_events: Array = []
	Scandal.tick_rumors(rumor_events, true)
	check(false_rumor.holders.size() > 1, "Gerücht wandert zu einem weiteren Trägertyp")
	check(false_rumor.impactApplied and false_rumor.belief >= 60.0, "Gerücht wirkt ab Glaubensschwelle")
	check(confidante.fame < fame_before_rumor, "Auch ein falsches Gerücht schadet")
	check(Scandal.rumor_fit_penalty(confidante) > 0.0, "Wechsel-Gerücht erzeugt Studio-Skepsis")

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
	# consume_favor kann per Zufall (25%) eine Gegenschuld erzeugen — für die
	# deterministische Zählung unten wird das Register vorher geleert.
	Game.state.debts.clear()
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
	check(Game.avg_burn(6) > 0.0, "Burn-Rate berechnet: %s/Mon." % Util.fmt_money(Game.avg_burn(6)))

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
	check(Util.grade(95) == "A+" and Util.grade(30) == "F", "Notenskala")
	check(Data.REAL_TITLES.size() > 150, "Echte Titel geladen: %d" % Data.REAL_TITLES.size())
	check(Data.ACTORS.size() == 200, "Schauspieler: %d" % Data.ACTORS.size())

	# 18. Drei Wahrheiten: Öffentlichkeit und Branche wirken getrennt
	Game.new_game("Drei Wahrheiten", 1950)
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var truth_client: Dictionary = Game.state.clients[0]
	var truth_fame := float(truth_client.fame)
	var industry_rumor := Scandal.add_rumor(int(truth_client.id), "Studios zweifeln intern an der Verlässlichkeit.", false, "wechsel", ["Studios"], 5.0, true, "", 70.0)
	Scandal.tick_rumors([], false)
	check(industry_rumor.industryImpactApplied and not industry_rumor.impactApplied, "Branchenwissen wird ohne öffentliche Schlagzeile wirksam")
	check(absf(float(truth_client.fame) - truth_fame) < 0.01 and Scandal.rumor_fit_penalty(truth_client) >= 12.0, "Branchenwissen schadet Casting, nicht Ruhm")
	var public_rumor := Scandal.add_rumor(int(truth_client.id), "Die Presse verbreitet eine öffentliche Geschichte.", false, "skandal", ["Journalisten"], 70.0, true, "", 5.0)
	Scandal.tick_rumors([], false)
	check(public_rumor.impactApplied and not public_rumor.industryImpactApplied, "Öffentlicher Glaube wirkt ohne Branchenmehrheit")
	check(float(truth_client.fame) < truth_fame, "Öffentliche Geschichte verändert Ruhm/Image")

	# 19. Zeitung: echte Simulationsdaten, Kategorien und anonymes Blind Item
	var news_prod: Dictionary = Game.quick_production(truth_client, {"genre":"drama", "prestige":3, "qualityMod":10.0}).prod
	Game.release_film(news_prod)
	Game.state.productions.erase(news_prod)
	Scandal.add_rumor(int(truth_client.id), "Marilyn Monroe werde in einem Bungalow beobachtet.", false, "affäre", ["Journalisten", "Partygäste"], 45.0, true, "", 20.0)
	Rivals.tick_rivals([], true)
	var issue: Dictionary = Newspaper.build_newspaper()
	var categories: Dictionary = {}
	var blind_text := ""
	for headline in issue.headlines:
		categories[str(headline.cat)] = true
		if str(headline.cat) == "Blind item":
			blind_text = str(headline.text)
	check(categories.size() >= 4, "Zeitung erzeugt mindestens 4 Kategorien aus Sim-Daten (%d)" % categories.size())
	check(blind_text != "" and not blind_text.contains("Marilyn") and not blind_text.contains("Monroe"), "Blind Item bleibt ohne Klarnamen")
	check(Game.state.newspaper.size() == 1 and str(issue.name).contains("Hollywood"), "Aktuelle Ausgabe im kompakten Archiv gespeichert")

	# 20. Karrierenarrativ: erkennen, ausrufen, passend verstärken, abschließen
	Game.new_game("Kapitel Zwei", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("wayne")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var narrative_client: Dictionary = Game.state.clients[0]
	check(Game.narrative_candidate_types(narrative_client).has("action_prestige"), "Action→Prestige-Narrativ erkannt")
	var narrative_result := Game.declare_narrative(int(narrative_client.id), "action_prestige")
	check(str(narrative_client.narrative.status) == "aktiv" and narrative_result.contains("press kit"), "Narrativ ausgerufen und PR-Budget gebucht")
	narrative_client.narrative.progress = 45.0
	var prestige_prod := {"title":"Das zweite Gesicht", "genre":"drama", "prestige":3}
	var prestige_role := {"type":"lead"}
	check(Game.narrative_multiplier(narrative_client, prestige_prod, prestige_role) == 2.0, "Passende Rolle verdoppelt Ruhm/DNA-Wirkung")
	Game.advance_narrative_on_release(narrative_client, prestige_prod, prestige_role)
	check(str(narrative_client.narrative.status) == "abgeschlossen" and float(narrative_client.narrative.progress) >= 100.0, "Narrativ abgeschlossen")

	# 21. Rivalen: Pool-Sperre, Groll-Gerücht und Persönlichkeit
	Game.new_game("Gegenwind", 1950)
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var rival: Dictionary = Game.state.rivals[0]
	var rival_before: int = rival.clients.size()
	rival.grudge = 80.0
	Rivals.tick_rivals([], true)
	check(rival.clients.size() > rival_before, "Rivale signiert Pool-Schauspieler")
	var rival_actor_id := str(rival.clients[0])
	check(not Game.available_actors().any(func(a): return str(a.id) == rival_actor_id) and Game.pool_actors().any(func(a): return str(a.id) == rival_actor_id), "Rivalenklient im Pool markierbar, aber gesperrt")
	check(Game.state.rumors.any(func(r): return str(r.get("sourceRival", "")) == str(rival.id)), "Groll-Gerücht landet im bestehenden Netzwerk")

	# 22. Identität zählt Verhalten und wirkt in Klientenverhandlungen
	Game.state.agency.rep = 100
	Game.start_negotiation("brando")
	var identity_offer := {"commission":10, "bonus":0, "years":5, "perks":[], "promise":"prestige"}
	var score_neutral := Game.evaluate_offer(identity_offer)
	Game.record_identity("kuenstlerisch", 12.0)
	Game.record_identity("klientenorientiert", 8.0)
	var score_artistic := Game.evaluate_offer(identity_offer)
	check(float(Game.state.identity.kuenstlerisch) == 12.0 and Game.identity_top_labels().has("artistic"), "Identität zählt konkrete Verhaltensmuster")
	check(score_artistic > score_neutral + 3.0, "Künstlerische Identität verbessert Angebot für Ausnahmetalent")
	Game.nego = null

	# 23. Save/Load-Roundtrip aller neuen JSON-Felder
	Game.state.clients[0].narrative = {"type":"comeback", "startedMi":Game.mi(), "progress":35.0, "status":"aktiv"}
	Newspaper.build_newspaper()
	var saved_rivals: int = Game.state.rivals.size()
	var saved_news: int = Game.state.newspaper.size()
	var saved_industry := float(Game.state.rumors[0].industryBelief)
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Neuer Feature-Spielstand geladen")
	check(Game.state.rivals.size() == saved_rivals and Game.state.newspaper.size() == saved_news, "Rivalen & Zeitung überleben Save/Load")
	check(float(Game.state.identity.kuenstlerisch) == 12.0 and str(Game.state.clients[0].narrative.type) == "comeback", "Identität & Narrativ überleben Save/Load")
	check(absf(float(Game.state.rumors[0].industryBelief) - saved_industry) < 0.01, "Branchenwissen überlebt Save/Load")

	# 24. Phase 2: alternde Stars werden Machtfiguren oder gründen Rivalen
	Game.new_game("Hinter der Kamera", 1980)
	Game.state.agency.rep = 100
	Game.start_negotiation("eastwood")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var power_client: Dictionary = Game.state.clients[0]
	power_client.fame = 85.0
	power_client.awards = 1
	check(Game.power_figure_candidates().has(power_client), "Erfolgsklient 45+ als Machtfigur erkannt")
	Game.become_power_figure(int(power_client.id), "director", true)
	check(Game.state.powerFigures.size() == 1 and bool(Game.state.powerFigures[0].agencyFriendly), "Klient übernimmt Regie und bleibt der Agentur verbunden")
	var power_casting: Dictionary = Game.state.castings[0]
	Game.assign_power_figure_to_casting(power_casting, true)
	check(power_casting.has("director") and float(power_casting.get("agencyBoost", 0.0)) >= 8.0, "Machtfigur taucht in Casting auf und bevorzugt die Agentur")

	Game.new_game("Zerrüttetes Haus", 1990)
	Game.state.agency.rep = 100
	Game.start_negotiation("eastwood")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var estranged: Dictionary = Game.state.clients[0]
	estranged.fame = 85.0
	estranged.loyalty = 10.0
	estranged.trust = 10.0
	var rivals_before_power: int = Game.state.rivals.size()
	Game.become_power_figure(int(estranged.id), "producer", false, true)
	check(Game.state.rivals.size() == rivals_before_power + 1 and Game.state.clients.is_empty(), "Zerrüttete Beziehung gründet neue Rivalen-Agentur")
	check(str(Game.state.powerFigures[0].rivalId) != "" and not bool(Game.state.powerFigures[0].agencyFriendly), "Unabhängige Machtfigur ist mit Rivalenhaus verknüpft")
	Game.save_game()
	Game.state = null
	check(Game.load_game() and Game.state.powerFigures.size() == 1, "Machtfiguren überleben Save/Load")

	# 25. Instinkt & Prognosen: anlegen, auflösen, Frust-Deckel (Feature 6)
	Game.new_game("Bauchgefühl", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var inst_before := int(Game.state.instinct)
	check(inst_before == 20, "Instinkt startet bei 20")
	var pr = Predictions.add_prediction("star", int(Game.state.clients[0].id), true, Game.mi() - 1, "Test-Star-Prognose")
	Predictions.tick_predictions([])
	check(bool(pr.resolved) and int(Game.state.instinct) == inst_before - 1, "Falsche Prognose: Instinkt −1 (%d → %d)" % [inst_before, int(Game.state.instinct)])
	var pr2 = Predictions.add_prediction("star", int(Game.state.clients[0].id), false, Game.mi() - 1, "Test-Prognose 2")
	Predictions.tick_predictions([])
	check(bool(pr2.resolved) and int(Game.state.instinct) == inst_before + 2, "Richtige Prognose: Instinkt +3 (→ %d)" % int(Game.state.instinct))
	Game.state.instinct = 5
	var pr3 = Predictions.add_prediction("star", int(Game.state.clients[0].id), true, Game.mi() - 1, "Frust-Deckel-Test")
	Predictions.tick_predictions([])
	check(bool(pr3.resolved) and int(Game.state.instinct) == 5, "Instinkt fällt nie unter 5")

	# 26. Klausel-Event feuert NUR mit Klausel-Flag (Feature 8)
	check(Ev._w_sequel_crisis() == 0.0, "Sequel-Krise ohne sequelDue-Flag stumm")
	Game.state.clients[0].flags["sequelDue"] = {"title":"Testfilm", "fee": 1000, "studioId": str(Game.active_studios()[0].id)}
	check(Ev._w_sequel_crisis() > 0.0, "Sequel-Krise feuert mit sequelDue-Flag")
	var sc_ev: Dictionary = Ev._b_sequel_crisis()
	check(sc_ev.choices.size() == 3, "Sequel-Krise bietet drei Auswege")
	sc_ev.choices[1].fn.call()
	check(Game.state.clients[0].flags.get("sequelDue") == null, "sequelDue nach Entscheidung gelöscht")

	# 27. profitShare wird beim Release über den Ledger gebucht (Feature 8)
	Game.new_game("Beteiligung", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var ps_client: Dictionary = Game.state.clients[0]
	ps_client.fame = 100.0
	var ps_prod: Dictionary = Game.quick_production(ps_client, {"genre":"drama", "prestige":3}).prod
	ps_prod.budget = 1000.0
	for rl in ps_prod.roles:
		rl.filled["clauses"] = ["profitShare"]
	Game.state.market = 2.0
	var ledger_before: int = Game.state.ledger.size()
	Game.release_film(ps_prod)
	Game.state.productions.clear()
	var ps_entries: Array = Game.state.ledger.filter(func(e): return str(e.text).contains("Profit share"))
	check(Game.state.ledger.size() > ledger_before, "Release schreibt ins Ledger")
	check(ps_entries.size() == 1 and float(ps_entries[0].amount) > 0.0, "Gewinnbeteiligung gebucht: %s" % (ps_entries[0].text if ps_entries.size() else "—"))

	# 28. Mehrparteien-Tisch: Regisseur-Veto trotz guter Gage + Rückweg (Feature 9)
	Game.new_game("Verhandlungstisch", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var t_client: Dictionary = Game.state.clients[0]
	var t_casting: Dictionary = Game.state.castings[0]
	Game.pitch_ctx = {"casting": t_casting, "roleIdx": 0, "role": t_casting.roles[0], "client": t_client, "fee": 50000, "haggled": false, "alts": []}
	var tbl := Game.start_table()
	check(tbl.parties.has("studio") and tbl.parties.has("director") and tbl.parties.has("client"), "Studio, Regisseur & Klient am Tisch")
	tbl.parties.director.sat = 5.0
	tbl.parties.studio.sat = 90.0
	tbl.parties.client.sat = 90.0
	var close_res := Game.close_table()
	check(not close_res.get("success", true) and str(close_res.get("veto", "")) == "director", "Deal scheitert am Regisseur-Veto trotz guter Gage")
	check(close_res.get("fallbacks", []).any(func(f): return str(f.kind) == "withdraw"), "Rückweg vorhanden: Rückzug ohne Zusatzschaden")
	Game.table = null
	Game.pitch_ctx = null

	# 29. Chemie: deterministisch, symmetrisch, historisch geprägt (Feature 12)
	var chem_a := Game.chemistry("a1", "b1")
	var chem_b := Game.chemistry("a1", "b1")
	check(int(chem_a.screen) == int(chem_b.screen) and int(chem_a.personal) == int(chem_b.personal), "Chemie deterministisch (Leinwand %+d, persönlich %+d)" % [chem_a.screen, chem_a.personal])
	check(Game.pair_key("x", "y") == Game.pair_key("y", "x"), "Paar-Schlüssel symmetrisch")
	Game.note_pair_history("a1", "b1", 5)
	check(Game.state.history_pairs.has(Game.pair_key("a1", "b1")), "Gemeinsame Historie gespeichert")
	var fake_prod := {"id": 999, "director": {"name": "Testregisseur"}, "roles": [
		{"type": "lead", "filled": {"clientId": int(t_client.id), "fee": 1}},
		{"type": "lead", "filled": {"npc": true, "name": "Co-Star", "talent": 50, "fame": 40}}]}
	var lcq := float(Game.lead_chem_quality(fake_prod))
	check(absf(lcq) <= 8.0, "Leinwandchemie fließt begrenzt in Qualität ein (%+0.1f von ±8)" % lcq)

	# 30. Produktions-Signale: generiert + Reaktion möglich, 1× pro Film (Feature 13)
	Game.new_game("Setgerüchte", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var sig_client: Dictionary = Game.state.clients[0]
	var sig_prod: Dictionary = Game.quick_production(sig_client, {"genre":"drama"}).prod
	Game._tick_signals([], true)
	check(sig_prod.get("signals", []).size() >= 1, "Signal generiert: %s" % (sig_prod.signals[0].t if sig_prod.get("signals", []).size() else "—"))
	var reneg_msg := Game.prod_renegotiate(int(sig_prod.id))
	check(bool(sig_prod.reactions.get("reneg", false)) and reneg_msg != "", "Nachverhandeln wirkt und sperrt sich (1× pro Film)")
	Game.prod_pull_client(int(sig_prod.id))
	check(sig_prod.roles[0].filled.get("clientId") == null, "Klienten-Rückzug ersetzt die Besetzung")

	# 31. Weekly Planner: Erholung senkt Erschöpfung, Dinner hebt Beziehung
	Game.new_game("Planer", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var pl_client: Dictionary = Game.state.clients[0]
	pl_client.exhaustion = 80.0
	pl_client.busyUntil = 0
	# Volle 21-Slot-Erholungswoche (7 Tage × 3 Abschnitte)
	Planner.planner_fill("client", int(pl_client.id), "erholung", null, false)
	var dinner_studio: Dictionary = Game.active_studios()[0]
	var rel_before := int(Game.state.studioRel[dinner_studio.id])
	for d in 5:
		Planner.planner_slot_set("player", 0, d, 0, "dinner", dinner_studio.id)
	Planner._apply_planner([])
	check(float(pl_client.exhaustion) <= 68.01, "Volle Erholungswoche senkt Erschöpfung (80 → %0.1f)" % pl_client.exhaustion)
	check(int(Game.state.studioRel[dinner_studio.id]) == rel_before + 1, "Studio-Dinner: 5 Abende ⇒ Beziehung +1")
	check(Game.state.planner.player[0] == null, "Planer beginnt die neue Woche leer")

	# 32. Save/Load-Roundtrip aller Simulations-Felder
	Planner.planner_slot_set("player", 0, 2, 1, "scouting")
	Game.state.instinct = 42
	Game.state.history_pairs["t1|t2"] = {"n": 2, "p": 3}
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Simulations-Spielstand geladen")
	check(int(Game.state.instinct) == 42, "Instinkt überlebt Save/Load")
	check(Game.state.has("predictions") and Game.state.has("planner") and Game.state.planner.has("player"), "Prognosen & Planer überleben Save/Load")
	check(str(Game.state.planner.player[7].get("a", "")) == "scouting", "Planer-Slots (Tag/Abschnitt) überleben Save/Load")
	check(int(Game.state.history_pairs.get("t1|t2", {}).get("p", 0)) == 3, "Chemie-Historie überlebt Save/Load")
	check(Game.state.clients[0].has("clauses") and Game.state.clients[0].has("exclusiveStudio"), "Klausel- & Exklusiv-Felder migriert")

	# 33. Script Coverage: Blatt, Marker, Auflösung, Schnitt-Wurf, Verfall
	Game.new_game("Lektorat", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var cov_client: Dictionary = Game.state.clients[0]
	Coverage._issue_coverage()
	var sheet: Dictionary = Game.state.coverage.current
	check(sheet != null and sheet.has("castingRef"), "Coverage-Blatt liegt auf dem Schreibtisch")
	check(sheet.statements.size() >= 4, "Coverage erzeugt mindestens 4 Aussagen aus Sim-Daten (%d)" % sheet.statements.size())
	var cov_casting = Game._casting(sheet.castingRef)
	check(cov_casting != null and bool(cov_casting.get("hidden", false)), "Coverage-Casting bleibt einen Monat verdeckt")
	var pred_n0: int = Game.state.predictions.size()
	var mark_msg := Coverage.coverage_mark(0, "schwach")
	check(Game.state.predictions.size() == pred_n0 + 1 and str(Game.state.predictions[-1].type) == "coverage", "Marker legt Coverage-Prognose an")
	check(mark_msg.contains("Marker set"), "Marker-Setzen bestätigt")
	Coverage.coverage_mark(1, "sicher")
	check(Coverage.coverage_mark(2, "prestige").contains("No markers left"), "Marker-Kontingent begrenzt (%d)" % int(sheet.markersMax))
	# Auflösung beim Release: richtig +3, falsch fällt nie unter 5
	var cov_fake := {"id": 4242, "title": "Testfilm", "genre": "drama", "prestige": 1, "budget": 1000.0,
		"qualityMod": 0.0, "signals": [], "studioId": str(Game.active_studios()[0].id),
		"roles": [{"type": "lead", "gender": "f", "minFame": 10, "ageMin": 18, "ageMax": 99, "fee": 1, "cutRisk": true, "filled": {"npc": true, "name": "X", "talent": 50, "fame": 30}, "rejected": []}]}
	var inst0 := int(Game.state.instinct)
	var pr_weak := Predictions.add_prediction("coverage", {"castingId": 4242, "cat": "schwach", "roleIdx": 0, "sheetId": int(sheet.id)}, true, Game.mi() + 9, "Coverage-Test schwach")
	Predictions._resolve_release_predictions(cov_fake, 0.5, {}, 50)
	check(bool(pr_weak.resolved) and bool(pr_weak.correct) and int(Game.state.instinct) == inst0 + 3, "Richtiger Marker: Instinkt +3 (%d → %d)" % [inst0, int(Game.state.instinct)])
	Game.state.instinct = 5
	var pr_pres := Predictions.add_prediction("coverage", {"castingId": 4242, "cat": "prestige", "roleIdx": 0, "sheetId": int(sheet.id)}, true, Game.mi() + 9, "Coverage-Test prestige")
	Predictions._resolve_release_predictions(cov_fake, 0.5, {}, 50)
	check(bool(pr_pres.resolved) and not bool(pr_pres.correct) and int(Game.state.instinct) == 5, "Falscher Marker: Instinkt fällt nie unter 5")
	# Schnitt-Auflösung: Wurf triggert, Release löst die Prognose auf
	var cut_hit := false
	for i in 80:
		if Coverage._coverage_cut_roll(cov_fake, cov_fake.roles[0]):
			cut_hit = true
			break
	check(cut_hit, "Schnitt-Wurf triggert bei markierter Rolle (cutRisk)")
	var cov_qp: Dictionary = Game.quick_production(cov_client, {"genre": "drama", "prestige": 1})
	var cov_prod: Dictionary = cov_qp.prod
	var pr_cut := Predictions.add_prediction("coverage", {"castingId": int(cov_prod.id), "cat": "schnitt", "roleIdx": 0, "sheetId": int(sheet.id)}, true, Game.mi() + 9, "Coverage-Test schnitt")
	Game.release_film(cov_prod)
	Game.state.productions.erase(cov_prod)
	check(bool(pr_cut.resolved), "Schnitt-Prognose wird beim Release aufgelöst (Schnitt eingetreten: %s)" % ("ja" if bool(pr_cut.correct) else "nein"))
	# Verfall: Blatt verfällt zum Monatsende, Casting wird sichtbar
	Jukebox._current_key = Jukebox.key_for_year(int(Game.state.year))
	cov_client.busyUntil = 0
	var hist_n0: int = Game.state.coverage.history.size()
	Game.end_month()
	check(Game.state.coverage.history.size() == hist_n0 + 1, "Coverage-Blatt verfällt ins Archiv")
	check(not bool(cov_casting.get("hidden", false)), "Coverage-Casting erscheint im Folgemonat regulär")

	# 34. Karrierebrett: Kontrast-Bonus, ×1,5-Imprint, Typecasting-Sog, Abschluss
	Game.new_game("Karriereplanung", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var board_client: Dictionary = Game.state.clients[0]
	Game.board_slot_add(int(board_client.id), "comedy", "lead", 1)
	Game.board_slot_add(int(board_client.id), "thriller", "lead", 2)
	Game.board_slot_add(int(board_client.id), "drama", "lead", 3)
	check(board_client.careerBoard.slots.size() == 3, "Drei Plan-Slots angelegt")
	var ana := Game.board_analysis(board_client)
	check(bool(ana.contrasting) and not bool(ana.repetitive), "Kontrastfolge erkannt (Transformations-Bonus)")
	var heat0 := float(board_client.heat)
	var bp1: Dictionary = Game.quick_production(board_client, {"genre": "comedy", "prestige": 1, "roleType": "lead"})
	check(int(board_client.careerBoard.slots[0].filledMi) >= 0, "Genre-Match füllt Slot 1")
	check(float(bp1.prod.roles[0].filled.get("boardMult", 1.0)) == 1.5, "Erfüllter Slot: DNA-Prägung ×1,5 markiert")
	check(float(board_client.heat) == heat0 + 1.0, "Slot-Bonus: Heat +1")
	var fame_before_miss := float(board_client.fame)
	Game.quick_production(board_client, {"genre": "horror", "prestige": 1, "roleType": "support"})
	check(Game.board_next_open(board_client) == 1, "Nicht passende Rolle: Slot 2 bleibt offen")
	check(absf(float(board_client.fame) - fame_before_miss) < 0.01, "Kein Match: kein Abzug, keine Strafe")
	# ×1,5-Imprint wirkt beim Release
	var popular0 := float(board_client.dna.popular)
	Game.release_film(bp1.prod)
	Game.state.productions.erase(bp1.prod)
	check(float(board_client.dna.popular) >= popular0 + 8.5, "Release prägt ×1,5 ein: populär %0.1f → %0.1f" % [popular0, float(board_client.dna.popular)])
	# Slots 2 & 3 füllen → Abschluss mit Ruhm +4, Titelstory, Transformations-Bonus
	var fame0b := float(board_client.fame)
	var unikat0 := float(board_client.dna.unikat)
	Game.quick_production(board_client, {"genre": "thriller", "prestige": 2, "roleType": "lead"})
	Game.quick_production(board_client, {"genre": "drama", "prestige": 3, "roleType": "lead"})
	check(board_client.careerBoard.slots.is_empty() and int(board_client.careerBoard.completed) == 1, "Komplettes Brett wird abgeräumt und gewürdigt")
	check(float(board_client.fame) >= fame0b + 4.0, "Abschluss: Ruhm +4 (+%0.1f)" % (float(board_client.fame) - fame0b))
	check(float(board_client.dna.unikat) >= unikat0 + 6.0, "Transformations-Bonus: Einzigartig +6")
	check(Game.state.pressFeed.any(func(p): return str(p.text).contains("reinvention")), "Titelstory „Die Neuerfindung des …“ im Pressespiegel")
	# Typecasting-Sog: dreimal dasselbe Profil
	Game.board_slot_add(int(board_client.id), "action", "lead", 1)
	Game.board_slot_add(int(board_client.id), "action", "lead", 1)
	Game.board_slot_add(int(board_client.id), "action", "lead", 1)
	check(bool(Game.board_analysis(board_client).repetitive), "Wiederholungsfolge erkannt (Typecasting-Sog)")
	var unikat1 := float(board_client.dna.unikat)
	Game.quick_production(board_client, {"genre": "action", "prestige": 1, "roleType": "lead"})
	Game.quick_production(board_client, {"genre": "action", "prestige": 1, "roleType": "lead"})
	check(not board_client.flags.get("typecastRisk", false), "Typecasting-Risiko erst ab Slot 3")
	Game.quick_production(board_client, {"genre": "action", "prestige": 1, "roleType": "lead"})
	check(bool(board_client.flags.get("typecastRisk", false)), "Typecasting-Risiko-Flag ab Slot 3 gesetzt")
	check(float(board_client.dna.unikat) <= unikat1 - 9.0, "Typecasting-Drift: Einzigartig −9 über drei Slots (%0.1f)" % float(board_client.dna.unikat))
	# Verfall: offener Slot verfällt nach 30 Monaten lautlos
	Game.board_slot_add(int(board_client.id), "western", "support", 2)
	board_client.careerBoard.slots[0].createdMi = Game.mi() - 31
	Game._tick_boards()
	check(board_client.careerBoard.slots.is_empty(), "Slot älter als 30 Monate verfällt still")

	# 35. Save/Load-Roundtrip: Coverage & Karrierebrett
	Coverage._issue_coverage()
	Game.board_slot_add(int(board_client.id), "comedy", "lead", 1)
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Bewertungs-Spielstand geladen")
	check(Game.state.has("coverage") and Game.state.coverage.has("history") and Game.state.has("coverageQueue"), "Coverage-Struktur migriert")
	check(Game.state.coverage.current != null and int(Game.state.coverage.current.castingRef) > 0, "Aktuelles Blatt überlebt Save/Load")
	check(Game.state.clients[0].careerBoard.slots.size() == 1, "Karrierebrett-Slots überleben Save/Load")
	check(int(Game.state.clients[0].careerBoard.completed) == 2, "Brett-Abschlüsse überleben Save/Load")

	# 36. Das entscheidende Vorsprechen: Profil, Hinweis, Sieg, Rückweg, Save/Load
	Game.new_game("Bühnenagentur", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":"lead12"})
	var aud_client: Dictionary = Game.state.clients[0]
	var aud_casting: Dictionary = Game.state.castings[0]
	var aud_role: Dictionary = aud_casting.roles[0]
	var aud_role_idx := 0
	for ari in aud_casting.roles.size():
		if str(aud_casting.roles[ari].gender) == "f":
			aud_role_idx = ari
			aud_role = aud_casting.roles[ari]
			break
	aud_casting.prestige = 3
	aud_role.type = "lead"
	aud_role.gender = "f"
	aud_role.minFame = 10
	aud_role.ageMin = 18
	aud_role.ageMax = 70
	var aud_director := Game._director_name_for(aud_casting)
	var profile_a := Game.audition_profile(aud_director, str(aud_casting.title))
	var profile_b := Game.audition_profile(aud_director, str(aud_casting.title))
	check(profile_a == profile_b and profile_a.size() == 4, "Regisseur-Profil ist deterministisch und vierdimensional")
	Game.grant_favor("scriptAccess", {"type":"regisseur", "name":aud_director}, true)
	check(bool(Game.begin_audition(int(aud_casting.id), aud_role_idx, int(aud_client.id)).ok), "Vorsprechen für Prestige-Hauptrolle gestartet")
	var revealed_hint: Dictionary = Game.audition_reveal_script()
	check(not revealed_hint.is_empty() and str(revealed_hint.value) == str(profile_a[revealed_hint.dim]), "Aufgedeckter Hinweis stimmt mit dem Regisseur-Profil überein")
	Game.audition_begin_choices()
	for adi in Game.AUDITION_DIMS.size():
		var dim_s: String = str(Game.AUDITION_DIMS[adi])
		Game.audition_choose(dim_s, str(profile_a[dim_s]), adi < 2)
	var aud_win := Game.resolve_audition("win")
	check(str(aud_win.outcome) == "win" and aud_role.filled != null and int(aud_role.filled.clientId) == int(aud_client.id), "Vorsprechen-Sieg besetzt die Rolle")
	check(bool(aud_client.promises[0].fulfilled), "Vorsprechen-Sieg läuft durch check_promises_on_deal")
	check(int(Game.chemistry("dir:" + aud_director, str(aud_client.aid)).personal) >= -8, "Regisseur-Chemie erhält den +2-Gedächtniseffekt")

	# Klare Niederlage: Rolle bleibt offen, Werte bleiben unverändert, normaler Pitch bleibt möglich.
	Game.new_game("Zweiter Take", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var loss_client: Dictionary = Game.state.clients[0]
	var loss_casting: Dictionary = Game.state.castings[0]
	var loss_idx := 0
	for lri in loss_casting.roles.size():
		if str(loss_casting.roles[lri].gender) == "f":
			loss_idx = lri
			break
	var loss_role: Dictionary = loss_casting.roles[loss_idx]
	loss_casting.prestige = 3
	loss_role.type = "lead"
	loss_role.gender = "f"
	loss_role.minFame = 10
	loss_role.ageMin = 18
	loss_role.ageMax = 70
	var fame_before_loss := float(loss_client.fame)
	var dna_before_loss: Dictionary = loss_client.dna.duplicate(true)
	Game.begin_audition(int(loss_casting.id), loss_idx, int(loss_client.id))
	Game.audition_begin_choices()
	for dim_v in Game.AUDITION_DIMS:
		Game.audition_choose(str(dim_v), str(Game.AUDITION_OPTIONS[str(dim_v)][0]), false)
	var aud_loss := Game.resolve_audition("clear")
	check(str(aud_loss.outcome) == "clear" and loss_role.filled == null and Game.audition_available(loss_casting, loss_role), "Niederlage lässt den normalen Casting-Rückweg offen")
	check(absf(float(loss_client.fame) - fame_before_loss) < 0.01 and loss_client.dna == dna_before_loss, "Niederlage verursacht keinen dauerhaften Karriere- oder DNA-Schaden")
	check(loss_client.flags.get("auditionSetbacks", {}).has(str(aud_loss.director)), "Nur ein einmaliger Regisseur-Malus wird vorgemerkt")
	# Laufendes Vorsprechen und kompaktes Regisseur-Gedächtnis überleben JSON.
	Game.begin_audition(int(loss_casting.id), loss_idx, int(loss_client.id))
	Game.audition_begin_choices()
	Game.audition_choose("scene", "quiet", true)
	var saved_audition: Dictionary = Game.state.audition.duplicate(true)
	var saved_director := str(aud_loss.director)
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Bühnen-Spielstand geladen")
	check(Game.state.audition != null and int(Game.state.audition.castingId) == int(saved_audition.castingId) and Game.state.audition.choices.has("scene"), "state.audition überlebt Save/Load")
	check(Game.state.directors.has(saved_director) and Game.state.directors[saved_director].get("liked", []).size() == 4, "Regisseur-Gedächtnis überlebt Save/Load")

	# 37. Chemistry Read: Rangfolge, indirekte Signale, Package und Fremdbesetzungs-Rückweg
	Game.new_game("Chemieagentur", 1950)
	Game.state.agency.rep = 100
	for chem_aid in ["monroe", "gkelly", "brando"]:
		Game.start_negotiation(chem_aid)
		Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var chem_casting: Dictionary = Game.state.castings[0]
	chem_casting.roles[0].type = "lead"
	chem_casting.roles[0].gender = "f"
	chem_casting.roles[0].minFame = 10
	chem_casting.roles[0].ageMin = 18
	chem_casting.roles[0].ageMax = 70
	chem_casting.roles[1].type = "lead"
	chem_casting.roles[1].gender = "m"
	chem_casting.roles[1].minFame = 10
	chem_casting.roles[1].ageMin = 18
	chem_casting.roles[1].ageMax = 70
	var chem_pairs := Game.chem_read_candidate_pairs(int(chem_casting.id))
	check(chem_pairs.size() >= 2, "Zwei eigene Kandidaten-Paarungen für den Chemistry Read verfügbar")
	var selected_keys := [str(chem_pairs[0].key), str(chem_pairs[1].key)]
	var chem_begin := Game.begin_chem_read(int(chem_casting.id), selected_keys, "love")
	check(bool(chem_begin.ok) and chem_begin.pairs.size() >= 3, "Chemistry Read ergänzt den Studio-NPC-Vorschlag")
	var chem_ranked: Array = Game.chem_read.pairs.duplicate()
	chem_ranked.sort_custom(func(a, b): return float(a.score) > float(b.score))
	var best_key := str(chem_ranked[0].key)
	var best_result := Game.resolve_chem_read(best_key)
	check(str(best_result.outcome) == "best" and chem_casting.roles[0].filled != null and chem_casting.roles[1].filled != null, "Beste Paarung gewinnt bei festem deterministischem Seed")
	check(chem_casting.get("signals", []).any(func(s): return str(s.t) == "The chemistry is right"), "Beste Paarung merkt das Set-Signal „Die Chemie stimmt“ vor")
	var pos_signal := Game.chemistry_signal(7, false, "test_pos")
	var neg_signal := Game.chemistry_signal(-7, false, "test_neg")
	check(int(pos_signal.sign) > 0 and (str(pos_signal.text).contains("finish each other") or str(pos_signal.text).contains("beat")), "Positive Signal-Prosa passt zum Vorzeichen des screen-Werts")
	check(int(neg_signal.sign) < 0 and (str(neg_signal.text).contains("avoids") or str(neg_signal.text).contains("distance")), "Negative Signal-Prosa passt zum Vorzeichen des screen-Werts")

	# Schlechteste Wahl: neuer Castinglauf, mindestens ein eigener Name bleibt sicher drin.
	Game.new_game("Chemie-Rückweg", 1950)
	Game.state.agency.rep = 100
	for chem_aid2 in ["monroe", "gkelly", "brando"]:
		Game.start_negotiation(chem_aid2)
		Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var worst_casting: Dictionary = Game.state.castings[0]
	worst_casting.roles[0].type = "lead"
	worst_casting.roles[0].gender = "f"
	worst_casting.roles[0].minFame = 10
	worst_casting.roles[0].ageMin = 18
	worst_casting.roles[0].ageMax = 70
	worst_casting.roles[1].type = "lead"
	worst_casting.roles[1].gender = "m"
	worst_casting.roles[1].minFame = 10
	worst_casting.roles[1].ageMin = 18
	worst_casting.roles[1].ageMax = 70
	var worst_pairs := Game.chem_read_candidate_pairs(int(worst_casting.id))
	Game.begin_chem_read(int(worst_casting.id), [str(worst_pairs[0].key), str(worst_pairs[1].key)], "comedy")
	var worst_ranked: Array = Game.chem_read.pairs.duplicate()
	worst_ranked.sort_custom(func(a, b): return float(a.score) > float(b.score))
	var worst_result := Game.resolve_chem_read(str(worst_ranked[-1].key))
	var own_filled: int = worst_casting.roles.slice(0, 2).filter(func(r): return r.filled != null and r.filled.get("clientId") != null).size()
	check(str(worst_result.outcome) == "worst" and bool(worst_result.ownRetained) and own_filled >= 1, "Fremdbesetzungs-Pfad lässt mindestens einen eigenen Klienten in der Rolle")
	check(Game.state.history_pairs.size() >= 1, "Chemistry-Read-Ergebnis schreibt die Paarhistorie fort")

	# =====================================================================
	# Gewichtsdynamik: Drift, Clamp, Planer, Events und Alt-Save-Migration
	# =====================================================================
	Game.new_game("Gewichts-Test", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
	var weight_client: Dictionary = Game.state.clients[0]
	var weight_base := Game.client_base_weight(weight_client)
	var weight_before_drift := float(weight_client.weightKg)
	for weight_week in 4:
		Game.end_week()
	var drift_amount := absf(float(weight_client.weightKg) - weight_before_drift)
	check(drift_amount >= 0.09 and drift_amount <= 0.41, "Monatliche Gewichtstrift nach vier Wochen bleibt plausibel (%0.2f kg)" % drift_amount)
	weight_client.weightKg = weight_base
	EvEngine.apply_effects([{"op": "weight", "amount": 2.0}], {"cid": int(weight_client.id)})
	check(absf(float(weight_client.weightKg) - (weight_base + 2.0)) < 0.01, "EventEngine: weight-Op verändert das Klientengewicht")
	EvEngine.apply_effects([{"op": "weight", "amount": 1000.0}], {"cid": int(weight_client.id)})
	check(absf(float(weight_client.weightKg) - weight_base * 1.25) < 0.01, "Gewichts-Clamp greift bei +25 % des Basiswerts")
	weight_client.weightKg = weight_base + 5.0
	var weight_before_training := float(weight_client.weightKg)
	Planner._planner_client_week(weight_client, {"training": 4})
	check(float(weight_client.weightKg) < weight_before_training and absf(float(weight_client.weightKg) - (weight_before_training - 0.20)) < 0.01, "Training zieht das Gewicht Richtung Basiswert")
	weight_client.weightKg = weight_base + 8.1
	check(EvEngine.check_conditions({"requires_client": {"weight_dev_min": 8}}), "weight_dev_min findet deutlich abweichenden Klienten")
	weight_client.weightKg = weight_base + 7.9
	check(not EvEngine.check_conditions({"requires_client": {"weight_dev_min": 8}}), "weight_dev_min sperrt bei zu kleiner Abweichung")
	check(not EvEngine.def_by_id("rollen_transformation").is_empty() and not EvEngine.def_by_id("boulevard_figur").is_empty(), "Körper-Ereignisse aus koerper.json geladen")
	check(not EvEngine.all_events().any(func(weight_ev): return str(weight_ev.id).begins_with("rollen_transformation_")), "Transformations-Folgeglieder bleiben aus dem Zufallspool")
	weight_client.weightKg = weight_base + 3.25
	weight_client.weightTrend = 0.25
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Gewichts-Spielstand geladen")
	var loaded_weight_client: Dictionary = Game.state.clients[0]
	check(absf(float(loaded_weight_client.weightKg) - (weight_base + 3.25)) < 0.01 and absf(float(loaded_weight_client.weightTrend) - 0.25) < 0.01, "weightKg und weightTrend überleben Save/Load")
	loaded_weight_client.erase("weightKg")
	loaded_weight_client.erase("weightTrend")
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Alt-Spielstand ohne Gewichtsfelder geladen")
	loaded_weight_client = Game.state.clients[0]
	check(absf(float(loaded_weight_client.weightKg) - weight_base) < 0.01 and absf(float(loaded_weight_client.weightTrend)) < 0.01, "Migration ergänzt Gewichtsfelder aus dem Basiswert")

	# =====================================================================
	# Wochenrhythmus: 4 Wochen = 1 Monat, Fixkosten nur beim Monatsabschluss
	# =====================================================================
	Game.new_game("Wochen-Test", 1950)
	Jukebox._current_key = Jukebox.key_for_year(1950)
	var wt_month := int(Game.state.month)
	var wt_cash: float = Game.state.agency.cash
	Game.end_week()
	check(int(Game.state.week) == 2 and int(Game.state.month) == wt_month, "Woche 1 → 2, Monat unverändert")
	Game.end_week()
	Game.end_week()
	check(Game.state.agency.cash == wt_cash, "Wochen 1–3 buchen keine Fixkosten")
	Game.end_week()
	check(int(Game.state.month) == wt_month + 1 and int(Game.state.week) == 1, "Nach 4 Wochen: Monatswechsel")
	check(Game.state.agency.cash < wt_cash, "Monatsabschluss bucht Bürokosten")
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
	var wt_c: Dictionary = Game.state.clients[0]
	Game.quick_production(wt_c, {"genre": "drama", "prestige": 1})
	var wt_prod: Dictionary = Game.state.productions[-1]
	wt_prod.weeksLeft = 2
	# Ein zufällig gefeuertes Streik-Event würde den Countdown anhalten —
	# für den Takt-Test wird der Arbeitsfrieden erzwungen.
	Game.state.strikeMonths = 0
	Game.end_week()
	check(int(wt_prod.weeksLeft) == 1, "Produktion zählt in Wochen herunter")
	var wt_rel: int = Game.state.released.size()
	Game.state.strikeMonths = 0
	Game.end_week()
	check(Game.state.released.size() == wt_rel + 1, "Release nach Ablauf der Wochen")

	# =====================================================================
	# Save-Migration v1 → v2 (Monats- auf Wochenrhythmus)
	# =====================================================================
	Game.new_game("Migrationstest", 1950)
	Game.state.erase("saveVersion")
	Game.state.erase("week")
	Game.state.planner = {"player": [null, {"a": "scouting"}, null, null], "clients": {}}
	Game.state.productions.append({"id": 999, "studioId": "mgm", "title": "Altfilm", "genre": "drama",
		"prestige": 1, "budget": 1000, "monthsLeft": 3, "qualityMod": 0.0, "roles": []})
	Game.state.castings[0]["deadline"] = 2
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "v1-Spielstand geladen")
	check(int(Game.state.saveVersion) == 2 and int(Game.state.week) == 1, "Migration setzt saveVersion 2 + Woche 1")
	var mig_prod: Dictionary = Game.state.productions[-1]
	check(int(mig_prod.get("weeksLeft", -1)) == 12 and not mig_prod.has("monthsLeft"), "Produktion: monthsLeft 3 → weeksLeft 12")
	check(int(Game.state.castings[0].deadline) == 8, "Casting-Deadline auf Wochen umgestellt (2 → 8)")
	Planner.ensure_planner()
	check(Game.state.planner.player.size() == 21, "Planer auf 21 Slots erweitert")

	# =====================================================================
	# Save-Migration: Alt-Save-Fixture (Chunk 04) — echtes v1-JSON von Platte
	# =====================================================================
	var fixture_f := FileAccess.open("res://tests/fixtures/save_v1.json", FileAccess.READ)
	check(fixture_f != null, "Alt-Save-Fixture vorhanden (tests/fixtures/save_v1.json)")
	var fixture_text := fixture_f.get_as_text()
	fixture_f.close()
	var fixture_save := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	fixture_save.store_string(fixture_text)
	fixture_save.close()
	Game.state = null
	check(Game.load_game(), "Alt-Save-Fixture (v1, ohne saveVersion) geladen")
	check(int(Game.state.saveVersion) == Game.SAVE_VERSION, "Fixture auf aktuelle Save-Version migriert")
	var fx_c: Dictionary = Game.state.clients[0]
	check(fx_c.has("dna") and fx_c.has("trust") and float(fx_c.weightKg) > 0.0, "Fixture-Klient: DNA, Vertrauen & Gewicht nachgerüstet")
	check(int(Game.state.productions[0].weeksLeft) == 12 and not Game.state.productions[0].has("monthsLeft"), "Fixture-Produktion: monthsLeft 3 → weeksLeft 12")
	check(int(Game.state.castings[0].deadline) == 8, "Fixture-Casting: Deadline auf Wochen umgestellt")
	Game.state.strikeMonths = 0
	Game.end_week()
	check(int(Game.state.week) == 2 and not Game.state.over, "Fixture-Stand ist bespielbar (end_week läuft durch)")

	# Korrupter Save: abweisen, Grund nennen, Backup anlegen — nie überschreiben
	if FileAccess.file_exists(Game.SAVE_BACKUP_PATH):
		DirAccess.remove_absolute(Game.SAVE_BACKUP_PATH)
	var corrupt_f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	corrupt_f.store_string("{ kaputt und kein JSON")
	corrupt_f.close()
	check(not Game.load_game(), "Korrupter Save wird abgewiesen statt zu crashen")
	check(Game.load_error != "", "Ladefehler nennt einen Grund für die UI")
	check(FileAccess.file_exists(Game.SAVE_BACKUP_PATH), "Korrupter Save wurde als hm_save.bak.json gesichert")

	# Save aus einer neueren Spielversion: abweisen + Backup
	var newer_f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	newer_f.store_string(JSON.stringify({"saveVersion": Game.SAVE_VERSION + 1}))
	newer_f.close()
	check(not Game.load_game(), "Save aus neuerer Version wird abgewiesen")
	check(Game.load_error.contains("newer"), "Fehlertext benennt die neuere Version")
	# Aufräumen: definierten Spielstand für die folgenden Tests herstellen
	Game.new_game("Nach Fixture", 1950)
	Game.save_game()

	# =====================================================================
	# DataLoader: Merge/Override/Anreicherung, Overlay unter user://data
	# =====================================================================
	DirAccess.make_dir_recursive_absolute("user://data/actors")
	var dl_f1 := FileAccess.open("user://data/actors/zz_test_a.json", FileAccess.WRITE)
	dl_f1.store_string(JSON.stringify([
		{"id": "testling", "name": "Testa Testling", "birth": 1900, "g": "f", "debut": 1920, "talent": 50, "peak": 1930, "peakFame": 60},
		{"id": "kaputt"}
	]))
	dl_f1.close()
	var dl_f2 := FileAccess.open("user://data/actors/zz_test_b.json", FileAccess.WRITE)
	dl_f2.store_string(JSON.stringify([{"id": "testling", "talent": 77, "films": [{"title": "Testfilm", "year": 1925}]}]))
	dl_f2.close()
	var dl_loaded := DataLoader.load_entries("actors", ["id"],
		{"death": null, "films": [], "ethnicity": "white", "genres": [], "ego": 50, "height_cm": 0, "weight_kg": 0},
		["id", "name", "birth", "g", "debut", "talent", "peak", "peakFame"])
	var dl_testling = null
	for dl_a in dl_loaded:
		if str(dl_a.id) == "testling":
			dl_testling = dl_a
	check(dl_testling != null, "DataLoader: Overlay-Eintrag aus user://data geladen")
	check(dl_testling != null and int(dl_testling.talent) == 77, "DataLoader: spätere Datei überschreibt Felder (talent 50→77)")
	check(dl_testling != null and dl_testling.films.size() == 1, "DataLoader: Anreicherung ergänzt Felder (films)")
	check(dl_testling != null and str(dl_testling.ethnicity) == "white" and dl_testling.death == null, "DataLoader: Schema-Defaults gesetzt")
	check(not dl_loaded.any(func(dl_x): return str(dl_x.get("id", "")) == "kaputt"), "DataLoader: Eintrag ohne Pflichtfelder übersprungen")
	check(dl_loaded.any(func(dl_x): return str(dl_x.id) == "bogart" and dl_x.films.size() >= 3), "DataLoader: Filmografie-Paket an Bogart gemergt")
	check(dl_loaded.any(func(dl_x): return str(dl_x.id) == "poitier" and str(dl_x.ethnicity) == "black"), "DataLoader: Ethnie-Paket gemergt")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://data/actors/zz_test_a.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://data/actors/zz_test_b.json"))

	# =====================================================================
	# EventEngine: Bedingungen, Platzhalter, Effekte, Kette
	# =====================================================================
	Game.new_game("Event-Test", 1950)
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
	var ee_c = Game.state.clients[0]
	check(EvEngine.all_events().size() >= 3, "EvEngine: JSON-Events geladen (%d, ohne followup_only)" % EvEngine.all_events().size())
	check(not EvEngine.all_events().any(func(ee_x): return str(ee_x.id) == "steuer_nachspiel"), "EvEngine: Kettenglied bleibt aus dem Zufallspool")
	check(EvEngine.check_conditions({"min_year": 1940, "max_year": 1960, "min_rep": 50}), "EvEngine: Jahresfenster + min_rep erfüllt")
	check(not EvEngine.check_conditions({"min_year": 1980}), "EvEngine: min_year sperrt")
	check(not EvEngine.check_conditions({"backstory": "anwalt"}), "EvEngine: Backstory-Bedingung sperrt ohne Backstory")
	var ee_built = EvEngine.build_event(EvEngine.def_by_id("press"))
	check(ee_built != null and str(ee_built.text).contains(Game.client_name(ee_c)), "EvEngine: {client}-Platzhalter ersetzt")
	var ee_cash: float = Game.state.agency.cash
	EvEngine.apply_effects([
		{"op": "money", "amount": -1000, "cat": "pr_recht", "label": "Test"},
		{"op": "rep", "amount": -5},
		{"op": "fame", "amount": 3}
	], {"cid": int(ee_c.id)})
	check(Game.state.agency.cash == ee_cash - 1000, "EvEngine: money-Effekt bucht ins Ledger")
	check(int(Game.state.agency.rep) == 95, "EvEngine: rep-Effekt angewendet")
	EvEngine.apply_effects([
		{"op": "favor_grant", "kind": "suppressStory"},
		{"op": "followup", "event": "steuer_nachspiel", "delay_weeks": 4}
	], {"cid": int(ee_c.id)})
	check(Game.has_favor("suppressStory"), "EvEngine: favor_grant delegiert an Game")
	var ee_fu: Dictionary = Game.state.followups[-1]
	check(str(ee_fu.type) == "json" and int(ee_fu.due) == Game.mi() + 1, "EvEngine: Kette terminiert (4 Wochen ⇒ +1 Monat)")
	var ee_chain = EvEngine.build_by_id(str(ee_fu.event), ee_fu.ctx)
	check(ee_chain != null and str(ee_chain.title) == "The audit spreads", "EvEngine: Kettenglied per id+ctx gebaut")
	var ee_fail := {"success_chance": 0.0, "effects": [{"op": "rep", "amount": 5}],
		"effects_fail": [{"op": "rep", "amount": -1}], "outcome": "gut", "outcome_fail": "schlecht"}
	var ee_out: String = EvEngine._choice_fn(ee_fail, {}).call()
	check(ee_out == "schlecht" and int(Game.state.agency.rep) == 94, "EvEngine: success_chance 0 nimmt den Fail-Pfad")

	# =====================================================================
	# Backstories: Startmodifikatoren, Hooks, exklusive Eventketten
	# =====================================================================
	Game.new_game("Neutral", 1950)
	var bs_rr_base := Game.required_rep(80.0)
	var bs_cash_base: float = Game.state.agency.cash
	var bs_ev := EvEngine.def_by_id("aufsteiger_alte_schulden")
	check(not bs_ev.is_empty(), "Backstory-Kette in data/events geladen")
	check(EvEngine.eval_weight(bs_ev) == 0.0, "Backstory-Event bleibt ohne Vorgeschichte gesperrt")
	Game.new_game("Aufstieg GmbH", 1950, "aufsteiger")
	check(Game.has_backstory("aufsteiger"), "Backstory gesetzt")
	check(int(Game.state.agency.rep) == 8, "Aufsteiger: Ruf-Start 15 − 7 = 8")
	check(Game.state.agency.cash > bs_cash_base, "Aufsteiger: Startkapital erhöht")
	check(Game.backstory_mod("office_cost_mult", 1.0) == 0.9, "Aufsteiger: Bürokosten-Trait aktiv")
	check(Game.required_rep(80.0) == bs_rr_base + 5, "Aufsteiger: A-Lister verlangen +5 Ruf")
	check(EvEngine.eval_weight(bs_ev) > 0.0, "Backstory-Event feuert mit passender Vorgeschichte")
	Game.new_game("Kanzlei & Partner", 1950, "anwalt")
	check(int(Game.state.instinct) == 12, "Anwalt: Instinkt-Start 20 − 8")
	check(Game.client_capacity() == 7, "Anwalt: Klienten-Kapazität +1 (dokumentiert, noch kein Limit)")
	Game.new_game("Zweite Chance", 1950, "gescheitert")
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
	var bs_c: Dictionary = Game.state.clients[0]
	var bs_t0: float = bs_c.trust
	Game.change_trust(bs_c, 4.0)
	check(absf(float(bs_c.trust) - (bs_t0 + 5.0)) < 0.01, "Gescheitert: Vertrauensgewinn ×1,25")
	Game.new_game("Federkiel", 1950, "kolumnist")
	var bs_rumor := Scandal.add_rumor("agency", "Testgerücht aus dem Hinterzimmer.", false, "skandal")
	check(bool(bs_rumor.knownToPlayer), "Kolumnist: Neues Gerücht ist sofort bekannt")

	# 22. Spielfigur: getrennte Privat-/Agenturfinanzen, Zustand, Karriere
	Game.new_game("Managertest", 1950)
	var pl: Dictionary = Game.state.player
	check(float(pl.cash) > 0.0, "Spielfigur startet mit privatem Erspartem (%s)" % Util.fmt_money(pl.cash))
	check(int(pl.career) == 0 and str(Persona.career_def().name) == "Junior Agent", "Karriere beginnt als Junior-Agent")
	check(Persona.title() == "No reputation yet", "Ruf-Titel ist anfangs unerspielt")
	var pl_cash0 := float(pl.cash)
	var ag_cash0 := float(Game.state.agency.cash)
	var pl_events: Array = []
	Game.state.week = 4
	Game._month_close(pl_events)
	check(float(pl.cash) != pl_cash0, "Monatsabschluss bucht Gehalt & Lebenshaltung privat")
	var pl_gehalt := float(Persona.salary())
	var pl_leben := float(Persona.living_cost())
	check(pl_gehalt > pl_leben, "Junior-Gehalt liegt über der Lebenshaltung")
	check(float(Game.state.agency.cash) < ag_cash0, "Agentur zahlt das Gehalt (getrennte Kassen)")
	check(pl.ledger.size() >= 3, "Privat-Ledger führt Einzelbuchungen")
	# Aktionen mit Monats-Cooldown
	var pl_energy0 := float(pl.energy)
	Persona.vacation()
	check(float(pl.energy) > pl_energy0, "Auszeit erhöht Energie")
	check(not Persona.can_act("vacation"), "Auszeit nur 1× pro Monat")
	var pl_agency1 := float(Game.state.agency.cash)
	Persona.draw()
	check(absf(float(Game.state.agency.cash) - (pl_agency1 - pl_gehalt)) < 0.01, "Privatentnahme belastet die Agenturkasse")
	var pl_priv1 := float(pl.cash)
	Persona.inject(1000.0)
	check(absf(float(pl.cash) - (pl_priv1 - 1000.0)) < 0.01, "Privateinlage verlässt das Privatkonto")
	# Beförderung, sobald die Bedingungen erfüllt sind
	Game.state.agency.rep = 30
	for i in 3:
		Game.state.released.append({"title": "Testfilm %d" % i})
	var promo_events: Array = []
	Persona._check_promotion(promo_events)
	check(int(pl.career) == 1 and promo_events.size() == 1, "Beförderung zum Etablierten Agenten gefeuert")
	check(Persona.promotion_requirements().any(func(r): return not r.met), "Nächste Stufe (Senior) noch gesperrt")
	# Save-Migration: alte Stände ohne player-Feld bekommen die Spielfigur nachgerüstet
	Game.state.erase("player")
	Persona.ensure_player()
	check(Game.state.has("player") and int(Game.state.player.career) == 1, "ensure_player rüstet nach und leitet Karrierestufe her")

	# 23. Kontakte & Versprechen: Kanäle, Gedächtnis, Kontaktzeit
	Game.new_game("Kontakttest", 1950)
	check(Game.state.contacts.size() >= 5, "Kontaktbuch initialisiert (%d Personen)" % Game.state.contacts.size())
	check(int(Game.state.contactAP) == Persona.AP_PER_WEEK, "Kontaktzeit startet mit %d Punkten" % Persona.AP_PER_WEEK)
	var kt: Dictionary = Game.state.contacts[0]
	var kt_rel0 := float(kt.rel)
	var kt_cash0 := float(Game.state.player.cash)
	var kt_res: Dictionary = Persona.contact_interact(int(kt.id), "meet")
	check(bool(kt_res.ok), "Persönliches Treffen durchgeführt")
	check(int(Game.state.contactAP) == Persona.AP_PER_WEEK - 2, "Treffen kostet 2 Kontaktzeit")
	check(float(Game.state.player.cash) < kt_cash0, "Treffen geht vom Privatkonto ab")
	check(float(kt.rel) > kt_rel0, "Beziehung steigt durch das Treffen")
	check(kt.log.size() >= 1, "Kontakt erinnert sich an die Begegnung")
	var kt_res2: Dictionary = Persona.contact_interact(int(kt.id), "call")
	check(not bool(kt_res2.ok), "Gleiche Woche, gleiche Person: gesperrt")
	var kt2: Dictionary = Game.state.contacts[1]
	Persona.hire_assistant()
	Persona.contact_interact(int(kt2.id), "aide")
	check(kt2.log.any(func(entry): return str(entry.text).contains("assistant")), "Assistenten-Besuch bleibt im Gedächtnis")
	# Versprechen brechen: Frist in die Vergangenheit legen
	Game.state.promises.append({"id": 9999, "to": str(kt.name), "madeMi": Game.mi() - 5, "dueMi": Game.mi() - 1, "text": "Testzusage", "status": "open"})
	var kt_events: Array = []
	Persona._tick_contacts_month(kt_events)
	check(str(Game.state.promises.back().status) == "broken", "Überfällige Zusage gilt als gebrochen")
	# Halten: neues Versprechen, dann Kontaktaufnahme in einer neuen Woche
	Game.state.promises.append({"id": 10000, "to": str(kt2.name), "madeMi": Game.mi(), "dueMi": Game.mi() + 3, "text": "Testzusage 2", "status": "open"})
	Game.state.week = 2
	Game.state.contactAP = 3
	Persona.contact_interact(int(kt2.id), "call")
	check(str(Game.state.promises.back().status) == "kept", "Kontaktaufnahme hält offene Zusage")
	# Verfall bei Vernachlässigung
	var kt3: Dictionary = Game.state.contacts[2]
	var kt3_rel0 := float(kt3.rel)
	kt3.lastMi = Game.mi() - 6
	Persona._tick_contacts_month(kt_events)
	check(float(kt3.rel) < kt3_rel0, "Vernachlässigte Kontakte kühlen ab")
	check(kt3.log.any(func(entry): return str(entry.text).contains("hear from you")), "Warten wird im Gedächtnis vermerkt")
	# Migration alter Stände
	Game.state.erase("contacts")
	Game.state.erase("promises")
	Persona.ensure_contacts()
	check(Game.state.contacts.size() >= 5 and Game.state.promises.is_empty(), "ensure_contacts rüstet alte Stände nach")

	# 24. Orte: Reisen, Anwesenheit, Saison, Ortsaktionen
	Game.new_game("Reisetest", 1950)
	check(Persona.location_id() == "la" and not Persona.is_away(), "Start in Los Angeles")
	check(Persona.travel_blocked_reason("cannes") != "", "Cannes im Januar gesperrt (Saison Mai)")
	var tr_cash0 := float(Game.state.agency.cash)
	check(Persona.travel_to("ny"), "Reise nach New York")
	check(Persona.is_away() and int(Game.state.contactAP) == 0, "Anreise frisst die Kontaktzeit der Woche")
	check(float(Game.state.agency.cash) < tr_cash0, "Agentur zahlt die Reisespesen")
	var tr_kt: Dictionary = Game.state.contacts[0]
	check(not bool(Persona.contact_interact(int(tr_kt.id), "meet").ok), "Treffen aus der Ferne unmöglich")
	Game.state.contactAP = 3  # neue Woche simulieren: Anreise hatte die Kontaktzeit gefressen
	check(Persona.contact_blocked_reason(tr_kt, "call") == "", "Telefonat bleibt aus der Ferne möglich")
	# Abwesenheits-Drift bei Klienten
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
	var tr_c: Dictionary = Game.state.clients[0]
	var tr_trust0 := float(tr_c.trust)
	Persona.tick_week()
	check(float(tr_c.trust) < tr_trust0, "Klienten-Vertrauen sinkt, solange du weg bist")
	# Ortsaktion mit Wochen-Cooldown
	var tr_pub0 := float(Game.state.player.pubRep)
	check(Persona.location_action_available(), "Ortsaktion in New York verfügbar")
	check(Persona.do_location_action() != "", "Pressetermine durchgeführt")
	check(float(Game.state.player.pubRep) > tr_pub0, "Öffentlicher Ruf steigt durch Pressetermine")
	check(not Persona.location_action_available(), "Ortsaktion nur 1× pro Woche")
	# Saison-Auto-Rückreise: Cannes im Mai, Monatswechsel wirft zurück
	Game.state.month = 5
	check(Persona.travel_to("cannes"), "Cannes zur Festivalsaison erreichbar")
	Game.state.month = 6
	Persona._tick_location_month()
	check(Persona.location_id() == "la", "Nach der Saison automatisch zurück in L.A.")
	# Migration alter Stände
	Game.state.player.erase("location")
	Persona.ensure_player()
	check(Persona.location_id() == "la", "ensure_player rüstet den Ort nach")

	# 25. Assistant & delegation (Feature 4)
	Game.new_game("Assistant test", 1950)
	check(not Persona.has_assistant(), "No assistant at the start")
	check(Persona.contact_blocked_reason(Game.state.contacts[0], "aide") != "", "Send-assistant channel blocked without an assistant")
	Persona.hire_assistant()
	check(Persona.has_assistant() and Persona.assistant_wage() > 0.0, "Assistant hired with a wage")
	check(Persona.rule("upkeep") and Persona.rule("briefing"), "Delegation rules on by default")
	check(Persona.contact_blocked_reason(Game.state.contacts[0], "aide") == "", "Send-assistant channel available with an assistant")
	# Upkeep keeps a neglected contact warm
	var as_ct: Dictionary = Game.state.contacts[2]
	as_ct.lastMi = Game.mi() - 3
	var as_rel0 := float(as_ct.rel)
	Game.state.contactAP = 3
	Persona.tick_week()
	check(Game.state.contacts.any(func(ct): return float(ct.rel) > as_rel0 and ct.log.any(func(e): return str(e.text).contains("checked in"))), "Upkeep rule keeps a neglected contact warm")
	# Morning briefing surfaces a due promise
	Game.state.promises.append({"id": 8888, "to": str(Game.state.contacts[0].name), "madeMi": Game.mi(), "dueMi": Game.mi(), "text": "x", "status": "open"})
	var brief: Dictionary = Persona.assistant_briefing()
	check(not brief.is_empty() and str(brief.title).contains("morning note"), "Assistant briefing surfaces open items")
	Persona.fire_assistant()
	check(not Persona.has_assistant(), "Assistant can be let go")

	# =========== Empire-Cluster (Features 5–9) ===========
	# 26. Immobilien & Statuskäufe: Kauf, Unterhalt, Abstiegs-Malus, Effekte
	Game.new_game("Empire AG", 1950)
	var mp: Dictionary = Game.state.player
	mp.cash = 100000.0
	check(Mogul.home_id() == "room", "Start im möblierten Zimmer")
	check(Mogul.buy_home("hills") == "", "Umzug in die Hollywood Hills")
	check(Mogul.upkeep_total() > 0.0, "Lebensstil-Unterhalt fällig: %s/Monat" % Util.fmt_money(Mogul.upkeep_total()))
	check(Mogul.buy_purchase("car") == "", "Automobil & Chauffeur gekauft")
	mp.energy = 50.0
	Mogul.tick_week()
	check(float(mp.energy) > 50.0, "Wagen spart Energie im Wochen-Tick")
	var pub0 := float(mp.pubRep)
	check(Mogul.buy_home("apartment") == "", "Abstieg ins Apartment möglich")
	check(float(mp.pubRep) < pub0, "Abstieg kostet öffentlichen Ruf")
	check(Mogul.purchase_blocked_reason("staff") != "", "Hauspersonal braucht ein größeres Haus")
	check(Mogul.purchase_blocked_reason("jet") != "", "Jet-Anteil 1950 noch nicht verfügbar")
	mp.cash = 300000.0
	check(Mogul.buy_home("beverly") == "", "Villa in Beverly Hills bezogen")
	check(Mogul.host_reception() != "", "Empfang in der Villa ausgerichtet")
	check(not Mogul.can_host(), "Empfang nur 1× pro Monat")
	Mogul.sell_purchase("car")
	check(not Mogul.owns("car"), "Statuskauf wieder verkauft")

	# 27. Erfahrung: Level, Freischaltungen, Ankündigung
	Mogul.grant_xp("negotiation", 25.0, "Test")
	check(Mogul.level("negotiation") >= 2, "XP heben das Level (L%d)" % Mogul.level("negotiation"))
	check(Mogul.has_ability("second_pass"), "Fähigkeit ab Level 2 freigeschaltet")
	check(not Mogul.has_ability("closer"), "Level-4-Fähigkeit bleibt gesperrt")
	check(str(Mogul.next_ability("negotiation").id) == "closer", "Nächste Fähigkeit wird angekündigt")

	# 28. Börse: Ära-Filter, Handel, Tipp-Auflösung, Berater
	Mogul.ensure_prices()
	var sdefs: Array = Mogul.stock_defs()
	check(sdefs.size() >= 5 and sdefs.any(func(s): return str(s.id).begins_with("st_")), "Ticker: Firmen + Studio-Aktien gelistet (%d)" % sdefs.size())
	check(not sdefs.any(func(s): return str(s.id) == "nimbus"), "Streaming 1950 nicht handelbar")
	var sid0 := str(sdefs[0].id)
	var trade_cash0 := float(mp.cash)
	check(Mogul.buy_stock(sid0, 1000.0) == "", "Aktienkauf ausgeführt")
	check(Mogul.shares_of(sid0) > 0 and float(mp.cash) < trade_cash0, "Depot & Privatkonto verbucht")
	var tip: Dictionary = Mogul.add_tip(sid0, 1, 0.15, Game.mi(), "Test", false)
	Mogul._tick_invest_month([])
	check(bool(tip.resolved), "Tipp wird zum Fälligkeitstermin aufgelöst")
	check(Mogul.price(sid0) > 0.0, "Kurs bleibt positiv")
	check(Mogul.sell_stock(sid0) == "", "Position glattgestellt")
	check(Mogul.shares_of(sid0) == 0, "Depot leer nach Verkauf")
	Mogul.hire_advisor()
	check(Mogul.has_advisor() and Mogul.advisor_fee() > 0.0, "Vermögensberater engagiert (Honorar fällig)")

	# 29. Filmbeteiligung: Zeichnung, Interessenkonflikt, Marketing, Auszahlung
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
	var stake_client: Dictionary = Game.state.clients[0]
	var sprod: Dictionary = Game.quick_production(stake_client, {"genre": "drama", "prestige": 2}).prod
	mp.cash = 500000.0
	check(Mogul.invest_stake(int(sprod.id), "equity") == "", "Eigenkapital-Beteiligung gezeichnet")
	check(bool(Mogul.stake_for(int(sprod.id)).conflict), "Eigener Klient im Film ⇒ Interessenkonflikt markiert")
	check(Mogul.boost_marketing(int(sprod.id)) == "", "Marketing-Nachschuss finanziert")
	check(float(sprod.qualityMod) >= 3.0, "Marketing hebt die Qualität")
	Game.state.market = 2.0
	Game.release_film(sprod)
	Game.state.productions.erase(sprod)
	check(mp.ledger.any(func(e): return str(e.text).contains("Film stake payout")), "Beteiligung beim Release privat ausgezahlt")
	check(Mogul.stake_for(int(sprod.id)).is_empty(), "Beteiligung nach Abrechnung abgeräumt")

	# 30. Hinterzimmer: Vorlagen, Abschluss, Boost, Fälligkeit & Wortbruch
	var br_ct = null
	for ct in Game.state.contacts:
		if str(ct.type) == "produzent":
			br_ct = ct
	br_ct.rel = 80.0
	check(Mogul.deals_for_contact(br_ct).size() >= 2, "Deal-Vorlagen für Produzenten verfügbar")
	var def_ns: Dictionary = Mogul.deal_def("newcomer_star")
	check(Mogul._accept_deal(br_ct, def_ns).contains("Handshake"), "Absprache im Hinterzimmer geschlossen")
	var br_rec: Dictionary = Game.state.backroom.back()
	check(str(br_rec.status) == "open" and int(br_rec.dueMi) > Game.mi(), "Register: offen mit Fälligkeitsdatum")
	var br_mods: Dictionary = Mogul.pitch_mods({"id": 999999, "studioId": str(Game.active_studios()[0].id)})
	check(float(br_mods.bonus) >= 0.15, "Pitch-Boost aus der Absprache aktiv")
	var ob_ev: Dictionary = Mogul._obligation_event(br_rec, def_ns)
	check(ob_ev.choices.size() == 2, "Fällige Absprache bietet Ehren oder Brechen")
	var rel_before_break := float(br_ct.rel)
	ob_ev.choices[1].fn.call()
	check(str(br_rec.status) == "broken" and float(br_ct.rel) < rel_before_break, "Wortbruch kostet Beziehung")
	mp.cash = 500000.0
	Mogul._accept_deal(br_ct, Mogul.deal_def("finance_casting"))
	var br_mods2: Dictionary = Mogul.pitch_mods({"id": 999998, "studioId": str(Game.active_studios()[0].id)})
	check(bool(br_mods2.golden), "Goldene Zusage: der nächste Pitch sitzt")
	check(str(Game.state.backroom.back().status) == "honored", "Goldene Zusage verbraucht sich beim Einsatz")

	# 31. Endgame: Partner-Einkauf, Gewinnanteil, Übernahme, Studio-Anteil
	mp.career = 3
	var eg_events: Array = []
	Mogul.on_promotion(eg_events)
	check(eg_events.size() == 1 and str(eg_events[0].title).contains("buy-in"), "Partner-Einkauf wird angeboten")
	mp.cash = 500000.0
	eg_events[0].choices[0].fn.call()
	check(Mogul.is_partner(), "Buy-in macht zum Namenspartner")
	Game.book(10000.0, "sonstiges", "Testgewinn")
	var pcash0 := float(mp.cash)
	Mogul._tick_endgame_month()
	check(float(mp.cash) > pcash0, "Partner-Gewinnanteil fließt aufs Privatkonto")
	mp.career = 4
	var rv_n: int = Game.state.rivals.size()
	mp.cash = 1000000.0
	check(Mogul.takeover(str(Game.state.rivals[0].id)) == "", "Rivalen-Agentur übernommen")
	check(Game.state.rivals.size() == rv_n - 1, "Rivale verschwindet vom Markt")
	mp.career = 5
	var sid_st := str(Game.active_studios()[0].id)
	check(Mogul.buy_studio_stake(sid_st) == "", "Studio-Anteil gekauft")
	check(int(Game.state.studioRel[sid_st]) >= 75, "Studio-Türen stehen dauerhaft offen")

	# 32. Save/Load-Roundtrip & Migration des Empire-Clusters
	var skills_xp := float(Game.state.skills.xp.get("negotiation", 0.0))
	var backroom_n: int = Game.state.backroom.size()
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Empire-Spielstand geladen")
	check(absf(float(Game.state.skills.xp.get("negotiation", 0.0)) - skills_xp) < 0.01, "Skill-XP überleben Save/Load")
	check(str(Game.state.estate.home) == "beverly", "Immobilie überlebt Save/Load")
	check(Game.state.backroom.size() == backroom_n, "Hinterzimmer-Register überlebt Save/Load")
	check(float(Game.state.endgame.partnerShare) > 0.0 and Game.state.endgame.studioStakes.size() == 1, "Endgame-Felder überleben Save/Load")
	check(Game.state.invest.advisor != null, "Vermögensberater überlebt Save/Load")
	Game.state.erase("skills")
	Game.state.erase("estate")
	Game.state.erase("invest")
	Game.state.erase("filmStakes")
	Game.state.erase("backroom")
	Game.state.erase("endgame")
	Mogul.ensure_all()
	check(Game.state.has("skills") and Game.state.has("estate") and Game.state.has("invest") and Game.state.has("backroom") and Game.state.has("endgame"), "ensure_all rüstet alte Stände nach")

	# =========== Netzwerk-Cluster (Features 10–15) ===========
	# 33. Mehrdimensionale Beziehungen, Netz & Spillover
	Game.new_game("Netzwerk AG", 1950)
	var nw_ct: Dictionary = Game.state.contacts[0]
	check(nw_ct.has("dims") and nw_ct.dims.size() == 6, "Kontakte starten mit 6 Beziehungsdimensionen")
	check(nw_ct.get("links", []).size() >= 1, "Kontaktnetz: Verbindungen gewoben")
	var close0 := Network.dim(nw_ct, "closeness")
	var trust0n := Network.dim(nw_ct, "trust")
	Network.apply_channel(nw_ct, "meet", 6.0)
	check(Network.dim(nw_ct, "closeness") > close0 and Network.dim(nw_ct, "trust") > trust0n, "Dinner baut Nähe und Vertrauen")
	var irr0 := Network.dim(nw_ct, "irritation")
	Network.apply_channel(nw_ct, "call", -2.0)
	check(Network.dim(nw_ct, "irritation") > irr0, "Fauxpas erzeugt Verärgerung")
	check(absf(float(nw_ct.rel) - Network.derived_rel(nw_ct)) < 0.01, "rel ist der abgeleitete Kompositwert")
	var linked := Network.contact_by_name(str(nw_ct.links[0].to))
	var linked_liking := Network.dim(linked, "liking")
	Network.adjust(nw_ct, {"liking": 10.0})
	check(Network.dim(linked, "liking") > linked_liking, "Sympathie strahlt auf Verbundene aus")
	nw_ct.erase("dims")
	nw_ct.erase("circles")
	Network.ensure_network()
	check(nw_ct.has("dims") and nw_ct.circles.size() >= 1, "ensure_network rüstet alte Kontakte nach")

	# 34. Gatekeeper: das Vorzimmer blockiert, Charme öffnet
	var vip_ct = null
	for ct in Game.state.contacts:
		if str(ct.type) == "studio":
			vip_ct = ct
	check(vip_ct != null and Network.is_vip(vip_ct) and not Network.gate_of(vip_ct).is_empty(), "Studioboss ist VIP mit Vorzimmer")
	vip_ct.gate.rel = 10.0
	vip_ct.dims.closeness = 10.0
	vip_ct.rel = Network.derived_rel(vip_ct)
	check(Persona.contact_blocked_reason(vip_ct, "meet") != "", "Vorzimmer blockiert Treffen & Clubabend")
	Game.state.player.cash = 10000.0
	var charm := Network.charm_gate(int(vip_ct.id))
	check(bool(charm.ok) and float(vip_ct.gate.rel) > 10.0, "Charme hebt die Vorzimmer-Gunst")
	check(not bool(Network.charm_gate(int(vip_ct.id)).ok), "Vorzimmer-Pflege nur 1× pro Woche")
	vip_ct.gate.rel = 80.0
	Game.state.contactAP = 3
	check(Persona.contact_blocked_reason(vip_ct, "meet") == "", "Gewonnenes Vorzimmer lässt durch")

	# 35. Vorstellungen, Marker & Glaubwürdigkeit (Soziales Kapital)
	check(Network.notables_unmet().size() >= 4, "Bedeutende Personen warten außerhalb des Zirkels")
	var intro_ct: Dictionary = Game.state.contacts[0]
	intro_ct.dims.liking = 70.0
	intro_ct.dims.trust = 60.0
	intro_ct.rel = Network.derived_rel(intro_ct)
	var hostess_def = null
	for nb in Network.notables_unmet():
		if str(nb.type) == "gastgeberin":
			hostess_def = nb
	check(hostess_def != null and Network.introducers_for(hostess_def).size() >= 1, "Gemeinsamer Bekannter kann vorstellen")
	var contacts_n: int = Game.state.contacts.size()
	Game.state.contactAP = 3
	var intro_res := Network.introduce(str(hostess_def.name), int(intro_ct.id))
	check(bool(intro_res.ok) and Game.state.contacts.size() == contacts_n + 1, "Vorstellung fügt neuen Kontakt hinzu")
	check(Game.state.memoirs.any(func(m): return m.get("people", []).has(str(hostess_def.name))), "Vorstellung landet im Karrieregedächtnis")
	intro_ct.dims.dependence = 60.0
	var marker_favors: int = Game.state.favors.size()
	var marker_res := Network.call_marker(int(intro_ct.id))
	check(bool(marker_res.ok) and Game.state.favors.size() == marker_favors + 1, "Marker eingelöst: konkreter Gefallen")
	check(Network.dim(intro_ct, "dependence") < 60.0, "Marker verbraucht Hebel")
	vip_ct.dims.respect = 80.0
	var vip_sid := ""
	for s in Data.STUDIOS:
		if str(vip_ct.name).contains(str(s.name)):
			vip_sid = str(s.id)
	check(vip_sid != "" and Network.pitch_bonus({"studioId": vip_sid}) > 0.0, "Respektierter Studio-Kontakt öffnet Ohren (Pitch-Bonus)")

	# 36. Karrieregedächtnis: automatische Erfassung & Save/Load
	var mem_n: int = Game.state.memoirs.size()
	Game.log_msg("Ein denkwürdiger Testmoment.", "history")
	check(Game.state.memoirs.size() == mem_n + 1, "History-Ereignisse landen automatisch im Memoir")
	Game.log_msg("Alltagsnotiz.", "info")
	check(Game.state.memoirs.size() == mem_n + 1, "Alltag bleibt aus dem Memoir draußen")
	var liking_saved := float(intro_ct.dims.liking)
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Netzwerk-Spielstand geladen")
	check(Game.state.memoirs.size() == mem_n + 1, "Memoir überlebt Save/Load")
	check(absf(float(Game.state.contacts[0].dims.liking) - liking_saved) < 0.01, "Beziehungsdimensionen überleben Save/Load")
	check(Game.state.contacts.any(func(ct): return not Network.gate_of(ct).is_empty()), "Gatekeeper überleben Save/Load")

	# =========== Netzwerkdynamik (Features 16–22) ===========
	# 37. Kontaktpflege: Anlässe beantworten oder verpassen
	Game.new_game("Pflege AG", 1950)
	Game.state.player.cash = 5000.0
	var oc_ct: Dictionary = Game.state.contacts[0]
	Game.state.occasions.append({"id": 90001, "ctName": str(oc_ct.name), "kind": "crisis", "madeMi": Game.mi(), "dueMi": Game.mi() + 2, "status": "open"})
	var oc_trust0 := Network.dim(oc_ct, "trust")
	Game.state.contactAP = 3
	var oc_res := Network.occasion_respond(90001)
	check(bool(oc_res.ok) and Network.dim(oc_ct, "trust") > oc_trust0, "Persönliche Hilfe im Anlass baut Vertrauen")
	check(Network.opinion_score(oc_ct) > 0.0, "Hilfe wird Teil ihres Bildes von dir (Fakt)")
	var oc_ct2: Dictionary = Game.state.contacts[1]
	Game.state.occasions.append({"id": 90002, "ctName": str(oc_ct2.name), "kind": "callback", "madeMi": Game.mi() - 3, "dueMi": Game.mi() - 1, "status": "open"})
	var oc_irr0 := Network.dim(oc_ct2, "irritation")
	Network._tick_occasions()
	check(Network.dim(oc_ct2, "irritation") > oc_irr0, "Verpasster Rückruf erzeugt Verärgerung")
	check(Game.state.occasions.any(func(o): return int(o.id) == 90002 and str(o.status) == "missed"), "Anlass als verpasst registriert")

	# 38. Berufsspezifische Information & Wissensfluss
	var press_ct = null
	for ct in Game.state.contacts:
		if str(ct.type) == "journalist":
			press_ct = ct
	press_ct.dims.trust = 75.0
	press_ct.rel = Network.derived_rel(press_ct)
	var info_rumor := Scandal.add_rumor(str(Game.available_actors()[0].id), "Ein Name macht in den Vorzimmern die Runde.", false, "skandal", ["Assistants"], 20.0, false)
	Game.state.contactAP = 3
	var info_res := Network.ask_info(int(press_ct.id))
	check(bool(info_res.ok) and bool(info_rumor.knownToPlayer), "Journalist enthüllt ein unbekanntes Gerücht")
	check(bool(Network.ask_info(int(press_ct.id)).ok) == false, "Informationszugang hat eine Abklingzeit")
	Game.state.contactAP = 3
	var dep0 := Network.dim(press_ct, "dependence")
	var share_res := Network.share_story(int(press_ct.id))
	check(bool(share_res.ok) and Network.dim(press_ct, "dependence") > dep0, "Story geteilt: die Presse schuldet dir")
	check(bool(info_rumor.get("sharedByPlayer", false)) and info_rumor.holders.has("Journalists"), "Wissen wandert nachvollziehbar weiter")
	Network.add_fact(press_ct, "testfakt wandert", -1, 1.0)
	var spread_target := Network.contact_by_name(str(press_ct.links[0].to))
	Network._spread_facts(true)
	check(spread_target.get("facts", []).any(func(f): return str(f.text) == "testfakt wandert" and str(f.via) == str(press_ct.name)), "Fakten verbreiten sich über Verbindungen mit Quellenangabe")

	# 39. Chancen aus dem Netzwerk: verdeckte Projekte über Kontakte
	var net_cs := Game._make_casting()
	net_cs["hidden"] = true
	net_cs["netSource"] = "produzent"
	Game.state.castings.append(net_cs)
	var prod_ct = null
	for ct in Game.state.contacts:
		if str(ct.type) == "produzent":
			prod_ct = ct
	prod_ct.dims.liking = 70.0
	prod_ct.dims.trust = 70.0
	prod_ct.rel = Network.derived_rel(prod_ct)
	Network._tick_reveal_castings(true)
	check(not bool(net_cs.hidden), "Produzenten-Kontakt bringt das verdeckte Projekt auf den Tisch")
	check(prod_ct.log.any(func(e): return str(e.text).contains("Tipped you off")), "Der Tipp bleibt im Gedächtnis des Kontakts")

	# 40. Gala: Begegnungen hinterlassen dauerhafte Spuren
	Game.grant_favor("galaInvite", {"type": "produzent", "name": str(prod_ct.name)}, true)
	Game.state.contactAP = 3
	var gl_n: int = Game.state.contacts.size()
	var gl_res := Network.attend_gala()
	check(bool(gl_res.ok) and Game.state.contacts.size() == gl_n + 1, "Gala: neue Bekanntschaft landet im Kontaktbuch")
	check(Game.state.memoirs.any(func(m): return str(m.text).contains("gala")), "Der Gala-Abend landet im Karrieregedächtnis")

	# 41. NPC-Karrieren: Aufstieg, Vorzimmer-Aufstieg, Ex-Assistent
	var career_ct = press_ct
	var old_ct_name := str(career_ct.name)
	Network.add_fact(career_ct, "halfst ihnen früh im Aufstieg", 1, 2.0)
	var dep_pre := Network.dim(career_ct, "dependence")
	var new_ct_name := Network.promote_contact(career_ct)
	check(str(career_ct.type) == "kolumnist" and new_ct_name != old_ct_name, "Journalist steigt zum Kolumnisten auf")
	check(career_ct.circles.has("gesellschaft"), "Kreise folgen der neuen Position")
	check(Network.dim(career_ct, "dependence") > dep_pre, "Frühe Freundlichkeit zahlt sich beim Aufstieg aus")
	var gate_vip = null
	for ct in Game.state.contacts:
		if not Network.gate_of(ct).is_empty():
			gate_vip = ct
	gate_vip.gate.rel = 80.0
	var rise_n: int = Game.state.contacts.size()
	var risen := Network.gate_rises(gate_vip)
	check(Game.state.contacts.size() == rise_n + 1 and float(risen.rel) > 20.0, "Das umgarnte Vorzimmer wird ein warmer Produzenten-Kontakt")
	check(Network.opinion_score(risen) > 0.0, "Der Aufstieg erinnert sich an frühe Blumen")
	Persona.hire_assistant()
	var ex_name := str(Persona.assistant().name)
	Network.assistant_departs(Persona.assistant(), true)
	Game.state.assistant = null
	check(Game.state.contacts.any(func(ct): return str(ct.name).contains(ex_name)), "Ex-Assistent taucht als Branchenkontakt wieder auf")
	var occ_n: int = Game.state.occasions.size()
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Netzwerkdynamik-Spielstand geladen")
	check(Game.state.occasions.size() == occ_n, "Anlässe überleben Save/Load")
	check(Game.state.contacts.any(func(ct): return ct.get("facts", []).size() > 0), "Subjektive Fakten überleben Save/Load")

	# =========== Dialogsystem & Posteingang ===========
	# 42. Dialog-Engine: Start, Auswahl, Effekte, Ende
	Game.new_game("Dialog AG", 1950)
	check(Data.DIALOGS.size() >= 4 and Dialogs.has_dialog("channel_meet"), "Dialogbäume aus data/dialogs geladen (%d)" % Data.DIALOGS.size())
	check(Data.LETTERS.size() >= 6, "Briefvorlagen aus data/letters geladen (%d)" % Data.LETTERS.size())
	var dlg_ct: Dictionary = Game.state.contacts[0]
	var dlg_liking0 := Network.dim(dlg_ct, "liking")
	var dlg_view := Dialogs.start("channel_meet", {"ctid": int(dlg_ct.id)})
	check(not bool(dlg_view.done) and dlg_view.choices.size() == 3, "Dialog startet mit Auswahlmöglichkeiten")
	check(str(dlg_view.title).contains(str(dlg_ct.name)), "Platzhalter {contact} wird ersetzt")
	check(bool(dlg_view.choices[2].disabled), "Bedingte Antwort ist bei zu wenig Sympathie gesperrt")
	dlg_view = Dialogs.choose(1)
	check(Network.dim(dlg_ct, "liking") > dlg_liking0, "Antwort-Effekte wirken auf die Beziehungsdimensionen")
	check(not bool(dlg_view.done) and dlg_view.choices.size() == 2, "Dialog wechselt in den Folgeknoten")
	var dlg_close0 := Network.dim(dlg_ct, "closeness")
	dlg_view = Dialogs.choose(0)
	check(bool(dlg_view.done), "Endknoten beendet das Gespräch")
	check(Network.dim(dlg_ct, "closeness") > dlg_close0, "Knoten-Effekte des Endwegs wirken")
	check(Dialogs.run == null, "Dialog-Laufzeitzustand wird aufgeräumt")
	var check_p := Dialogs.check_p({"skill": "negotiation", "base": 0.5})
	check(check_p >= 0.05 and check_p <= 0.95, "Würfe bleiben im Wahrscheinlichkeitsfenster (%0.2f)" % check_p)

	# 43. Posteingang: Zustellung, Antwort, Ablauf, Epochenwort
	check(Dialogs.mail_word() == "Letters", "1950 kommt die Post als Brief")
	var lt := Dialogs.spawn_letter("studio_lunch", true)
	check(not lt.is_empty() and Dialogs.open_letters().size() == 1, "Brief zugestellt")
	check(str(lt["from"].get("type", "")) == "studio" and lt["from"].has("ctid"), "Absender aus dem Kontaktbuch aufgelöst")
	var lt_ct: Dictionary = Persona.contact_by_id(int(lt["from"].ctid))
	var lt_close0 := Network.dim(lt_ct, "closeness")
	Game.state.contactAP = 3
	var lt_res := Dialogs.letter_choose(int(lt.id), 0)
	check(bool(lt_res.ok) and str(lt.status) == "done", "Brief-Antwort ausgeführt und abgelegt")
	check(Network.dim(lt_ct, "closeness") > lt_close0, "Brief-Effekte wirken auf den Absender-Kontakt")
	check(int(Game.state.contactAP) == 2, "Brief-Antwort kostet Kontaktzeit")
	var lt2 := Dialogs.spawn_letter("tax_audit", true)
	lt2.expireWi = Game.wi() - 1
	var lt_cash0 := float(Game.state.player.cash)
	Dialogs.tick_week()
	check(str(lt2.status) == "expired", "Liegengebliebene Post verfällt")
	check(float(Game.state.player.cash) < lt_cash0, "Verfall mit Konsequenz: Säumniszuschlag gebucht")
	check(Dialogs.open_letters().size() >= 1, "Wöchentliche Zustellung bringt neue Post")
	Game.state.year = 2005
	check(Dialogs.mail_word() == "E-mail", "Ab der Jahrtausendwende kommt die Post als E-Mail")
	Game.state.year = 1950

	# 44. Dialog-Einstiege & Save/Load
	Game.state.contactAP = 3
	Game.state.player.cash = 5000.0
	dlg_ct.lastActWeek = Game.wi()
	var bd := Persona.begin_channel_dialog(int(dlg_ct.id), "meet")
	check(not bool(bd.ok), "Kanal-Dialog respektiert die Wochensperre (bereits kontaktiert)")
	var dlg_ct2: Dictionary = Game.state.contacts[1]
	var bd2 := Persona.begin_channel_dialog(int(dlg_ct2.id), "meet")
	check(bool(bd2.ok) and int(Game.state.contactAP) == 1, "Kanal-Dialog bucht Zeit & Kosten vor dem Gespräch")
	Game.grant_favor("galaInvite", Game.favor_contact_for("galaInvite"), true)
	check(bool(Network.begin_gala().ok), "Gala-Dialog-Einstieg konsumiert die Einladung")
	var inbox_n: int = Game.state.inbox.size()
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Dialog-Spielstand geladen")
	check(Game.state.inbox.size() == inbox_n, "Posteingang überlebt Save/Load")
	Game.state.erase("inbox")
	Dialogs.ensure_inbox()
	check(Game.state.has("inbox"), "ensure_inbox rüstet alte Stände nach")

	# =========== Kommunikation & Bedeutungsstaffelung (Features 23–26) ===========
	# 45. Kommunikationswege: Daten-Profile & der langsame Brief
	Game.new_game("Korrespondenz AG", 1950)
	Game.state.player.cash = 5000.0
	check(Data.CONTACT_CHANNELS.has("letter") and Data.CONTACT_CHANNELS.meet.has("profile"), "Kanäle tragen Wirkungsprofile aus den Daten")
	var ch_ct: Dictionary = Game.state.contacts[0]
	var ch_respect0 := Network.dim(ch_ct, "respect")
	Network.apply_channel(ch_ct, "note", 4.0)
	check(Network.dim(ch_ct, "respect") > ch_respect0, "Nachricht wirkt laut Datenprofil auf Respekt")
	Game.state.contactAP = 3
	var letter_res := Persona.contact_interact(int(ch_ct.id), "letter")
	check(bool(letter_res.ok) and Game.state.outMail.size() == 1, "Brief geht in die Ausgangspost statt sofort zu wirken")
	var ch_trust0 := Network.dim(ch_ct, "trust")
	Game.state.outMail[0].dueWi = Game.wi()
	Persona.tick_week()
	check(Game.state.outMail.is_empty(), "Zustellung leert die Ausgangspost")
	check(Network.dim(ch_ct, "trust") > ch_trust0, "Der angekommene Brief wirkt verzögert auf die Beziehung")

	# 46. Relevanz & Staffelung: Digest, Nachricht, Kurzdialog
	var digest0: int = Game.state.weekDigest.size()
	Dialogs.dispatch("test_minor", {"impact": 0.0, "text": "eine Randnotiz"})
	check(Game.state.seenKinds.has("test_minor"), "Neuigkeitswert wird pro Ereignisart gezählt")
	var tier_low2 := Dialogs.dispatch("test_minor", {"impact": 0.0, "text": "noch eine Randnotiz"})
	check(tier_low2 == "digest" and Game.state.weekDigest.size() > digest0, "Routine landet im Wochen-Digest")
	Dialogs.flush_digest()
	check(Game.state.weekDigest.is_empty() and Game.state.log.any(func(l): return str(l.text).contains("In passing")), "Digest wird zu EINER Ticker-Zeile zusammengefasst")
	var vip_ct2 = null
	for ct in Game.state.contacts:
		if Network.is_vip(ct):
			vip_ct2 = ct
	var inbox_before: int = Game.state.inbox.size()
	var tier_mid := Dialogs.dispatch("test_notice", {"impact": 1.0, "ctid": int(vip_ct2.id), "subject": "Testnachricht", "body": "Ein wichtiger Vorgang."})
	check(tier_mid != "digest" and Game.state.inbox.size() == inbox_before + 1, "Wichtige Vorgänge werden zur Nachricht im Posteingang")
	vip_ct2.dims.liking = 70.0
	vip_ct2.rel = Network.derived_rel(vip_ct2)
	var tier_high := Dialogs.dispatch("test_scene", {"impact": 2.5, "ctid": int(vip_ct2.id), "scene_letter": "npc_rise", "subject": "x", "body": "y"})
	check(tier_high == "scene" or tier_high == "event", "Hohe Relevanz erzeugt einen beantwortbaren Kurzdialog/Szene (%s)" % tier_high)
	var scene_letter = null
	for l in Game.state.inbox:
		if str(l.tid) == "npc_rise":
			scene_letter = l
	check(scene_letter != null and str(scene_letter["from"].name) == str(vip_ct2.name), "Szenen-Brief kommt vom richtigen Absender")
	var rise_liking0 := Network.dim(vip_ct2, "liking")
	check(bool(Dialogs.letter_choose(int(scene_letter.id), 0).ok) and Network.dim(vip_ct2, "liking") > rise_liking0, "Antwort im Kurzdialog wirkt auf die Beziehung")
	check(bool(Dialogs.letter_def("summons_meet").manual) and bool(Dialogs.letter_def("npc_rise").manual), "Dispatcher-Vorlagen sind als manuell markiert (keine Zufallszustellung)")

	# 47. Simulation & Text strikt getrennt: Validierung der Daten
	check(Dialogs.validate_defs().is_empty(), "Alle mitgelieferten Dialoge & Briefe validieren sauber")
	Data.DIALOGS.append({"id": "bad_test", "title": "x", "start": "opening",
		"nodes": {"opening": {"text": ["{invented_contract}"], "choices": [
			{"label": "x", "goto": "nowhere", "effects": [{"op": "invent_contract"}]}]}}})
	var warnings: Array = Dialogs.validate_defs()
	check(warnings.size() >= 3, "Unbekannte Ops, Platzhalter und Sprungziele werden erkannt (%d Befunde)" % warnings.size())
	Data.DIALOGS.pop_back()
	check(Dialogs.validate_defs().is_empty(), "Nach Entfernen der kaputten Definition ist alles wieder sauber")
	var tiers_saved: Dictionary = Game.state.seenKinds.duplicate()
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Staffelungs-Spielstand geladen")
	check(Game.state.seenKinds.size() == tiers_saved.size() and Game.state.has("outMail"), "Neuigkeitszähler & Ausgangspost überleben Save/Load")

	# =========== Erinnerungen, Budget, Versprechen & Verpflichtungen (27–31) ===========
	# 48. Gesprächserinnerungen & Wiederholungskontrolle
	Game.new_game("Gedächtnis AG", 1950)
	var rc_ct: Dictionary = Game.state.contacts[0]
	Game.state.promises.append({"id": 95001, "to": str(rc_ct.name), "kind": "callback", "madeMi": Game.mi() - 3,
		"dueMi": Game.mi() - 1, "witnesses": 0, "written": false, "text": "x", "status": "broken"})
	var rc := Dialogs.recall_for(rc_ct)
	check(str(rc.get("text", "")).contains("your word"), "Gebrochene Zusagen werden konkret angesprochen")
	check(bool(Game.state.promises.back().recalled), "Jeder Vorwurf wird nur einmal ausgesprochen")
	Network.add_fact(rc_ct, "stood by them in a rough patch", 1, 2.0)
	var rc2 := Dialogs.recall_for(rc_ct)
	check(str(rc2.get("text", "")).contains("stood by them"), "Frühere Hilfe wird dankbar erinnert")
	check(Dialogs.recall_for(rc_ct).is_empty(), "Erinnerungen haben eine Abklingzeit")
	var pick1 := Dialogs._pick_text(["Variante A", "Variante B"])
	var pick2 := Dialogs._pick_text(["Variante A", "Variante B"])
	check(pick1 != pick2, "Formulierungen wiederholen sich erst, wenn alle Varianten durch sind")

	# 49. Kommunikationsbudget: wenige große Szenen pro Woche
	var stress0 := float(Game.state.player.stress)
	Dialogs.note_scene()
	Dialogs.note_scene()
	check(int(Game.state.weekScenes) == 2 and float(Game.state.player.stress) == stress0, "Zwei große Szenen sind eine normale Woche")
	Dialogs.note_scene()
	check(float(Game.state.player.stress) > stress0, "Die dritte Szene signalisiert Krise (Stress steigt)")
	Dialogs.tick_week()
	check(int(Game.state.weekScenes) == 0 and not bool(Game.state.weekScenesNoted), "Das Budget beginnt jede Woche frisch")

	# 50. Versprechensregister & Gefallen als Verpflichtungen
	Game.state.contactAP = 3
	var pr_ct2: Dictionary = Game.state.contacts[1]
	Persona._make_promise(pr_ct2, "dinner", 2, false)
	var pr_new: Dictionary = Game.state.promises.back()
	check(str(pr_new.kind) == "dinner" and int(pr_new.witnesses) == 2, "Zusagen tragen Inhalt, Frist und Zeugen")
	var pr_trust0 := Network.dim(pr_ct2, "trust")
	Persona._fulfill_promises(pr_ct2)
	check(str(pr_new.status) == "kept" and Network.dim(pr_ct2, "trust") - pr_trust0 >= 7.9, "Vor Zeugen gehaltenes Wort zahlt stärker auf Vertrauen ein")
	var wr_ct: Dictionary = Game.state.contacts[2]
	Persona._make_promise(wr_ct, "intro", 0, true)
	var pr_wr: Dictionary = Game.state.promises.back()
	check(bool(pr_wr.written), "Schriftliche Zusagen werden als solche registriert")
	# Gefallen: Einfordern kühlt und erzeugt manchmal Gegenschulden
	Game.grant_favor("suppressStory", {"type": str(rc_ct.type), "name": str(rc_ct.name)}, true)
	var rc_liking := Network.dim(rc_ct, "liking")
	check(Game.consume_favor("suppressStory"), "Gefallen eingefordert")
	check(Network.dim(rc_ct, "liking") < rc_liking, "Einfordern kühlt die Beziehung einen Hauch ab")
	# Schulden werden per Brief eingefordert; Ops begleichen oder verweigern
	Game.owe_favor("galaInvite", {"type": str(rc_ct.type), "name": str(rc_ct.name)})
	var dc_letter := Dialogs.spawn_letter_for("debt_called", rc_ct)
	check(not dc_letter.is_empty(), "Schuld-Brief zugestellt")
	Game.state.player.cash = 5000.0
	var debts0: int = Game.state.debts.size()
	Game.state.contactAP = 3
	check(bool(Dialogs.letter_choose(int(dc_letter.id), 1).ok), "Schuld großzügig mit Geld beglichen")
	check(Game.state.debts.size() < debts0, "settle_debt räumt die Verpflichtung aus dem Register")
	var refuse_ct: Dictionary = Game.state.contacts[3]
	Game.owe_favor("scriptAccess", {"type": str(refuse_ct.type), "name": str(refuse_ct.name)})
	var dc2 := Dialogs.spawn_letter_for("debt_called", refuse_ct)
	var refuse_irr0 := Network.dim(refuse_ct, "irritation")
	Dialogs.letter_choose(int(dc2.id), 2)
	check(Network.dim(refuse_ct, "irritation") > refuse_irr0, "Verweigerte Schulden hinterlassen Verärgerung")
	check(Network.opinion_score(refuse_ct) < 0.0, "»Vergisst Hilfe« wird Teil des Bildes von dir")
	var promises_saved: int = Game.state.promises.size()
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Verpflichtungs-Spielstand geladen")
	check(Game.state.promises.size() == promises_saved and Game.state.promises.back().has("witnesses"), "Erweitertes Versprechensregister überlebt Save/Load")

	# =========== Assistent+, Mitarbeiter & Eskalation (Features 32–36) ===========
	# 51. Assistent: Reise-Organisation, Postfilter, erweitertes Briefing
	Game.new_game("Delegation AG", 1950)
	Persona.hire_assistant()
	Persona.set_rule("travel", true)
	Game.state.agency.cash = 100000.0
	check(Persona.travel_to("ny"), "Reise mit Reise-Organisation angetreten")
	check(int(Game.state.contactAP) == 1, "Assistent rettet 1⏱ Kontaktzeit über die Anreise")
	Persona.travel_to("la")
	Persona.set_rule("mailfilter", true)
	var mf_letter := Dialogs.spawn_letter("fan_mail", true)
	Dialogs.tick_week()
	check(str(mf_letter.status) == "done", "Postfilter: Routinepost wird vom Assistenten beantwortet")
	Game.state.occasions.append({"id": 97001, "ctName": str(Game.state.contacts[0].name), "kind": "birthday", "madeMi": Game.mi(), "dueMi": Game.mi() + 1, "status": "open"})
	var brief2: Dictionary = Persona.assistant_briefing()
	check(not brief2.is_empty() and str(brief2.text).contains("gesture"), "Briefing erinnert an offene Anlässe")

	# 52. Mitarbeiter: Anstellung, Empfehlung mit Unsicherheit & Eigeninteresse
	var deal_staff := Staff.hire("deals")
	check(not deal_staff.is_empty() and Game.state.staff.size() == 1, "Deal-Desk besetzt")
	check(Staff.hire_blocked_reason("deals") != "", "Ein Desk wird nur einmal besetzt")
	var conf := Staff.confidence(deal_staff)
	check(conf >= 20 and conf <= 95, "Unsicherheit wird als Sicherheitswert beziffert (%d%%)" % conf)
	check(Data.STAFF_TRAITS.has(str(deal_staff.trait)), "Mitarbeiter tragen ein (verdecktes) Eigeninteresse")
	Game.state.agency.rep = 100
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
	for cs in Game.state.castings:
		for srole in cs.roles:
			if srole.filled == null and str(srole.gender) == "f":
				srole.minFame = 10
				srole.ageMin = 18
				srole.ageMax = 70
	var rec_events: Array = []
	deal_staff.mode = "propose"
	Staff._work_deals(deal_staff, rec_events)
	check(rec_events.size() == 1 and rec_events[0].choices.size() == 3, "Empfehlung mit Freigeben/Ablehnen/Selbst übernehmen")
	check(str(rec_events[0].text).contains("certainty") or str(rec_events[0].text).contains("%"), "Empfehlung nennt Begründung und Unsicherheit")
	rec_events[0].choices[0].fn.call()
	var handled: bool = Game.state.castings.any(func(cs): return cs.roles.any(func(r): return r.filled != null and r.filled.get("clientId") != null)) or Game.state.castings.any(func(cs): return cs.roles.any(func(r): return r.rejected.size() > 0))
	check(handled, "Freigabe: der Mitarbeiter führt den Pitch aus (Erfolg oder Absage)")

	# 53. Eskalationsregeln & autonome Arbeit
	Game.state.delegation.feeCap = 0
	deal_staff.mode = "auto"
	deal_staff.actsWeek = -99
	var esc_events: Array = []
	Staff._work_deals(deal_staff, esc_events)
	if not esc_events.is_empty():
		check(str(esc_events[0].title).contains("Escalation"), "Über dem Freigabelimit wird eskaliert statt gehandelt")
	else:
		check(true, "Kein offener Pitch mehr — Eskalationspfad ohne Ziel")
	Game.state.delegation.feeCap = 50000
	var care_staff := Staff.hire("care")
	care_staff.mode = "auto"
	var cold_ct: Dictionary = Game.state.contacts[0]
	cold_ct.dims.liking = 5.0
	cold_ct.dims.trust = 5.0
	cold_ct.rel = Network.derived_rel(cold_ct)
	var cold0 := Network.dim(cold_ct, "liking")
	Staff._work_care(care_staff, [])
	check(Network.dim(cold_ct, "liking") > cold0, "Autonome Kontaktpflege wärmt den kältesten Kontakt")
	check(Game.state.weekDigest.any(func(d): return str(d).contains("warm")), "Autonome Arbeit landet im Wochen-Digest")
	var crisis_staff := Staff.hire("crisis")
	crisis_staff.mode = "auto"
	var cr_rumor := Scandal.add_rumor("agency", "Eine laute Geschichte.", false, "skandal", ["Journalists"], 70.0, true)
	var cr_events: Array = []
	Staff._work_crisis(crisis_staff, cr_events)
	check(cr_events.size() == 1 and str(cr_events[0].title).contains("Escalation"), "Laute Skandale eskalieren trotz Autonomie (Regel)")
	Game.state.delegation.escalateScandal = false
	cr_rumor.belief = 40.0
	var cr_events2: Array = []
	Staff._work_crisis(crisis_staff, cr_events2)
	check(cr_events2.is_empty() and float(cr_rumor.belief) < 40.0, "Ohne Regel handelt der Krisen-Desk autonom (Gerücht gedämpft)")
	var mw0: float = Game.state.agency.cash
	Staff.tick_month()
	check(float(Game.state.agency.cash) < mw0, "Monatsende bucht Mitarbeiter-Löhne")
	var staff_n: int = Game.state.staff.size()
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Mitarbeiter-Spielstand geladen")
	check(Game.state.staff.size() == staff_n and int(Game.state.delegation.feeCap) == 50000, "Mitarbeiter & Delegationsregeln überleben Save/Load")
	Game.state.erase("staff")
	Game.state.erase("delegation")
	Staff.ensure_staff()
	check(Game.state.has("staff") and Game.state.delegation.has("feeCap"), "ensure_staff rüstet alte Stände nach")

	# =========== Qualität, Betreuung, Biografie & Privatleben (33–35, 41–44) ===========
	# 54. Mitarbeiterqualität, Fehler, Bindung & Abwerbung
	Game.new_game("Qualität AG", 1950)
	var q_staff := Staff.hire("care")
	check(q_staff.has("loyalty") and q_staff.has("load"), "Mitarbeiter tragen Loyalität & Auslastung")
	q_staff.load = 100.0
	q_staff.loyalty = 10.0
	q_staff.skill = 20
	check(Staff.mishap_chance(q_staff) > Staff.mishap_chance({"skill": 90, "load": 0.0, "loyalty": 90.0}), "Überlastung, Illoyalität & schwache Kompetenz erhöhen die Fehlerquote")
	Staff.give_raise(int(q_staff.id))
	check(absf(float(q_staff.loyalty) - 25.0) < 0.01 and float(q_staff.wageBonus) > 0.0, "Gehaltserhöhung bindet (Loyalität +15, Lohn +20%)")
	check(Staff.raise_blocked_reason(int(q_staff.id)) != "", "Erhöhungen brauchen Abstand")
	q_staff.loyalty = 5.0
	var rv_n2: int = Game.state.rivals.size()
	var d_events: Array = []
	Staff._defect(q_staff, d_events)
	check(Game.state.staff.is_empty() and d_events.size() == 1, "Abwerbung/Abspaltung: der Mitarbeiter geht, der Spieler erfährt es")
	check(Game.state.rivals.size() >= rv_n2, "Abspaltung gründet eine Agentur oder stärkt die Konkurrenz")

	# 55. Persönliche Betreuung bedeutender Kontakte
	var pt_ct = null
	for ct in Game.state.contacts:
		if Network.is_vip(ct):
			pt_ct = ct
	pt_ct.lastPersonalMi = Game.mi() - 6
	pt_ct.lastMi = Game.mi()
	Network.tick_month()
	check(pt_ct.facts.any(func(f): return str(f.text) == "only ever sends the help"), "Wichtige Kontakte merken, wenn nur noch Personal erscheint")
	Game.state.contactAP = 3
	Game.state.player.cash = 5000.0
	pt_ct.gate = {"name": "x", "rel": 90.0}
	Persona.begin_channel_dialog(int(pt_ct.id), "meet")
	check(int(pt_ct.lastPersonalMi) == Game.mi(), "Eigenes Erscheinen setzt die persönliche Betreuung zurück")

	# 56. Biografischer Start, Spezialisierung & Statusbesitz
	Game.new_game("Biografie AG", 1950, "anwalt")
	check(Mogul.xp("contracts") >= 15.0, "Herkunft & Ausbildung bringen Fähigkeiten mit (Anwalt: Vertragswissen)")
	check(Game.state.contacts.any(func(ct): return str(ct.type) == "anwalt"), "Frühere Tätigkeit bringt ein Anfangsnetzwerk mit")
	Mogul.grant_xp("negotiation", 100.0, "Test")
	check(Mogul.has_ability("master_negotiator"), "Level 5 schaltet die Meister-Spezialisierung frei")
	check(str(Mogul.specialization().label) == "The Negotiator", "Der Spezialisierungs-Titel folgt dem stärksten Feld")
	Game.state.player.cash = 100000.0
	check(Mogul.buy_purchase("own_club") == "", "Eigener Club gekauft (Statusbesitz)")
	var club_ledger0: int = Game.state.player.ledger.size()
	Mogul._tick_estate_month()
	check(Game.state.player.ledger.any(func(e): return str(e.text).contains("establishments")), "Der eigene Club wirft Einnahmen ab")
	check(Game.state.player.ledger.size() > club_ledger0, "Unterhalt & Erträge laufen über das Privatkonto")

	# 57. Privatleben: Partnerschaft, Ehe, Bruch, Freundschaften
	Persona.private_action("courtship_accept", 0.0, "Vivian Hale")
	check(Game.state.player.privateLife.partner != null, "Partnerschaft beginnt")
	Persona.private_action("evening", 0.0, "")
	check(float(Game.state.player.privateLife.partner.rel) > 55.0, "Gemeinsame Abende stärken die Nähe")
	Persona.private_action("proposal_accept", 0.0, "")
	check(Persona.is_married(), "Heirat registriert")
	var lc_married := Persona.living_cost()
	Game.state.player.privateLife.partner.rel = 10.0
	var br_events: Array = []
	Persona._tick_private_life(br_events)
	check(Game.state.player.privateLife.partner == null and not Persona.is_married(), "Zerrüttung beendet Partnerschaft und Ehe — öffentlich")
	check(br_events.size() == 1 and Persona.living_cost() < lc_married, "Der Haushalt schrumpft nach der Trennung")
	Persona.private_action("friend_add", 0.0, "")
	Persona.private_action("friend_add", 0.0, "")
	check(int(Game.state.player.privateLife.friends) == 2, "Freundschaften außerhalb der Branche gezählt")
	Game.state.player.stress = 50.0
	Persona._tick_private_life([])
	check(float(Game.state.player.stress) < 50.0, "Freundschaften nehmen Druck aus dem Monat")
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Privatlebens-Spielstand geladen")
	check(int(Game.state.player.privateLife.friends) == 2, "Privatleben überlebt Save/Load")

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

	# =====================================================================
	# Chunk 05: Kern-Regressionen — fame_at-Kurve, Pool nach Tod, Casting-Fit,
	# Package-Deal, Box-Office-Determinismus, Wortbruch, Insolvenz
	# =====================================================================
	var fa_bg: Dictionary = Game.actor_by_id["bogart"]
	check(Util.fame_at(fa_bg, float(int(fa_bg.debut) - 5)) == 0, "fame_at: vor dem Debüt 0")
	check(Util.fame_at(fa_bg, float(fa_bg.peak)) == int(fa_bg.peakFame), "fame_at: am Karrierehoch = peakFame")
	check(Util.fame_at(fa_bg, float(fa_bg.peak) - 6.0) < int(fa_bg.peakFame) and Util.fame_at(fa_bg, float(fa_bg.peak) + 8.0) < int(fa_bg.peakFame), "fame_at: Kurve steigt zum Hoch und fällt danach")
	check(Util.fame_at(fa_bg, 2005.0) == 5, "fame_at: lange nach der Karriere nur Sockelruhm")

	Game.new_game("Pool 1980", 1980)
	check(not Game.available_actors().any(func(a): return str(a.id) == "bogart"), "Verstorbene Schauspieler fehlen im Pool (Bogart 1980)")

	# Casting-Fit: Genre-Match schlägt fremdes Genre (fit_score ist RNG-frei)
	Game.new_game("Regression", 1950)
	var fit_c := {"id": 77777, "aid": "bogart", "perks": [], "fame": 60.0, "heat": 0.0,
		"exhaustion": 0.0, "flags": {}, "dna": CareerDNA.initial_dna(Game.actor_by_id["bogart"]),
		"exclusiveStudio": "", "clauses": [], "talentBonus": 0.0}
	var fit_role := {"type": "lead", "gender": "m", "minFame": 30, "ageMin": 30, "ageMax": 60, "fee": 40000, "filled": null, "rejected": []}
	var fit_cast := {"id": 9001, "studioId": "mgm", "title": "Fit-Test", "genre": "crime", "prestige": 1, "budget": 1000000, "deadline": 8, "qualityMod": 0.0, "roles": [fit_role]}
	var fit_match := Game.fit_score(fit_cast, fit_role, fit_c)
	fit_cast.genre = "western"
	var fit_off := Game.fit_score(fit_cast, fit_role, fit_c)
	check(fit_match > fit_off, "fit_score: Genre-Match (%d) schlägt fremdes Genre (%d)" % [fit_match, fit_off])

	# Karriere-DNA (Chunk 03): Prägung schiebt die erwartete Achse in die
	# erwartete Richtung, Hauptrolle (mult 1,0) prägt doppelt so stark wie
	# Nebenrolle (mult 0,5).
	var dna_lead := {"dna": CareerDNA.initial_dna(Game.actor_by_id["bogart"])}
	var dna_supp := {"dna": dna_lead.dna.duplicate(true)}
	var dna_rom0: float = float(dna_lead.dna.romantik)
	CareerDNA.imprint_dna(dna_lead, "romance", 1.0, 1, 1.5)
	CareerDNA.imprint_dna(dna_supp, "romance", 0.5, 1, 1.5)
	var dna_d_lead: float = float(dna_lead.dna.romantik) - dna_rom0
	var dna_d_supp: float = float(dna_supp.dna.romantik) - dna_rom0
	check(dna_d_lead > 0.0, "DNA-Prägung: Romance schiebt die Romantik-Achse ins Positive")
	check(absf(dna_d_lead - 2.0 * dna_d_supp) < 0.001, "DNA-Prägung: Hauptrolle prägt doppelt so stark wie Nebenrolle")

	# RPG-Attribute (Chunk 15): Seeding, Ertragskurve, Save/Load, Migration
	check(Data.ATTRIBUTES.size() == 5, "Attribute-Definitionen aus data/attributes geladen")
	Game.new_game("Attributtest", 1950, "anwalt")
	check(Game.attr("verhandlung") > roundi(Balance.ATTR_BASE), "Backstory Anwalt seedet Verhandlung über die Basis")
	Game.state.attributes["netzwerk"] = 80.0
	Game.attr_gain("netzwerk", 1.0)
	check(absf(float(Game.state.attributes.netzwerk) - 80.25) < 0.001, "attr_gain über 70: nur ×0,25 Ertrag")
	Game.state.attributes["diskretion"] = 20.0
	Game.attr_gain("diskretion", 0.4)
	check(absf(float(Game.state.attributes.diskretion) - 20.4) < 0.001, "attr_gain unter 40: voller Ertrag")
	Game.state.attributes["menschenkenntnis"] = 55.0
	Game.attr_gain("menschenkenntnis", 1.0)
	check(absf(float(Game.state.attributes.menschenkenntnis) - 55.5) < 0.001, "attr_gain zwischen 40 und 70: halber Ertrag")
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Attribut-Spielstand geladen")
	check(absf(float(Game.state.attributes.netzwerk) - 80.25) < 0.001, "Attribute überleben Save/Load")
	Game.state.erase("attributes")
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Alt-Stand ohne Attribute geladen")
	check(Game.attr("verhandlung") == roundi(Balance.ATTR_BASE), "Migration rüstet Attribute mit Basiswerten nach")

	# RPG-Proben (Chunk 16): Chance-Formel, Sichtbarkeit, Pfade, min_attr
	Game.state.attributes["menschenkenntnis"] = 45.0
	check(absf(EvEngine.check_chance({"attr": "menschenkenntnis", "dc": 45}) - 0.5) < 0.001, "Probe: Attribut = DC ⇒ 50 %")
	check(absf(EvEngine.check_chance({"attr": "menschenkenntnis", "dc": 145}) - 0.05) < 0.001, "Probe: Untergrenze 5 %")
	check(absf(EvEngine.check_chance({"attr": "menschenkenntnis", "dc": -100}) - 0.95) < 0.001, "Probe: Obergrenze 95 %")
	var probe_def := {"id": "probe_test", "title": "T", "text": "T", "choices": [
		{"label": "Probe", "check": {"attr": "verhandlung", "dc": -1000},
		"effects": [{"op": "rep", "amount": 1}], "effects_fail": [{"op": "rep", "amount": -1}],
		"outcome": "ok", "outcome_fail": "fail"}]}
	var probe_ev: Dictionary = EvEngine.build_event(probe_def)
	check(str(probe_ev.choices[0].label).begins_with("["), "Proben-Button trägt sichtbares Label-Präfix")
	check(str(probe_ev.choices[0].label).contains("%"), "Proben-Label enthält Prozentangabe")
	var probe_attr0 := float(Game.state.attributes.verhandlung)
	var probe_rep0 := int(Game.state.agency.rep)
	seed(11)
	var probe_out := str(probe_ev.choices[0].fn.call())
	check(probe_out == "ok" and int(Game.state.agency.rep) == probe_rep0 + 1, "Probe mit 95 %: Erfolgspfad läuft (Seed)")
	check(float(Game.state.attributes.verhandlung) > probe_attr0, "Erfolgreiche Probe lässt das Attribut wachsen")
	check(not EvEngine.check_conditions({"min_attr": {"verhandlung": 99}}), "min_attr sperrt bei zu niedrigem Attribut")
	check(EvEngine.check_conditions({"min_attr": {"verhandlung": 5}}), "min_attr öffnet bei erfülltem Attribut")
	check(Data.EVENTS.any(func(e): return str(e.id) == "brown_derby_abend"), "Schaufenster-Event rpg_proben.json geladen")

	# Quest-Journal (Chunk 17): Kette mit quest-Block wird verfolgbar
	Game.new_game("Questtest", 1950)
	check(Game.state.quests.is_empty(), "Neues Spiel startet ohne offene Aufträge")
	var q_start := {"id": "steuerpruefung", "title": "T", "text": "T", "choices": [
		{"label": "Weiter", "effects": [{"op": "followup", "event": "steuer_nachspiel", "delay_weeks": 6}], "outcome": "läuft"}]}
	var q_ev: Dictionary = EvEngine.build_event(q_start)
	q_ev.choices[0].fn.call()
	check(Game.state.quests.size() == 1 and str(Game.state.quests[0].status) == "aktiv", "Kettenstart mit quest-Block legt aktiven Auftrag an")
	check(str(Game.state.quests[0].step) != "", "Auftrag trägt einen Schritttext")
	check(Game.state.followups[0].ctx.has("_questId"), "Followup transportiert die Quest-Id weiter")
	var q_end := {"id": "steuer_nachspiel", "title": "T", "text": "T", "choices": [
		{"label": "Ende", "effects": [{"op": "rep", "amount": 1}], "outcome": "Der Prüfer zieht ab."}]}
	var q_ev2: Dictionary = EvEngine.build_event(q_end, {"_questId": "steuerpruefung"})
	q_ev2.choices[0].fn.call()
	check(str(Game.state.quests[0].status) == "abgeschlossen", "Kettenende ohne Followup schließt den Auftrag")
	var q_plain := {"id": "no_quest_event", "title": "T", "text": "T", "choices": [
		{"label": "Weiter", "effects": [{"op": "followup", "event": "irgendwas", "delay_weeks": 2}], "outcome": "ok"}]}
	EvEngine.build_event(q_plain).choices[0].fn.call()
	check(Game.state.quests.size() == 1, "Event ohne quest-Block erzeugt keinen Journal-Eintrag")
	Game.save_game()
	Game.state = null
	Game.load_game()
	check(Game.state.quests.size() == 1 and str(Game.state.quests[0].status) == "abgeschlossen", "Aufträge überleben Save/Load")

	# Tonfilm-Umbruch: deterministische Stimme, Risiko-Fenster, Casting-Malus
	var v_probe := Util.voice_of({"id": "bogart"})
	check(v_probe == Util.voice_of({"id": "bogart"}) and v_probe >= 20 and v_probe <= 100, "Sprechstimme ist deterministisch und im Wertebereich")
	var weak_actor := {}
	for wa in Data.ACTORS:
		if Util.voice_of(wa) < Balance.VOICE_WEAK_THRESHOLD:
			weak_actor = wa
			break
	check(not weak_actor.is_empty(), "Der Pool enthält fragile Stimmen")
	var vc := {"aid": str(weak_actor.id), "flags": {}}
	Game.state.year = 1925
	check(not Game.voice_at_risk(vc), "Vor dem Tonfilm ist die Stimme egal")
	Game.state.year = 1930
	check(Game.voice_at_risk(vc), "1930: fragile Stimme ohne Training ist ein Risiko")
	vc.flags["voiceTrained"] = true
	check(not Game.voice_at_risk(vc), "Sprechtraining beendet das Risiko")
	vc.flags.clear()
	Game.state.year = 1940
	check(not Game.voice_at_risk(vc), "Nach der Übergangszeit ist der Markt sortiert")
	Game.state.year = 1930
	var v_role := {"type": "lead", "gender": str(weak_actor.g), "minFame": 10, "ageMin": -100, "ageMax": 999, "fee": 30000, "filled": null, "rejected": []}
	var v_cast := {"id": 9300, "studioId": "mgm", "title": "V", "genre": "drama", "prestige": 1, "budget": 500000, "deadline": 8, "qualityMod": 0.0, "roles": [v_role]}
	var v_client := {"id": 9301, "aid": str(weak_actor.id), "perks": [], "fame": 50.0, "heat": 0.0,
		"exhaustion": 0.0, "flags": {}, "dna": CareerDNA.initial_dna(weak_actor), "exclusiveStudio": "", "clauses": [], "talentBonus": 0.0}
	var v_fit_risk := Game.fit_score(v_cast, v_role, v_client)
	v_client.flags["voiceTrained"] = true
	var v_fit_ok := Game.fit_score(v_cast, v_role, v_client)
	check(v_fit_ok - v_fit_risk >= 10, "Tonfilm-Fenster: fragile Stimme kostet Casting-Passung (%d vs %d)" % [v_fit_risk, v_fit_ok])
	check(Data.EVENTS.any(func(e): return str(e.id) == "tonfilm_tontest"), "Tonfilm-Eventkette geladen")

	# Rivalen: Agentur-Ranking & aktives Abwerbe-Duell
	Game.new_game("Rivalenduell", 1950)
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null})
	var rank: Array = Rivals.agency_ranking()
	check(rank.any(func(r): return bool(r.isPlayer)), "Agentur-Ranking enthält die eigene Agentur")
	check(rank.size() == Game.state.rivals.size() + 1, "Ranking listet alle Häuser")
	check(float(rank[0].score) >= float(rank[rank.size() - 1].score), "Ranking ist absteigend sortiert")
	var pv_c: Dictionary = Game.state.clients[0]
	pv_c.loyalty = 30.0
	var pv_events: Array = []
	Rivals.tick_rivals(pv_events, true)
	var pv_duel = null
	for pe in pv_events:
		if str(pe.get("title", "")).begins_with("Poaching attempt"):
			pv_duel = pe
			break
	check(pv_duel != null, "Unzufriedener Klient löst ein Abwerbe-Duell aus")
	var pv_loy0 := float(pv_c.loyalty)
	# Teil A3: ab Ruhm 50 steht die volle Szene vorn — die klassischen
	# Optionen bleiben als Fallback dahinter erhalten.
	var pv_match: Dictionary = pv_duel.choices.filter(func(chx): return str(chx.label).begins_with("Match the terms"))[0]
	pv_match.fn.call()
	check(Game.state.clients.size() == 1 and float(pv_c.loyalty) > pv_loy0, "Mitbieten hält den Klienten (Loyalität steigt)")
	pv_c.loyalty = 30.0
	var pv_events2: Array = []
	Rivals.tick_rivals(pv_events2, true)
	var pv_duel2 = null
	for pe2 in pv_events2:
		if str(pe2.get("title", "")).begins_with("Poaching attempt"):
			pv_duel2 = pe2
			break
	var pv_letgo: Dictionary = pv_duel2.choices.filter(func(chx): return str(chx.label) == "Let them go")[0]
	pv_letgo.fn.call()
	check(Game.state.clients.is_empty(), "Ziehen lassen: der Klient verlässt die Agentur")
	check(Game.state.rivals.any(func(r): return r.clients.has("monroe")), "Der Rivale übernimmt den Klienten")

	# Comeback: Berechtigung, Start, Auflösung
	Game.new_game("Comeback", 1950)
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null})
	var cb_c: Dictionary = Game.state.clients[0]
	check(not Game.comeback_possible(cb_c), "Aufsteigender Star ist kein Comeback-Kandidat")
	var cb_actor: Dictionary = Game.actor_by_id[cb_c.aid]
	Game.state.year = float(cb_actor.peak) + 10.0
	cb_c.fame = 25.0
	check(Game.comeback_possible(cb_c), "Nach dem Zenit mit tiefem Ruhm: Comeback möglich")
	var cb_cash0 := float(Game.state.agency.cash)
	Game.launch_comeback(int(cb_c.id))
	check(float(Game.state.agency.cash) < cb_cash0, "Comeback-Kampagne kostet Budget")
	check(bool(Game.state.productions[-1].get("comeback", false)) and bool(cb_c.flags.get("comebackActive", false)), "Comeback-Produktion ist markiert")
	check(not Game.comeback_possible(cb_c), "Nur ein Comeback-Versuch zugleich")
	var cb_prod: Dictionary = Game.state.productions[-1]
	Game.state.market = 2.5
	seed(21)
	var cb_fame0 := float(cb_c.fame)
	Game.release_film(cb_prod)
	check(float(cb_c.fame) >= cb_fame0 + 10.0, "Gelungenes Comeback hebt den Ruhm deutlich")
	check(bool(cb_c.flags.get("comebackDone", false)) and not cb_c.flags.has("comebackActive"), "Das Comeback ist verbraucht — ein Versuch pro Klient")
	Game.state.market = 1.0

	# FYC-Kampagnen: Saisonfenster, Boost mit Kappung, Reset nach der Zeremonie
	Game.new_game("FYC", 1950)
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null})
	var fy_c: Dictionary = Game.state.clients[0]
	Game.state.released.append({"title": "Class Film", "year": 1950, "quality": 82,
		"roles": [{"type": "lead", "filled": {"clientId": int(fy_c.id)}}]})
	Game.state.month = 5
	check(not Game.fyc_eligible(fy_c), "Außerhalb der Saison keine FYC-Kampagne")
	Game.state.month = 11
	check(Game.fyc_eligible(fy_c), "Hauptrolle im Klassenjahr macht kampagnenfähig")
	var fy_cash0 := float(Game.state.agency.cash)
	Game.fyc_campaign(int(fy_c.id), false)
	check(absf(float(fy_c.campaign) - Balance.FYC_SMALL_BOOST) < 0.001 and float(Game.state.agency.cash) < fy_cash0, "Trade-Ads buchen Kosten und Boost")
	Game.fyc_campaign(int(fy_c.id), true)
	Game.fyc_campaign(int(fy_c.id), true)
	check(float(fy_c.campaign) <= Balance.FYC_CAP + 0.001, "FYC-Boost ist gekappt")
	Game.state.year = 1951
	Game.state.month = 2
	var fy_award = Game.awards_ceremony()
	check(fy_award != null and absf(float(fy_c.campaign)) < 0.001, "Zeremonie verbraucht die Kampagne (Reset auf 0)")

	# Power-Couples & Feuds im Roster
	Game.new_game("Paare", 1950)
	check(not Game.start_negotiation("wayne").get("locked", true) or Game.sign_client({"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null}).get("accepted", false) == false, "Gescheiterte Anbahnung hinterlässt keine stale Verhandlung")
	Game.state.clients.clear()
	var pr_pool: Array = Game.available_actors().filter(func(a): return Util.fame_at(a, Game.state.year) <= 55).slice(0, 12)
	var pair_a := ""
	var pair_b := ""
	for pi in pr_pool.size():
		for pj in range(pi + 1, pr_pool.size()):
			if pair_a == "" and int(Game.chemistry(str(pr_pool[pi].id), str(pr_pool[pj].id)).personal) >= -1:
				pair_a = str(pr_pool[pi].id)
				pair_b = str(pr_pool[pj].id)
	check(pair_a != "", "Ein verfügbares Paar mit tragfähiger Basis-Chemie existiert")
	Game.start_negotiation(pair_a)
	Game.sign_client({"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null})
	Game.start_negotiation(pair_b)
	Game.sign_client({"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null})
	var pc1: Dictionary = Game.state.clients[0]
	var pc2: Dictionary = Game.state.clients[1]
	check(str(pc1.aid) == pair_a and str(pc2.aid) == pair_b, "Beide Partner sind im Roster")
	Game.state.history_pairs[Game.pair_key(pair_a, pair_b)] = {"n": 3, "p": 8}
	var pair_events: Array = []
	Game._tick_roster_pairs(pair_events)
	check(pair_events.size() == 1 and str(pair_events[0].title) == "More than chemistry", "Starke Chemie + gemeinsame Filme ⇒ Couple-Ereignis")
	pair_events[0].choices[0].fn.call()
	check(str(pc1.flags.get("coupleWith", "")) == pair_b and str(pc2.flags.get("coupleWith", "")) == pair_a, "Traumpaar ist beidseitig verankert")
	var pair_role1 := {"type": "lead", "gender": str(Game.actor_by_id[pair_b].g), "minFame": 5, "ageMin": -100, "ageMax": 999, "fee": 30000, "filled": {"clientId": int(pc2.id), "fee": 30000}, "rejected": []}
	var pair_role2 := {"type": "support", "gender": str(Game.actor_by_id[pair_a].g), "minFame": 5, "ageMin": -100, "ageMax": 999, "fee": 12000, "filled": null, "rejected": []}
	var pair_cast := {"id": 9400, "studioId": "mgm", "title": "P", "genre": "drama", "prestige": 1, "budget": 800000, "deadline": 8, "qualityMod": 0.0, "roles": [pair_role1, pair_role2]}
	var fit_with := Game.fit_score(pair_cast, pair_role2, pc1)
	pc1.flags.erase("coupleWith")
	var fit_without := Game.fit_score(pair_cast, pair_role2, pc1)
	check(fit_with > fit_without, "Power-Couple: gemeinsames Plakat gibt Casting-Bonus")
	pc1.flags["feudWith"] = pair_b
	var pair_elig: Array = Game.eligible_clients(pair_cast, pair_role2)
	check(not pair_elig.any(func(e): return int(e.c.id) == int(pc1.id)), "Feud: gemeinsame Besetzung ist blockiert")

	# Package-Deal: fester Seed macht den Chance-Wurf deterministisch,
	# beide Gagen liegen 12 % über dem regulären Satz.
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null})
	Game.start_negotiation("gkelly")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null})
	var pk_c1: Dictionary = Game.state.clients[0]
	var pk_c2: Dictionary = Game.state.clients[1]
	var pk_lead := {"type": "lead", "gender": "f", "minFame": 10, "ageMin": 18, "ageMax": 45, "fee": 60000, "filled": null, "rejected": []}
	var pk_supp := {"type": "support", "gender": "f", "minFame": 5, "ageMin": 18, "ageMax": 45, "fee": 20000, "filled": null, "rejected": []}
	var pk_cast := {"id": 9002, "studioId": "mgm", "title": "Package-Test", "genre": "drama", "prestige": 1, "budget": 1200000, "deadline": 8, "qualityMod": 0.0, "roles": [pk_lead, pk_supp]}
	Game.pitch_ctx = {"casting": pk_cast, "roleIdx": 0, "role": pk_lead, "client": pk_c1,
		"fee": Game.role_fee_for(pk_cast, pk_lead, pk_c1), "haggled": false}
	var pk_exp1 := roundi(float(Game.pitch_ctx.fee) * 1.12)
	var pk_exp2 := roundi(float(Game.role_fee_for(pk_cast, pk_supp, pk_c2)) * 1.12)
	seed(1234)
	var pk_res: Dictionary = Game.try_package(1, int(pk_c2.id))
	check(bool(pk_res.get("success", false)), "Package-Deal kommt zustande (Seed 1234)")
	check(pk_lead.filled != null and int(pk_lead.filled.fee) == pk_exp1 and pk_supp.filled != null and int(pk_supp.filled.fee) == pk_exp2, "Package-Deal: beide Gagen +12 %")

	# Box-Office: gleicher Seed → identisches Ergebnis (Determinismus)
	var bo_proto := {"id": 9100, "studioId": "mgm", "title": "Det-Test", "genre": "drama", "prestige": 1, "budget": 1000000, "qualityMod": 0.0, "roles": [
		{"type": "lead", "gender": "m", "filled": {"clientId": null, "name": "NPC A", "talent": 62.0, "fame": 58.0}},
		{"type": "support", "gender": "f", "filled": {"clientId": null, "name": "NPC B", "talent": 55.0, "fame": 30.0}}]}
	seed(4711)
	var bo_a: Dictionary = Game.release_film(bo_proto.duplicate(true))
	seed(4711)
	var bo_b: Dictionary = Game.release_film(bo_proto.duplicate(true))
	check(str(bo_a.text) == str(bo_b.text), "Box-Office: gleicher Seed → gleiches Ergebnis")

	# Flop senkt Heat, Hit steigert Ruhm — die Marktlage erzwingt das Verdikt
	# (Markt 0,2: ratio maximal ~0,9; Markt 2,5: ratio sicher über 2).
	var bh_c: Dictionary = Game.state.clients[0]
	bh_c.heat = 5.0
	var bh_heat := float(bh_c.heat)
	var bh_flop := {"id": 9101, "studioId": "mgm", "title": "Flop-Test", "genre": "drama", "prestige": 0, "budget": 1000000, "qualityMod": 0.0, "roles": [
		{"type": "lead", "gender": "f", "filled": {"clientId": int(bh_c.id), "fee": 50000}}]}
	Game.state.market = 0.2
	seed(99)
	Game.release_film(bh_flop)
	check(float(bh_c.heat) < bh_heat, "Flop senkt den Heat des Klienten")
	var bh_fame := float(bh_c.fame)
	var bh_hit := {"id": 9102, "studioId": "mgm", "title": "Hit-Test", "genre": "drama", "prestige": 2, "budget": 1000000, "qualityMod": 0.0, "roles": [
		{"type": "lead", "gender": "f", "filled": {"clientId": int(bh_c.id), "fee": 50000}}]}
	Game.state.market = 2.5
	seed(99)
	Game.release_film(bh_hit)
	check(float(bh_c.fame) > bh_fame, "Hit steigert den Ruhm des Klienten")
	Game.state.market = 1.0

	# Gebrochenes Klienten-Versprechen: Loyalität und Agentur-Ruf sinken
	Game.new_game("Wortbruch", 1950)
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": "lead12"})
	var wb_c: Dictionary = Game.state.clients[0]
	var wb_loy := float(wb_c.loyalty)
	var wb_rep := int(Game.state.agency.rep)
	wb_c.promises[0].due = Game.mi() - 1
	Game.tick_clients([])
	check(bool(wb_c.promises[0].get("broken", false)), "Überfälliges Klienten-Versprechen gilt als gebrochen")
	check(float(wb_c.loyalty) < wb_loy and int(Game.state.agency.rep) < wb_rep, "Wortbruch: Loyalität und Agentur-Ruf sinken")

	# Emotionsmodell (Teil A): wahre und wahrgenommene Gefühle
	Game.new_game("Emotionen", 1950)
	check(Data.EMOTIONS.size() == 8, "Acht Grundemotionen geladen")
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null})
	var em_c: Dictionary = Game.state.clients[0]
	em_c.mood = 70.0
	em_c.trust = 65.0
	em_c.loyalty = 60.0
	var em_ctx := {"cid": int(em_c.id)}
	var em_true: Dictionary = Emotions.true_state("client", em_ctx)
	check(str(em_true.key) == "warm", "Zufriedener Klient mit Vertrauen ist warm (%s)" % str(em_true.key))
	em_c.promises.append({"type": "lead12", "label": "a lead role within 12 months", "due": Game.mi() - 1, "fulfilled": false, "broken": true})
	em_true = Emotions.true_state("client", em_ctx)
	check(str(em_true.key) == "resentful" and str(em_true.cause).contains("broke your word"), "Gebrochenes Versprechen ⇒ resentful mit konkreter Ursache")
	Game.state.instinct = 0
	Game.state.attributes["menschenkenntnis"] = 80.0
	var em_p80: Dictionary = Emotions.perceived("client", em_ctx)
	check(str(em_p80.key) == "resentful" and not bool(em_p80.wrong) and str(em_p80.cause) != "", "Menschenkenntnis 80: Emotion korrekt + Ursachenzeile")
	Game.state.attributes["menschenkenntnis"] = 20.0
	var em_p20a: Dictionary = Emotions.perceived("client", em_ctx)
	var em_p20b: Dictionary = Emotions.perceived("client", em_ctx)
	check(str(em_p20a.key) == str(em_p20b.key) and bool(em_p20a.wrong) == bool(em_p20b.wrong), "Wahrnehmung ist pro Subjekt und Woche deterministisch")
	check(str(em_p20a.key) == "unreadable" or bool(em_p20a.wrong), "Menschenkenntnis 20: unlesbar oder falsche Nachbaremotion")
	check(str(em_p20a.get("cause", "")) == "", "Unterhalb der höchsten Stufe keine Ursachenzeile")
	if bool(em_p20a.wrong):
		check(str(em_p20a.key) != "resentful" and Emotions.EMO_RING.has(str(em_p20a.key)), "Fehllesung ist eine echte Nachbaremotion")
	var em_ct: Dictionary = Game.state.contacts[0]
	Game.state.promises.append({"id": 99801, "to": str(em_ct.name), "kind": "callback", "status": "broken", "madeMi": Game.mi() - 3, "dueMi": Game.mi() - 1})
	var em_ct_true: Dictionary = Emotions.true_state("contact", {"ctid": int(em_ct.id)})
	check(str(em_ct_true.key) == "resentful", "Kontakt mit gebrochener Zusage ist resentful")
	var em_rv: Dictionary = Game.state.rivals[0]
	em_rv.grudge = 70.0
	var em_rv_true: Dictionary = Emotions.true_state("rival", {"rid": str(em_rv.id)})
	check(str(em_rv_true.key) == "resentful" and int(em_rv_true.intensity) >= 60, "Rivale mit hohem Groll ist resentful")

	# Emotionen im Dialogsystem (Teil A2): Gates, Attribut-Proben, Chip
	var emd_def := {"id": "emo_testdialog", "title": "Test", "start": "opening", "nodes": {
		"opening": {"text": ["…"],
			"reads": {"unreadable": "Nothing.", "likely": "Something.", "clear": "Anger.", "certain": "Anger, and you know why."},
			"choices": [
				{"label": "Only for the warm", "goto": "end", "requires_emotion": ["warm"]},
				{"label": "Only for the resentful", "goto": "end", "requires_emotion": ["resentful"]},
				{"label": "Always there", "goto": "end"},
				{"label": "Probe", "check": {"attr": "verhandlung", "dc": 50, "success": "end", "fail": "end"}}]}}}
	Data.DIALOGS.append(emd_def)
	check(Dialogs.validate_defs().is_empty(), "requires_emotion/reads/check.attr validieren warnungsfrei")
	var emd_view: Dictionary = Dialogs.start("emo_testdialog", em_ctx)
	check(emd_view.choices.size() == 3, "requires_emotion filtert auf die WAHRE Emotion (resentful): %d Antworten" % emd_view.choices.size())
	check(str(emd_view.choices[0].label) == "Only for the resentful", "Das passende Emotions-Gate bleibt sichtbar")
	check(str(emd_view.choices[2].label).begins_with("["), "Attributs-Probe trägt das Event-Label (sichtbare Chance)")
	check(absf(Dialogs.check_p({"attr": "verhandlung", "dc": 50}) - EvEngine.check_chance({"attr": "verhandlung", "dc": 50})) < 0.0001, "Dialog-Probe nutzt DIE Formel der Event-Engine")
	check(str(emd_view.get("read", "")) != "", "Wahrnehmungszeile (reads) wird geliefert")
	Game.state.attributes["menschenkenntnis"] = 80.0
	var emd_view80: Dictionary = Dialogs.start("emo_testdialog", em_ctx)
	check(str(emd_view80.emotion.text).contains("Resentful") and str(emd_view80.emotion.text).contains("because"), "Chip bei Menschenkenntnis 80: Emotion + Ursache")
	check(str(emd_view80.read) == "Anger, and you know why.", "reads: höchste Präzisionsstufe liefert die volle Zeile")
	Game.state.attributes["menschenkenntnis"] = 20.0
	var emd_view20: Dictionary = Dialogs.start("emo_testdialog", em_ctx)
	check(emd_view20.choices.size() == 3, "Gates hängen NICHT an der Wahrnehmung — die Lücke ist gewollt")
	Dialogs.run = null
	var emd_bad := {"id": "emo_baddialog", "title": "T", "start": "opening", "nodes": {
		"opening": {"text": ["…"], "choices": [{"label": "x", "goto": "end", "requires_emotion": ["furious"]}]}}}
	Data.DIALOGS.append(emd_bad)
	check(Dialogs.validate_defs().any(func(w): return str(w).contains("furious")), "Unbekannte Emotion im Gate erzeugt eine Ladewarnung")
	Data.DIALOGS.erase(emd_bad)
	Data.DIALOGS.erase(emd_def)

	# Schlüsselbegegnungen (Teil A3): vier mehrstufige Szenen + Trigger
	Game.new_game("Begegnungen", 1950)
	for beg_id in ["contract_showdown", "poach_defense", "crisis_confession", "studio_summit"]:
		check(Dialogs.has_dialog(str(beg_id)), "Begegnungsbaum geladen: %s" % str(beg_id))
	check(Dialogs.validate_defs().is_empty(), "Alle Begegnungs-Bäume und -Briefe laden warnungsfrei")
	Game.start_negotiation("monroe")
	Game.sign_client({"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null})
	var beg_c: Dictionary = Game.state.clients[0]
	beg_c.loyalty = 30.0
	beg_c.contractEnd = Game.mi()
	var beg_events: Array = []
	Game.tick_clients(beg_events)
	var beg_showdown = null
	for be in beg_events:
		if str(be.get("title", "")).begins_with("Contract talk"):
			beg_showdown = be
	check(beg_showdown != null and str(beg_showdown.choices[0].get("dialog", "")) == "contract_showdown", "Niedrige Loyalität am Vertragsende öffnet die Showdown-Szene")
	check(int(beg_c.contractEnd) > Game.mi(), "Fallback: der Vertrag ist trotzdem verlängert (BalanceSim blockiert nicht)")
	var beg_promises0: int = beg_c.promises.size()
	var beg_view: Dictionary = Dialogs.start("contract_showdown", {"cid": int(beg_c.id)})
	check(str(beg_view.get("emotion", {}).get("text", "")) != "", "Showdown-Szene zeigt den Emotions-Chip")
	beg_view = Dialogs.choose(0)
	beg_view = Dialogs.choose(0)
	check(bool(beg_view.done), "Showdown-Pfad läuft bis zum Endknoten durch")
	check(beg_c.promises.size() == beg_promises0 + 1 and str(beg_c.promises[-1].type) == "lead12", "client_promise-Op legt ein echtes Klienten-Versprechen mit Frist an")
	# Abwerbe-Duell wird ab Ruhm 50 zur Szene
	beg_c.fame = 60.0
	beg_c.loyalty = 30.0
	var beg_poach_events: Array = []
	Rivals.tick_rivals(beg_poach_events, true)
	var beg_duel = null
	for be2 in beg_poach_events:
		if str(be2.get("title", "")).begins_with("Poaching attempt"):
			beg_duel = be2
	check(beg_duel != null and str(beg_duel.choices[0].get("dialog", "")) == "poach_defense", "Abwerbe-Duell ab Ruhm 50: volle Szene steht vorn, Modal bleibt Fallback")
	# Geständnis-Szene: wahres Gerücht ab belief 40, einmal pro Geheimnis
	Scandal.reveal_secret(beg_c, "beziehung", 2)
	Scandal.add_rumor(int(beg_c.id), "Something about a bungalow.", true, "affäre", ["Assistants"], 45.0, true, "beziehung")
	var beg_conf_events: Array = []
	Scandal.tick_rumors(beg_conf_events)
	check(beg_conf_events.any(func(e): return str(e.get("title", "")).begins_with("A confession")), "Wahres Gerücht ab belief 40 löst die Geständnis-Szene aus")
	var beg_conf_events2: Array = []
	Scandal.tick_rumors(beg_conf_events2)
	check(not beg_conf_events2.any(func(e): return str(e.get("title", "")).begins_with("A confession")), "Das Geständnis kommt nur einmal pro Geheimnis")
	# Studio-Gipfel: zwei geplatzte Deals rufen den Boss auf den Plan
	var beg_sid := str(Game.active_studios()[0].id)
	Game.note_deal_burst(beg_sid)
	check(not Game.state.inbox.any(func(l): return str(l.tid) == "studio_summit_invite"), "Ein geplatzter Deal allein ruft den Boss nicht")
	Game.note_deal_burst(beg_sid)
	var beg_letter: Dictionary = {}
	for l in Game.state.inbox:
		if str(l.tid) == "studio_summit_invite":
			beg_letter = l
	check(not beg_letter.is_empty() and str(beg_letter.get("ctx", {}).get("sid", "")) == beg_sid, "Zwei geplatzte Deals: Einladung des Studiobosses mit sid im Kontext")
	var beg_res: Dictionary = Dialogs.letter_choose(int(beg_letter.id), 0)
	check(str(beg_res.get("dialog", "")) == "studio_summit" and str(beg_res.get("ctx", {}).get("sid", "")) == beg_sid, "Brief-Annahme öffnet den Gipfel mit Studio-Kontext")
	Dialogs.start("studio_summit", beg_res.ctx)
	Dialogs.choose(0)
	var beg_summit_end: Dictionary = Dialogs.choose(0)
	check(bool(beg_summit_end.done), "Gipfel-Pfad läuft bis zum Endknoten durch")
	check(Game.state.followups.any(func(fu): return str(fu.get("event", "")) == "summit_package"), "Paket-Zusage plant die Followup-Kette mit Frist")
	var beg_pkg = EvEngine.build_by_id("summit_package", {"sid": beg_sid})
	check(beg_pkg != null, "Followup-Event der Kette baut sich mit Studio-Kontext")
	beg_pkg.choices[0].fn.call()
	check(Game.state.quests.any(func(q): return str(q.id) == "summit_package"), "Die Paket-Kette erscheint als Auftrag im Journal (quest-Block)")

	# Drei Monate zahlungsunfähig → Game Over (als letzter Test, beendet das Spiel)
	Game.new_game("Pleite", 1950)
	Game.state.agency.cash = -5000000.0
	Game.state.agency.debtMonths = 2
	for i in 4:
		Game.state.strikeMonths = 0
		Game.end_week()
	check(Game.state.over, "Drei Monate insolvent → Game Over")

	print("=== FERTIG: %d Fehler ===" % fails)
	get_tree().call_deferred("quit", 1 if fails > 0 else 0)
