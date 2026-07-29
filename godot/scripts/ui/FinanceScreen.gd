extends RefCounted
# =====================================================================
# Screen „Finanzen" — aus Main.gd extrahiert (Chunk 09, Muster-Screen).
# Bekommt die Main-Referenz für die UI-Bausteine (_grid/_card/_lbl/_bar,
# Farben, font_scale, content_box) und liest den Spielzustand über die
# Autoloads. Kein eigener Zustand — pro Render-Aufruf wird neu gebaut.
# =====================================================================

var main


func _init(main_ref) -> void:
	main = main_ref


func render() -> void:
	var st = Game.state
	var grid: GridContainer = main._grid(560.0)
	grid.columns = clampi(grid.columns, 1, 2)
	main.content_box.add_child(grid)

	# Kennzahlen
	var kc = main._card("Key figures", "📊")
	grid.add_child(kc[0])
	var burn := Game.avg_burn(6)
	var runway := Game.months_to_broke()
	kc[1].add_child(main._lbl("💰 Capital: %s" % Util.fmt_money(st.agency.cash), 14, main.RED if st.agency.cash < 0 else main.TEXT_C))
	var credit := Game.credit_limit()
	if float(st.agency.cash) < 0.0:
		kc[1].add_child(main._lbl("🏦 Credit line: %s of %s drawn · banks take over after %d months in the red (%d/%d)" % [Util.fmt_money(-float(st.agency.cash)), Util.fmt_money(credit), Balance.INSOLVENCY_MONTHS, int(st.agency.debtMonths), Balance.INSOLVENCY_MONTHS], 13, main.RED))
	else:
		kc[1].add_child(main._lbl("🏦 Credit line: up to −%s (reputation-based)" % Util.fmt_money(credit), 13, main.DIM))
	kc[1].add_child(main._lbl("🔥 Avg. expenses (6 mo.): %s / month" % Util.fmt_money(burn), 13, main.DIM))
	if runway >= 0.0 and runway < 900.0:
		kc[1].add_child(main._lbl("⏳ Runway at the current burn: ~%d months" % roundi(runway), 13, main.RED if runway < 6.0 else (main.AMBER if runway < 12.0 else main.GREEN)))
	var top_cat := Game.top_income_cat(12)
	if top_cat != "":
		kc[1].add_child(main._lbl("🏆 Biggest income source: %s" % Game.LEDGER_CATS.get(top_cat, top_cat), 13, main.DIM))

	# Laufender Monat nach Kategorie
	var lm: Dictionary = Game.live_month(Game.mi())
	var mc = main._card("Current month: %s" % Game.date_str(), "🗓")
	grid.add_child(mc[0])
	mc[1].add_child(main._lbl("Income %s · expenses %s · balance %s" % [Util.fmt_money(lm.income), Util.fmt_money(lm.expenses), Util.fmt_money(lm.income - lm.expenses)], 13, main.GREEN if lm.income >= lm.expenses else main.RED))
	var cat_max := 1.0
	for cat in lm.byCat:
		cat_max = maxf(cat_max, absf(float(lm.byCat[cat])))
	for cat in lm.byCat:
		var amt: float = lm.byCat[cat]
		var row := HBoxContainer.new()
		var nm: Label = main._lbl("%s %s" % ["▲" if amt >= 0 else "▼", Game.LEDGER_CATS.get(cat, cat)], 12, main.GREEN if amt >= 0 else main.RED)
		nm.custom_minimum_size = Vector2(220 * main.font_scale, 0)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(nm)
		var pb: Control = main._bar(absf(amt) / cat_max * 100.0, main.GREEN if amt >= 0 else main.RED, 7)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pb)
		var av: Label = main._lbl(Util.fmt_money(amt), 12, main.DIM)
		av.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(av)
		mc[1].add_child(row)
	if lm.byCat.is_empty():
		mc[1].add_child(main._lbl("No bookings this month yet.", 12, main.DIM))

	# Letzte 12 Monate
	var hist: Array = st.ledgerMonthly.slice(maxi(0, st.ledgerMonthly.size() - 12))
	if hist.size():
		var hc = main._card("Last %d months" % hist.size(), "📈")
		grid.add_child(hc[0])
		var cumulative := 0.0
		for m in hist:
			var saldo: float = float(m.income) - float(m.expenses)
			cumulative += saldo
			hc[1].add_child(main._lbl("%s — ▲ %s · ▼ %s · balance %s · Σ %s" % [Game.mi_str(m.mi), Util.fmt_money(m.income), Util.fmt_money(m.expenses), Util.fmt_money(saldo), Util.fmt_money(cumulative)], 12, main.GREEN if saldo >= 0 else main.RED))

	# Einzelbuchungen der letzten 3 Monate
	var jc = main._card("Itemized bookings (last 3 months)", "🧾")
	grid.add_child(jc[0])
	var shown := 0
	for i in range(st.ledger.size() - 1, -1, -1):
		var e: Dictionary = st.ledger[i]
		if Game.mi() - int(e.mi) > 2 or shown >= 30:
			break
		jc[1].add_child(main._lbl("%s · %s%s · %s — %s" % [Game.mi_str(e.mi), "▲" if float(e.amount) >= 0 else "▼", Util.fmt_money(absf(float(e.amount))), Game.LEDGER_CATS.get(str(e.cat), str(e.cat)), e.text], 12, main.GREEN if float(e.amount) >= 0 else main.RED))
		shown += 1
	if shown == 0:
		jc[1].add_child(main._lbl("No bookings yet.", 12, main.DIM))
