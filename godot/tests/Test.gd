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
	# Volle 21-Slot-Erholungswoche (7 Tage × 3 Abschnitte)
	Game.planner_fill("client", int(pl_client.id), "erholung", null, false)
	var dinner_studio: Dictionary = Game.active_studios()[0]
	var rel_before := int(Game.state.studioRel[dinner_studio.id])
	for d in 5:
		Game.planner_slot_set("player", 0, d, 0, "dinner", dinner_studio.id)
	Game._apply_planner([])
	check(float(pl_client.exhaustion) <= 68.01, "Volle Erholungswoche senkt Erschöpfung (80 → %0.1f)" % pl_client.exhaustion)
	check(int(Game.state.studioRel[dinner_studio.id]) == rel_before + 1, "Studio-Dinner: 5 Abende ⇒ Beziehung +1")
	check(Game.state.planner.player[0] == null, "Planer beginnt die neue Woche leer")

	# 32. Save/Load-Roundtrip aller Simulations-Felder
	Game.planner_slot_set("player", 0, 2, 1, "scouting")
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
	Game._issue_coverage()
	var sheet: Dictionary = Game.state.coverage.current
	check(sheet != null and sheet.has("castingRef"), "Coverage-Blatt liegt auf dem Schreibtisch")
	check(sheet.statements.size() >= 4, "Coverage erzeugt mindestens 4 Aussagen aus Sim-Daten (%d)" % sheet.statements.size())
	var cov_casting = Game._casting(sheet.castingRef)
	check(cov_casting != null and bool(cov_casting.get("hidden", false)), "Coverage-Casting bleibt einen Monat verdeckt")
	var pred_n0: int = Game.state.predictions.size()
	var mark_msg := Game.coverage_mark(0, "schwach")
	check(Game.state.predictions.size() == pred_n0 + 1 and str(Game.state.predictions[-1].type) == "coverage", "Marker legt Coverage-Prognose an")
	check(mark_msg.contains("Marker gesetzt"), "Marker-Setzen bestätigt")
	Game.coverage_mark(1, "sicher")
	check(Game.coverage_mark(2, "prestige").contains("Keine Marker"), "Marker-Kontingent begrenzt (%d)" % int(sheet.markersMax))
	# Auflösung beim Release: richtig +3, falsch fällt nie unter 5
	var cov_fake := {"id": 4242, "title": "Testfilm", "genre": "drama", "prestige": 1, "budget": 1000.0,
		"qualityMod": 0.0, "signals": [], "studioId": str(Game.active_studios()[0].id),
		"roles": [{"type": "lead", "gender": "f", "minFame": 10, "ageMin": 18, "ageMax": 99, "fee": 1, "cutRisk": true, "filled": {"npc": true, "name": "X", "talent": 50, "fame": 30}, "rejected": []}]}
	var inst0 := int(Game.state.instinct)
	var pr_weak := Game.add_prediction("coverage", {"castingId": 4242, "cat": "schwach", "roleIdx": 0, "sheetId": int(sheet.id)}, true, Game.mi() + 9, "Coverage-Test schwach")
	Game._resolve_release_predictions(cov_fake, 0.5, {}, 50)
	check(bool(pr_weak.resolved) and bool(pr_weak.correct) and int(Game.state.instinct) == inst0 + 3, "Richtiger Marker: Instinkt +3 (%d → %d)" % [inst0, int(Game.state.instinct)])
	Game.state.instinct = 5
	var pr_pres := Game.add_prediction("coverage", {"castingId": 4242, "cat": "prestige", "roleIdx": 0, "sheetId": int(sheet.id)}, true, Game.mi() + 9, "Coverage-Test prestige")
	Game._resolve_release_predictions(cov_fake, 0.5, {}, 50)
	check(bool(pr_pres.resolved) and not bool(pr_pres.correct) and int(Game.state.instinct) == 5, "Falscher Marker: Instinkt fällt nie unter 5")
	# Schnitt-Auflösung: Wurf triggert, Release löst die Prognose auf
	var cut_hit := false
	for i in 80:
		if Game._coverage_cut_roll(cov_fake, cov_fake.roles[0]):
			cut_hit = true
			break
	check(cut_hit, "Schnitt-Wurf triggert bei markierter Rolle (cutRisk)")
	var cov_qp: Dictionary = Game.quick_production(cov_client, {"genre": "drama", "prestige": 1})
	var cov_prod: Dictionary = cov_qp.prod
	var pr_cut := Game.add_prediction("coverage", {"castingId": int(cov_prod.id), "cat": "schnitt", "roleIdx": 0, "sheetId": int(sheet.id)}, true, Game.mi() + 9, "Coverage-Test schnitt")
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
	check(Game.state.pressFeed.any(func(p): return str(p.text).contains("Neuerfindung")), "Titelstory „Die Neuerfindung des …“ im Pressespiegel")
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
	Game._issue_coverage()
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
	check(chem_casting.get("signals", []).any(func(s): return str(s.t) == "Die Chemie stimmt"), "Beste Paarung merkt das Set-Signal „Die Chemie stimmt“ vor")
	var pos_signal := Game.chemistry_signal(7, false, "test_pos")
	var neg_signal := Game.chemistry_signal(-7, false, "test_neg")
	check(int(pos_signal.sign) > 0 and (str(pos_signal.text).contains("vervollständigen") or str(pos_signal.text).contains("Takt")), "Positive Signal-Prosa passt zum Vorzeichen des screen-Werts")
	check(int(neg_signal.sign) < 0 and (str(neg_signal.text).contains("weicht") or str(neg_signal.text).contains("Abstand")), "Negative Signal-Prosa passt zum Vorzeichen des screen-Werts")

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
	Game.end_week()
	check(int(wt_prod.weeksLeft) == 1, "Produktion zählt in Wochen herunter")
	var wt_rel: int = Game.state.released.size()
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
	Game.ensure_planner()
	check(Game.state.planner.player.size() == 21, "Planer auf 21 Slots erweitert")

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
		{"death": null, "films": [], "ethnicity": "white", "genres": [], "ego": 50},
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
	check(ee_chain != null and str(ee_chain.title) == "Die Prüfung zieht Kreise", "EvEngine: Kettenglied per id+ctx gebaut")
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
	var bs_rumor := Game.add_rumor("agency", "Testgerücht aus dem Hinterzimmer.", false, "skandal")
	check(bool(bs_rumor.knownToPlayer), "Kolumnist: Neues Gerücht ist sofort bekannt")

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
