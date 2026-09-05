extends Node

func fresh() -> void:
	seed(9052026)
	Game.new_game("QA Audit", 1950)
	Jukebox._current_key = Jukebox.key_for_year(1950)

func sign_monroe() -> Dictionary:
	Game.start_negotiation("monroe")
	return Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null}).get("client", {})

func _ready() -> void:
	print("AUDIT_BEGIN")
	fresh()
	print("AUDIT_PATH;", ProjectSettings.globalize_path(Game.SAVE_PATH))
	var c := sign_monroe()
	Game.state.agency.cash = -Game.credit_limit()
	var before: float = Game.state.agency.cash
	Planner.planner_fill("client", int(c.id), "pr")
	Planner._apply_planner([])
	print("AUDIT_CREDIT_PR;before=", before, ";after=", Game.state.agency.cash, ";limit=", Game.credit_limit())
	fresh()
	c = sign_monroe()
	Game.state.agency.cash = -Game.credit_limit()
	before = Game.state.agency.cash
	Planner.planner_fill("client", int(c.id), "gala")
	Planner._apply_planner([])
	print("AUDIT_CREDIT_GALA;before=", before, ";after=", Game.state.agency.cash, ";limit=", Game.credit_limit())
	fresh()
	var sid: String = Game.state.studioRel.keys()[0]
	before = Game.state.studioRel[sid]
	for i in 5:
		Planner.planner_slot_set("player", -1, 0, 0, "dinner", sid)
		Planner._apply_planner([])
	print("AUDIT_DINNER;five_separate_slots;before=", before, ";after=", Game.state.studioRel[sid])
	fresh()
	Game.state.agency.cash = -1.0
	print("AUDIT_SIGN_CREDIT;can_spend_zero=", Game.can_spend(0.0))
	Game.start_negotiation("monroe")
	print("AUDIT_SIGN_CREDIT;result=", Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null}))
	fresh()
	c = sign_monroe()
	Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
	print("AUDIT_DUPLICATE_SIGN;clients=", Game.state.clients.size())
	fresh()
	var stock: String = Mogul.stock_defs()[0].id
	Game.state.player.cash = 100000.0
	Mogul.buy_stock(stock, 1000.0)
	var xp_before: float = Mogul.xp("finance")
	before = Game.state.player.cash
	var held: int = Mogul.shares_of(stock)
	for i in 10:
		Mogul.sell_stock(stock, 0)
	print("AUDIT_ZERO_SALE;xp_before=", xp_before, ";xp_after=", Mogul.xp("finance"), ";cash_delta=", Game.state.player.cash-before, ";shares_before=", held, ";shares_after=", Mogul.shares_of(stock))
	fresh()
	Game.state.followups.append({"type":"json", "event":"tonfilm_training", "due":Game.mi(), "ctx":{}})
	var evs: Array = Game.end_week()
	var followups: int = Game.state.followups.size()
	Game.load_game()
	print("AUDIT_EVENT_SAVE;returned_events=", evs.size(), ";followups_before_load=", followups, ";followups_after_load=", Game.state.followups.size(), ";state_keys=", Game.state.keys())
	for ev in evs:
		print("AUDIT_EVENT_TITLE;", ev.get("title", ""))
	for payload in ["{}", "{\"saveVersion\":2}", "{\"saveVersion\":2,\"year\":1950,\"agency\":null}"]:
		fresh()
		var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
		f.store_string(payload)
		f.close()
		print("AUDIT_BAD_SAVE_BEGIN;", payload)
		var loaded: bool = Game.load_game()
		print("AUDIT_BAD_SAVE_END;accepted=", loaded, ";load_error=", Game.load_error, ";has_agency=", Game.state.has("agency"))
	fresh()
	Game.save_game()
	print("AUDIT_DONE")
	get_tree().quit()
