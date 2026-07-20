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

	# 18. Drei Wahrheiten: Öffentlichkeit und Branche wirken getrennt
	Game.new_game("Drei Wahrheiten", 1950)
	Game.start_negotiation("monroe")
	Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
	var truth_client: Dictionary = Game.state.clients[0]
	var truth_fame := float(truth_client.fame)
	var industry_rumor := Game.add_rumor(int(truth_client.id), "Studios zweifeln intern an der Verlässlichkeit.", false, "wechsel", ["Studios"], 5.0, true, "", 70.0)
	Game.tick_rumors([], false)
	check(industry_rumor.industryImpactApplied and not industry_rumor.impactApplied, "Branchenwissen wird ohne öffentliche Schlagzeile wirksam")
	check(absf(float(truth_client.fame) - truth_fame) < 0.01 and Game.rumor_fit_penalty(truth_client) >= 12.0, "Branchenwissen schadet Casting, nicht Ruhm")
	var public_rumor := Game.add_rumor(int(truth_client.id), "Die Presse verbreitet eine öffentliche Geschichte.", false, "skandal", ["Journalisten"], 70.0, true, "", 5.0)
	Game.tick_rumors([], false)
	check(public_rumor.impactApplied and not public_rumor.industryImpactApplied, "Öffentlicher Glaube wirkt ohne Branchenmehrheit")
	check(float(truth_client.fame) < truth_fame, "Öffentliche Geschichte verändert Ruhm/Image")

	# 19. Zeitung: echte Simulationsdaten, Kategorien und anonymes Blind Item
	var news_prod: Dictionary = Game.quick_production(truth_client, {"genre":"drama", "prestige":3, "qualityMod":10.0}).prod
	Game.release_film(news_prod)
	Game.state.productions.erase(news_prod)
	Game.add_rumor(int(truth_client.id), "Marilyn Monroe werde in einem Bungalow beobachtet.", false, "affäre", ["Journalisten", "Partygäste"], 45.0, true, "", 20.0)
	Game.tick_rivals([], true)
	var issue: Dictionary = Newspaper.build_newspaper()
	var categories: Dictionary = {}
	var blind_text := ""
	for headline in issue.headlines:
		categories[str(headline.cat)] = true
		if str(headline.cat) == "Blind Item":
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
	check(str(narrative_client.narrative.status) == "aktiv" and narrative_result.contains("Pressemappe"), "Narrativ ausgerufen und PR-Budget gebucht")
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
	Game.tick_rivals([], true)
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
	check(float(Game.state.identity.kuenstlerisch) == 12.0 and Game.identity_top_labels().has("künstlerisch"), "Identität zählt konkrete Verhaltensmuster")
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
	var pr = Game.add_prediction("star", int(Game.state.clients[0].id), true, Game.mi() - 1, "Test-Star-Prognose")
	Game.tick_predictions([])
	check(bool(pr.resolved) and int(Game.state.instinct) == inst_before - 1, "Falsche Prognose: Instinkt −1 (%d → %d)" % [inst_before, int(Game.state.instinct)])
	var pr2 = Game.add_prediction("star", int(Game.state.clients[0].id), false, Game.mi() - 1, "Test-Prognose 2")
	Game.tick_predictions([])
	check(bool(pr2.resolved) and int(Game.state.instinct) == inst_before + 2, "Richtige Prognose: Instinkt +3 (→ %d)" % int(Game.state.instinct))
	Game.state.instinct = 5
	var pr3 = Game.add_prediction("star", int(Game.state.clients[0].id), true, Game.mi() - 1, "Frust-Deckel-Test")
	Game.tick_predictions([])
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
	var ps_entries: Array = Game.state.ledger.filter(func(e): return str(e.text).contains("Gewinnbeteiligung"))
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
	for w in 4:
		Game.planner_slot_set("client", int(pl_client.id), w, "erholung")
	var dinner_studio: Dictionary = Game.active_studios()[0]
	var rel_before := int(Game.state.studioRel[dinner_studio.id])
	Game.planner_slot_set("player", 0, 0, "dinner", dinner_studio.id)
	Game._apply_planner([])
	check(float(pl_client.exhaustion) <= 32.01, "Erholung senkt Erschöpfung (80 → %0.0f)" % pl_client.exhaustion)
	check(int(Game.state.studioRel[dinner_studio.id]) == rel_before + 4, "Studio-Dinner: Beziehung +4")

	# 32. Save/Load-Roundtrip aller Simulations-Felder
	Game.state.instinct = 42
	Game.state.history_pairs["t1|t2"] = {"n": 2, "p": 3}
	Game.save_game()
	Game.state = null
	check(Game.load_game(), "Simulations-Spielstand geladen")
	check(int(Game.state.instinct) == 42, "Instinkt überlebt Save/Load")
	check(Game.state.has("predictions") and Game.state.has("planner") and Game.state.planner.has("player"), "Prognosen & Planer überleben Save/Load")
	check(str(Game.state.planner.player[0].get("a", "")) == "dinner", "Planer-Slots überleben Save/Load")
	check(int(Game.state.history_pairs.get("t1|t2", {}).get("p", 0)) == 3, "Chemie-Historie überlebt Save/Load")
	check(Game.state.clients[0].has("clauses") and Game.state.clients[0].has("exclusiveStudio"), "Klausel- & Exklusiv-Felder migriert")

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
