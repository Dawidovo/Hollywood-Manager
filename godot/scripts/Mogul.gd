extends Node
# =====================================================================
# Hollywood Manager — The manager as an economic actor (Features 5–9).
# Covers: real estate & status purchases with running private costs,
# an experience system that unlocks new perception & action options,
# the stock ticker & film stakes (with insider tips and conflicts of
# interest), backroom deals with witnesses/paper trails/expiry, and
# the partner/takeover/mogul endgame.
# Data-driven: homes, purchases, skills, stocks and deal templates come
# from data/*.json and can be extended via user://data/ mods.
# All amounts are in 1925 dollars and scaled with Game.infl().
# =====================================================================

const STOCK_HIST_MAX := 24
const TRADES_MAX := 30
const SKILL_LOG_MAX := 8
const PARTNER_SHARE := 0.1
const STUDIO_STAKE_DIVIDEND := 0.03


func _st() -> Dictionary:
	return Game.state


func _p() -> Dictionary:
	return Game.state.player


# =====================================================================
# State setup & migration
# =====================================================================
func init_state() -> void:
	var st := _st()
	st["skills"] = {"xp": {}, "unlocked": [], "log": []}
	st["estate"] = {"home": "room", "owned": [], "ownedMeta": {}, "expectNoted": -1}
	st["invest"] = {"holdings": {}, "avgCost": {}, "prices": {}, "hist": {}, "tips": [], "trades": [], "advisor": null, "crashNoted": false}
	st["filmStakes"] = []
	st["backroom"] = []
	st["endgame"] = {"partnerShare": 0.0, "mogulShown": false, "takeovers": [], "studioStakes": {}}
	ensure_prices()


# Migration: retrofit all Feature-5–9 fields on old saves.
func ensure_all() -> void:
	var st := _st()
	if st == null:
		return
	if not st.has("skills") or not (st.skills is Dictionary):
		st["skills"] = {"xp": {}, "unlocked": [], "log": []}
	for key in ["xp", "unlocked", "log"]:
		if not st.skills.has(key):
			st.skills[key] = {} if key == "xp" else []
	if not st.has("estate") or not (st.estate is Dictionary):
		st["estate"] = {"home": "room", "owned": [], "ownedMeta": {}, "expectNoted": -1}
	for key in [["home", "room"], ["owned", []], ["ownedMeta", {}], ["expectNoted", -1]]:
		if not st.estate.has(key[0]):
			st.estate[key[0]] = key[1]
	if not st.has("invest") or not (st.invest is Dictionary):
		st["invest"] = {}
	for key in [["holdings", {}], ["avgCost", {}], ["prices", {}], ["hist", {}], ["tips", []], ["trades", []], ["advisor", null], ["crashNoted", false]]:
		if not st.invest.has(key[0]):
			st.invest[key[0]] = key[1]
	if not st.has("filmStakes"):
		st["filmStakes"] = []
	if not st.has("backroom"):
		st["backroom"] = []
	if not st.has("endgame") or not (st.endgame is Dictionary):
		st["endgame"] = {}
	for key in [["partnerShare", 0.0], ["mogulShown", false], ["takeovers", []], ["studioStakes", {}]]:
		if not st.endgame.has(key[0]):
			st.endgame[key[0]] = key[1]
	ensure_prices()


# =====================================================================
# Feature 6 — Experience & specializations
# Experience unlocks new perception and action options, no dull % boni.
# Failures teach too: several hooks grant XP on setbacks.
# =====================================================================
func xp(field: String) -> float:
	var st := _st()
	if st == null or not st.has("skills"):
		return 0.0
	return float(st.skills.xp.get(field, 0.0))


func level_of_xp(v: float) -> int:
	var lvl := 0
	for i in Data.SKILL_THRESHOLDS.size():
		if v >= float(Data.SKILL_THRESHOLDS[i]):
			lvl = i
	return lvl


func level(field: String) -> int:
	return level_of_xp(xp(field))


func has_ability(id_s: String) -> bool:
	if _st() == null or not _st().has("skills"):
		return false
	for a in Data.SKILL_ABILITIES:
		if str(a.id) == id_s:
			return level(str(a.field)) >= int(a.level)
	return false


# The next ability this field will unlock (empty dict = none left).
func next_ability(field: String) -> Dictionary:
	var lvl := level(field)
	var best := {}
	for a in Data.SKILL_ABILITIES:
		if str(a.field) != field or int(a.level) <= lvl:
			continue
		if best.is_empty() or int(a.level) < int(best.level):
			best = a
	return best


func grant_xp(field: String, amount: float, why: String = "") -> void:
	var st := _st()
	if st == null or not st.has("skills") or not Data.SKILL_FIELDS.has(field) or amount <= 0.0:
		return
	var before := level(field)
	st.skills.xp[field] = xp(field) + amount
	st.skills.log.push_front({"mi": Game.mi(), "field": field, "amount": amount, "why": why})
	while st.skills.log.size() > SKILL_LOG_MAX:
		st.skills.log.pop_back()
	var after := level(field)
	if after <= before:
		return
	var fname := str(Data.SKILL_FIELDS[field].name)
	Game.log_msg("Experience: your %s reaches level %d." % [fname, after], "history")
	for a in Data.SKILL_ABILITIES:
		if str(a.field) == field and int(a.level) == after and not st.skills.unlocked.has(str(a.id)):
			st.skills.unlocked.append(str(a.id))
			Game.log_msg("New ability: %s — %s" % [str(a.name), str(a.desc)], "history")


# =====================================================================
# Feature 5 — Real estate, status purchases & running private costs
# =====================================================================
func home_id() -> String:
	return str(_st().estate.get("home", "room"))


func home_def() -> Dictionary:
	return Data.ESTATE_HOME_BY_ID.get(home_id(), Data.ESTATE_HOME_BY_ID.get("room", {}))


func home_price(id_s: String) -> float:
	return roundf(float(Data.ESTATE_HOME_BY_ID[id_s].price) * Game.infl(_st().year))


# Resale value of the current home (market cycles matter).
func home_value() -> float:
	var h := home_def()
	if float(h.get("price", 0)) <= 0.0:
		return 0.0
	return roundf(float(h.price) * Game.infl(_st().year) * float(_st().market) * 0.9)


# Why buying this home is impossible right now ("" = fine).
func home_blocked_reason(id_s: String) -> String:
	if not Data.ESTATE_HOME_BY_ID.has(id_s):
		return "Unknown address"
	if id_s == home_id():
		return "You already live here"
	var need := home_price(id_s) - home_value()
	if float(_p().cash) < need:
		return "Privately short on cash (%s needed)" % Game.fmt_money(maxf(need, 0.0))
	return ""


# Moving: the old home is sold automatically. Moving DOWN a tier costs
# public standing — whoever lived like a mogul cannot quietly shrink.
func buy_home(id_s: String) -> String:
	var reason := home_blocked_reason(id_s)
	if reason != "":
		return reason
	var st := _st()
	var old := home_def()
	var new_home: Dictionary = Data.ESTATE_HOME_BY_ID[id_s]
	var sale := home_value()
	if sale > 0.0:
		Persona.book(sale, "Sold: %s" % str(old.name))
	Persona.book(-home_price(id_s), "Bought: %s" % str(new_home.name))
	st.estate.home = id_s
	if int(new_home.tier) < int(old.get("tier", 0)):
		_p().pubRep = clampf(float(_p().pubRep) - 6.0, 0.0, 100.0)
		Game.press_event("Society", "Downsizing: word is money has gotten tight around %s." % str(st.agency.name))
		Game.log_msg("Moving down is noticed: public reputation −6.", "bad")
	else:
		Game.log_msg("New address: %s %s." % [str(new_home.icon), str(new_home.name)], "info")
		Game.press_event("Society", "New keys: the head of %s now resides at a finer address." % str(st.agency.name))
	return ""


func owns(pid: String) -> bool:
	return _st() != null and _st().has("estate") and _st().estate.owned.has(pid)


func purchase_price(pid: String) -> float:
	return roundf(float(Data.ESTATE_PURCHASE_BY_ID[pid].price) * Game.infl(_st().year))


func purchase_blocked_reason(pid: String) -> String:
	if not Data.ESTATE_PURCHASE_BY_ID.has(pid):
		return "Unknown"
	if owns(pid):
		return "Already yours"
	var def: Dictionary = Data.ESTATE_PURCHASE_BY_ID[pid]
	if int(_st().year) < int(def.get("from", 0)):
		return "Not available in this era yet"
	if int(def.get("req_tier", 0)) > int(home_def().get("tier", 0)):
		return "Your home is too small for this"
	if float(_p().cash) < purchase_price(pid):
		return "Privately short on cash"
	return ""


func buy_purchase(pid: String) -> String:
	var reason := purchase_blocked_reason(pid)
	if reason != "":
		return reason
	var def: Dictionary = Data.ESTATE_PURCHASE_BY_ID[pid]
	Persona.book(-purchase_price(pid), "Bought: %s" % str(def.name))
	_st().estate.owned.append(pid)
	_st().estate.ownedMeta[pid] = {"boughtMi": Game.mi()}
	Game.log_msg("%s %s — the lifestyle grows, and so do the running costs." % [str(def.icon), str(def.name)], "info")
	return ""


# Resale value: art appreciates over the months held, most goods lose
# value, memberships are simply cancelled without a refund.
func purchase_value(pid: String) -> float:
	var def: Dictionary = Data.ESTATE_PURCHASE_BY_ID[pid]
	var resale := float(def.get("resale", 0.0))
	if resale <= 0.0:
		return 0.0
	var months := Game.mi() - int(_st().estate.ownedMeta.get(pid, {}).get("boughtMi", Game.mi()))
	var appreciation := 1.0 + float(def.get("appreciation", 0.0)) * float(maxi(months, 0))
	return roundf(float(def.price) * Game.infl(_st().year) * resale * appreciation * float(_st().market))


func sell_purchase(pid: String) -> void:
	if not owns(pid):
		return
	var def: Dictionary = Data.ESTATE_PURCHASE_BY_ID[pid]
	var value := purchase_value(pid)
	if value > 0.0:
		Persona.book(value, "Sold: %s" % str(def.name))
		Game.log_msg("Sold: %s brings in %s." % [str(def.name), Game.fmt_money(value)], "info")
	else:
		Game.log_msg("Cancelled: %s." % str(def.name), "info")
	_st().estate.owned.erase(pid)
	_st().estate.ownedMeta.erase(pid)


# Sum of one effect key across home + owned purchases.
func effect_sum(key: String) -> float:
	var total := float(home_def().get("effects", {}).get(key, 0.0))
	for pid in _st().estate.owned:
		total += float(Data.ESTATE_PURCHASE_BY_ID.get(pid, {}).get("effects", {}).get(key, 0.0))
	return total


func _effect_mult(key: String) -> float:
	var mult := 1.0
	var home_m = home_def().get("effects", {}).get(key)
	if home_m != null:
		mult *= float(home_m)
	for pid in _st().estate.owned:
		var m = Data.ESTATE_PURCHASE_BY_ID.get(pid, {}).get("effects", {}).get(key)
		if m != null:
			mult *= float(m)
	return mult


func upkeep_total() -> float:
	var total := float(home_def().get("upkeep", 0))
	for pid in _st().estate.owned:
		total += float(Data.ESTATE_PURCHASE_BY_ID.get(pid, {}).get("upkeep", 0))
	return roundf(total * Game.infl(_st().year))


# ---------- Hooks used by Persona (travel & contact channels) ----------
func travel_cost_mult(dest: String) -> float:
	if dest == "ny" and effect_sum("nyTravelFree") > 0.0:
		return 0.0
	return _effect_mult("travelCostMult")


func travel_energy_mult() -> float:
	return _effect_mult("travelEnergyMult")


func channel_cost_mult(key: String) -> float:
	if key == "club":
		return _effect_mult("clubCostMult")
	return 1.0


func channel_ap(key: String) -> int:
	var ap := int(Data.CONTACT_CHANNELS[key].ap)
	if key == "club" and has_ability("open_doors"):
		ap = mini(ap, 1)
	return ap


func paparazzi_mult() -> float:
	var mult := _effect_mult("paparazziMult")
	if has_ability("ghost"):
		mult *= 0.5
	return mult


# ---------- Reception: the villa as a social instrument ----------
func can_host() -> bool:
	return int(home_def().get("capacity", 0)) >= 3 and Persona.can_act("reception")


func reception_cost() -> float:
	return roundf(25.0 * float(home_def().get("capacity", 0)) * Game.infl(_st().year))


func host_reception() -> String:
	if not can_host():
		return ""
	var st := _st()
	if float(_p().cash) < reception_cost():
		return "Privately short on cash — a reception at this address cannot look cheap."
	_p().monthFlags["reception"] = true
	var h := home_def()
	Persona.book(-reception_cost(), "Reception at %s" % str(h.name))
	var guests: Array = st.contacts.duplicate()
	guests.shuffle()
	guests = guests.slice(0, maxi(int(h.capacity) / 2, 2))
	var lines: Array = []
	for ct in guests:
		Network.adjust(ct, {"liking": 2.0, "closeness": 2.5}, false)
		ct.lastMi = Game.mi()
		lines.append(str(ct.name))
	_p().influence = clampf(float(_p().influence) + 1.5, 0.0, 100.0)
	_p().energy = clampf(float(_p().energy) - 5.0, 0.0, 100.0)
	grant_xp("networking", 2.0, "Hosted a reception")
	var text := "An evening at %s %s: %s leave warmer than they arrived (relationship +3, influence +1.5)." % [str(h.icon), str(h.name), ", ".join(lines)]
	if Game.chance(0.3):
		var kind: String = Game.pick(["extraAudition", "billing", "galaInvite", "scriptAccess"])
		var fav: Dictionary = Game.grant_favor(kind, Game.favor_contact_for(kind))
		text += "\n\nOver dessert, a promise: %s owes you a favor (%s)." % [fav["from"].get("name", "?"), str(Game.FAVOR_KINDS[kind].name)]
	if Game.chance(float(h.get("paparazzi", 0.0)) * paparazzi_mult() * 2.0):
		_p().pubRep = clampf(float(_p().pubRep) - 2.0, 0.0, 100.0)
		Game.add_rumor("agency", "Photographers counted the empty bottles outside the party at %s." % str(st.agency.name), true, "skandal", ["Party guests"], 15.0, true)
		text += "\n\n⚠ A photographer waited at the gate — not every picture is flattering (public reputation −2)."
	Game.log_msg("Reception at %s — the town talks about it, mostly kindly." % str(h.name), "info")
	return text


# ---------- Estate ticks ----------
func _tick_estate_week() -> void:
	var e := effect_sum("energyWeekly")
	if e != 0.0:
		_p().energy = clampf(float(_p().energy) + e, 0.0, 100.0)


func _tick_estate_month() -> void:
	var st := _st()
	var p := _p()
	var h := home_def()
	var upkeep := upkeep_total()
	if upkeep > 0.0:
		Persona.book(-upkeep, "Upkeep: home & lifestyle")
	p.pubRep = clampf(float(p.pubRep) + float(h.get("prestige", 0)) * 0.08 + effect_sum("pubRepMonthly"), 0.0, 100.0)
	p.indRep = clampf(float(p.indRep) + effect_sum("indRepMonthly"), 0.0, 100.0)
	p.discretion = clampf(float(p.discretion) + float(h.get("privacy", 0)) * 0.05, 0.0, 100.0)
	p.stress = clampf(float(p.stress) + effect_sum("stressMonthly"), 0.0, 100.0)
	# Paparazzi: a big address draws long lenses.
	if Game.chance(float(h.get("paparazzi", 0.0)) * paparazzi_mult()):
		p.pubRep = clampf(float(p.pubRep) - 2.0, 0.0, 100.0)
		p.discretion = clampf(float(p.discretion) - 3.0, 0.0, 100.0)
		Game.add_rumor("agency", "Long lenses at the driveway: pictures from the private life of %s's boss are making the rounds." % str(st.agency.name), true, "skandal", ["Journalists"], 15.0, true)
		Game.log_msg("Paparazzi outside your home — not every picture is flattering.", "bad")
	# Expectations: a partner in a boarding-house room raises eyebrows.
	var expected := 0
	match int(p.career):
		2: expected = 1
		3: expected = 2
		4, 5: expected = 3
		_: expected = 0
	if int(h.get("tier", 0)) < expected:
		p.pubRep = clampf(float(p.pubRep) - 1.0, 0.0, 100.0)
		p.indRep = clampf(float(p.indRep) - 0.5, 0.0, 100.0)
		if int(st.estate.expectNoted) != int(p.career):
			st.estate.expectNoted = int(p.career)
			Game.log_msg("Your address no longer matches your title — the industry notices things like that.", "bad")


# =====================================================================
# Feature 7a — The stock ticker
# Not a day-trading minigame: interesting through conflicts of interest,
# insider tips and the temptation to bet with money you don't have idle.
# =====================================================================
# Era-filtered companies incl. dynamically listed studio shares.
func stock_defs() -> Array:
	var y := int(_st().year)
	var out: Array = []
	for s in Data.STOCKS:
		if y >= int(s.get("from", 0)) and y <= int(s.get("to", 9999)):
			out.append(s)
	for studio in Game.active_studios():
		out.append({"id": "st_%s" % str(studio.id), "name": "%s (shares)" % str(studio.name), "icon": "🎬",
			"sector": "Studio", "price": 32, "vol": 0.06, "drift": 0.004, "studioId": str(studio.id), "desc": ""})
	return out


func stock_def(id_s: String) -> Dictionary:
	for s in stock_defs():
		if str(s.id) == id_s:
			return s
	return {}


func ensure_prices() -> void:
	var st := _st()
	if st == null or not st.has("invest"):
		return
	for s in stock_defs():
		var id_s := str(s.id)
		if not st.invest.prices.has(id_s):
			st.invest.prices[id_s] = snappedf(float(s.price) * Game.infl(st.year) * Game.rndf(0.85, 1.2), 0.01)
			st.invest.hist[id_s] = [float(st.invest.prices[id_s])]


func price(id_s: String) -> float:
	return float(_st().invest.prices.get(id_s, 0.0))


# Price change vs. last month, in percent (for arrows in the UI).
func trend(id_s: String) -> float:
	var hist: Array = _st().invest.hist.get(id_s, [])
	if hist.size() < 2 or float(hist[hist.size() - 2]) <= 0.0:
		return 0.0
	return (float(hist.back()) / float(hist[hist.size() - 2]) - 1.0) * 100.0


func shares_of(id_s: String) -> int:
	return int(_st().invest.holdings.get(id_s, 0))


func portfolio_value() -> float:
	var total := 0.0
	for id_s in _st().invest.holdings:
		total += float(_st().invest.holdings[id_s]) * price(str(id_s))
	return total


func _note_trade(id_s: String, dir: int) -> void:
	var trades: Array = _st().invest.trades
	trades.append({"id": id_s, "mi": Game.mi(), "dir": dir})
	while trades.size() > TRADES_MAX:
		trades.pop_front()


# Buy for a budget (whole shares only). Returns "" or a blocked reason.
func buy_stock(id_s: String, budget: float) -> String:
	ensure_prices()
	var p := price(id_s)
	if p <= 0.0:
		return "Not listed"
	var n := int(floorf(budget / p))
	if n < 1:
		return "Budget below the share price"
	var cost := snappedf(n * p, 0.01)
	if float(_p().cash) < cost:
		return "Privately short on cash"
	var inv: Dictionary = _st().invest
	var old_n := shares_of(id_s)
	inv.avgCost[id_s] = (float(inv.avgCost.get(id_s, 0.0)) * old_n + cost) / float(old_n + n)
	inv.holdings[id_s] = old_n + n
	Persona.book(-cost, "Bought %d× %s" % [n, str(stock_def(id_s).get("name", id_s))])
	_note_trade(id_s, 1)
	grant_xp("finance", 1.0, "Traded on the exchange")
	return ""


func sell_stock(id_s: String, n: int = -1) -> String:
	var held := shares_of(id_s)
	if held <= 0:
		return "You hold no shares"
	if n < 0 or n > held:
		n = held
	var proceeds := snappedf(n * price(id_s), 0.01)
	var inv: Dictionary = _st().invest
	inv.holdings[id_s] = held - n
	if int(inv.holdings[id_s]) <= 0:
		inv.holdings.erase(id_s)
		inv.avgCost.erase(id_s)
	Persona.book(proceeds, "Sold %d× %s" % [n, str(stock_def(id_s).get("name", id_s))])
	_note_trade(id_s, -1)
	grant_xp("finance", 1.0, "Traded on the exchange")
	return ""


# ---------- Tips: whispers with a due date ----------
func add_tip(company_id: String, dir: int, pct: float, due_mi: int, source: String, insider: bool) -> Dictionary:
	var tip := {"id": Game.next_id(), "companyId": company_id, "dir": dir, "pct": pct,
		"madeMi": Game.mi(), "dueMi": due_mi, "source": source, "insider": insider, "resolved": false}
	_st().invest.tips.append(tip)
	return tip


# A confidential market whisper for club nights & studio dinners.
# Returns a text line for the interaction, or "" if nothing came up.
func maybe_market_tip(ct: Dictionary) -> String:
	ensure_prices()
	var defs := stock_defs()
	if defs.is_empty():
		return ""
	var def: Dictionary = {}
	var insider := false
	if str(ct.get("type", "")) == "studio":
		for s in defs:
			if s.has("studioId") and str(ct.name).contains(str(Game._studio(str(s.studioId)).name)):
				def = s
				insider = true
				break
	if def.is_empty():
		def = Game.pick(defs)
		insider = Game.chance(0.4)
	var dir := 1 if Game.chance(0.65) else -1
	var pct := Game.rndf(0.08, 0.2)
	add_tip(str(def.id), dir, pct, Game.mi() + Game.rndi(1, 3), str(ct.name), insider)
	var flavor := "quietly optimistic about" if dir > 0 else "getting out of"
	var warn := " Officially, you never heard it." if insider else ""
	return "💹 Between two glasses, %s mentions being %s %s.%s" % [str(ct.name), flavor, str(def.name), warn]


# ---------- Advisor: delegating your money ----------
func has_advisor() -> bool:
	return _st() != null and _st().has("invest") and _st().invest.get("advisor") != null


func advisor_fee() -> float:
	if not has_advisor():
		return 0.0
	return roundf((80.0 + float(_st().invest.advisor.skill)) * Game.infl(_st().year))


func hire_advisor() -> void:
	if has_advisor():
		return
	var first: String = Game.pick(Data.NPC_FIRST_M if Game.chance(0.7) else Data.NPC_FIRST_F)
	_st().invest.advisor = {"name": "%s %s" % [first, Game.pick(Data.NPC_LAST)], "skill": Game.rndi(40, 75), "hiredMi": Game.mi()}
	Game.log_msg("%s now manages your money — you save time, and lose a little control." % str(_st().invest.advisor.name), "info")


func fire_advisor() -> void:
	if not has_advisor():
		return
	Game.log_msg("%s clears their desk. The portfolio is your problem again." % str(_st().invest.advisor.name), "info")
	_st().invest.advisor = null


func _tick_advisor_month() -> void:
	if not has_advisor():
		return
	var st := _st()
	var adv: Dictionary = st.invest.advisor
	Persona.book(-advisor_fee(), "Fee: financial manager %s" % str(adv.name))
	# Acts on open (non-insider) tips — the discreet ones stay your call.
	for tip in st.invest.tips:
		if bool(tip.resolved) or bool(tip.insider) or not Game.chance(float(adv.skill) / 100.0):
			continue
		if int(tip.dir) > 0 and float(_p().cash) > 400.0:
			buy_stock(str(tip.companyId), minf(float(_p().cash) * 0.2, 2000.0 * Game.infl(st.year)))
		elif int(tip.dir) < 0 and shares_of(str(tip.companyId)) > 0:
			sell_stock(str(tip.companyId))
	# Questionable positions: delegation means someone else's judgement.
	if Game.chance(0.06) and not st.invest.holdings.is_empty():
		var id_s := str(st.invest.holdings.keys()[0])
		st.invest.prices[id_s] = snappedf(price(id_s) * 0.92, 0.01)
		Game.log_msg("%s put your money into a shaky venture — the position loses 8%%." % str(adv.name), "bad")


# ---------- Monthly market tick ----------
func _tick_invest_month(events: Array) -> void:
	var st := _st()
	ensure_prices()
	var defs := stock_defs()
	var listed: Dictionary = {}
	for s in defs:
		var id_s := str(s.id)
		listed[id_s] = true
		var p := price(id_s)
		p *= 1.0 + float(s.drift) + float(s.vol) * Game.rndf(-1.0, 1.0) + (float(st.market) - 1.0) * 0.25
		st.invest.prices[id_s] = snappedf(maxf(p, 0.5), 0.01)
	# A collapsing market drags the ticker down hard — 1929 hurts twice.
	if float(st.market) < 0.8 and not bool(st.invest.crashNoted):
		st.invest.crashNoted = true
		for id_s in st.invest.prices:
			st.invest.prices[id_s] = snappedf(float(st.invest.prices[id_s]) * 0.72, 0.01)
		Game.log_msg("Black days at the exchange: the ticker falls faster than anyone can read it.", "bad")
		if portfolio_value() > 0.0:
			events.append({"title": "The crash", "text": "The market collapses — your portfolio loses over a quarter of its value overnight.\n\nWhoever needs cash now sells at the worst moment.", "choices": [{"label": "Grit your teeth"}]})
	if float(st.market) >= 0.9:
		st.invest.crashNoted = false
	# Delisted companies (era over): forced sale at the last price.
	for id_s in st.invest.holdings.keys():
		if not listed.has(str(id_s)):
			Game.log_msg("%s disappears from the ticker — your shares are paid out." % str(id_s), "info")
			sell_stock(str(id_s))
	# Tips mature: prices jump, insider trades can come to light.
	for tip in st.invest.tips:
		if bool(tip.resolved) or Game.mi() < int(tip.dueMi):
			continue
		tip.resolved = true
		var id_s := str(tip.companyId)
		if st.invest.prices.has(id_s):
			st.invest.prices[id_s] = snappedf(float(st.invest.prices[id_s]) * (1.0 + float(tip.dir) * float(tip.pct)), 0.01)
		if bool(tip.insider) and _acted_on_tip(tip):
			var discovery := 0.3 if int(st.year) >= 1934 else 0.18
			if has_ability("back_channels"):
				discovery *= 0.7
			if Game.chance(discovery):
				_p().pubRep = clampf(float(_p().pubRep) - 8.0, 0.0, 100.0)
				_p().indRep = clampf(float(_p().indRep) - 5.0, 0.0, 100.0)
				_p().discretion = clampf(float(_p().discretion) - 10.0, 0.0, 100.0)
				Network.memoir("Your trades sat suspiciously close to the news from %s — the town asked questions." % str(stock_def(id_s).get("name", id_s)))
				Game.record_identity("skrupellos", 2.0)
				Game.add_rumor("agency", "Curious timing: %s's boss traded shares right before the news broke." % str(st.agency.name), true, "skandal", ["Journalists", "Studios"], 30.0, true)
				events.append({"title": "Insider trading?", "text": "Your trades sat too close to the news. Nobody can prove anything — yet — but the question alone stains: public reputation −8, industry standing −5.", "choices": [{"label": "Deny everything"}]})
			else:
				grant_xp("discretion", 1.0, "A discreet trade")
	st.invest.tips = st.invest.tips.filter(func(t): return not bool(t.resolved) or Game.mi() - int(t.dueMi) < 2)
	_tick_advisor_month()
	# History for the trend arrows.
	for s in defs:
		var id_s := str(s.id)
		if not st.invest.hist.has(id_s):
			st.invest.hist[id_s] = []
		st.invest.hist[id_s].append(float(st.invest.prices[id_s]))
		while st.invest.hist[id_s].size() > STOCK_HIST_MAX:
			st.invest.hist[id_s].pop_front()


func _acted_on_tip(tip: Dictionary) -> bool:
	for tr in _st().invest.trades:
		if str(tr.id) == str(tip.companyId) and int(tr.mi) >= int(tip.madeMi) and int(tr.mi) <= int(tip.dueMi) and int(tr.dir) == int(tip.dir):
			return true
	return false


# =====================================================================
# Feature 7b — Film stakes: the thematically strongest investment
# =====================================================================
func stake_for(ref_id: int) -> Dictionary:
	for stk in _st().filmStakes:
		if int(stk.refId) == ref_id:
			return stk
	return {}


# Castings (pre-production) and running productions can be financed.
func stake_targets() -> Array:
	var out: Array = []
	for cs in _st().castings:
		if not bool(cs.get("hidden", false)):
			out.append({"ref": cs, "phase": "casting"})
	for prod in _st().productions:
		out.append({"ref": prod, "phase": "production"})
	return out


func stake_cost(target: Dictionary, type_s: String) -> float:
	var pct := 0.05 if type_s == "equity" else 0.02
	return roundf(float(target.get("budget", 0)) * pct)


func stake_blocked_reason(ref_id: int, type_s: String) -> String:
	var target := _stake_ref(ref_id)
	if target.is_empty():
		return "Project unknown"
	if not stake_for(ref_id).is_empty():
		return "You already hold a stake"
	if float(_p().cash) < stake_cost(target, type_s):
		return "Privately short on cash"
	return ""


func _stake_ref(ref_id: int) -> Dictionary:
	for cs in _st().castings:
		if int(cs.id) == ref_id:
			return cs
	for prod in _st().productions:
		if int(prod.id) == ref_id:
			return prod
	return {}


func _own_client_in(target: Dictionary) -> bool:
	for r in target.get("roles", []):
		if r.get("filled") != null and r.filled.get("clientId") != null:
			return true
	return false


func invest_stake(ref_id: int, type_s: String) -> String:
	var reason := stake_blocked_reason(ref_id, type_s)
	if reason != "":
		return reason
	var target := _stake_ref(ref_id)
	var cost := stake_cost(target, type_s)
	Persona.book(-cost, "Film stake: “%s” (%s)" % [str(target.title), "equity" if type_s == "equity" else "profit points"])
	_st().filmStakes.append({"id": Game.next_id(), "refId": ref_id, "title": str(target.title),
		"type": type_s, "amount": cost, "madeMi": Game.mi(), "conflict": _own_client_in(target), "boosted": false})
	grant_xp("finance", 2.0, "Financed a picture")
	Game.log_msg("You put %s of your own money into “%s” — now it's personal." % [Game.fmt_money(cost), str(target.title)], "info")
	return ""


# Marketing/reshoot money: more quality, thrown after the first stake.
func boost_marketing(ref_id: int) -> String:
	var stk := stake_for(ref_id)
	if stk.is_empty() or bool(stk.boosted):
		return "No stake, or already boosted"
	var prod := {}
	for pr in _st().productions:
		if int(pr.id) == ref_id:
			prod = pr
	if prod.is_empty():
		return "Only running productions can take marketing money"
	var cost := roundf(2000.0 * Game.infl(_st().year))
	if float(_p().cash) < cost:
		return "Privately short on cash"
	Persona.book(-cost, "Marketing push: “%s”" % str(prod.title))
	prod.qualityMod = float(prod.get("qualityMod", 0.0)) + 3.0
	stk.boosted = true
	grant_xp("finance", 1.0, "Financed a marketing push")
	Game.log_msg("Fresh money for posters and reshoots: “%s” gets a push." % str(prod.title), "info")
	return ""


# Conflict of interest: you push your own client into a picture you
# financed. Lucrative — and the client may learn the recommendation
# was not selfless. Called from close_deal.
func on_deal_closed(casting: Dictionary) -> void:
	var stk := stake_for(int(casting.id))
	if stk.is_empty() or bool(stk.conflict):
		return
	stk.conflict = true
	Game.record_identity("skrupellos", 1.0)
	Game.log_msg("You place your own client in a picture you financed — nobody knows. Yet.", "info")


# Release settlement: stake payouts, studio-share reactions, dividends,
# and the conflict of interest that may finally surface.
func on_release(prod: Dictionary, revenue: int, ratio: float, _quality: int) -> void:
	var st := _st()
	if st == null or not st.has("filmStakes"):
		return
	var stk := stake_for(int(prod.id))
	if not stk.is_empty():
		var payout := 0.0
		if str(stk.type) == "equity":
			payout = float(stk.amount) * (0.25 + ratio * 0.7)
		else:
			payout = float(stk.amount) * 2.2 * maxf(0.0, ratio - 1.4)
		if has_ability("green_light"):
			payout *= 1.1
		payout = roundf(payout)
		if payout > 0.0:
			Persona.book(payout, "Film stake payout: “%s”" % str(prod.title))
		var profit := payout - float(stk.amount)
		Game.log_msg("Your stake in “%s” settles: %s%s." % [str(prod.title),
			"+" if profit >= 0.0 else "−", Game.fmt_money(absf(profit))], "deal" if profit >= 0.0 else "bad")
		grant_xp("finance", 2.0 + (1.0 if profit > 0.0 else 0.0), "A stake settled")
		if bool(stk.conflict) and Game.chance(0.3):
			for r in prod.roles:
				if r.get("filled") != null and r.filled.get("clientId") != null:
					var c = Game.client(r.filled.clientId)
					if c != null:
						Game.change_trust(c, -12.0)
						c.mood = clampf(float(c.mood) - 8.0, 0.0, 100.0)
						Network.memoir("%s learned that you had money in “%s” — your advice suddenly read differently." % [Game.client_name(c), str(prod.title)], [Game.client_name(c)])
						Game.log_msg("%s learns that you had money in “%s” — the recommendation suddenly reads differently." % [Game.client_name(c), str(prod.title)], "bad")
						break
		st.filmStakes.erase(stk)
	# Studio shares breathe with their pictures.
	var sid := "st_%s" % str(prod.get("studioId", ""))
	if st.invest.prices.has(sid):
		var mult := 1.05 if ratio >= 2.0 else (0.96 if ratio < 1.0 else 1.01)
		st.invest.prices[sid] = snappedf(float(st.invest.prices[sid]) * mult, 0.01)
	# Mogul endgame: a studio stake pays dividends on every release.
	if st.has("endgame") and st.endgame.studioStakes.has(str(prod.get("studioId", ""))):
		var dividend := roundf(float(revenue) * STUDIO_STAKE_DIVIDEND)
		if dividend > 0.0:
			Persona.book(dividend, "Studio dividend: “%s”" % str(prod.title))


# =====================================================================
# Feature 8 — Backroom deals & favors from dialogue
# Every deal has parties, a concrete promise, witnesses, a channel,
# an expiry date, a paper trail, discovery risk and breach consequences.
# =====================================================================
func deals_for_contact(ct: Dictionary) -> Array:
	var out: Array = []
	for def in Data.BACKROOM_DEALS:
		if not def.partners.has(str(ct.type)):
			continue
		if float(ct.rel) < float(def.minRel):
			continue
		var open_same: bool = _st().backroom.any(func(d): return str(d.dealId) == str(def.id) and str(d.status) == "open")
		if not open_same:
			out.append(def)
	return out


func deal_def(deal_id: String) -> Dictionary:
	return Data.BACKROOM_BY_ID.get(deal_id, {})


# Propose over drinks: costs contact time, can be declined.
func propose_deal(cid, deal_id: String) -> Dictionary:
	var st := _st()
	var ct := Persona.contact_by_id(cid)
	var def := deal_def(deal_id)
	if ct.is_empty() or def.is_empty():
		return {"ok": false, "text": "Unknown deal."}
	if Persona.is_away():
		return {"ok": false, "text": "You are not in Los Angeles."}
	if int(st.contactAP) < 1:
		return {"ok": false, "text": "No contact time left this week."}
	var cost := roundf(float(def.get("cost", 0)) * Game.infl(st.year))
	if float(_p().cash) < cost:
		return {"ok": false, "text": "Privately short on cash — this deal needs %s up front." % Game.fmt_money(cost)}
	st.contactAP = int(st.contactAP) - 1
	_p().energy = clampf(float(_p().energy) - 3.0, 0.0, 100.0)
	var p := clampf(0.25 + float(ct.rel) / 200.0 + float(_p().influence) / 200.0, 0.15, 0.9)
	if not Game.chance(p):
		ct.rel = clampf(float(ct.rel) - 2.0, 0.0, 100.0)
		grant_xp("negotiation", 1.0, "A refusal teaches too")
		return {"ok": false, "text": "%s hears you out, swirls the glass — and changes the subject. Not this time.\n\n(A refusal costs a little standing, but you learned how the wind blows.)" % str(ct.name)}
	return {"ok": true, "text": _accept_deal(ct, def)}


func _accept_deal(ct: Dictionary, def: Dictionary) -> String:
	var st := _st()
	var cost := roundf(float(def.get("cost", 0)) * Game.infl(st.year))
	if cost > 0.0:
		Persona.book(-cost, "Backroom: %s" % str(def.name))
	var give: Dictionary = def.get("give", {})
	var rec := {"id": Game.next_id(), "dealId": str(def.id), "with": {"type": str(ct.type), "name": str(ct.name)},
		"madeMi": Game.mi(), "dueMi": Game.mi() + int(give.get("months", 3)), "channel": "club",
		"witnesses": Game.rndi(0, 2), "paper": bool(def.paper), "status": "open", "used": false, "blockCasting": -1}
	var lines: Array = ["Handshake in the back room: [b]%s[/b] with %s." % [str(def.name), str(ct.name)]]
	lines.append(_apply_deal_get(rec, def, ct))
	if not give.is_empty():
		lines.append("In return: %s (due by %s)." % [str(give.get("label", "")), Game.mi_str(rec.dueMi)])
	if rec.witnesses > 0:
		lines.append("⚠ %d witness(es) heard the terms." % int(rec.witnesses))
	if bool(rec.paper):
		lines.append("⚠ There is a paper trail.")
	st.backroom.append(rec)
	Network.adjust(ct, {"trust": 3.0, "closeness": 3.0}, false)
	Network.memoir("Backroom deal struck with %s: %s%s." % [str(ct.name), str(def.name), " — with a paper trail" if bool(def.paper) else ""], [str(ct.name)])
	Game.record_identity("skrupellos" if bool(def.illegal) else "diskret", 1.0 if bool(def.illegal) else 0.5)
	grant_xp("networking", 2.0, "Closed a backroom deal")
	grant_xp("discretion", 1.0, "Closed a backroom deal")
	Persona.touch_contact_person({"name": str(ct.name)}, 0.0, "You have an arrangement — %s." % str(def.name))
	return "\n".join(lines)


func _apply_deal_get(rec: Dictionary, def: Dictionary, ct: Dictionary) -> String:
	var st := _st()
	var gains: Dictionary = def.get("get", {})
	match str(gains.get("op", "")):
		"favor":
			Game.grant_favor(str(gains.kind), {"type": str(ct.type), "name": str(ct.name)}, true)
			return "You get: %s." % str(gains.get("label", ""))
		"pitch_boost":
			rec["boostUntil"] = Game.mi() + int(gains.get("months", 3))
			return "You get: %s." % str(gains.get("label", ""))
		"studio_rel":
			var sid := ""
			for s in Data.STUDIOS:
				if str(ct.name).contains(str(s.name)):
					sid = str(s.id)
			if sid == "":
				sid = str(Game.pick(Game.active_studios()).id)
			st.studioRel[sid] = clampi(int(st.studioRel.get(sid, 40)) + int(gains.get("amount", 8)), 0, 100)
			Game.spawn_castings(1)
			# Hands off one current casting — the newest one they brought.
			var give: Dictionary = def.get("give", {})
			if str(give.get("op", "")) == "no_pitch" and st.castings.size() > 1:
				rec.blockCasting = int(st.castings[Game.rndi(0, st.castings.size() - 2)].id)
			return "You get: %s (%s)." % [str(gains.get("label", "")), str(Game._studio(sid).name)]
		"intel":
			var revealed := false
			for cs in st.castings:
				if bool(cs.get("hidden", false)):
					cs.hidden = false
					revealed = true
					break
			if not revealed:
				Game.spawn_castings(1)
			Game.grant_favor("scriptAccess", {"type": str(ct.type), "name": str(ct.name)}, true)
			for rumor in st.rumors:
				if not bool(rumor.knownToPlayer):
					rumor.knownToPlayer = true
					break
			return "You get: %s." % str(gains.get("label", ""))
		"campaign":
			var best = null
			for c in st.clients:
				if best == null or float(c.fame) > float(best.fame):
					best = c
			if best != null:
				best.campaign = float(best.get("campaign", 0.0)) + float(gains.get("amount", 12))
				return "You get: an awards push for %s (campaign +%d)." % [Game.client_name(best), int(gains.get("amount", 12))]
			return "You get: an awards push — as soon as you have a client worth pushing."
		"truce":
			var target = null
			for rival in st.rivals:
				if target == null or float(rival.grudge) > float(target.grudge):
					target = rival
			if target != null:
				target["truceUntil"] = Game.mi() + int(gains.get("months", 12))
				target.grudge = minf(float(target.grudge), 10.0)
				return "You get: %s — %s stands down." % [str(gains.get("label", "")), str(target.name)]
			return "You get: peace — though nobody was at war with you."
		"golden":
			rec["boostUntil"] = Game.mi() + int(gains.get("months", 3))
			return "You get: %s." % str(gains.get("label", ""))
	return ""


# Modifiers (and breach checks) for submit_pitch.
func pitch_mods(casting: Dictionary) -> Dictionary:
	var st := _st()
	if st == null or not st.has("backroom"):
		return {}
	var out := {"bonus": 0.0, "golden": false}
	for rec in st.backroom:
		if str(rec.status) != "open":
			continue
		# Breach: pitching on the casting you promised to leave alone.
		if int(rec.get("blockCasting", -1)) >= 0 and int(rec.get("blockCasting", -1)) == int(casting.id):
			rec.status = "broken"
			_deal_contact(rec, -15.0, "You broke your word — hands off, you said.")
			st.studioRel[casting.studioId] = clampi(int(st.studioRel.get(casting.studioId, 40)) - 6, 0, 100)
			Game.log_msg("Word breaks: you pitch on the very project you promised to pass on. The back rooms take note.", "bad")
			continue
		var def := deal_def(str(rec.dealId))
		var op := str(def.get("get", {}).get("op", ""))
		if op == "pitch_boost" and Game.mi() <= int(rec.get("boostUntil", -1)):
			out.bonus = maxf(float(out.bonus), 0.15)
		if op == "golden" and not bool(rec.used) and Game.mi() <= int(rec.get("boostUntil", -1)):
			out.golden = true
			rec.used = true
			rec.status = "honored"
	return out


# Truce breach: you launched a smear against a protected house.
func on_launch_rumor(owner_rival) -> void:
	var st := _st()
	if owner_rival == null or st == null or not st.has("backroom"):
		return
	if Game.mi() > int(owner_rival.get("truceUntil", -1)):
		return
	for rec in st.backroom:
		if str(rec.dealId) == "truce" and str(rec.status) == "open":
			rec.status = "broken"
			owner_rival.grudge = clampf(float(owner_rival.grudge) + 40.0, 0.0, 100.0)
			owner_rival["truceUntil"] = -1
			_deal_contact(rec, -15.0, "You broke the pact — everyone at the table remembers.")
			Game.log_msg("The non-aggression pact is dead — and you lit the match.", "bad")
			return


func _deal_contact(rec: Dictionary, rel_delta: float, memo: String) -> void:
	for ct in _st().contacts:
		if str(ct.name) == str(rec["with"].get("name", "")):
			# Gehaltene Deals bauen Vertrauen, gebrochene hinterlassen Ärger (Feature 12)
			if rel_delta >= 0.0:
				Network.adjust(ct, {"trust": rel_delta * 0.7, "liking": rel_delta * 0.3}, false)
			else:
				Network.adjust(ct, {"trust": rel_delta * 0.8, "irritation": -rel_delta * 0.7})
			if memo != "":
				Persona.touch_contact_person({"name": str(ct.name)}, 0.0, memo)
			return


# Monthly: due obligations become decisions, open deals can be exposed.
func _tick_backroom_month(events: Array) -> void:
	var st := _st()
	for rec in st.backroom:
		if str(rec.status) != "open":
			continue
		var def := deal_def(str(rec.dealId))
		if def.is_empty():
			rec.status = "done"
			continue
		# Exposure: witnesses and paper make secrets expensive.
		var risk := float(def.risk) * (1.5 if bool(rec.paper) else 1.0) * (1.0 + 0.3 * float(rec.witnesses))
		if has_ability("back_channels"):
			risk *= 0.7
		if Game.chance(risk):
			rec.status = "exposed"
			var illegal := bool(def.illegal)
			_p().pubRep = clampf(float(_p().pubRep) - (8.0 if illegal else 4.0), 0.0, 100.0)
			_p().indRep = clampf(float(_p().indRep) - (5.0 if illegal else 2.0), 0.0, 100.0)
			if illegal:
				st.agency.rep = clampi(int(st.agency.rep) - 4, 0, 100)
			Game.add_rumor("agency", "There is talk of an arrangement between %s and %s that neither would sign in daylight." % [st.agency.name, rec["with"].get("name", "?")], true, "skandal", ["Journalists", "Assistants"], 30.0, true)
			Network.memoir("Exposed: the arrangement “%s” with %s became public%s." % [str(def.name), rec["with"].get("name", "?"), " — paper trail included" if bool(rec.paper) else ""], [str(rec["with"].get("name", "?"))])
			grant_xp("crisis", 2.0, "A deal blew up in public")
			events.append({"title": "Backroom deal exposed", "text": "The arrangement “[b]%s[/b]” with %s has leaked%s.\n\n%s" % [str(def.name), rec["with"].get("name", "?"),
				" — including the paper trail" if bool(rec.paper) else "",
				"An illegal pact in the open: reputation, standing and the agency all take the hit." if illegal else "Not illegal, but not pretty: your reputation takes a scratch."], "choices": [{"label": "Damage control"}]})
			continue
		# Due obligations: honor, or break your word.
		if Game.mi() < int(rec.dueMi):
			continue
		match str(def.get("give", {}).get("op", "")):
			"discreet", "truce_keep", "no_pitch":
				rec.status = "honored"
				_deal_contact(rec, 3.0, "You kept your side quiet — that counts.")
			"give_role", "open_favor", "award_support":
				events.append(_obligation_event(rec, def))
			_:
				rec.status = "honored"
	# Compact register: settled deals age out after a while.
	while st.backroom.size() > 20:
		var oldest = null
		for rec2 in st.backroom:
			if str(rec2.status) != "open" and (oldest == null or int(rec2.madeMi) < int(oldest.madeMi)):
				oldest = rec2
		if oldest == null:
			break
		st.backroom.erase(oldest)


func _obligation_event(rec: Dictionary, def: Dictionary) -> Dictionary:
	var give: Dictionary = def.get("give", {})
	var partner: String = rec["with"].get("name", "?")
	var honor_label := ""
	var honor_fn: Callable
	match str(give.op):
		"give_role":
			var cost := roundf(1200.0 * Game.infl(_st().year))
			honor_label = "Make room (%s)" % Game.fmt_money(cost)
			honor_fn = func():
				Game.book(-cost, "abfindung", "Backroom: made room for a protégé")
				rec.status = "honored"
				_deal_contact(rec, 10.0, "You delivered. Word counts for something with you.")
				grant_xp("leadership", 1.0, "Honored an arrangement")
		"open_favor":
			var cost2 := roundf(3000.0 * Game.infl(_st().year))
			honor_label = "Settle the debt (favor or %s)" % Game.fmt_money(cost2)
			honor_fn = func():
				if not Game.consume_any_favor():
					Persona.book(-cost2, "Backroom: an old debt settled")
				rec.status = "honored"
				_deal_contact(rec, 8.0, "Debt settled — cleanly and without fuss.")
		"award_support":
			var cost3 := roundf(2500.0 * Game.infl(_st().year))
			honor_label = "Back their candidate (%s)" % Game.fmt_money(cost3)
			honor_fn = func():
				Game.book(-cost3, "pr_recht", "Backroom: award-season support")
				Game.record_identity("studiotreu", 1.0)
				rec.status = "honored"
				_deal_contact(rec, 8.0, "You kept the pact through awards season.")
	var break_fn := func():
		rec.status = "broken"
		_deal_contact(rec, -18.0, "You broke your word. That gets around.")
		Network.memoir("You broke your word to %s — the arrangement “%s” died with it." % [partner, str(def.name)], [partner])
		_p().stress = clampf(float(_p().stress) + 4.0, 0.0, 100.0)
		Game.record_identity("skrupellos", 1.5)
		if Game.chance(0.5):
			Game.add_rumor("agency", "%s is said to make promises that expire with the last glass." % _st().agency.name, true, "skandal", ["Party guests"], 20.0, true)
		Game.log_msg("Broken word: %s will remember it — and talk about it." % partner, "bad")
	return {"title": "An arrangement comes due", "text": "%s reminds you of your side of “[b]%s[/b]”: %s." % [partner, str(def.name), str(give.get("label", ""))],
		"choices": [{"label": honor_label, "fn": honor_fn}, {"label": "Break your word", "fn": break_fn}]}


# =====================================================================
# Feature 9 — Partner, rivals & the mogul endgame
# =====================================================================
func on_promotion(events: Array) -> void:
	var st := _st()
	var career := int(_p().career)
	if career == 3:
		var cost := roundf(25000.0 * Game.infl(st.year))
		events.append({"title": "The partnership buy-in", "text": "The name on the door can be yours — for real. A buy-in of [b]%s[/b] (private money) makes you a true partner: from then on, 10%% of every profitable month flows into your own account.\n\nOr you stay a salaried man with a grand title." % Game.fmt_money(cost),
			"choices": [{"label": "Buy in (%s)" % Game.fmt_money(cost), "fn": func(): accept_buyin(cost)},
				{"label": "Stay salaried"}]})
	if career >= 5 and not bool(st.endgame.mogulShown):
		st.endgame.mogulShown = true
		events.append({"title": "Hollywood Mogul", "text": "There is no title above this one. Studios return your calls before you make them; rival agencies can be bought like real estate; a studio stake is within reach.\n\nWhat remains is the question every mogul answers differently: what was it all for?", "choices": [{"label": "Keep building"}]})
		Game.press_event("Business", "The word 'mogul' is being used about the head of %s — and nobody laughs." % str(st.agency.name))


func accept_buyin(cost: float) -> void:
	var st := _st()
	if float(_p().cash) < cost:
		Game.log_msg("The buy-in fails: your private account cannot cover %s." % Game.fmt_money(cost), "bad")
		return
	Persona.book(-cost, "Partnership buy-in")
	st.endgame.partnerShare = PARTNER_SHARE
	Game.log_msg("You are a name partner now — 10% of every profitable month is yours.", "history")
	Game.record_identity("kommerziell", 1.0)


func is_partner() -> bool:
	return _st() != null and _st().has("endgame") and float(_st().endgame.partnerShare) > 0.0


# ---------- Taking over a rival agency ----------
func takeover_cost(rival: Dictionary) -> float:
	return roundf((20000.0 + 15000.0 * rival.get("clients", []).size() + float(rival.get("grudge", 0.0)) * 80.0) * Game.infl(_st().year))


func takeover_blocked_reason(rival_id: String) -> String:
	if int(_p().career) < 4:
		return "Only a head of agency swallows whole houses"
	for rival in _st().rivals:
		if str(rival.id) == rival_id:
			if float(_p().cash) < takeover_cost(rival):
				return "Privately short on cash"
			return ""
	return "Rival unknown"


func takeover(rival_id: String) -> String:
	var reason := takeover_blocked_reason(rival_id)
	if reason != "":
		return reason
	var st := _st()
	var rival = null
	for r in st.rivals:
		if str(r.id) == rival_id:
			rival = r
	var cost := takeover_cost(rival)
	Persona.book(-cost, "Takeover: %s" % str(rival.name))
	var freed: int = rival.clients.size()
	st.rivals.erase(rival)
	st.agency.rep = clampi(int(st.agency.rep) + 4, 0, 100)
	_p().influence = clampf(float(_p().influence) + 10.0, 0.0, 100.0)
	st.endgame.takeovers.append(str(rival.name))
	for other in st.rivals:
		other.grudge = clampf(float(other.grudge) + 15.0, 0.0, 100.0)
	grant_xp("leadership", 3.0, "Bought a rival agency")
	grant_xp("negotiation", 2.0, "Bought a rival agency")
	Game.press_event("Agencies", "%s swallows %s — the market just got smaller" % [st.agency.name, rival.name])
	Game.log_msg("Takeover: %s is history. %d of their clients drift back into the open market." % [str(rival.name), freed], "history")
	if Game.chance(0.35):
		Game.log_msg("Not everyone stays: their best agent walks out the door with two clients under the arm.", "bad")
	return ""


# ---------- A stake in a studio ----------
func studio_stake_cost() -> float:
	return roundf(120000.0 * Game.infl(_st().year))


func studio_stake_blocked_reason(sid: String) -> String:
	if int(_p().career) < 5:
		return "Only a mogul buys into a studio"
	if _st().endgame.studioStakes.has(sid):
		return "You already hold this stake"
	if float(_p().cash) < studio_stake_cost():
		return "Privately short on cash"
	return ""


func buy_studio_stake(sid: String) -> String:
	var reason := studio_stake_blocked_reason(sid)
	if reason != "":
		return reason
	var st := _st()
	Persona.book(-studio_stake_cost(), "Studio stake: %s" % str(Game._studio(sid).name))
	st.endgame.studioStakes[sid] = 0.1
	st.studioRel[sid] = maxi(int(st.studioRel.get(sid, 40)), 75)
	Game.press_event("Business", "%s's boss buys into %s — agent and studio owner in one person" % [st.agency.name, Game._studio(sid).name])
	Game.log_msg("You own a piece of %s now. Every conversation with them is a conflict of interest — and everyone knows it." % str(Game._studio(sid).name), "history")
	Game.record_identity("studiotreu", 2.0)
	return ""


func _tick_endgame_month() -> void:
	var st := _st()
	# Partner share: 10% of a profitable month flows to the manager.
	if float(st.endgame.partnerShare) > 0.0:
		var profit := 0.0
		for e in st.ledger:
			if int(e.mi) == Game.mi():
				profit += float(e.amount)
		var share := roundf(maxf(profit, 0.0) * float(st.endgame.partnerShare))
		if share > 0.0:
			Game.book(-share, "gehalt", "Partner profit share")
			Persona.book(share, "Partner share (%d%% of the month's profit)" % roundi(float(st.endgame.partnerShare) * 100.0))
	# Studio stakes keep doors open.
	for sid in st.endgame.studioStakes:
		st.studioRel[sid] = maxi(int(st.studioRel.get(sid, 40)), 75)
	# Truces keep rivals calm while they hold.
	for rival in st.rivals:
		if Game.mi() <= int(rival.get("truceUntil", -1)):
			rival.grudge = minf(float(rival.grudge), 15.0)


# =====================================================================
# Central ticks & briefing
# =====================================================================
func tick_week() -> void:
	if _st() == null or not _st().has("estate"):
		return
	_tick_estate_week()


func tick_month(events: Array) -> void:
	var st := _st()
	if st == null or not st.has("estate"):
		return
	_tick_estate_month()
	_tick_invest_month(events)
	_tick_backroom_month(events)
	_tick_endgame_month()
	# Crisis radar: once a month, a rumor finds YOU.
	if has_ability("early_warning"):
		for rumor in st.rumors:
			if not bool(rumor.knownToPlayer):
				rumor.knownToPlayer = true
				Game.log_msg("Early warning: a rumor reaches you that was never meant for your ears.", "info")
				break


# Extra lines for the assistant's morning note.
func briefing_items() -> Array:
	var st := _st()
	var items: Array = []
	if st == null or not st.has("backroom"):
		return items
	for rec in st.backroom:
		if str(rec.status) == "open" and int(rec.dueMi) <= Game.mi() + 1:
			var def := deal_def(str(rec.dealId))
			if not def.get("give", {}).is_empty():
				items.append("🤝 The arrangement with %s comes due — decide how much your word weighs." % rec["with"].get("name", "?"))
	for tip in st.invest.tips:
		if not bool(tip.resolved) and int(tip.dueMi) <= Game.mi() + 1:
			items.append("💹 The whisper about %s should resolve within weeks." % str(stock_def(str(tip.companyId)).get("name", tip.companyId)))
	for stk in st.filmStakes:
		for prod in st.productions:
			if int(prod.id) == int(stk.refId) and int(prod.get("weeksLeft", 99)) <= 4:
				items.append("🎬 “%s” opens soon — your %s is riding on it." % [str(stk.title), Game.fmt_money(float(stk.amount))])
	return items
