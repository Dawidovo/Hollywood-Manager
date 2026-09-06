extends Node
# =====================================================================
# Wochenplaner (aus Game.gd extrahiert): der 21-Slot-Kalender (7 Tage ×
# 3 Abschnitte) für Spieler und Klienten — Slots setzen/füllen, die
# wöchentliche Auswertung samt Klienten-Default-Autoplanung und die
# Presse-Recherche. Autoload "Planner"; liest den Zustand über Game.state.
# =====================================================================

# ---------- Weekly Planner ----------
# 7 Tage × 3 Tagesabschnitte (Vormittag/Nachmittag/Abend) = 21 Slots pro Woche.
# Flaches Array, Index = tag * 3 + abschnitt. Aufgelöst wird wöchentlich in
# end_week(); danach beginnt die Planung der neuen Woche leer.
const PLANNER_SLOTS := 21
const PLANNER_PARTS := ["Morning", "Afternoon", "Evening"]
const PLANNER_DAYS := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

const PLANNER_CLIENT = {
	"erholung": {"name": "Rest", "icon": "🌴", "desc": "Exhaustion −0.6 per slot"},
	"pr": {"name": "PR appointment", "icon": "📸", "desc": "Heat +0.08 per slot, small costs"},
	"training": {"name": "Training", "icon": "🎭", "desc": "Talent grows slowly"},
	"gala": {"name": "Gala", "icon": "🥂", "desc": "Evenings only: chance of favors & contacts"},
	"vorbereitung": {"name": "Preparation", "icon": "📖", "desc": "Next pitch: fit +8 (from 3 slots/week)"},
}
const PLANNER_PLAYER = {
	"scouting": {"name": "Scouting", "icon": "🔭", "desc": "Talent pool assessment gets sharper"},
	"dinner": {"name": "Studio dinner", "icon": "🍽", "desc": "Relations +0.2 per slot with the chosen studio"},
	"pflege": {"name": "Client care", "icon": "🤝", "desc": "Trust +0.15 per slot with the chosen client"},
	"presse": {"name": "Press work", "icon": "🗞", "desc": "Early rumor detection (from 2 slots/week)"},
	"buecher": {"name": "Check the books", "icon": "🧾", "desc": "Office costs −10% (from 3 slots/month)"},
	"weiterbildung": {"name": "Training", "icon": "📚", "desc": "From 3 slots/week your weakest attribute grows"},
	"kolumne": {"name": "Trade column", "icon": "🖋", "desc": "Private honorarium per slot — your own money, from day one"},
}

# Bezahlte Planer-Aktivitäten kosten pro Slot (Basisjahr-Dollar, × Inflation).
const PR_COST_PER_SLOT := 20.0
const GALA_COST_PER_SLOT := 60.0

func _empty_week() -> Array:
	var out: Array = []
	out.resize(PLANNER_SLOTS)
	return out

func ensure_planner() -> void:
	if not Game.state.has("planner"):
		Game.state["planner"] = {"player": _empty_week(), "clients": {}}
	if not Game.state.planner.has("player"):
		Game.state.planner["player"] = _empty_week()
	if not Game.state.planner.has("clients"):
		Game.state.planner["clients"] = {}
	while Game.state.planner.player.size() < PLANNER_SLOTS:
		Game.state.planner.player.append(null)
	if not Game.state.has("plannerMonthCounts"):
		Game.state["plannerMonthCounts"] = {}
	var clients: Dictionary = Game.state.planner.clients
	for c in Game.state.clients:
		var key := str(int(c.id))
		if not clients.has(key):
			clients[key] = _empty_week()
		while clients[key].size() < PLANNER_SLOTS:
			clients[key].append(null)
	for key in clients.keys().duplicate():
		if Game.client(key) == null:
			clients.erase(key)

func planner_slot_set(who: String, cid: int, day: int, part: int, action, target = null) -> void:
	ensure_planner()
	var idx := clampi(day * 3 + part, 0, PLANNER_SLOTS - 1)
	var slot = null
	if action != null:
		slot = {"a": str(action)}
		if target != null:
			slot["t"] = str(target)
	if who == "player":
		Game.state.planner.player[idx] = slot
	else:
		var key := str(cid)
		if not Game.state.planner.clients.has(key):
			Game.state.planner.clients[key] = _empty_week()
		Game.state.planner.clients[key][idx] = slot

# Bequemlichkeit: eine Aktion in alle (oder alle leeren) Slots eines Tracks legen
func planner_fill(who: String, cid: int, action, target = null, only_empty: bool = true) -> void:
	ensure_planner()
	var track: Array = Game.state.planner.player if who == "player" else Game.state.planner.clients.get(str(cid), _empty_week())
	for idx in PLANNER_SLOTS:
		if only_empty and track[idx] != null:
			continue
		var day := int(idx / 3.0)
		var part := idx % 3
		if action != null and who != "player" and str(action) == "gala" and part != 2:
			continue  # Galas finden abends statt
		planner_slot_set(who, cid, day, part, action, target)

# Wöchentliche Auswertung in end_week() VOR den Ereignissen.
# Effekte sind pro Slot skaliert (÷21 gegenüber den alten Monats-Slots),
# damit ein voll geplanter Monat ≈ dem alten 4-Slot-Monat entspricht.
func _apply_planner(_events: Array) -> void:
	ensure_planner()
	var counts: Dictionary = Game.state.get("plannerMonthCounts", {})
	var scouting := 0
	var presse := 0
	var weiterbildung := 0
	var kolumne := 0
	var dinner_slots: Dictionary = {}
	var pflege_slots: Dictionary = {}
	for s in Game.state.planner.player:
		if s == null:
			continue
		var a := str(s.get("a", ""))
		counts[a] = int(counts.get(a, 0)) + 1
		match a:
			"scouting":
				scouting += 1
			"weiterbildung":
				weiterbildung += 1
			"dinner":
				var sid := str(s.get("t", ""))
				if sid != "":
					dinner_slots[sid] = int(dinner_slots.get(sid, 0)) + 1
			"pflege":
				var pcid := str(s.get("t", ""))
				if pcid != "":
					pflege_slots[pcid] = int(pflege_slots.get(pcid, 0)) + 1
			"presse":
				presse += 1
			"kolumne":
				kolumne += 1
			"buecher":
				pass  # zählt über plannerMonthCounts in den Monatsabschluss
	# ~5 Scouting-Slots wirken wie früher eine ganze Scouting-Woche
	Game.state["scoutBonus"] = clampi(roundi(scouting / 5.0), 0, 4)
	for sid in dinner_slots:
		if Game.state.studioRel.has(sid):
			# QA-05: Bruchteile gehen nicht mehr verloren — der Rest unter
			# einem ganzen Punkt wird je Studio übertragen (state.dinnerCarry),
			# damit 5 × 1 Slot dasselbe ergibt wie 1 × 5 Slots (+1).
			var gain := 0.2 * float(dinner_slots[sid]) * Game.backstory_mod("dinner_mult", 1.0)
			var carry := float(Game.state.dinnerCarry.get(sid, 0.0)) + gain
			var whole := int(floor(carry + 0.000001))
			Game.state.dinnerCarry[sid] = carry - float(whole)
			if whole > 0:
				Game.state.studioRel[sid] = clampi(int(Game.state.studioRel[sid]) + whole, 0, 100)
				Game.log_msg("Studio dinner: the relationship with %s deepens (+%d)." % [Game._studio(str(sid)).name, whole], "deal")
	for pcid in pflege_slots:
		var pc = Game.client(pcid)
		if pc != null:
			Game.change_trust(pc, 0.15 * float(pflege_slots[pcid]))
	if presse >= maxi(1, 2 - int(Game.backstory_mod("presse_slot_bonus", 0.0))):
		_planner_presse()
	# Branchenkolumne (Design-Review Punkt 4): frühe PRIVATE Einkommensquelle,
	# damit die Empire-Schiene (Lifestyle/Invest) ab Jahr 1 bespielbar ist.
	# Honorar je Slot: Monatsgehalt/80 — eine volle Kolumnen-Woche ersetzt
	# grob ein Monatsgehalt, kostet dafür die komplette übrige Planung.
	if kolumne > 0:
		var honorar := roundf(Persona.salary() / 80.0 * float(kolumne))
		Persona.book(honorar, "Trade column: %d piece(s)" % kolumne)
		Game.state.player.pubRep = clampf(float(Game.state.player.pubRep) + 0.05 * kolumne, 0.0, 100.0)
		Game.log_msg("Your byline runs in the trades — %s honorarium, and the right people read it." % Util.fmt_money(honorar), "info")
	# Weiterbildung (Chunk 15): ab 3 Slots wächst das schwächste Attribut —
	# kein gezieltes Pumpen, der Manager arbeitet an seiner Schwäche.
	if weiterbildung >= 3 and Game.state.has("attributes") and not Game.state.attributes.is_empty():
		var weakest := ""
		for attr_key in Game.state.attributes:
			if weakest == "" or float(Game.state.attributes[attr_key]) < float(Game.state.attributes[weakest]):
				weakest = str(attr_key)
		Game.attr_gain(weakest, 0.3)
	Game.state["plannerMonthCounts"] = counts
	# Klienten-Wochen auswerten
	for c in Game.state.clients:
		if not Game.is_free(c):
			continue  # Dreh-Wochen sind automatisch belegt
		var slots: Array = Game.state.planner.clients.get(str(int(c.id)), _empty_week())
		var week_counts: Dictionary = {}
		for s in slots:
			# Default-Autoplanung: Erholung bei Erschöpfung > 50, sonst PR
			var action := "erholung" if float(c.exhaustion) > 50.0 else "pr"
			if s != null:
				action = str(s.get("a", action))
			elif action == "pr" and not Game.can_spend(PR_COST_PER_SLOT * Util.infl(Game.state.year)):
				# QA-04 Ersatzplanung: automatische PR ohne Deckung wird zur
				# freien Erholung statt zu stiller Kreditüberziehung.
				action = "erholung"
			week_counts[action] = int(week_counts.get(action, 0)) + 1
		_planner_client_week(c, week_counts)
	# Die neue Woche beginnt mit leerem Plan
	Game.state.planner.player = _empty_week()
	for key in Game.state.planner.clients:
		Game.state.planner.clients[key] = _empty_week()

# QA-04: Wie viele bezahlte Slots deckt der Kreditrahmen noch? Geprüft wird
# gegen die tatsächliche Buchungssumme (inkl. Rundung), von hinten kürzend —
# der letzte bezahlbare Slot läuft, alles danach entfällt ersatzlos.
func _affordable_slots(cost_per_slot: float, wanted: int) -> int:
	var paid := wanted
	while paid > 0 and not Game.can_spend(float(roundi(cost_per_slot * paid))):
		paid -= 1
	return paid

func _planner_client_week(c: Dictionary, counts: Dictionary) -> void:
	var base_weight := Game.client_base_weight(c)
	var weight_start := float(c.get("weightKg", base_weight))
	var weight_next := weight_start
	# Innenleben (Teil C1): Erholung füllt die Ruhe, PR/Galas zehren sie.
	Needs.on_planner_week(c, counts)
	var n_erh := int(counts.get("erholung", 0))
	if n_erh > 0:
		c.exhaustion = clampf(c.exhaustion - 0.6 * n_erh, 0.0, 100.0)
	# QA-04: PR/Galas nur mit Deckung — unbezahlte Slots wirken nicht und
	# werden dem Spieler mit Ursache gemeldet.
	var n_pr := _affordable_slots(PR_COST_PER_SLOT * Util.infl(Game.state.year), int(counts.get("pr", 0)))
	if n_pr < int(counts.get("pr", 0)):
		Game.log_msg("Credit line exhausted: %d of %d PR appointment(s) for %s cancelled — no coverage, no effect." % [int(counts.get("pr", 0)) - n_pr, int(counts.get("pr", 0)), Game.client_name(c)], "bad")
	if n_pr > 0:
		c.heat = clampf(c.heat + 0.08 * n_pr, -10.0, 10.0)
		Game.book(-float(roundi(PR_COST_PER_SLOT * n_pr * Util.infl(Game.state.year))), "pr_recht", "PR appointments: %s" % Game.client_name(c))
	var n_tr := int(counts.get("training", 0))
	if n_tr > 0:
		c.talentBonus = minf(10.0, float(c.get("talentBonus", 0.0)) + 0.015 * n_tr)
		weight_next = move_toward(weight_next, base_weight, 0.05 * n_tr)
	var n_gala := _affordable_slots(GALA_COST_PER_SLOT * Util.infl(Game.state.year), int(counts.get("gala", 0)))
	if n_gala < int(counts.get("gala", 0)):
		Game.log_msg("Credit line exhausted: %d of %d gala evening(s) for %s cancelled — no coverage, no effect." % [int(counts.get("gala", 0)) - n_gala, int(counts.get("gala", 0)), Game.client_name(c)], "bad")
	if n_gala > 0:
		var gala_dir := -1.0 if weight_next < base_weight else 1.0
		weight_next += gala_dir * 0.02 * n_gala
		Game.book(-float(roundi(GALA_COST_PER_SLOT * n_gala * Util.infl(Game.state.year))), "events", "Gala evenings: %s" % Game.client_name(c))
		# Höchstens ein Gefallen pro Woche — Galas sind kein Bauernhof
		if Util.chance(1.0 - pow(0.95, float(n_gala))):
			var kind_s: String = Util.pick(["galaInvite", "extraAudition", "billing"])
			Game.grant_favor(kind_s, Game.favor_contact_for(kind_s))
		else:
			c.heat = clampf(c.heat + 0.05 * n_gala, -10.0, 10.0)
	var n_vor := int(counts.get("vorbereitung", 0))
	if n_vor > 0:
		var fit := 8.0 * minf(1.0, float(n_vor) / 3.0)
		c.flags["prepFit"] = maxf(float(c.flags.get("prepFit", 0.0)), fit)
	if not is_equal_approx(weight_next, weight_start):
		Game.change_client_weight(c, weight_next - weight_start)

func _planner_presse() -> void:
	# Gerücht-Früherkennung: das jüngste unbekannte Gerücht kommt auf den Tisch
	for rumor in Game.state.get("rumors", []):
		if not rumor.get("knownToPlayer", false):
			rumor["knownToPlayer"] = true
			Game.log_msg("Press work: your people hear early what is circulating about %s." % Scandal.rumor_subject_name(rumor), "info")
			return
	# Nichts Neues: das stärkste bekannte Gerücht verliert etwas Zugkraft
	var worst = null
	for rumor in Game.state.get("rumors", []):
		if worst == null or float(rumor.belief) > float(worst.belief):
			worst = rumor
	if worst != null:
		worst.belief = maxf(0.0, float(worst.belief) - 5.0)


# =====================================================================
# Bewertungs-Cluster
# (Script Coverage · Das perfekte Rollen-Karrierebrett)
# =====================================================================

# ---------- Feature C: Script Coverage ----------
# Einmal im Monat (≈60 %, mindestens einmal pro Quartal) legt das Lektorat
# ein Coverage-Blatt auf den Schreibtisch: eine verdichtete Einschätzung zu
# einem Casting, das erst NÄCHSTEN Monat sichtbar ausgeschrieben wird.
# Der Spieler setzt wenige Marker (Prognosen) auf Aussagen des Blattes.

