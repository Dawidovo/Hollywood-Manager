extends Control
# =====================================================================
# Hollywood Manager (Godot) — UI
# Epochen-Design: Farbwelt wechselt mit der Ära (gekoppelt an die
# Musik-Epochen), responsive Karten-Grids für große Monitore,
# Piktogramme & Farbcodes für schnelle Lesbarkeit.
# =====================================================================

# Semantische Festfarben (in allen Epochen gleich lesbar)
const TEXT_C := Color("e8dfc9")
const DIM := Color("a89b7e")
const RED := Color("c0504d")
const GREEN := Color("7da05c")
const BLUE := Color("6f9bbf")
const AMBER := Color("c9963f")
const GOLD := Color("d4af37")

# Epochen-Farbwelten — Schlüssel identisch mit Jukebox.key_for_year()
# Typografie & Formensprache pro Epoche (Fonts: SIL OFL, siehe assets/CREDITS.md):
#   ragtime  — Art-Deco-Titelkarten der Stummfilmzeit: Limelight, scharfe Kanten, Doppelrahmen-Optik
#   noir     — Kinoplakate des Studiosystems (Trajan-Stil): Cinzel, Gold, dezente Rundung
#   synth    — Neon/Chrom der Blockbuster-Jahre: Orbitron, runde Ecken, Leuchtrand
#   modern   — Streaming-Interfaces: Bebas Neue, flach, randlos, starke Rundung
const ERA_THEMES := {
	"ragtime": {"name": "Silent Era", "icon": "🎞", "accent": Color("cfcfcf"), "accent_dim": Color("8a8a86"),
		"panel": Color("242220"), "panel2": Color("2f2c29"), "header": Color("191817"), "bg": Color("151413"),
		"font": "res://assets/fonts/Limelight-Regular.ttf", "radius": 0, "btn_radius": 0, "border_w": 2, "glow": false, "header_border": 3},
	"noir": {"name": "Golden Age", "icon": "🎬", "accent": Color("d4af37"), "accent_dim": Color("9c823a"),
		"panel": Color("2a241b"), "panel2": Color("332c21"), "header": Color("1a1610"), "bg": Color("16130f"),
		"font": "res://assets/fonts/Cinzel.ttf", "radius": 3, "btn_radius": 3, "border_w": 1, "glow": false, "header_border": 2},
	"synth": {"name": "Blockbuster Era", "icon": "🌆", "accent": Color("ff9d45"), "accent_dim": Color("b06a2c"),
		"panel": Color("232030"), "panel2": Color("2c2841"), "header": Color("161425"), "bg": Color("121019"),
		"font": "res://assets/fonts/Orbitron.ttf", "radius": 6, "btn_radius": 6, "border_w": 1, "glow": true, "header_border": 2},
	"modern": {"name": "Streaming Era", "icon": "📡", "accent": Color("e05a5a"), "accent_dim": Color("97423f"),
		"panel": Color("21252b"), "panel2": Color("2a2f38"), "header": Color("14171c"), "bg": Color("101317"),
		"font": "res://assets/fonts/BebasNeue-Regular.ttf", "radius": 8, "btn_radius": 8, "border_w": 0, "glow": false, "header_border": 1},
}

const GENRE_ICONS := {"drama": "🎭", "comedy": "😄", "action": "💥", "romance": "💘", "thriller": "🕵", "western": "🤠",
	"musical": "🎵", "scifi": "🚀", "horror": "👻", "crime": "🔫", "adventure": "🗺"}
const LOG_ICONS := {"deal": "🤝", "bad": "⚠", "history": "🏛", "info": "•", "event": "•"}
const SECRET_ICONS := {"beziehung": "💞", "gesundheit": "🩺", "wechsel": "🚪", "schwangerschaft": "👶",
	"sucht": "🍾", "politik": "🗳", "setkonflikt": "🎬"}

# Aktive Epochen-Farben (von _apply_era_theme gesetzt)
var ACC := GOLD
var ACC_DIM := Color("9c823a")
var PANEL_C := Color("2a241b")
var PANEL2_C := Color("332c21")
var _era_key := ""
# Aktive Epochen-Formensprache (von _apply_era_theme gesetzt)
var RADIUS := 3
var BTN_RADIUS := 3
var BORDER_W := 1
var GLOW := false
var DISPLAY_FONT: Font = null
var _font_cache: Dictionary = {}

var bg_rect: ColorRect
var start_screen: Control
var game_root: Control
var header_sb: StyleBoxFlat
var modal_sb: StyleBoxFlat
var header_stats: Dictionary = {}
var era_chip: Label
var tab_bar: HFlowContainer
var content_scroll: ScrollContainer
var content_box: VBoxContainer
var side_scroll: ScrollContainer
var sidebar_box: VBoxContainer
var modal_layer: Control
var modal_panel: PanelContainer
var modal_box: VBoxContainer

var current_tab := "buero"
var modal_queue: Array = []
var modal_open := false
var pool_filter := ""
var nego_form: Dictionary = {}
var _offer_clauses: Array = []
var _chem_selected: Array = []
var _nego_widgets: Dictionary = {}
var font_scale := 1.0
var _resize_timer: Timer

# ---------------------------------------------------------------------
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_apply_shot_resolution(args)
	bg_rect = ColorRect.new()
	bg_rect.color = ERA_THEMES["noir"].bg
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_rect)
	DISPLAY_FONT = _era_font("noir")
	_recalc_scale()
	_build_start_screen()
	_build_game_ui()
	_build_modal_layer()
	_resize_timer = Timer.new()
	_resize_timer.one_shot = true
	_resize_timer.wait_time = 0.15
	_resize_timer.timeout.connect(_on_resized_settled)
	add_child(_resize_timer)
	get_viewport().size_changed.connect(func(): _resize_timer.start())
	if args.has("--shot-start"):
		await _take_shot("start")
	elif args.has("--shot-game"):
		_on_era_selected(1950)
		await _take_shot("game")
	elif args.has("--shot-1980"):
		_on_era_selected(1980)
		await _take_shot("1980")
	elif args.has("--shot-2010"):
		_on_era_selected(2010)
		await _take_shot("2010")
	elif args.has("--shot-privat"):
		_on_era_selected(1950)
		_switch_tab("privat")
		await _take_shot("privat")
	elif args.has("--shot-orte"):
		_on_era_selected(1950)
		Persona.travel_to("ny")
		_switch_tab("orte")
		await _take_shot("orte")
	elif args.has("--shot-kontakte"):
		_on_era_selected(1950)
		Persona.hire_assistant()
		Persona.contact_interact(int(Game.state.contacts[0].id), "meet")
		Persona.contact_interact(int(Game.state.contacts[1].id), "aide")
		_switch_tab("kontakte")
		await _take_shot("kontakte")
	elif args.has("--shot-client"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": ["assistant", "pr"], "promise": "lead12"})
		var c = Game.state.clients[0]
		c.dna = {"romantik": 62.0, "popular": 45.0, "verlass": -20.0, "unikat": 12.0, "familie": -35.0}
		c.films.push_front({"title": "Gilda", "year": 1950, "verdict": "Hit", "quality": 71, "lead": true})
		_switch_tab("klienten")
		await _take_shot("client")
	elif args.has("--shot-deal"):
		# Repro: Klient über den echten Casting-Pfad verpflichten, dann rendern
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": "lead12"})
		var deal_done := false
		for cs in Game.state.castings:
			if deal_done:
				break
			for ri in cs.roles.size():
				var role: Dictionary = cs.roles[ri]
				if role.filled == null and role.gender == "f":
					role.minFame = 10
					role.ageMin = 18
					role.ageMax = 60
					for attempt in 12:
						var pres = Game.submit_pitch(int(cs.id), ri, int(Game.state.clients[0].id))
						if pres.get("success", false):
							Game.accept_offer()
							deal_done = true
							break
					if deal_done:
						break
		_close_modal()
		_switch_tab("castings")
		await _take_shot("deal")
	elif args.has("--shot-backstory"):
		_show_backstory_picker(1925)
		await _take_shot("backstory")
	elif args.has("--shot-pool"):
		_on_era_selected(1925)
		_switch_tab("pool")
		await _take_shot("pool")
	elif args.has("--shot-rumors"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": ["assistant", "pr"], "promise": null})
		var shot_client: Dictionary = Game.state.clients[0]
		Game.reveal_secret(shot_client, "beziehung", 2)
		var shot_rumor := Game.add_rumor(int(shot_client.id), "Louella Parsons hears of late-night meetings in a bungalow by the beach.", true, "affäre", ["Assistants", "Journalists", "Party guests"], 67.0, true, "beziehung")
		shot_rumor.industryBelief = 38.0
		shot_rumor.impactApplied = true
		Game.add_rumor(int(shot_client.id), "A studio messenger claims the next contract is being negotiated elsewhere in secret.", false, "wechsel", ["Studios", "Directors"], 24.0, true, "", 72.0)
		_switch_tab("rumors")
		await _take_shot("rumors")
	elif args.has("--shot-zeitung"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": ["pr"], "promise": null})
		var news_client: Dictionary = Game.state.clients[0]
		var news_prod: Dictionary = Game.quick_production(news_client, {"genre":"drama", "prestige":3, "qualityMod":12.0}).prod
		Game.release_film(news_prod)
		Game.state.productions.erase(news_prod)
		Game.add_rumor(int(news_client.id), "A columnist is gathering material for a story that names no names yet.", false, "skandal", ["Journalists", "Party guests"], 44.0, true, "", 31.0)
		Game.tick_rivals([], true)
		Newspaper.build_newspaper()
		_switch_tab("zeitung")
		await _take_shot("zeitung")
	elif args.has("--shot-zeitungsarchiv"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": ["pr"], "promise": null})
		for archive_month in 3:
			Game.state.month = archive_month + 1
			Game.press_event("Casting", "Archive item %d: a new contract stirs the studios." % (archive_month + 1))
			Newspaper.build_newspaper()
		_switch_tab("zeitung")
		await get_tree().process_frame
		content_scroll.scroll_vertical = 100000
		await _take_shot("zeitungsarchiv")
	elif args.has("--shot-nego"):
		_on_era_selected(1950)
		_open_negotiation("monroe")
		Game.nego.counter = Game.build_counter({"commission": 12, "bonus": 0, "years": 2, "perks": [], "promise": null})
		_render_negotiation("Monroe: “Don't promise me anything you can't keep.”")
		await _take_shot("nego")
	elif args.has("--shot-pitch"):
		_on_era_selected(1950)
		Game.state.agency.rep = 80
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
		var pitch_client: Dictionary = Game.state.clients[0]
		var pitch_casting: Dictionary = Game.state.castings[0]
		var pitch_role: Dictionary = pitch_casting.roles[0]
		pitch_role.type = "support"
		pitch_role.gender = "f"
		pitch_role.minFame = 10
		pitch_role.ageMin = 18
		pitch_role.ageMax = 70
		Game.pitch_ctx = {"casting": pitch_casting, "roleIdx": 0, "role": pitch_role, "client": pitch_client,
			"fee": Game.role_fee_for(pitch_casting, pitch_role, pitch_client), "haggled": false, "alts": []}
		_render_studio_offer("The studio is waiting for your answer.")
		await _take_shot("pitch")
	elif args.has("--shot-finanzen"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 8000, "years": 5, "perks": ["assistant", "pr"], "promise": "lead12"})
		var c = Game.state.clients[0]
		Game.quick_production(c, {"genre": "romance", "prestige": 1})
		Game.start_negotiation("brando")
		Game.sign_client({"commission": 12, "bonus": 0, "years": 3, "perks": [], "promise": null})
		var c2 = Game.state.clients[1]
		Game.quick_production(c2, {"genre": "drama", "prestige": 2})
		Game.grant_favor("suppressStory", Game.favor_contact_for("suppressStory"))
		Game.owe_favor("galaInvite", Game.favor_contact_for("galaInvite"))
		for i in 4:
			Game.end_month()
		_switch_tab("finanzen")
		await _take_shot("finanzen")
	elif args.has("--shot-power"):
		_on_era_selected(1980)
		Game.state.agency.rep = 100
		Game.start_negotiation("eastwood")
		Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":[], "promise":null})
		var power_client: Dictionary = Game.state.clients[0]
		power_client.fame = 85.0
		Game.become_power_figure(int(power_client.id), "director", true)
		Game.assign_power_figure_to_casting(Game.state.castings[0], true)
		_switch_tab("buero")
		await _take_shot("power")
	elif args.has("--shot-planner"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": ["assistant"], "promise": null})
		Game.start_negotiation("brando")
		Game.sign_client({"commission": 12, "bonus": 0, "years": 3, "perks": [], "promise": null})
		Game.ensure_planner()
		Game.planner_slot_set("player", 0, 0, 0, "scouting")
		Game.planner_slot_set("player", 0, 1, 1, "dinner", Game.active_studios()[0].id)
		Game.planner_slot_set("client", int(Game.state.clients[0].id), 0, 0, "pr")
		Game.planner_slot_set("client", int(Game.state.clients[1].id), 1, 2, "gala")
		_switch_tab("planer")
		await _take_shot("planer")
	elif args.has("--shot-verhandlung") or args.has("--shot-tisch"):
		_on_era_selected(1950)
		Game.state.agency.rep = 80
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
		var table_client: Dictionary = Game.state.clients[0]
		table_client.fame = 70.0
		var table_done := false
		for cs in Game.state.castings:
			if table_done:
				break
			for ri in cs.roles.size():
				var role: Dictionary = cs.roles[ri]
				if role.filled == null and str(role.type) == "lead" and int(cs.prestige) >= 2:
					role.minFame = 10
					role.ageMin = 18
					role.ageMax = 60
					for attempt in 14:
						var pres = Game.submit_pitch(int(cs.id), ri, int(table_client.id))
						if pres.get("success", false):
							table_done = true
							break
					if table_done:
						break
			if table_done:
				break
		if Game.pitch_ctx != null and Game.pitch_ctx.get("table", false):
			Game.start_table()
			_render_table("")
		else:
			_switch_tab("castings")
		await _take_shot("tisch" if args.has("--shot-tisch") else "verhandlung")
	elif args.has("--shot-produktionsverhandlung"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
		var production_client: Dictionary = Game.state.clients[0]
		var production: Dictionary = Game.quick_production(production_client, {"genre": "drama", "prestige": 2}).prod
		Game.ensure_prod_fields(production)
		production.signals = [{"t": "Strong dailies convince the studio.", "pos": true, "mi": Game.mi()}]
		_run_production_negotiation(int(production.id), "reneg")
		await _take_shot("produktionsverhandlung")
	elif args.has("--shot-filme"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
		var film_client: Dictionary = Game.state.clients[0]
		var film_prod: Dictionary = Game.quick_production(film_client, {"genre": "drama", "prestige": 2}).prod
		Game.ensure_prod_fields(film_prod)
		film_prod.signals = [
			{"t": "Glowing set reports", "pos": true, "mi": Game.mi()},
			{"t": "The schedule comes under pressure", "pos": false, "mi": Game.mi()},
		]
		_switch_tab("filme")
		await _take_shot("filme")
	elif args.has("--shot-eventverhandlung"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
		var event_client: Dictionary = Game.state.clients[0]
		event_client.fame = 70.0
		var event_data = EvEngine.build_by_id("rollen_transformation", {"cid": int(event_client.id), "sid": str(Game.active_studios()[0].id)})
		if event_data != null:
			modal_queue.append(event_data)
			_show_next_modal()
		await _take_shot("eventverhandlung")
	elif args.has("--shot-eventergebnis"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
		var result_client: Dictionary = Game.state.clients[0]
		result_client.fame = 70.0
		var result_event = EvEngine.build_by_id("rollen_transformation", {"cid": int(result_client.id), "sid": str(Game.active_studios()[0].id)})
		if result_event != null:
			var result_text = result_event.choices[2].fn.call()
			_show_outcome_modal(str(result_event.title), str(result_text))
		await _take_shot("eventergebnis")
	elif args.has("--shot-audition"):
		_on_era_selected(1950)
		Game.state.agency.rep = 100
		Game.start_negotiation("monroe")
		Game.sign_client({"commission":10, "bonus":0, "years":5, "perks":["assistant"], "promise":"lead12"})
		var audition_client: Dictionary = Game.state.clients[0]
		var audition_casting: Dictionary = Game.state.castings[0]
		audition_casting.prestige = 3
		var audition_role: Dictionary = audition_casting.roles[0]
		audition_role.type = "lead"
		audition_role.gender = "f"
		audition_role.minFame = 10
		audition_role.ageMin = 18
		audition_role.ageMax = 70
		Game.state.rivals[0].clients = ["gkelly", "hepburn"]
		Game.grant_favor("scriptAccess", {"type":"regisseur", "name":"Script Supervisor"}, true)
		Game.begin_audition(int(audition_casting.id), 0, int(audition_client.id))
		_render_audition_briefing()
		await _take_shot("audition")
	elif args.has("--shot-chemread"):
		_on_era_selected(1950)
		Game.state.agency.rep = 100
		for aid in ["monroe", "gkelly", "brando", "bogart"]:
			Game.start_negotiation(aid)
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
		_chem_selected = Game.chem_read_candidate_pairs(int(chem_casting.id)).slice(0, 2).map(func(p): return str(p.key))
		Game.begin_chem_read(int(chem_casting.id), _chem_selected, "love")
		_render_chem_signals()
		await _take_shot("chemread")
	elif args.has("--shot-coverage"):
		# Coverage-Blatt erzwingen, einen Marker setzen, Modal zeigen
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
		Game._issue_coverage()
		Game.coverage_mark(0, "prestige")
		_switch_tab("buero")
		_open_coverage()
		await _take_shot("coverage")
	elif args.has("--shot-coveragearchiv"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": [], "promise": null})
		Game._issue_coverage()
		var archived_sheet: Dictionary = Game.state.coverage.current.duplicate(true)
		archived_sheet["mi"] = Game.mi()
		Game.state.coverage.history = [archived_sheet, archived_sheet.duplicate(true)]
		_coverage_archive = true
		_open_coverage()
		await _take_shot("coveragearchiv")
	elif args.has("--shot-karrierebrett"):
		# Drei kontrastreiche Slots planen, Klientenkarte mit Brett zeigen
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": ["assistant"], "promise": null})
		var board_client: Dictionary = Game.state.clients[0]
		Game.board_slot_add(int(board_client.id), "comedy", "lead", 1)
		Game.board_slot_add(int(board_client.id), "thriller", "lead", 2)
		Game.board_slot_add(int(board_client.id), "drama", "lead", 3)
		_switch_tab("klienten")
		await _take_shot("karrierebrett")
	elif args.has("--shot-chronik"):
		_on_era_selected(1950)
		Game.log_msg("A long chronicle entry checks the available width without per-letter wrapping in the historical overview.", "history")
		Game.log_msg("The agency receives an offer and prepares the next negotiation.", "deal")
		_switch_tab("chronik")
		await _take_shot("chronik")

func _apply_shot_resolution(user_args: PackedStringArray) -> void:
	var shot_requested := false
	for arg in user_args:
		if str(arg).begins_with("--shot-"):
			shot_requested = true
			break
	if not shot_requested:
		return
	var size_text := ""
	var all_args := OS.get_cmdline_args()
	for i in all_args.size() - 1:
		if str(all_args[i]) == "--resolution":
			size_text = str(all_args[i + 1])
	for arg in user_args:
		if str(arg).begins_with("--shot-resolution="):
			size_text = str(arg).trim_prefix("--shot-resolution=")
	if size_text == "":
		return
	var parts := size_text.to_lower().split("x")
	if parts.size() != 2:
		return
	var shot_size := Vector2i(maxi(640, int(parts[0])), maxi(480, int(parts[1])))
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = shot_size

func _take_shot(name_s: String) -> void:
	await get_tree().create_timer(1.2).timeout
	var img := get_viewport().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path("res://../shot_%s.png" % name_s)
	img.save_png(output_path)
	print("SHOT_SAVED " + output_path)
	get_tree().quit()

# ---------------------------------------------------------------------
# Responsiveness: Schriftgröße & Spaltenzahl folgen der Fensterbreite
# ---------------------------------------------------------------------
func _recalc_scale() -> void:
	var w := float(get_viewport_rect().size.x)
	font_scale = clampf(w / 1680.0, 0.9, 1.4)

func _on_resized_settled() -> void:
	_recalc_scale()
	_update_modal_width()
	if Game.state != null and game_root.visible and not modal_open:
		render()

func _cols(card_w: float = 500.0) -> int:
	var avail := float(get_viewport_rect().size.x) - _sidebar_w() - 70.0
	return clampi(int(avail / (card_w * font_scale)), 1, 4)

func _sidebar_w() -> float:
	return clampf(float(get_viewport_rect().size.x) * 0.21, 350.0, 540.0)

# Epochen-Displayfont laden (mit Fallback auf den Default-Font,
# damit Emojis/Symbole weiterhin über die Systemschrift gerendert werden)
func _era_font(key: String) -> Font:
	if _font_cache.has(key):
		return _font_cache[key]
	var path := str(ERA_THEMES[key].font)
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path)
		if f is FontFile:
			f.fallbacks = [ThemeDB.fallback_font]
	_font_cache[key] = f
	return f

func _apply_era_theme() -> void:
	var key: String = Jukebox.key_for_year(int(Game.state.year)) if Game.state != null else "noir"
	if key == _era_key:
		return
	_era_key = key
	var t: Dictionary = ERA_THEMES[key]
	ACC = t.accent
	ACC_DIM = t.accent_dim
	PANEL_C = t.panel
	PANEL2_C = t.panel2
	RADIUS = int(t.radius)
	BTN_RADIUS = int(t.btn_radius)
	BORDER_W = int(t.border_w)
	GLOW = bool(t.glow)
	DISPLAY_FONT = _era_font(key)
	bg_rect.color = t.bg
	header_sb.bg_color = t.header
	header_sb.border_color = ACC
	header_sb.border_width_bottom = int(t.header_border)
	if GLOW:
		header_sb.shadow_color = Color(ACC.r, ACC.g, ACC.b, 0.25)
		header_sb.shadow_size = 6
	else:
		header_sb.shadow_size = 0
	modal_sb.border_color = ACC
	modal_sb.bg_color = PANEL_C
	modal_sb.set_corner_radius_all(RADIUS)
	modal_sb.set_border_width_all(maxi(BORDER_W, 1) * 2)
	# Persistente Header-Labels auf den Epochen-Font umstellen
	for n in [header_stats.get("agency"), era_chip]:
		if n != null and DISPLAY_FONT != null:
			n.add_theme_font_override("font", DISPLAY_FONT)
	# Persistente Header-Buttons in die Formensprache der Epoche bringen
	for pair in [["music", false], ["save", false], ["next", true]]:
		var b = header_stats.get(pair[0])
		if b != null:
			_style_btn(b, bool(pair[1]))

# =====================================================================
# UI-Bausteine
# =====================================================================
func _lbl(text: String, size: int = 15, color: Color = TEXT_C) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(size * font_scale))
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

# Wie _lbl, aber für den Einsatz direkt in HBox-/HFlow-Containern:
# ohne EXPAND_FILL kollabiert ein autowrappendes Label dort auf ~1 Zeichen Breite.
func _lbl_fill(text: String, size: int = 15, color: Color = TEXT_C) -> Label:
	var l := _lbl(text, size, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _rich(bbcode: String, size: int = 15) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.text = bbcode
	r.add_theme_font_size_override("normal_font_size", int(size * font_scale))
	r.add_theme_font_size_override("bold_font_size", int(size * font_scale))
	r.add_theme_font_size_override("italics_font_size", int(size * font_scale))
	r.add_theme_color_override("default_color", TEXT_C)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

func _btn(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	_style_btn(b, primary)
	return b

# Epochen-Styling eines Buttons (auch zum Umstylen persistenter
# Header-Buttons beim Epochenwechsel wiederverwendet)
func _style_btn(b: Button, primary: bool = false) -> void:
	if DISPLAY_FONT != null:
		b.add_theme_font_override("font", DISPLAY_FONT)
	b.add_theme_font_size_override("font_size", int(14 * font_scale))
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACC if primary else PANEL2_C
	sb.border_color = ACC if primary else ACC_DIM
	sb.set_border_width_all(maxi(BORDER_W, 1) if not primary else BORDER_W)
	sb.set_corner_radius_all(BTN_RADIUS)
	sb.set_content_margin_all(int(7 * font_scale))
	if GLOW and primary:
		sb.shadow_color = Color(ACC.r, ACC.g, ACC.b, 0.4)
		sb.shadow_size = 4
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = ACC.lightened(0.2) if primary else ACC_DIM
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_color_override("font_color", Color("16130f") if primary else TEXT_C)
	b.add_theme_color_override("font_hover_color", Color("16130f"))

func _card(title: String = "", icon: String = "") -> Array:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_C
	sb.border_color = PANEL2_C.lightened(0.08)
	sb.set_border_width_all(BORDER_W)
	sb.set_corner_radius_all(RADIUS)
	if GLOW:
		sb.shadow_color = Color(ACC.r, ACC.g, ACC.b, 0.12)
		sb.shadow_size = 5
	sb.set_content_margin_all(int(12 * font_scale))
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(4 * font_scale))
	p.add_child(v)
	if title != "":
		var tl := _lbl(("%s " % icon if icon != "" else "") + title, 18, ACC)
		if DISPLAY_FONT != null:
			tl.add_theme_font_override("font", DISPLAY_FONT)
		v.add_child(tl)
	return [p, v]

func _grid(card_w: float = 500.0) -> GridContainer:
	var g := GridContainer.new()
	g.columns = _cols(card_w)
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g

func _bar(value: float, color: Color = Color("9c823a"), height: int = 8) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 100
	pb.value = clampf(value, 0.0, 100.0)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("14120f")
	pb.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	pb.add_theme_stylebox_override("fill", fg)
	return pb

# Farbiger Status-Chip mit Piktogramm
func _chip(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.13)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := _lbl(text, 11, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p

func _gender_symbol(a: Dictionary) -> String:
	return "♀" if str(a.get("g", "")) == "f" else "♂"

func _ethnicity_de(a: Dictionary) -> String:
	var eth := str(a.get("ethnicity", ""))
	if eth == "":
		return ""
	var map = Data.get("ETHNICITIES")
	if map is Dictionary:
		return str(map.get(eth, ""))
	return ""

# Meta-Zeile eines Schauspielers: Geschlecht · Alter · Geburtsjahr [· Ethnie] · Genres
# Bewusst OHNE Todesjahr — reale Todesdaten werden dem Spieler nicht gespoilert.
func _actor_meta(a: Dictionary, year: int, client_data: Dictionary = {}) -> String:
	var parts: Array = [_gender_symbol(a), "%d yrs" % Game.age_of(a, year), "*%d" % int(a.birth)]
	var eth_s := _ethnicity_de(a)
	if eth_s != "":
		parts.append(eth_s)
	parts.append(" · ".join(a.genres.map(_genre_de)))
	var body := Game.body_of(a)
	parts.append("%d cm" % int(body.height))
	if client_data.is_empty():
		parts.append("%d kg" % int(body.weight))
	else:
		var trend := float(client_data.get("weightTrend", 0.0))
		var arrow := " ↗" if trend > 0.1 else (" ↘" if trend < -0.1 else "")
		parts.append("%.1f kg%s" % [float(client_data.get("weightKg", body.weight)), arrow])
	return " · ".join(parts)

# "Bekannt aus: „Titel“ (Jahr) · …" — reale Filmografie bis zum aktuellen Spieljahr
func _filmography_line(a: Dictionary, year: int) -> String:
	var films: Array = a.get("films", [])
	var known: Array = films.filter(func(f): return int(f.get("year", 9999)) <= year)
	if known.is_empty():
		return ""
	known.sort_custom(func(x, y): return int(x.get("year", 0)) > int(y.get("year", 0)))
	var parts: Array = []
	for f in known.slice(0, 4):
		parts.append("“%s” (%d)" % [str(f.get("title", "?")), int(f.get("year", 0))])
	return "🎞 Known for: " + " · ".join(parts)

func _chip_row(chips: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for c in chips:
		h.add_child(c)
	return h

func _nego_header(icon_title: String, subtitle: String, chips: Array = []) -> VBoxContainer:
	var header := VBoxContainer.new()
	header.name = "NegotiationHeader"
	header.add_theme_constant_override("separation", 5)
	header.add_child(_lbl(icon_title, 22, ACC))
	if subtitle != "":
		header.add_child(_lbl(subtitle, 12, DIM))
	if chips.size():
		var chip_line := _chip_row(chips)
		chip_line.name = "NegotiationChips"
		header.add_child(chip_line)
	return header

func _nego_action_button(spec: Dictionary, primary: bool = false) -> Button:
	var cb: Callable = spec.get("cb", func(): pass)
	var button := _btn(str(spec.get("label", "Continue")), cb, primary)
	button.disabled = bool(spec.get("disabled", false))
	return button

func _nego_actions(primary: Dictionary, secondary: Array, cancel = null) -> HFlowContainer:
	var actions := HFlowContainer.new()
	actions.name = "NegotiationActions"
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 6)
	if not primary.is_empty():
		actions.add_child(_nego_action_button(primary, true))
	for spec in secondary:
		if spec is Dictionary and not spec.is_empty():
			actions.add_child(_nego_action_button(spec))
	if cancel is Callable and cancel.is_valid():
		actions.add_child(_btn("Cancel", cancel))
	return actions

func _nego_mood_chip(score: float) -> PanelContainer:
	var mood := Game.mood_label(score)
	var icon := {"thrilled": "😃", "interested": "🙂", "weighing it": "🤔", "dismissive": "😒"}.get(str(mood[0]), "")
	var color := GREEN if str(mood[1]) == "pos" else (RED if str(mood[1]) == "neg" else DIM)
	return _chip("%s Mood: %s" % [icon, str(mood[0])], color)

# Bipolarer DNA-Balken: füllt von der Mitte nach links oder rechts
class DnaBar extends Control:
	var value := 0.0
	var acc := Color("d4af37")
	func _init(v: float, a: Color) -> void:
		value = v
		acc = a
		custom_minimum_size = Vector2(140, 12)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color("14120f"))
		draw_rect(Rect2(w / 2.0 - 1, 0, 2, h), Color("453b2a"))
		var half := w / 2.0 - 2.0
		var frac: float = clampf(absf(value) / 100.0, 0.0, 1.0)
		var col := acc if absf(value) < 85 else Color("c0504d")
		if value >= 0:
			draw_rect(Rect2(w / 2.0, 2, half * frac, h - 4), col)
		else:
			draw_rect(Rect2(w / 2.0 - half * frac, 2, half * frac, h - 4), col)

func _dna_row(axis: Dictionary, value: float) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var neg := _lbl(axis.neg, 12, DIM if value > -25 else TEXT_C)
	neg.custom_minimum_size = Vector2(120 * font_scale, 0)
	neg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	neg.autowrap_mode = TextServer.AUTOWRAP_OFF
	var pos := _lbl(axis.pos, 12, DIM if value < 25 else TEXT_C)
	pos.custom_minimum_size = Vector2(120 * font_scale, 0)
	pos.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(neg)
	h.add_child(DnaBar.new(value, ACC))
	h.add_child(pos)
	return h

func _clear(node: Node) -> void:
	# WICHTIG: remove_child VOR queue_free — sonst bleiben die alten Kinder
	# bis zum Frame-Ende im Layout und Tabs/Karten erscheinen für einen Frame
	# doppelt („zerschossener“ Header beim Re-Render nach Deals/Modals).
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()

func _genre_de(g: String) -> String:
	return "%s %s" % [GENRE_ICONS.get(g, ""), Data.GENRES[g].label]

# =====================================================================
# Startbildschirm
# =====================================================================
var name_edit: LineEdit

func _build_start_screen() -> void:
	start_screen = CenterContainer.new()
	start_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(start_screen)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	start_screen.add_child(v)
	var title := _lbl("HOLLYWOOD MANAGER", 52, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if DISPLAY_FONT != null:
		title.add_theme_font_override("font", DISPLAY_FONT)
	v.add_child(title)
	var tag := _lbl("You don't make movies. You make careers.", 18, DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	v.add_child(_lbl("Name of your agency:", 13, DIM))
	name_edit = LineEdit.new()
	name_edit.text = "Morningstar & Partners"
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(340, 36)
	v.add_child(name_edit)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for era in Data.ERAS:
		var era_key: String = Jukebox.key_for_year(int(era.year))
		var theme: Dictionary = ERA_THEMES[era_key]
		var cv = _card("%s %d" % [theme.icon, int(era.year)])
		var card: PanelContainer = cv[0]
		var box: VBoxContainer = cv[1]
		card.custom_minimum_size = Vector2(290, 180)
		# Jede Epochen-Karte trägt ihre eigene Schrift & Farbwelt
		var era_lbl := _lbl(era.name, 15, theme.accent)
		var era_f := _era_font(era_key)
		if era_f != null:
			cv[1].get_child(0).add_theme_font_override("font", era_f)
			era_lbl.add_theme_font_override("font", era_f)
		box.add_child(era_lbl)
		box.add_child(_lbl(era.desc, 12, DIM))
		box.add_child(_btn("Start in %d" % int(era.year), _show_backstory_picker.bind(int(era.year)), true))
		grid.add_child(card)
	if Game.has_save():
		v.add_child(_btn("Continue saved game", _on_load_save, true))
	var credits := _lbl("Type & music from open sources: Limelight · Cinzel · Orbitron · Bebas Neue (SIL OFL)  —  Soundtrack: public-domain & CC0 recordings (assets/CREDITS.md)", 11, DIM)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(credits)

# Nach der Ära wählt der Spieler die Vorgeschichte seiner Figur
func _show_backstory_picker(year: int) -> void:
	_open_modal()
	modal_box.add_child(_lbl("Who are you? — Choose your backstory", 24, ACC))
	modal_box.add_child(_lbl("Your past shapes starting capital, contacts and special events — and one day it comes knocking again.", 13, DIM))
	var grid := _grid(420.0)
	modal_box.add_child(grid)
	for b in Data.BACKSTORIES:
		var cv = _card("%s %s" % [str(b.get("icon", "🎬")), str(b.name)])
		grid.add_child(cv[0])
		cv[1].add_child(_lbl(str(b.get("desc", "")), 12, DIM))
		var trait_de := str(b.get("trait", {}).get("de", ""))
		if trait_de != "":
			cv[1].add_child(_lbl("✔ " + trait_de, 12, GREEN))
		var weak_de := str(b.get("weakness", {}).get("de", ""))
		if weak_de != "":
			cv[1].add_child(_lbl("✖ " + weak_de, 12, RED))
		cv[1].add_child(_btn("Begin this way", _start_with_backstory.bind(year, str(b.id)), true))
	modal_box.add_child(_btn("Start without a special backstory (career changer)", _start_with_backstory.bind(year, "")))
	modal_box.add_child(_btn("Back", _close_modal))

func _start_with_backstory(year: int, bs_id: String) -> void:
	_close_modal()
	Game.new_game(name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "My Agency", year, bs_id)
	Jukebox.start(year)
	_enter_game()

# Kompatibilität für CLI-Screenshot-Hooks: direkter Start ohne Vorgeschichte
func _on_era_selected(year: int) -> void:
	_start_with_backstory(year, "")

func _on_load_save() -> void:
	if Game.load_game():
		Jukebox.start(int(Game.state.year))
		_enter_game()

func _enter_game() -> void:
	start_screen.visible = false
	game_root.visible = true
	current_tab = "buero"
	render()

# =====================================================================
# Spiel-UI-Gerüst
# =====================================================================
func _build_game_ui() -> void:
	game_root = VBoxContainer.new()
	game_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_root.visible = false
	add_child(game_root)

	var header := PanelContainer.new()
	header_sb = StyleBoxFlat.new()
	header_sb.bg_color = ERA_THEMES["noir"].header
	header_sb.border_color = GOLD
	header_sb.border_width_bottom = 2
	header_sb.set_content_margin_all(10)
	header.add_theme_stylebox_override("panel", header_sb)
	game_root.add_child(header)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	header.add_child(hb)
	var agency := _lbl("", 20, GOLD)
	agency.autowrap_mode = TextServer.AUTOWRAP_OFF
	header_stats["agency"] = agency
	hb.add_child(agency)
	era_chip = _lbl("", 12, GOLD)
	era_chip.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(era_chip)
	for key in [["date", "📅 Date"], ["cash", "💰 Capital"], ["rep", "⭐ Reputation"], ["network", "🤝 Favors"], ["market", "📈 Market"], ["clients", "👥 Clients"], ["instinct", "🧠 Instinct"], ["zustand", "🔋 Condition"], ["ort", "📍 Location"]]:
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 0)
		var cap := _lbl(key[1], 10, DIM)
		cap.autowrap_mode = TextServer.AUTOWRAP_OFF
		sv.add_child(cap)
		var val := _lbl("", 15, TEXT_C)
		val.autowrap_mode = TextServer.AUTOWRAP_OFF
		header_stats[key[0]] = val
		sv.add_child(val)
		hb.add_child(sv)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	var music_btn := _btn("🔊", func(): pass)
	music_btn.pressed.connect(func(): music_btn.text = "🔊" if Jukebox.toggle() else "🔇")
	header_stats["music"] = music_btn
	hb.add_child(music_btn)
	var vol := HSlider.new()
	vol.min_value = 0
	vol.max_value = 100
	vol.value = 35
	vol.custom_minimum_size = Vector2(90, 20)
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol.value_changed.connect(func(v): Jukebox.set_volume(v / 100.0))
	hb.add_child(vol)
	var save_btn := _btn("💾 Save", func(): Game.save_game())
	header_stats["save"] = save_btn
	hb.add_child(save_btn)
	var next_btn := _btn("End week ▸", _on_end_week, true)
	header_stats["next"] = next_btn
	hb.add_child(next_btn)

	# HFlowContainer: Tabs brechen bei schmalen Fenstern in eine zweite Zeile
	# um, statt rechts aus dem Fenster zu laufen.
	tab_bar = HFlowContainer.new()
	tab_bar.add_theme_constant_override("h_separation", 4)
	tab_bar.add_theme_constant_override("v_separation", 4)
	game_root.add_child(tab_bar)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_root.add_child(main)
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(content_scroll)
	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 10)
	content_scroll.add_child(content_box)
	side_scroll = ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(390, 0)
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(side_scroll)
	sidebar_box = VBoxContainer.new()
	sidebar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_box.add_theme_constant_override("separation", 10)
	side_scroll.add_child(sidebar_box)

func _build_modal_layer() -> void:
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.visible = false
	add_child(modal_layer)
	var dim_r := ColorRect.new()
	dim_r.color = Color(0, 0, 0, 0.72)
	dim_r.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim_r)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)
	modal_panel = PanelContainer.new()
	modal_sb = StyleBoxFlat.new()
	modal_sb.bg_color = PANEL_C
	modal_sb.border_color = GOLD
	modal_sb.set_border_width_all(2)
	modal_sb.set_content_margin_all(20)
	modal_panel.add_theme_stylebox_override("panel", modal_sb)
	center.add_child(modal_panel)
	modal_box = VBoxContainer.new()
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.add_theme_constant_override("separation", 8)
	modal_panel.add_child(modal_box)
	_update_modal_width()

func _update_modal_width() -> void:
	if modal_box == null or modal_panel == null:
		return
	# Verhindert schmale Buchstabensäulen, bleibt aber auch bei kleinen
	# Viewports vollständig sichtbar. Der Panelwert enthält die Innenränder.
	var viewport_w := float(get_viewport_rect().size.x)
	var content_w := minf(720.0 * font_scale, maxf(360.0, viewport_w - 120.0))
	modal_box.custom_minimum_size.x = content_w
	modal_panel.custom_minimum_size.x = minf(content_w + 40.0 * font_scale, viewport_w - 72.0)

# =====================================================================
# Rendering
# =====================================================================
func render() -> void:
	var st = Game.state
	if st == null:
		return
	_apply_era_theme()
	var theme: Dictionary = ERA_THEMES[_era_key]
	era_chip.text = "%s %s" % [theme.icon, theme.name]
	era_chip.add_theme_color_override("font_color", ACC)
	header_stats.music.tooltip_text = "♪ %s" % Jukebox.current_title()
	header_stats.agency.text = st.agency.name
	header_stats.agency.add_theme_color_override("font_color", ACC)
	header_stats.date.text = Game.date_str()
	header_stats.cash.text = Game.fmt_money(st.agency.cash)
	header_stats.cash.add_theme_color_override("font_color", RED if st.agency.cash < 0 else ACC)
	header_stats.rep.text = "%d/100" % int(st.agency.rep)
	header_stats.network.text = "%d%s" % [st.favors.size(), (" · ⚠%d owed" % st.debts.size()) if st.debts.size() else ""]
	header_stats.network.add_theme_color_override("font_color", AMBER if st.debts.size() else TEXT_C)
	header_stats.market.text = "%d %%%s" % [roundi(st.market * 100.0), "  ⚠" if int(st.strikeMonths) > 0 else ""]
	header_stats.market.add_theme_color_override("font_color", RED if st.market < 0.85 or int(st.strikeMonths) > 0 else (GREEN if st.market > 1.1 else TEXT_C))
	header_stats.clients.text = str(st.clients.size())
	header_stats.instinct.text = "%d/100" % int(st.get("instinct", 20))
	header_stats.instinct.add_theme_color_override("font_color", GREEN if int(st.get("instinct", 20)) >= 55 else TEXT_C)
	var pl: Dictionary = st.player
	header_stats.zustand.text = "🔋%d 😰%d" % [roundi(float(pl.energy)), roundi(float(pl.stress))]
	header_stats.zustand.add_theme_color_override("font_color", RED if float(pl.energy) < 25.0 or float(pl.stress) > 70.0 else TEXT_C)
	var cur_loc: Dictionary = Persona.location_def()
	header_stats.ort.text = "%s %s" % [str(cur_loc.icon), str(cur_loc.name)]
	header_stats.ort.add_theme_color_override("font_color", AMBER if Persona.is_away() else TEXT_C)
	header_stats.next.disabled = st.over
	side_scroll.custom_minimum_size = Vector2(_sidebar_w(), 0)

	_clear(tab_bar)
	var known_rumors: int = st.rumors.filter(func(r): return r.knownToPlayer).size()
	var tabs := [["buero", "🏢 Agency"], ["privat", "🎩 Personal"], ["kontakte", "📇 Contacts (%d⏱)" % int(st.contactAP)], ["orte", "🗺 Places"], ["klienten", "👥 Clients (%d)" % st.clients.size()], ["rumors", "🗣 Rumors (%d)" % known_rumors],
		["zeitung", "🗞 Newspaper"], ["pool", "🎭 Talent pool"], ["castings", "🎬 Castings (%d)" % st.castings.filter(func(cs): return not bool(cs.get("hidden", false))).size()], ["filme", "🎞 Films"], ["planer", "🗓 Planner"], ["finanzen", "💰 Finances"], ["chronik", "📰 Chronicle"]]
	for t in tabs:
		tab_bar.add_child(_btn(t[1], _switch_tab.bind(t[0]), t[0] == current_tab))

	_clear(content_box)
	match current_tab:
		"buero": _render_buero()
		"privat": _render_privat()
		"kontakte": _render_kontakte()
		"orte": _render_orte()
		"klienten": _render_klienten()
		"rumors": _render_rumors()
		"zeitung": _render_zeitung()
		"pool": _render_pool()
		"castings": _render_castings()
		"filme": _render_filme()
		"planer": _render_planer()
		"finanzen": _render_finanzen()
		"chronik": _render_chronik()
	_render_sidebar()

func _switch_tab(t: String) -> void:
	current_tab = t
	render()

func _on_end_week() -> void:
	var events: Array = Game.end_week()
	render()
	if events.size():
		modal_queue.append_array(events)
		_show_next_modal()


# ---------- Personal: the manager as their own system ----------
# Runs a persona action, then re-renders.
func _player_action(action: Callable) -> void:
	action.call()
	render()

func _stat_row(box: VBoxContainer, label: String, value: float, color: Color) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := _lbl("%s  %d/100" % [label, roundi(value)], 12, TEXT_C)
	l.custom_minimum_size = Vector2(180 * font_scale, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	var b := _bar(value, color)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	box.add_child(h)

func _render_privat() -> void:
	var st = Game.state
	var p: Dictionary = st.player
	var grid := _grid(520.0)
	content_box.add_child(grid)

	# Career & earned reputation title
	var cv = _card("Career", "🎩")
	grid.add_child(cv[0])
	cv[1].add_child(_lbl(str(Persona.career_def().name), 24, ACC))
	cv[1].add_child(_lbl("Reputation profile: %s — earned, not chosen. How you behave decides who calls and which deals reach you." % Persona.title(), 12, DIM))
	var reqs: Array = Persona.promotion_requirements()
	if reqs.is_empty():
		cv[1].add_child(_lbl("Top of the ladder — Hollywood knows no bigger name.", 13, GREEN))
	else:
		cv[1].add_child(_lbl("Next level: %s" % str(Data.CAREER_LEVELS[int(p.career) + 1].name), 14, TEXT_C))
		for r in reqs:
			cv[1].add_child(_lbl(("✔ " if r.met else "✖ ") + str(r.label), 12, GREEN if r.met else DIM))
		cv[1].add_child(_lbl("Promotion happens automatically at the end of the month once everything is met.", 11, DIM))

	# Private finances — strictly separate from the agency till
	var fv = _card("Private finances", "💼")
	grid.add_child(fv[0])
	var cash := float(p.cash)
	fv[1].add_child(_lbl(("Private wealth: %s" if cash >= 0.0 else "Private debt: %s") % Game.fmt_money(absf(cash)), 17, GREEN if cash >= 0.0 else RED))
	fv[1].add_child(_lbl("Salary: %s/month + %d%% royalty on commissions" % [Game.fmt_money(Persona.salary()), roundi(Persona.ROYALTY * 100.0)], 12, DIM))
	fv[1].add_child(_lbl("Living costs: %s/month — the lifestyle grows with the title" % Game.fmt_money(Persona.living_cost()), 12, DIM))
	if cash < 0.0:
		fv[1].add_child(_lbl("⚠ Private debt accrues 2% interest per month.", 12, RED))
	var draw := _btn("Private draw: +%s to your own account" % Game.fmt_money(Persona.salary()), _player_action.bind(Persona.draw), true)
	draw.disabled = not Persona.can_act("draw") or float(st.agency.cash) < Persona.salary()
	fv[1].add_child(draw)
	fv[1].add_child(_lbl("Private injection into the agency:", 12, DIM))
	var inj_row := HBoxContainer.new()
	inj_row.add_theme_constant_override("separation", 6)
	fv[1].add_child(inj_row)
	for mult in [1, 3, 10]:
		var amount: float = Persona.salary() * float(mult)
		var ib := _btn(Game.fmt_money(amount), _player_action.bind(Persona.inject.bind(amount)))
		ib.disabled = cash < amount
		inj_row.add_child(ib)
	var entries: Array = p.ledger.slice(maxi(0, p.ledger.size() - 6))
	if not entries.is_empty():
		fv[1].add_child(_lbl("Recent bookings:", 12, DIM))
		entries.reverse()
		for e in entries:
			var amt := float(e.amount)
			fv[1].add_child(_lbl("%s%s — %s" % ["+" if amt >= 0.0 else "−", Game.fmt_money(absf(amt)), str(e.text)], 11, GREEN if amt >= 0.0 else RED))

	# Condition: energy, stress, health + recovery actions
	var zv = _card("Condition", "🧘")
	grid.add_child(zv[0])
	_stat_row(zv[1], "🔋 Energy", float(p.energy), GREEN if float(p.energy) >= 25.0 else RED)
	_stat_row(zv[1], "😰 Stress", float(p.stress), RED if float(p.stress) > 70.0 else AMBER)
	_stat_row(zv[1], "❤ Health", float(p.health), GREEN if float(p.health) >= 40.0 else RED)
	zv[1].add_child(_lbl("Workload drains energy, crises build stress. Chronic stress eats your health — all the way to the clinic.", 11, DIM))
	var vac := _btn("🌴 Time off in Palm Springs (−%s)" % Game.fmt_money(roundf(220.0 * Game.infl(st.year))), _player_action.bind(Persona.vacation))
	vac.disabled = not Persona.can_act("vacation")
	zv[1].add_child(vac)
	var doc := _btn("🩺 Doctor's checkup (−%s)" % Game.fmt_money(roundf(150.0 * Game.infl(st.year))), _player_action.bind(Persona.checkup))
	doc.disabled = not Persona.can_act("checkup")
	zv[1].add_child(doc)
	zv[1].add_child(_lbl("Once per month each.", 11, DIM))

	# Reputation & influence — the manager has a standing of their own
	var rv = _card("Reputation & influence", "🌟")
	grid.add_child(rv[0])
	_stat_row(rv[1], "📰 Public reputation", float(p.pubRep), BLUE)
	_stat_row(rv[1], "🏛 Industry standing", float(p.indRep), ACC)
	_stat_row(rv[1], "🤫 Discretion", float(p.discretion), BLUE)
	_stat_row(rv[1], "🧲 Influence", float(p.influence), AMBER)
	rv[1].add_child(_lbl("Industry standing follows the agency's reputation, influence grows with career level and open favors. Scandals hit your public reputation first.", 11, DIM))

	# Assistant & delegation (Feature 4): from doing to managing
	var av = _card("Assistant & delegation", "🧑‍💼")
	grid.add_child(av[0])
	if not Persona.has_assistant():
		av[1].add_child(_lbl("Nobody covers the front desk. An assistant relieves stress, keeps neglected contacts warm and puts a morning note on your desk.", 12, DIM))
		av[1].add_child(_btn("Hire an assistant (wages ≈ %s/month)" % Game.fmt_money(roundf((Persona.ASSISTANT_BASE_WAGE + 75.0) * Game.infl(st.year))), _player_action.bind(Persona.hire_assistant), true))
	else:
		var a: Dictionary = Persona.assistant()
		av[1].add_child(_lbl("%s — skill %d/100 · wages %s/month (agency)" % [str(a.name), int(a.skill), Game.fmt_money(Persona.assistant_wage())], 13, TEXT_C))
		av[1].add_child(_lbl("Delegation rules — what may be handled without you:", 12, DIM))
		var up := _btn(("☑ " if Persona.rule("upkeep") else "☐ ") + "Relationship upkeep: check in on neglected contacts weekly", _player_action.bind(Persona.set_rule.bind("upkeep", not Persona.rule("upkeep"))))
		av[1].add_child(up)
		var br := _btn(("☑ " if Persona.rule("briefing") else "☐ ") + "Morning note: weekly decision brief on promises, contacts & crises", _player_action.bind(Persona.set_rule.bind("briefing", not Persona.rule("briefing"))))
		av[1].add_child(br)
		av[1].add_child(_lbl("The “Send assistant” contact channel is only available while someone holds this desk.", 11, DIM))
		av[1].add_child(_btn("Let %s go" % str(a.name), _player_action.bind(Persona.fire_assistant)))

# ---------- Contacts: relationships over real channels ----------
func _on_contact_channel(cid: int, key: String) -> void:
	var res: Dictionary = Persona.contact_interact(cid, key)
	_open_modal()
	modal_box.add_child(_lbl("Reaching out", 22, ACC))
	modal_box.add_child(_rich(str(res.text), 14))
	modal_box.add_child(_btn("Continue", _modal_done, true))

func _modal_done() -> void:
	_close_modal()
	render()

func _months_ago(m: int) -> String:
	var diff := Game.mi() - m
	if diff <= 0:
		return "this month"
	if diff == 1:
		return "a month ago"
	return "%d months ago" % diff

func _render_kontakte() -> void:
	var st = Game.state
	var head = _card("Relationship work", "📇")
	content_box.add_child(head[0])
	head[1].add_child(_lbl("Contact time this week: %d/%d ⏱ — personal appointments cost more time than a phone call. All costs come out of your private account (currently %s)." % [int(st.contactAP), Persona.AP_PER_WEEK, Game.fmt_money(st.player.cash)], 13))
	head[1].add_child(_lbl("People remember: whether you came yourself or sent the assistant, what you promised — and how long you kept them waiting.", 12, DIM))

	# Promise register: your own commitments + favor debts
	var pv = _card("Promise register", "🤞")
	content_box.add_child(pv[0])
	var pr_list: Array = st.promises.slice(maxi(0, st.promises.size() - 8))
	pr_list.reverse()
	if pr_list.is_empty() and st.debts.is_empty():
		pv[1].add_child(_lbl("No open commitments. Nobody owes anybody anything yet — that rarely lasts.", 12, DIM))
	for pr in pr_list:
		var status := str(pr.status)
		var color := AMBER if status == "open" else (GREEN if status == "kept" else RED)
		var suffix := " — due by %s" % Game.mi_str(pr.dueMi) if status == "open" else " (%s)" % status
		pv[1].add_child(_lbl("%s %s%s" % ["⏳" if status == "open" else ("✔" if status == "kept" else "✖"), str(pr.text), suffix], 12, color))
	for d in st.debts:
		pv[1].add_child(_lbl("⚠ Favor owed to %s: %s" % [d["from"].get("name", "?"), str(d.get("note", ""))], 12, AMBER))

	var grid := _grid(560.0)
	content_box.add_child(grid)
	for ct in st.contacts:
		var cv = _card(str(ct.name))
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		box.add_child(_chip(str(Data.CONTACT_ROLES.get(str(ct.type), str(ct.type))), BLUE))
		_stat_row(box, "💛 Relationship", float(ct.rel), ACC if float(ct.rel) >= 40.0 else DIM)
		box.add_child(_lbl("Last spoken: %s" % _months_ago(int(ct.lastMi)), 11, DIM))
		var mem: Array = ct.log.slice(0, 3)
		if not mem.is_empty():
			box.add_child(_lbl("Remembers:", 11, DIM))
			for entry in mem:
				box.add_child(_lbl("• %s (%s)" % [str(entry.text), Game.mi_str(entry.mi)], 11, TEXT_C))
		for pr in st.promises:
			if str(pr.status) == "open" and str(pr.to) == str(ct.name):
				box.add_child(_lbl("⏳ Open promise — due by %s" % Game.mi_str(pr.dueMi), 11, AMBER))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		box.add_child(flow)
		for key in Data.CONTACT_CHANNELS:
			var ch: Dictionary = Data.CONTACT_CHANNELS[key]
			var cost := Persona.channel_cost(key)
			var label := "%s %s" % [str(ch.icon), str(ch.name)]
			if cost > 0.0:
				label += " (−%s)" % Game.fmt_money(cost)
			if int(ch.ap) > 0:
				label += " %d⏱" % int(ch.ap)
			var b := _btn(label, _on_contact_channel.bind(int(ct.id), str(key)))
			var reason: String = Persona.contact_blocked_reason(ct, key)
			b.disabled = reason != ""
			b.tooltip_text = str(ch.desc) + ("" if reason == "" else "\n⛔ " + reason)
			flow.add_child(b)

# ---------- Locations: the node map with presence ----------
func _on_travel(id_s: String) -> void:
	Persona.travel_to(id_s)
	render()

func _on_location_action() -> void:
	var text_s: String = Persona.do_location_action()
	if text_s == "":
		render()
		return
	_open_modal()
	modal_box.add_child(_lbl("%s %s" % [str(Persona.location_def().icon), str(Persona.location_def().name)], 22, ACC))
	modal_box.add_child(_rich(text_s, 14))
	modal_box.add_child(_btn("Continue", _modal_done, true))

func _render_orte() -> void:
	var st = Game.state
	var cur: Dictionary = Persona.location_def()
	var head = _card("Presence", "🗺")
	content_box.add_child(head[0])
	head[1].add_child(_lbl("You are in: %s %s" % [str(cur.icon), str(cur.name)], 16, ACC))
	if Persona.is_away():
		head[1].add_child(_lbl("⚠ Without you in L.A.: clients lose trust and mood every week, and meetings or club nights with your contacts are impossible.", 12, AMBER))
	else:
		head[1].add_child(_lbl("Traveling costs the week's contact time, energy and agency expenses. Whoever is away misses what happens at home — and finds doors elsewhere that L.A. does not have.", 12, DIM))

	var grid := _grid(520.0)
	content_box.add_child(grid)
	for loc in Data.LOCATIONS:
		var id_s := str(loc.id)
		var cv = _card("%s %s" % [str(loc.icon), str(loc.name)])
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		box.add_child(_lbl(str(loc.desc), 12, DIM))
		if loc.has("months"):
			box.add_child(_chip("📅 Season: %s" % Game.MONTHS[int(loc.months[0]) - 1], AMBER))
		if id_s == Persona.location_id():
			box.add_child(_chip("📍 You are here", GREEN))
			if loc.get("action") != null:
				box.add_child(_lbl(str(loc.action.desc), 11, DIM))
				var ab := _btn("★ %s" % str(loc.action.name), _on_location_action, true)
				ab.disabled = not Persona.location_action_available()
				ab.tooltip_text = str(loc.action.desc) + ("" if not ab.disabled else "\n⛔ Already done this week")
				box.add_child(ab)
		else:
			var cost := Persona.travel_cost(id_s)
			var label := "✈ Travel there" if id_s != "la" else "✈ Back to Los Angeles"
			if cost > 0.0:
				label += " (−%s)" % Game.fmt_money(cost)
			var tb := _btn(label, _on_travel.bind(id_s), id_s == "la")
			var reason: String = Persona.travel_blocked_reason(id_s)
			tb.disabled = reason != ""
			tb.tooltip_text = "Costs the week's contact time and %d energy." % roundi(float(loc.energy)) + ("" if reason == "" else "\n⛔ " + reason)
			box.add_child(tb)

# ---------- Sidebar ----------
func _render_sidebar() -> void:
	_clear(sidebar_box)
	var st = Game.state
	var cv = _card("Pipeline", "🎬")
	sidebar_box.add_child(cv[0])
	var any := false
	for cs in st.castings:
		if bool(cs.get("hidden", false)):
			continue  # Coverage-Casting: erscheint erst nächsten Monat
		var open := 0
		for r in cs.roles:
			if r.filled == null:
				open += 1
		cv[1].add_child(_lbl("%s “%s” — casting: %d wk left, %d role(s) open" % [GENRE_ICONS.get(cs.genre, "🎬"), cs.title, int(cs.deadline), open], 12, AMBER if open > 0 else DIM))
		any = true
	for p in st.productions:
		Game.ensure_prod_fields(p)
		cv[1].add_child(_lbl("🎥 “%s” — premiere in ~%d wk" % [p.title, int(p.weeksLeft)], 12, BLUE))
		any = true
	if not any:
		cv[1].add_child(_lbl("Nothing in the works. Time to hustle.", 12, DIM))
	# Set-Signale laufender Produktionen (Feature 13) — unzuverlässig, aber laut
	var sig_lines: Array = []
	for p in st.productions:
		for sig in p.get("signals", []):
			var sig_icon := "🟢" if bool(sig.get("pos", true)) else "🔴"
			sig_lines.append([int(sig.get("mi", 0)), "%s “%s”: %s" % [sig_icon, p.title, str(sig.get("t", ""))]])
	if sig_lines.size():
		sig_lines.sort_custom(func(a, b): return a[0] > b[0])
		var sv = _card("Set signals (rumor mill)", "📡")
		sidebar_box.add_child(sv[0])
		for sl in sig_lines.slice(0, 5):
			sv[1].add_child(_lbl(str(sl[1]), 12, GREEN if str(sl[1]).begins_with("🟢") else RED))
	var deadlines: Array = []
	for c in st.clients:
		for pr in c.promises:
			if not pr.fulfilled and not pr.get("broken", false):
				deadlines.append([int(pr.due), "📜 %s: %s" % [Game.client_name(c), pr.label]])
		if int(c.contractEnd) - Game.mi() <= 12:
			deadlines.append([int(c.contractEnd), "📄 Contract with %s expiring" % Game.client_name(c)])
	if deadlines.size():
		deadlines.sort_custom(func(a, b): return a[0] < b[0])
		var dv = _card("Deadlines", "⏳")
		sidebar_box.add_child(dv[0])
		for d in deadlines.slice(0, 6):
			var urgent: bool = d[0] - Game.mi() <= 3
			dv[1].add_child(_lbl("%s — %s" % [d[1], Game.mi_str(d[0])], 12, RED if urgent else DIM))
	var tv = _card("Ticker", "📰")
	sidebar_box.add_child(tv[0])
	for l in st.log.slice(0, 12):
		var col: Color = {"deal": GREEN, "bad": RED, "history": ACC}.get(l.type, DIM)
		tv[1].add_child(_lbl("%s %s %d — %s" % [LOG_ICONS.get(l.type, "•"), Game.MONTHS[int(l.m) - 1].substr(0, 3), int(l.y), l.text], 12, col))

# ---------- Tab: Agency ----------
func _render_buero() -> void:
	var st = Game.state
	var grid := _grid(560.0)
	grid.columns = clampi(grid.columns, 1, 3)
	content_box.add_child(grid)

	var c1 = _card(st.agency.name, "🏢")
	grid.add_child(c1[0])
	c1[1].add_child(_lbl("Founded %d · %s" % [int(st.startYear), Game.date_str()], 12, DIM))
	c1[1].add_child(_lbl("💰 Capital: %s" % Game.fmt_money(st.agency.cash), 14, RED if st.agency.cash < 0 else TEXT_C))
	c1[1].add_child(_lbl("⭐ Reputation: %d/100 — decides which stars will talk to you" % int(st.agency.rep), 14))
	c1[1].add_child(_bar(st.agency.rep, ACC))
	c1[1].add_child(_lbl("Office costs/month: %s (of which perks: %s)" % [Game.fmt_money(Game.overhead()), Game.fmt_money(Game.perk_costs())], 13, DIM))
	var bs_def := Game.backstory_def()
	if not bs_def.is_empty():
		c1[1].add_child(_lbl("%s Backstory: %s" % [str(bs_def.get("icon", "🎬")), str(bs_def.name)], 13, ACC))
		var bs_trait := str(bs_def.get("trait", {}).get("de", ""))
		if bs_trait != "":
			c1[1].add_child(_lbl("✔ " + bs_trait, 12, GREEN))
		var bs_weak := str(bs_def.get("weakness", {}).get("de", ""))
		if bs_weak != "":
			c1[1].add_child(_lbl("✖ " + bs_weak, 12, RED))

	# Konkrete Gefallen & Schulden statt eines abstrakten Netzwerk-Werts
	var cg = _card("Favors & debts", "🤝")
	grid.add_child(cg[0])
	if st.favors.is_empty() and st.debts.is_empty():
		cg[1].add_child(_lbl("Nobody owes you anything — and you owe nobody. In this town that is almost suspicious.", 13, DIM))
	for f in st.favors:
		var exp_s: String = (" · expires %s" % Game.mi_str(f.expiresMi)) if int(f.expiresMi) >= 0 else ""
		cg[1].add_child(_lbl("🤝 %s — %s%s" % [f["from"].get("name", "?"), Game.FAVOR_KINDS.get(str(f.kind), {}).get("name", str(f.kind)), exp_s], 12, GREEN))
	for d in st.debts:
		cg[1].add_child(_lbl("⚠ You owe %s: %s" % [d["from"].get("name", "?"), Game.FAVOR_KINDS.get(str(d.kind), {}).get("name", str(d.kind))], 12, AMBER))

	var c2 = _card("Market %d%%" % roundi(st.market * 100.0), "📈")
	grid.add_child(c2[0])
	if int(st.strikeMonths) > 0:
		c2[1].add_child(_chip("⚠ Strike: %d month(s) left" % int(st.strikeMonths), RED))
	c2[1].add_child(_bar(clampf(st.market * 60.0, 0.0, 100.0), RED if st.market < 0.85 else (GREEN if st.market > 1.1 else ACC_DIM)))
	c2[1].add_child(_lbl("👥 Clients: %d · 🎥 Productions: %d · 🎞 Brokered films: %d" % [st.clients.size(), st.productions.size(), st.released.size()], 13, DIM))
	var awards := 0
	for c in st.clients:
		awards += int(c.get("awards", 0))
	c2[1].add_child(_lbl("🏆 Awards won: %d" % awards, 13, DIM))
	var gw = Game.genre_weights()
	var keys := gw.keys()
	keys.sort_custom(func(a, b): return gw[a] > gw[b])
	var demand: Array = []
	for k in keys.slice(0, 5):
		demand.append(_genre_de(k))
	c2[1].add_child(_lbl("In demand: " + " · ".join(demand), 13, DIM))

	var c3 = _card("Studio relations", "🏛")
	grid.add_child(c3[0])
	for s in Game.active_studios():
		var row := HBoxContainer.new()
		var style_icon: String = {"prestige": "🎩", "indie": "🎨", "commercial": "🏭"}[s.style]
		var nm := _lbl("%s %s" % [style_icon, s.name], 13, DIM)
		nm.custom_minimum_size = Vector2(250 * font_scale, 0)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(nm)
		var rel: float = st.studioRel[s.id]
		var pb := _bar(rel, GREEN if rel >= 60 else (RED if rel < 30 else ACC_DIM))
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pb)
		c3[1].add_child(row)

	var c4 = _card("Open promises", "📜")
	grid.add_child(c4[0])
	var any_pr := false
	for c in st.clients:
		for pr in c.promises:
			if not pr.fulfilled and not pr.get("broken", false):
				var urgent: bool = int(pr.due) - Game.mi() <= 3
				c4[1].add_child(_lbl("📜 %s: %s — due %s" % [Game.client_name(c), pr.label, Game.mi_str(pr.due)], 13, RED if urgent else DIM))
				any_pr = true
	if not any_pr:
		c4[1].add_child(_lbl("None. An agent without promises is an agent without clients.", 13, DIM))

	var ci = _card("Moral identity", "🪞")
	grid.add_child(ci[0])
	var top_labels := Game.identity_top_labels()
	ci[1].add_child(_lbl("Your agency is considered: %s" % ("still unwritten" if top_labels.is_empty() else " & ".join(top_labels)), 14, ACC))
	var identity_max := 1.0
	for key in Game.IDENTITY_KEYS:
		identity_max = maxf(identity_max, float(st.identity.get(key, 0.0)))
	for key in Game.IDENTITY_KEYS:
		var identity_row := HBoxContainer.new()
		var identity_name := _lbl(Game.IDENTITY_LABELS[key].capitalize(), 12, DIM)
		identity_name.custom_minimum_size = Vector2(150 * font_scale, 0)
		identity_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		identity_row.add_child(identity_name)
		var identity_bar := _bar(float(st.identity.get(key, 0.0)) / identity_max * 100.0, ACC_DIM, 7)
		identity_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		identity_row.add_child(identity_bar)
		ci[1].add_child(identity_row)

	var cr = _card("Rival agencies", "⚔")
	grid.add_child(cr[0])
	for rival in st.rivals:
		var info: Dictionary = Game.RIVAL_STYLE_INFO.get(str(rival.style), {"label":str(rival.style), "icon":"◆"})
		var rr := HBoxContainer.new()
		var rival_text := _lbl("%s %s · %s · %d clients" % [info.icon, rival.name, info.label, rival.clients.size()], 12, DIM)
		rival_text.custom_minimum_size = Vector2(280 * font_scale, 0)
		rival_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		rr.add_child(rival_text)
		var rel_value := (float(rival.rel) + 100.0) * 0.5
		var rel_bar := _bar(rel_value, GREEN if float(rival.rel) >= 20.0 else (RED if float(rival.grudge) >= 60.0 else ACC_DIM), 8)
		rel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rr.add_child(rel_bar)
		cr[1].add_child(rr)
		cr[1].add_child(_lbl("Relations %+d · Grudge %d/100%s" % [roundi(float(rival.rel)), roundi(float(rival.grudge)), (" · House studio: " + Game._studio(str(rival.studioId)).name) if str(rival.get("studioId", "")) != "" else ""], 11, RED if float(rival.grudge) >= 60.0 else DIM))

	var cp = _card("Power players", "🎬")
	grid.add_child(cp[0])
	if st.powerFigures.is_empty():
		cp[1].add_child(_lbl("None of your stars directs or produces yet.", 12, DIM))
	for figure in st.powerFigures:
		var role_label := "directing" if str(figure.role) == "director" else "producing"
		var figure_rival = Game.rival_by_id(str(figure.rivalId))
		var allegiance := "close to your house" if bool(figure.agencyFriendly) else ("with %s" % figure_rival.name if figure_rival != null else "independent")
		cp[1].add_child(_lbl("🎥 %s · %s · %d Credits · %s" % [figure.name, role_label, int(figure.credits), allegiance], 12, GREEN if bool(figure.agencyFriendly) else RED))

	# Instinkt & Prognosen (Feature 6): wächst nur durch richtige Vorhersagen
	var ci2 = _card("Instinct %d/100" % int(st.get("instinct", 20)), "🧠")
	grid.add_child(ci2[0])
	ci2[1].add_child(_bar(float(st.get("instinct", 20)), GREEN if int(st.get("instinct", 20)) >= 55 else ACC_DIM))
	ci2[1].add_child(_lbl("Grows only through correct predictions. Sharpens talent pool grades (spread ±%d), script insights and gut feelings." % roundi(Game.pool_spread()), 12, DIM))
	var open_preds: Array = st.get("predictions", []).filter(func(pr): return not pr.get("resolved", false))
	var done_preds: Array = st.get("predictions", []).filter(func(pr): return pr.get("resolved", false))
	var hits := done_preds.filter(func(pr): return pr.get("correct", false)).size()
	if done_preds.size():
		ci2[1].add_child(_lbl("Track record: %d/%d correct" % [hits, done_preds.size()], 13, GREEN if hits * 2 >= done_preds.size() else AMBER))
	if open_preds.is_empty():
		ci2[1].add_child(_lbl("No open predictions. Shooting starts and signings will ask for your gut call.", 12, DIM))
	for pr in open_preds.slice(0, 5):
		ci2[1].add_child(_lbl("🔮 %s — resolves ~%s" % [str(pr.get("note", "prediction")), Game.mi_str(int(pr.get("dueMi", 0)))], 12, ACC))

	# Script Coverage: das Lektorats-Blatt auf dem Schreibtisch
	var cc = _card("Script Coverage", "📋")
	grid.add_child(cc[0])
	var cov_stats := Game.coverage_stats()
	if int(cov_stats.done) > 0:
		cc[1].add_child(_lbl("Hit rate: %d/%d correct%s" % [int(cov_stats.hits), int(cov_stats.done), (" · %d open" % int(cov_stats.open)) if int(cov_stats.open) > 0 else ""], 12, GREEN if int(cov_stats.hits) * 2 >= int(cov_stats.done) else AMBER))
	var cov_cur = st.coverage.get("current") if st.has("coverage") else null
	if cov_cur != null:
		cc[1].add_child(_lbl("“%s” — %s casts next month. The sheet expires at the end of the month." % [str(cov_cur.title), Game._studio(str(cov_cur.studioId)).name], 13, TEXT_C))
		var used_marks := 0
		for sttm in cov_cur.statements:
			if str(sttm.get("marked", "")) != "":
				used_marks += 1
		cc[1].add_child(_lbl("Markers: %d/%d set · %d statements" % [used_marks, int(cov_cur.markersMax), cov_cur.statements.size()], 12, AMBER if used_marks < int(cov_cur.markersMax) else DIM))
		cc[1].add_child(_btn("📋 Read coverage", _open_coverage, true))
	else:
		cc[1].add_child(_lbl("No sheet on the desk. The story department delivers an assessment of an upcoming casting roughly once a month — optional, but often worth gold.", 12, DIM))
		var cov_hist: Array = st.coverage.get("history", []) if st.has("coverage") else []
		if cov_hist.size():
			cc[1].add_child(_btn("📚 Archive (%d sheets)" % cov_hist.size(), _open_coverage))

# ---------- Script Coverage: Lektorats-Blatt & Archiv ----------
var _coverage_pick := -1          # Statement-Index, der auf eine Kategorie wartet
var _coverage_archive := false    # Archiv-Ansicht statt aktuellem Blatt
var _coverage_note := ""          # kurze Rückmeldung nach einem Marker

func _coverage_prediction_for(sheet_id: int, cat: String) -> Variant:
	for pr in Game.state.get("predictions", []):
		if str(pr.get("type", "")) == "coverage" and int(pr.subject.get("sheetId", -1)) == sheet_id and str(pr.subject.get("cat", "")) == cat:
			return pr
	return null

func _open_coverage() -> void:
	var st = Game.state
	_open_modal()
	var cur = st.coverage.get("current") if st.has("coverage") else null
	var y := int(st.year)
	if _coverage_archive:
		_render_coverage_archive()
		return
	if cur == null:
		modal_box.add_child(_lbl("📋 Script Coverage", 22, ACC))
		modal_box.add_child(_lbl("No sheet on the desk. The story department delivers an assessment of an upcoming casting roughly once a month.", 13, DIM))
		_coverage_archive = true
		_render_coverage_archive(true)
		return
	# Epochen-Tonfall: Schreibmaschine vor 1970, Listicle ab 2010
	if _coverage_pick >= 0:
		_render_coverage_pick(cur)
		return
	if y < 1970:
		modal_box.add_child(_lbl("COVERAGE · STRICTLY CONFIDENTIAL", 22, ACC))
		modal_box.add_child(_lbl("FROM: Story dept.  ·  RE: “%s”  ·  STUDIO: %s" % [str(cur.title), Game._studio(str(cur.studioId)).name], 12, DIM))
	elif y >= 2010:
		modal_box.add_child(_lbl("%d things you need to know about “%s”" % [cur.statements.size(), str(cur.title)], 22, ACC))
		modal_box.add_child(_lbl("%s · %s — the story department read it so you don't have to" % [Game._studio(str(cur.studioId)).name, _genre_de(str(cur.genre))], 12, DIM))
	else:
		modal_box.add_child(_lbl("📋 Coverage: “%s”" % str(cur.title), 22, ACC))
		modal_box.add_child(_lbl("%s · %s · %s" % [Game._studio(str(cur.studioId)).name, _genre_de(str(cur.genre)), "★".repeat(int(cur.prestige))], 12, DIM))
	modal_box.add_child(_rich("[i]%s[/i]" % str(cur.logline), 13))
	if _coverage_note != "":
		modal_box.add_child(_lbl(_coverage_note, 12, GREEN))
		_coverage_note = ""
	var used_marks := 0
	for sttm in cur.statements:
		if str(sttm.get("marked", "")) != "":
			used_marks += 1
	var marks_left: int = int(cur.markersMax) - used_marks
	modal_box.add_child(_lbl("Markers left: %d/%d — the sheet expires at the end of the month. Skipping costs nothing." % [marks_left, int(cur.markersMax)], 12, AMBER if marks_left > 0 else DIM))
	for i in cur.statements.size():
		var sttm: Dictionary = cur.statements[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		modal_box.add_child(row)
		var tl := _lbl("%d. %s" % [i + 1, str(sttm.get("text", ""))], 13, TEXT_C)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tl)
		var marked := str(sttm.get("marked", ""))
		if marked != "":
			var info: Dictionary = Game.COVERAGE_CATS.get(marked, {})
			var pr = _coverage_prediction_for(int(cur.id), marked)
			var state_icon := "⏳"
			if pr != null and bool(pr.get("resolved", false)):
				state_icon = "✅" if bool(pr.get("correct", false)) else "❌"
			row.add_child(_chip("%s %s %s" % [state_icon, info.get("icon", ""), info.get("name", marked)], ACC))
		elif marks_left > 0:
			row.add_child(_btn("🏷 Marker", _on_coverage_pick.bind(i)))
	modal_box.add_child(_lbl("Categories: 🛡 Safe role · 🎩 Prestige chance · 📉 Weak script · 🌟 Sleeper hit · ✂ Role gets cut · 🌪 Troubled production", 11, DIM))
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	modal_box.add_child(btn_row)
	btn_row.add_child(_btn("Close", _close_modal, true))
	if st.coverage.get("history", []).size():
		btn_row.add_child(_btn("📚 Archive (%d)" % st.coverage.history.size(), func():
			_coverage_archive = true
			_open_coverage()))

# Kategorie-Auswahl für eine Aussage
func _render_coverage_pick(cur: Dictionary) -> void:
	var sttm: Dictionary = cur.statements[_coverage_pick]
	modal_box.add_child(_lbl("🏷 Set a marker", 22, ACC))
	modal_box.add_child(_rich("[i]“%s”[/i]" % str(sttm.get("text", "")), 14))
	modal_box.add_child(_lbl("Which call do you put on this note? It resolves at the theatrical release — correct gives instinct +3, wrong costs only one point.", 12, DIM))
	for cat in Game.COVERAGE_CATS:
		var info: Dictionary = Game.COVERAGE_CATS[cat]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		modal_box.add_child(row)
		var dl := _lbl("%s %s — %s" % [info.icon, info.name, info.desc], 12, TEXT_C)
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(dl)
		var stmt_idx := _coverage_pick
		row.add_child(_btn("Choose", _on_coverage_mark.bind(stmt_idx, cat)))
	modal_box.add_child(_btn("Back", _on_coverage_pick.bind(-1)))

func _on_coverage_pick(i: int) -> void:
	_coverage_pick = i
	_open_coverage()

func _on_coverage_mark(stmt_idx: int, cat: String) -> void:
	_coverage_pick = -1
	_coverage_note = Game.coverage_mark(stmt_idx, cat)
	_open_coverage()

# Archiv der letzten 8 Blätter inkl. Trefferquote (embedded = ohne eigene Kopfzeile)
func _render_coverage_archive(embedded: bool = false) -> void:
	var st = Game.state
	if not embedded:
		modal_box.add_child(_lbl("📚 Coverage archive", 22, ACC))
	var cov_stats := Game.coverage_stats()
	modal_box.add_child(_lbl("Overall hit rate: %d/%d markers correct%s" % [int(cov_stats.hits), int(cov_stats.done), (" · %d waiting for release" % int(cov_stats.open)) if int(cov_stats.open) > 0 else ""], 13, GREEN if int(cov_stats.hits) * 2 >= int(cov_stats.done) else AMBER))
	var hist: Array = st.coverage.get("history", [])
	if hist.is_empty():
		modal_box.add_child(_lbl("No expired sheets yet.", 12, DIM))
	for sheet in hist:
		var marks: Array = []
		var truth_n := 0
		for sttm in sheet.statements:
			if bool(sttm.get("truth", false)):
				truth_n += 1
			var marked := str(sttm.get("marked", ""))
			if marked == "":
				continue
			var info: Dictionary = Game.COVERAGE_CATS.get(marked, {})
			var pr = _coverage_prediction_for(int(sheet.id), marked)
			var icon := "⏳"
			if pr != null and bool(pr.get("resolved", false)):
				icon = "✅" if bool(pr.get("correct", false)) else "❌"
			marks.append("%s %s" % [icon, info.get("name", marked)])
		modal_box.add_child(_lbl("“%s” (%s) · story dept. was right: %d/%d%s" % [str(sheet.title), Game.mi_str(int(sheet.mi)), truth_n, sheet.statements.size(),
			(" · markers: " + " · ".join(marks)) if marks.size() else " · no markers set"], 12, TEXT_C))
	var back_row := HBoxContainer.new()
	back_row.add_theme_constant_override("separation", 8)
	modal_box.add_child(back_row)
	if st.coverage.get("current") != null:
		back_row.add_child(_btn("📋 Current sheet", func():
			_coverage_archive = false
			_open_coverage(), true))
	back_row.add_child(_btn("Close", _close_modal, st.coverage.get("current") == null))

# ---------- Tab: Clients (incl. career DNA & dossier) ----------
func _render_klienten() -> void:
	var st = Game.state
	if st.clients.is_empty():
		var cv = _card("No clients yet", "👥")
		cv[1].add_child(_lbl("Go to the talent pool and convince somebody that you will turn their career into gold.", 13, DIM))
		content_box.add_child(cv[0])
		return
	var grid := _grid(640.0)
	content_box.add_child(grid)
	for c in st.clients:
		var a: Dictionary = Game.actor_by_id[c.aid]
		var busy := not Game.is_free(c)
		var cv = _card("%s %s" % [a.name, "🏆".repeat(int(c.get("awards", 0)))])
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		var chips: Array = []
		chips.append(_chip("🎬 On set until %s" % Game.mi_str(c.busyUntil), BLUE) if busy else _chip("🟢 Available", GREEN))
		if c.heat >= 4:
			chips.append(_chip("🔥 Hot +%d" % roundi(c.heat), RED))
		elif c.heat <= -4:
			chips.append(_chip("❄ Cold %d" % roundi(c.heat), BLUE))
		if c.exhaustion > 60:
			chips.append(_chip("⚠ Overworked", RED))
		if c.flags.get("typecast", false):
			chips.append(_chip("🎭 Typecast", AMBER))
		if c.flags.get("typecastRisk", false):
			chips.append(_chip("⚠ Typecasting risk", AMBER))
		if c.flags.get("tvIncome") != null and int(c.flags.tvIncome.months) > 0:
			chips.append(_chip("📺 TV series: %d mo." % int(c.flags.tvIncome.months), BLUE))
		if str(c.flags.get("powerFigure", "")) != "":
			chips.append(_chip("🎬 Power player: %s" % ("directing" if str(c.flags.powerFigure) == "director" else "producing"), GOLD))
		chips.append(_chip("📈 Rising", GREEN) if st.year < a.peak else _chip("📉 Past the peak", DIM))
		box.add_child(_chip_row(chips))
		box.add_child(_lbl(_actor_meta(a, st.year, c), 12, DIM))
		box.add_child(_lbl("Talent %s · Charisma %s · Discipline %s · Presence %s" % [
			Game.grade_range(Game.eff_talent(c), 4, str(a.id) + "tal"), Game.grade_range(Game.attrs(a).charisma, 4, str(a.id) + "cha"),
			Game.grade_range(Game.attrs(a).discipline, 4, str(a.id) + "dis"), Game.grade_range(Game.attrs(a).presence, 4, str(a.id) + "pre")], 12, DIM))
		box.add_child(_lbl("📄 %d%% commission · until %s · 💰 fee %s" % [int(c.commission), Game.mi_str(c.contractEnd), Game.fmt_money(Game.ask_fee(c.fame, st.year))], 12, DIM))
		if c.perks.size():
			box.add_child(_lbl("🎁 " + ", ".join(c.perks.map(func(p): return Game.PERKS[p].name)), 12, GREEN))
		var row := GridContainer.new()
		row.columns = 5
		row.add_theme_constant_override("h_separation", 14)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(row)
		for stat in [["⭐ Fame", c.fame, ACC], ["❤ Loyalty", c.loyalty, RED if c.loyalty < 35 else GREEN], ["🔐 Trust", c.trust, RED if c.trust < 25 else GREEN], ["😊 Mood", c.mood, RED if c.mood < 35 else ACC_DIM], ["🔋 Exhaustion", c.exhaustion, RED if c.exhaustion > 60 else BLUE]]:
			var sv := VBoxContainer.new()
			sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sl := _lbl("%s %d" % [stat[0], roundi(stat[1])], 11, DIM)
			sl.autowrap_mode = TextServer.AUTOWRAP_OFF
			sv.add_child(sl)
			sv.add_child(_bar(stat[1], stat[2]))
			row.add_child(sv)
		box.add_child(_lbl("🧬 Career DNA — public image: “%s”" % Game.dna_label(c), 13, ACC))
		for ax in Game.DNA_AXES:
			box.add_child(_dna_row(ax, c.dna[ax.key]))
		var narrative: Dictionary = c.get("narrative", {})
		if not narrative.is_empty():
			var narrative_info: Dictionary = Game.NARRATIVE_TYPES.get(str(narrative.type), {"label":str(narrative.type), "desc":""})
			var narrative_color := GREEN if str(narrative.status) == "abgeschlossen" else ACC
			box.add_child(_lbl("📖 %s%s" % [narrative_info.label, " · completed" if str(narrative.status) == "abgeschlossen" else ""], 13, narrative_color))
			box.add_child(_lbl(str(narrative_info.desc), 11, DIM))
			box.add_child(_bar(float(narrative.get("progress", 0.0)), narrative_color, 8))
		elif Game.narrative_candidate_types(c).size():
			box.add_child(_lbl("📖 Declare a possible career narrative (PR budget)", 13, ACC))
			var narrative_buttons := HFlowContainer.new()
			narrative_buttons.add_theme_constant_override("h_separation", 6)
			narrative_buttons.add_theme_constant_override("v_separation", 6)
			for type_s in Game.narrative_candidate_types(c):
				narrative_buttons.add_child(_btn(str(Game.NARRATIVE_TYPES[type_s].label), _on_narrative.bind(int(c.id), str(type_s))))
			box.add_child(narrative_buttons)
		for pr in c.promises:
			var icon := "✅" if pr.fulfilled else ("❌" if pr.get("broken", false) else "📜")
			var pcol := GREEN if pr.fulfilled else (RED if pr.get("broken", false) else DIM)
			box.add_child(_lbl("%s %s" % [icon, pr.label], 12, pcol))
		if c.secrets.size():
			box.add_child(_lbl("🔒 Confidential dossier", 13, ACC))
			for secret in c.secrets:
				var info: Dictionary = Game.SECRET_TYPES.get(str(secret.type), {"label": str(secret.type)})
				var status_text := {"geheim": "under wraps", "entschärft": "prepared", "publik": "public"}.get(str(secret.status), str(secret.status))
				var status_color := GREEN if str(secret.status) == "entschärft" else (RED if str(secret.status) == "publik" else DIM)
				var sicon: String = SECRET_ICONS.get(str(secret.type), "◆")
				var secret_row := HBoxContainer.new()
				var secret_label := _lbl("%s %s · severity %d · %s (since %s)" % [sicon, info.label, int(secret.severity), status_text, Game.mi_str(secret.knownSince)], 12, status_color)
				secret_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				secret_row.add_child(secret_label)
				if str(secret.status) == "geheim":
					secret_row.add_child(_btn("Prepare", _on_secret_action.bind(int(c.id), str(secret.type), "prepare")))
				if str(secret.status) != "publik":
					secret_row.add_child(_btn("Sell to the press …", _on_secret_action.bind(int(c.id), str(secret.type), "sell")))
				box.add_child(secret_row)
		for f in c.films.slice(0, 3):
			var fcol := GREEN if f.verdict in ["Hit", "Blockbuster"] else (RED if f.verdict == "Flop" else DIM)
			box.add_child(_lbl("🎞 “%s” (%d) — %s, Q %d" % [f.title, int(f.year), f.verdict, int(f.quality)], 12, fcol))
		_render_career_board(box, c)

func _on_narrative(cid: int, type_s: String) -> void:
	_show_simple_modal("A career becomes a story", Game.declare_narrative(cid, type_s))

# ---------- Career board: 3 plan slots with a DNA trajectory ----------
func _render_career_board(box: VBoxContainer, c: Dictionary) -> void:
	Game.ensure_board(c)
	var board: Dictionary = c.careerBoard
	var ana := Game.board_analysis(c)
	box.add_child(_lbl("🎯 Career board — the next three projects%s" % (" · completed %d×" % int(board.get("completed", 0)) if int(board.get("completed", 0)) > 0 else ""), 13, ACC))
	# Ehrliche Vorschau der Folge: Bonus UND Risiko auf den Tisch
	if int(ana.planned) == Game.BOARD_SLOTS:
		if bool(ana.contrasting):
			box.add_child(_lbl("✨ Transformation bonus: three genres in a row — the press will celebrate the versatility (Unique rises).", 11, GREEN))
		elif bool(ana.repetitive):
			box.add_child(_lbl("⚠ Typecasting pull: the same profile three times — quick fame short-term, but the image hardens (risk from slot 3).", 11, AMBER))
		else:
			box.add_child(_lbl("A balanced sequence — neither fireworks nor pull, but control over the image.", 11, DIM))
		var proj_label: String = Game.dna_label({"dna": ana.projected})
		box.add_child(_lbl("Projection: “%s” → “%s” (under a normal run)" % [Game.dna_label(c), proj_label], 11, DIM))
	elif int(ana.planned) > 0:
		box.add_child(_lbl("%d slot(s) still free — only the full sequence shows its effect." % (Game.BOARD_SLOTS - int(ana.planned)), 11, DIM))
	var next_open := Game.board_next_open(c)
	for i in board.slots.size():
		var slot: Dictionary = board.slots[i]
		var filled := int(slot.get("filledMi", -1)) >= 0
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 8)
		box.add_child(srow)
		if filled:
			var fl := _lbl("✅ Slot %d: %s — fulfilled by “%s” (×1.5 imprint)" % [i + 1, Game.board_slot_label(slot), str(slot.get("filledTitle", ""))], 11, GREEN)
			fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			srow.add_child(fl)
		else:
			var sl2 := _lbl("%s Slot %d: %s%s" % ["🎯" if i == next_open else "▫", i + 1, Game.board_slot_label(slot), " — up next" if i == next_open else ""], 11, TEXT_C if i == next_open else DIM)
			sl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			srow.add_child(sl2)
			srow.add_child(_btn("✕", Game.board_slot_remove.bind(int(c.id), i)))
	if board.slots.size() < Game.BOARD_SLOTS:
		box.add_child(_btn("＋ Plan a role profile", _open_board_picker.bind(int(c.id))))
	# Narrativ-Integration: passende Profile per Ein-Klick-Übernahme
	var nar: Dictionary = c.get("narrative", {})
	if not nar.is_empty() and str(nar.get("status", "")) == "aktiv":
		var sug := Game.board_suggestions(c)
		var sug_labels: Array = []
		for s in sug:
			sug_labels.append(Game.board_slot_label({"genre": s[0], "roleType": s[1], "prestige": s[2]}))
		box.add_child(_lbl("📖 Suggestion for the narrative: %s" % "  →  ".join(sug_labels), 11, ACC))
		box.add_child(_btn("Adopt suggestion", _on_board_adopt.bind(int(c.id))))

var _board_picker := {}

func _on_board_adopt(cid: int) -> void:
	_show_simple_modal("Career board", Game.board_adopt_suggestion(cid))

func _open_board_picker(cid: int) -> void:
	_open_modal()
	modal_box.add_child(_lbl("＋ Plan a role profile", 22, ACC))
	modal_box.add_child(_lbl("An intention, not a specific film: genre + role type + prestige tier. The slot is fulfilled when a deal matches the genre OR the combination of type & tier.", 12, DIM))
	_board_picker = {"cid": cid}
	var genre_opt := OptionButton.new()
	for g in Data.GENRES:
		genre_opt.add_item(_genre_de(g))
	genre_opt.add_theme_font_size_override("font_size", int(14 * font_scale))
	modal_box.add_child(_lbl("Genre", 12, DIM))
	modal_box.add_child(genre_opt)
	_board_picker["genre"] = genre_opt
	var type_opt := OptionButton.new()
	type_opt.add_item("🎯 Lead")
	type_opt.add_item("▫ Supporting role")
	type_opt.add_theme_font_size_override("font_size", int(14 * font_scale))
	modal_box.add_child(_lbl("Role type", 12, DIM))
	modal_box.add_child(type_opt)
	_board_picker["type"] = type_opt
	var tier_opt := OptionButton.new()
	for t in [1, 2, 3]:
		tier_opt.add_item(str(Game.BOARD_PRESTIGE_TIERS[t]))
	tier_opt.add_theme_font_size_override("font_size", int(14 * font_scale))
	modal_box.add_child(_lbl("Prestige tier", 12, DIM))
	modal_box.add_child(tier_opt)
	_board_picker["tier"] = tier_opt
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	modal_box.add_child(btn_row)
	btn_row.add_child(_btn("Plan slot", _do_board_slot_add, true))
	btn_row.add_child(_btn("Cancel", _close_modal))

func _do_board_slot_add() -> void:
	var genres := Data.GENRES.keys()
	var g := str(genres[_board_picker.genre.selected])
	var rt := "lead" if _board_picker.type.selected == 0 else "support"
	var p: int = _board_picker.tier.selected + 1
	_show_simple_modal("Career board", Game.board_slot_add(int(_board_picker.cid), g, rt, p))

# ---------- Tab: Rumors ----------
func _render_rumors() -> void:
	content_box.add_child(_lbl("🗣 The whisper of the town", 22, ACC))
	content_box.add_child(_lbl("The public and the industry don't believe the same things. A lie can fizzle at the box office and still end a career behind studio doors.", 13, DIM))
	var launch_card = _card("Launch a rumor", "🕸")
	content_box.add_child(launch_card[0])
	launch_card[1].add_child(_lbl("Deliberately seed a rumor about free or rival-represented talent. Risky: if the agency is exposed, reputation, trust and moral identity suffer.", 12, DIM))
	var target_buttons := HFlowContainer.new()
	target_buttons.add_theme_constant_override("h_separation", 6)
	target_buttons.add_theme_constant_override("v_separation", 6)
	for actor in Game.rumor_targets().slice(0, 6):
		var owner = Game.rival_for_actor(str(actor.id))
		var suffix := " · %s" % owner.name if owner != null else ""
		target_buttons.add_child(_btn("🕸 %s%s" % [actor.name, suffix], _on_rumor_launch.bind(str(actor.id))))
	launch_card[1].add_child(target_buttons)
	var known: Array = Game.state.rumors.filter(func(r): return r.knownToPlayer)
	known.sort_custom(func(a, b): return maxf(float(a.belief), float(a.get("industryBelief", 0.0))) > maxf(float(b.belief), float(b.get("industryBelief", 0.0))))
	if known.is_empty():
		var empty = _card("The anteroom is still quiet", "🤫")
		empty[1].add_child(_lbl("Good assistants, studio contacts and a strong network let you hear earlier what the town is saying.", 13, DIM))
		content_box.add_child(empty[0])
		return
	var grid := _grid(620.0)
	content_box.add_child(grid)
	for rumor in known:
		var cv = _card(Game.rumor_subject_name(rumor), "🗣")
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		box.add_child(_rich("[i]“%s”[/i]" % rumor.text, 14))
		var chips: Array = [_chip("Topic: %s" % str(rumor.topic).capitalize(), BLUE), _chip("⏳ %d month(s) in circulation" % int(rumor.age), DIM)]
		if Game.player_knows_rumor_truth(rumor):
			chips.append(_chip("🔒 Confirmed by your dossier", GREEN))
		if rumor.belief >= 60:
			chips.append(_chip("⚠ Publicly effective", RED))
		if float(rumor.get("industryBelief", 0.0)) >= 60:
			chips.append(_chip("🏛 Effective inside the industry", AMBER))
		box.add_child(_chip_row(chips))
		box.add_child(_lbl("Public %d/100" % roundi(rumor.belief), 12, RED if rumor.belief >= 60 else DIM))
		box.add_child(_bar(rumor.belief, RED if rumor.belief >= 60 else ACC_DIM, 10))
		box.add_child(_lbl("Industry %d/100" % roundi(float(rumor.get("industryBelief", 0.0))), 12, AMBER if float(rumor.get("industryBelief", 0.0)) >= 60 else DIM))
		box.add_child(_bar(float(rumor.get("industryBelief", 0.0)), AMBER if float(rumor.get("industryBelief", 0.0)) >= 60 else BLUE, 10))
		box.add_child(_lbl("👥 Known carriers: %s" % ", ".join(rumor.holders), 12, DIM))
		var actions := HFlowContainer.new()
		actions.add_theme_constant_override("h_separation", 6)
		actions.add_theme_constant_override("v_separation", 6)
		box.add_child(actions)
		actions.add_child(_btn("📢 Deny", _on_rumor_action.bind(int(rumor.id), "deny")))
		actions.add_child(_btn("🏛 Studio talks", _on_rumor_action.bind(int(rumor.id), "studio")))
		actions.add_child(_btn("🤫 Suppress", _on_rumor_action.bind(int(rumor.id), "suppress"), true))
		actions.add_child(_btn("🌀 Counter-rumor", _on_rumor_action.bind(int(rumor.id), "counter")))
		actions.add_child(_btn("⏳ Wait it out", _on_rumor_action.bind(int(rumor.id), "wait")))

func _on_rumor_action(rid: int, action: String) -> void:
	var outcome := ""
	match action:
		"deny": outcome = Game.deny_rumor(rid)
		"studio": outcome = Game.studio_talk_rumor(rid)
		"suppress": outcome = Game.suppress_rumor(rid)
		"counter": outcome = Game.counter_rumor(rid)
		"wait": outcome = Game.wait_out_rumor(rid)
	_show_simple_modal("The story behind the story", outcome)

func _on_rumor_launch(actor_id: String) -> void:
	_show_simple_modal("A sentence makes the rounds", Game.launch_rumor(actor_id, str(Game.pick(["skandal", "wechsel", "affäre"]))))

func _on_secret_action(cid: int, type_s: String, action: String) -> void:
	var outcome := Game.prepare_secret(cid, type_s) if action == "prepare" else Game.sell_secret(cid, type_s)
	_show_simple_modal("Strictly confidential", outcome)

# ---------- Tab: Talent pool ----------
func _render_pool() -> void:
	var st = Game.state
	var filter_row := HBoxContainer.new()
	content_box.add_child(filter_row)
	var fe := LineEdit.new()
	fe.placeholder_text = "🔍 Search name …"
	fe.text = pool_filter
	fe.custom_minimum_size = Vector2(240, 32)
	fe.text_changed.connect(func(t): pool_filter = t; _refresh_pool_list())
	filter_row.add_child(fe)
	filter_row.add_child(_lbl_fill("  Big names only negotiate with agencies of standing. Values = industry assessment (spread).", 12, DIM))
	var list := VBoxContainer.new()
	list.name = "PoolList"
	list.add_theme_constant_override("separation", 8)
	content_box.add_child(list)
	_fill_pool_list(list)

func _refresh_pool_list() -> void:
	var list = content_box.get_node_or_null("PoolList")
	if list:
		_clear(list)
		_fill_pool_list(list)

func _fill_pool_list(list: VBoxContainer) -> void:
	var st = Game.state
	var all = Game.pool_actors()
	if pool_filter.strip_edges() != "":
		var f := pool_filter.to_lower()
		all = all.filter(func(a): return a.name.to_lower().contains(f))
	var grid := _grid(440.0)
	list.add_child(grid)
	for a in all.slice(0, 48):
		var fame := Game.fame_at(a, st.year)
		var owner = Game.rival_for_actor(str(a.id))
		var req := Game.required_rep(fame) + (10 if owner != null else 0)
		var locked: bool = st.agency.rep < req
		var cv = _card(a.name, "⚔" if owner != null else ("🔒" if locked else ""))
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		var chips: Array = []
		if st.year < a.peak:
			chips.append(_chip("📈 Rising", GREEN))
		elif fame < a.peakFame * 0.6:
			chips.append(_chip("📉 Fading", DIM))
		if locked:
			chips.append(_chip("🔒 Reputation ≥ %d required" % req, RED))
		if owner != null:
			chips.append(_chip("⚔ Under contract with %s" % owner.name, AMBER))
		if chips.size():
			box.add_child(_chip_row(chips))
		box.add_child(_lbl(_actor_meta(a, st.year), 12, DIM))
		var known_s := _filmography_line(a, st.year)
		if known_s != "":
			box.add_child(_lbl(known_s, 12, DIM))
		box.add_child(_lbl("⭐ Fame %d/100" % fame, 12, DIM))
		box.add_child(_bar(fame, ACC))
		box.add_child(_lbl("Talent %s · Charisma %s · Discipline %s · Presence %s" % [
			Game.grade_range(a.talent, 9, str(a.id) + "tal"), Game.grade_range(Game.attrs(a).charisma, 9, str(a.id) + "cha"),
			Game.grade_range(Game.attrs(a).discipline, 9, str(a.id) + "dis"), Game.grade_range(Game.attrs(a).presence, 9, str(a.id) + "pre")], 12, DIM))
		box.add_child(_lbl("💰 Fee level ca. %s" % Game.fmt_money(Game.ask_fee(fame, st.year)), 12, DIM))
		if locked:
			var lb := _btn("🔒 Reputation %d required" % req, func(): pass)
			lb.disabled = true
			box.add_child(lb)
		else:
			box.add_child(_btn("Poach" if owner != null else "Sign", _open_negotiation.bind(a.id)))

# ---------- Negotiation v2 ----------
func _open_negotiation(actor_id: String) -> void:
	var n = Game.start_negotiation(actor_id)
	if n.get("locked", false):
		var rival_note := (" The existing contract with %s raises the bar." % n.rivalName) if str(n.get("rivalName", "")) != "" else ""
		_show_simple_modal("No appointment", "[i]“%s sends word: nobody here knows your agency.”[/i]\n\nStars of this caliber (fame %d) only negotiate with agencies from reputation %d up (currently: %d).%s" % [n.actor.name, n.fame, n.reqRep, int(Game.state.agency.rep), rival_note])
		return
	nego_form = {"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null, "clauses": []}
	_render_negotiation("")

func _render_negotiation(hint: String) -> void:
	var n = Game.nego
	var a: Dictionary = n.actor
	var body := Game.body_of(a)
	_open_modal()
	var mood_chip := _nego_mood_chip(Game.evaluate_offer(_offer()))
	var header := _nego_header("🤝 Signing talks: %s" % a.name,
		"%s · ⭐ fame %d · talent %s · %d yrs · %d cm · %d kg · fee level %s" % [_gender_symbol(a), n.fame, Game.grade_range(a.talent, 6, str(a.id) + "tal"), Game.age_of(a, Game.state.year), int(body.height), int(body.weight), Game.fmt_money(n.ask)], [
			_chip("Round %d/%d" % [int(n.round), int(n.maxRounds)], BLUE),
			mood_chip,
		])
	modal_box.add_child(header)
	_nego_widgets = {"mood_row": header.get_node("NegotiationChips"), "mood_chip": mood_chip}
	var nego_known := _filmography_line(a, Game.state.year)
	if nego_known != "":
		modal_box.add_child(_lbl(nego_known, 12, DIM))
	if hint != "":
		modal_box.add_child(_rich("[i]%s[/i]" % hint, 14))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	modal_box.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	var comm_lbl := _lbl("Commission: %d%%" % nego_form.commission, 13)
	left.add_child(comm_lbl)
	var comm := HSlider.new()
	comm.min_value = 5
	comm.max_value = 20
	comm.value = nego_form.commission
	comm.value_changed.connect(func(v): nego_form.commission = int(v); comm_lbl.text = "Commission: %d%%" % int(v); _update_mood())
	left.add_child(comm)
	var max_bonus: int = maxi(1000, roundi(n.ask * 0.4 / 1000.0) * 1000)
	var bonus_lbl := _lbl("Signing bonus: %s" % Game.fmt_money(nego_form.bonus), 13)
	left.add_child(bonus_lbl)
	var bonus := HSlider.new()
	bonus.min_value = 0
	bonus.max_value = max_bonus
	bonus.step = maxi(1000, roundi(max_bonus / 40000.0) * 1000)
	bonus.value = nego_form.bonus
	bonus.value_changed.connect(func(v): nego_form.bonus = int(v); bonus_lbl.text = "Signing bonus: %s" % Game.fmt_money(v); _update_mood())
	left.add_child(bonus)
	left.add_child(_lbl("Contract term:", 13))
	var years := OptionButton.new()
	for y in Game.CONTRACT_YEARS:
		years.add_item("%d years" % y)
	years.selected = Game.CONTRACT_YEARS.find(int(nego_form.years))
	years.item_selected.connect(func(i): nego_form.years = Game.CONTRACT_YEARS[i]; _update_mood())
	left.add_child(years)
	left.add_child(_lbl("📜 Promise (goes on the record!):", 13))
	var prom := OptionButton.new()
	prom.add_item("No promise")
	var pkeys := Game.PROMISES.keys()
	for pk in pkeys:
		prom.add_item(Game.PROMISES[pk].label)
	prom.selected = 0 if nego_form.promise == null else pkeys.find(nego_form.promise) + 1
	prom.item_selected.connect(func(i): nego_form.promise = null if i == 0 else pkeys[i - 1]; _update_mood())
	left.add_child(prom)

	right.add_child(_lbl("🎁 Extras (perks):", 13))
	for pk in Game.PERKS:
		var perk: Dictionary = Game.PERKS[pk]
		var cb := CheckBox.new()
		var cost_s: String = (" · %s/mo." % Game.fmt_money(perk.cost * Game.infl(Game.state.year))) if perk.cost > 0 else " · free"
		cb.text = perk.name + cost_s
		cb.tooltip_text = perk.desc
		cb.button_pressed = nego_form.perks.has(pk)
		cb.toggled.connect(func(on):
			if on and not nego_form.perks.has(pk):
				nego_form.perks.append(pk)
			elif not on:
				nego_form.perks.erase(pk)
			_update_mood())
		right.add_child(cb)

	right.add_child(_lbl("📑 Contract clauses (trigger events later):", 13))
	for clk in Game.CLAUSES:
		if not Game.clause_available(clk):
			continue
		var clause: Dictionary = Game.CLAUSES[clk]
		var ccb := CheckBox.new()
		ccb.text = clause.name
		ccb.tooltip_text = clause.desc
		ccb.button_pressed = nego_form.clauses.has(clk)
		ccb.toggled.connect(func(on):
			if on and not nego_form.clauses.has(clk):
				nego_form.clauses.append(clk)
			elif not on:
				nego_form.clauses.erase(clk)
			_update_mood())
		right.add_child(ccb)
	if int(Game.state.year) < 1995:
		right.add_child(_lbl("Likeness rights only become negotiable from 1995 on.", 11, DIM))

	var secondary_actions: Array = []
	if n.counter != null:
		var cbox = _card("Counter-offer from %s" % a.name, "↩")
		modal_box.add_child(cbox[0])
		cbox[1].add_child(_rich("[i]%s[/i]" % n.counter.text, 14))
		var affordable: bool = n.counter.bonus <= Game.state.agency.cash
		secondary_actions.append({"label": "Accept counter-offer" + ("" if affordable else " (too expensive)"), "cb": _accept_counter, "disabled": not affordable})

	modal_box.add_child(_nego_actions({"label": "Make your offer", "cb": _submit_offer}, secondary_actions, _close_modal))

func _update_mood() -> void:
	if not _nego_widgets.has("mood_row") or not is_instance_valid(_nego_widgets.mood_row):
		return
	var row: HBoxContainer = _nego_widgets.mood_row
	var old_chip = _nego_widgets.get("mood_chip")
	var index := row.get_child_count()
	if old_chip != null and is_instance_valid(old_chip):
		index = old_chip.get_index()
		row.remove_child(old_chip)
		old_chip.queue_free()
	var new_chip := _nego_mood_chip(Game.evaluate_offer(_offer()))
	row.add_child(new_chip)
	row.move_child(new_chip, mini(index, row.get_child_count() - 1))
	_nego_widgets["mood_chip"] = new_chip

func _offer() -> Dictionary:
	return {"commission": nego_form.commission, "bonus": nego_form.bonus, "years": nego_form.years, "perks": nego_form.perks.duplicate(), "promise": nego_form.promise, "clauses": nego_form.get("clauses", []).duplicate()}

func _submit_offer() -> void:
	var offer := _offer()
	var res = Game.make_offer(offer)
	if res.get("broke", false):
		_show_outcome_modal("Signing talks", "[b]Not enough capital:[/b] the signing bonus exceeds your till.")
		return
	if res.get("accepted", false):
		_show_signed(offer)
	elif res.get("final", false):
		_show_outcome_modal("Signing talks", "[b]Declined[/b]\n\n[i]%s[/i]\n\n%s has heard enough. Maybe next year — with a better reputation." % [res.hint, Game.nego.actor.name])
	else:
		_render_negotiation(res.hint)

func _accept_counter() -> void:
	var res = Game.accept_counter()
	if res.get("broke", false):
		return
	_show_signed(Game.nego.counter)

func _show_signed(terms: Dictionary) -> void:
	var a: Dictionary = Game.nego.actor
	var perks_s: String = (", perks: " + ", ".join(terms.perks.map(func(p): return Game.PERKS[p].name))) if terms.perks.size() else ""
	var clause_s: String = ("\n\n📑 Agreed clauses: " + ", ".join(terms.get("clauses", []).map(func(cl): return Game.clause_label(str(cl))))) if terms.get("clauses", []).size() else ""
	var prom_s: String = ("\n\n📜 Your promise (%s) has been put on record." % Game.PROMISES[terms.promise].label) if terms.get("promise") != null else ""
	_show_outcome_modal("Signing talks", "[b]Contract signed![/b]\n\n[i]“All right then. Make me immortal.”[/i]\n\n%s is now a client — %d%% commission, %d years%s%s.%s%s" % [a.name, int(terms.commission), int(terms.years), (", %s bonus" % Game.fmt_money(terms.bonus)) if terms.bonus > 0 else "", perks_s, clause_s, prom_s])
	# Star-Prognose (Feature 6b): beim Signing unter Ruhm 40 das Bauchgefühl befragen
	var pev = Game.pop_pending_star_prediction()
	if pev != null:
		modal_queue.append(pev)

# ---------- Tab: Castings ----------
func _render_castings() -> void:
	var st = Game.state
	if int(st.strikeMonths) > 0:
		var cv0 = _card("Strike!", "⚠")
		cv0[1].add_child(_lbl("All castings rest for %d more month(s)." % int(st.strikeMonths), 13, DIM))
		content_box.add_child(cv0[0])
		return
	# Coverage-Castings bleiben bis nächsten Monat verdeckt
	var visible_castings: Array = st.castings.filter(func(cs): return not bool(cs.get("hidden", false)))
	if visible_castings.is_empty():
		var cv1 = _card("No open castings", "🎬")
		cv1[1].add_child(_lbl("Next month the studios will announce new projects.", 13, DIM))
		content_box.add_child(cv1[0])
		return
	var grid := _grid(620.0)
	content_box.add_child(grid)
	for cs in visible_castings:
		var studio = Game._studio(cs.studioId)
		var cv = _card("“%s”" % cs.title, GENRE_ICONS.get(cs.genre, "🎬"))
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		var rel: float = st.studioRel[cs.studioId]
		box.add_child(_chip_row([
			_chip(_genre_de(cs.genre), BLUE),
			_chip("★".repeat(int(cs.prestige)) + "☆".repeat(3 - int(cs.prestige)), ACC),
			_chip("⏳ %d wk" % int(cs.deadline), RED if int(cs.deadline) <= 4 else DIM),
			_chip("🏛 Relations %d" % int(rel), GREEN if rel >= 60 else (RED if rel < 30 else DIM)),
		]))
		box.add_child(_lbl("%s · Budget %s" % [studio.name, Game.fmt_money(cs.budget)], 12, DIM))
		if cs.has("director"):
			box.add_child(_lbl("🎬 Director: %s%s" % [cs.director.name, " · favors your agency" if bool(cs.director.agencyFriendly) else " · from a rival house"], 12, GREEN if bool(cs.director.agencyFriendly) else RED))
		if cs.has("producer"):
			box.add_child(_lbl("💼 Producer: %s%s" % [cs.producer.name, " · favors your agency" if bool(cs.producer.agencyFriendly) else " · from a rival house"], 12, GREEN if bool(cs.producer.agencyFriendly) else RED))
		if Game.chem_read_available(cs):
			box.add_child(_btn("🧪 Arrange a chemistry read", _start_chem_read_ui.bind(int(cs.id)), true))
			box.add_child(_lbl("Two open roles, two pairings of your own — plus the studio's suggestion. Skippable at any time.", 11, DIM))
		for i in cs.roles.size():
			var r: Dictionary = cs.roles[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			box.add_child(row)
			var desc := "%s %s (%s, %d–%d yrs) · from ⭐ %d · ca. %s" % ["🎯" if r.type == "lead" else "▫", "Lead" if r.type == "lead" else "Supporting role", "♂" if r.gender == "m" else "♀", int(r.ageMin), int(r.ageMax), int(r.minFame), Game.fmt_money(r.fee)]
			var dl := _lbl(desc, 12, TEXT_C if r.type == "lead" else DIM)
			dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dl.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(dl)
			if r.filled == null:
				row.add_child(_btn("Pitch a client", _open_pitch.bind(int(cs.id), i)))
			elif r.filled.get("clientId") != null:
				var cl = Game.client(r.filled.clientId)
				var st_lbl := _lbl("✅ %s (%s)" % [Game.client_name(cl) if cl else "?", Game.fmt_money(r.filled.fee)], 12, GREEN)
				st_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF  # sonst Buchstaben-Umbruch neben Expand-Label
				row.add_child(st_lbl)
			else:
				var npc_lbl := _lbl(r.filled.get("name", "?"), 12, DIM)
				npc_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
				row.add_child(npc_lbl)

func _open_pitch(casting_id: int, role_idx: int, insight: int = -1) -> void:
	var cs = Game._casting(casting_id)
	var role: Dictionary = cs.roles[role_idx]
	var options = Game.eligible_clients(cs, role).filter(func(e): return not role.rejected.has(int(e.c.id)))
	_open_modal()
	modal_box.add_child(_nego_header("🎬 Studio pitch: “%s”" % cs.title,
		"%s · from ⭐ %d · base fee ca. %s" % ["🎯 Lead" if role.type == "lead" else "▫ Supporting role", int(role.minFame), Game.fmt_money(role.fee)], [
			_chip(str(Game._studio(str(cs.studioId)).name), BLUE),
			_chip("%d candidates" % int(options.size()), DIM),
			_chip("%d wk deadline" % int(cs.deadline), RED if int(cs.deadline) <= 4 else DIM),
		]))
	var footer_actions: Array = []
	# Bauchgefühl bei hohem Instinkt (Feature 6)
	var gf: String = Game.gut_feeling(cs)
	if gf != "":
		modal_box.add_child(_lbl(gf, 13, ACC))
	# Chemie-Partner am Set (Feature 12): bereits besetzte Rollen
	var partner_keys: Array = []
	for r2 in cs.roles:
		if r2.filled != null:
			var pk2: String = Game._person_key_for_role(r2)
			if pk2 != "" and not partner_keys.has(pk2):
				partner_keys.append(pk2)
	if insight >= 0:
		modal_box.add_child(_lbl("🔍 Script access (favor): quality base ca. %d/100 — prestige plus script roll, before cast and market apply." % insight, 13, ACC))
	if options.is_empty():
		modal_box.add_child(_lbl("No available client fits this role — or has already been rejected. Clients with script approval decline roles with fit < 35.", 13, DIM))
	else:
		for e in options:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			modal_box.add_child(row)
			var ficon := "🟢" if e.fit >= 60 else ("🟡" if e.fit >= 35 else "🔴")
			var dicon := "🧬↑" if e.dna >= 3 else ("🧬↓" if e.dna <= -3 else "🧬·")
			var chem_s := ""
			if partner_keys.size():
				var csum := 0.0
				for pk3 in partner_keys:
					csum += float(Game.chemistry(str(e.c.aid), str(pk3)).screen)
				var cavg := csum / partner_keys.size()
				chem_s = " · 🧪" + ("🟢" if cavg >= 3 else ("🔴" if cavg <= -3 else "🟡"))
			var nl := _lbl("%s %s — fit %d%% · %s %+d · 💰 %s · 🔋 %d%s" % [ficon, Game.client_name(e.c), e.fit, dicon, e.dna, Game.fmt_money(e.estFee), roundi(e.c.exhaustion), chem_s], 13, TEXT_C if e.fit >= 35 else DIM)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nl)
			row.add_child(_btn("Propose", _do_pitch.bind(casting_id, role_idx, int(e.c.id))))
			if Game.audition_available(cs, role):
				row.add_child(_btn("Step into the audition", _start_audition_ui.bind(casting_id, role_idx, int(e.c.id)), true))
		modal_box.add_child(_lbl("🧬 = career DNA/image match. A western star does not convince as a romantic overnight.", 12, DIM))
	# Gefallen: Drehbuch-Einsicht vor dem Pitch
	if insight < 0 and Game.has_favor("scriptAccess"):
		footer_actions.append({"label": "🔍 Call in a favor: script access", "cb": func():
			if Game.consume_favor("scriptAccess"):
				_open_pitch(casting_id, role_idx, Game.script_insight(cs))})
	# Gefallen: abgelehnte Klienten erneut pitchen lassen
	var rejected_clients: Array = []
	for cid in role.rejected:
		var rc = Game.client(cid)
		if rc != null:
			rejected_clients.append(rc)
	if rejected_clients.size():
		modal_box.add_child(_lbl("Already rejected:", 13, DIM))
		for rc in rejected_clients:
			var rrow := HBoxContainer.new()
			rrow.add_theme_constant_override("separation", 10)
			modal_box.add_child(rrow)
			var rl := _lbl("❌ %s — rejected by the studio" % Game.client_name(rc), 13, DIM)
			rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rrow.add_child(rl)
			if Game.has_favor("extraAudition"):
				var rid := int(rc.id)
				rrow.add_child(_btn("🤝 Favor: pitch again", func():
					if Game.use_extra_audition(role, rid):
						_open_pitch(casting_id, role_idx, insight)
					else:
						_show_simple_modal("No favor", "Nobody owes you an extra audition anymore.")))
			else:
				var favor_hint := _lbl("(requires the “Extra audition” favor)", 11, DIM)
				favor_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
				rrow.add_child(favor_hint)
	modal_box.add_child(_nego_actions({}, footer_actions, _close_modal))

func _do_pitch(casting_id: int, role_idx: int, client_id: int) -> void:
	var res = Game.submit_pitch(casting_id, role_idx, client_id)
	if not res.success:
		_show_outcome_modal("Studio pitch", "[b]Rejection[/b]\n\n[i]“We had imagined the role … differently. Thank you for your time.”[/i]")
		return
	_offer_clauses = []
	# Große Hauptrollen: Mehrparteien-Verhandlung (Feature 9)
	if Game.pitch_ctx != null and Game.pitch_ctx.get("table", false):
		Game.start_table()
		_render_table("")
		return
	_render_studio_offer("")

# ---------- Stage cluster: the decisive audition ----------
func _start_audition_ui(casting_id: int, role_idx: int, client_id: int) -> void:
	var result := Game.begin_audition(casting_id, role_idx, client_id)
	if not bool(result.get("ok", false)):
		_show_simple_modal("Audition missed", str(result.get("msg", "The opportunity has passed.")))
		return
	_render_audition_briefing()

func _render_audition_briefing() -> void:
	if Game.state.get("audition") == null:
		_close_modal()
		return
	var aud: Dictionary = Game.state.audition
	var casting = Game._casting(aud.castingId)
	var c = Game.client(aud.clientId)
	if casting == null or c == null:
		Game.state.audition = null
		_close_modal()
		return
	var role: Dictionary = casting.roles[int(aud.roleIdx)]
	var director_name := Game._director_name_for(casting)
	_open_modal()
	modal_box.add_child(_lbl("🎭 The decisive audition", 22, ACC))
	modal_box.add_child(_rich("[i]“One scene. Four decisions. Afterwards the room knows whether it forgets your name.”[/i]", 14))
	modal_box.add_child(_lbl("“%s” · %s · director: %s" % [casting.title, "Lead" if str(role.type) == "lead" else "Supporting role", director_name], 13, DIM))
	modal_box.add_child(_chip_row([_chip(Game.client_name(c), BLUE), _chip("🧬 " + Game.dna_label(c), ACC),
		_chip("📖 %d decisions can be prepared" % Game.audition_preparation_limit(c), GREEN)]))
	var competition := Game.audition_competition(casting, role)
	if competition.size():
		modal_box.add_child(_lbl("Known competition", 13, AMBER))
		for rival in competition:
			modal_box.add_child(_lbl("• %s · %s · image: %s" % [rival.name, rival.agency, rival.image], 12, DIM))
	if aud.revealed.size():
		modal_box.add_child(_lbl("Hints from the anteroom", 13, GREEN))
		for hint in aud.revealed:
			modal_box.add_child(_lbl("• " + Game.audition_hint_text(casting, hint), 12, GREEN))
	var archive_s := Game.director_archive_hint(director_name)
	if archive_s != "":
		modal_box.add_child(_lbl(archive_s, 12, DIM))
	if Game.has_favor("scriptAccess") and not aud.revealed.any(func(h): return str(h.get("source", "")) == "script"):
		modal_box.add_child(_btn("🔍 Use script access — reveal one preference", func():
			Game.audition_reveal_script()
			_render_audition_briefing()))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	modal_box.add_child(actions)
	actions.add_child(_btn("Begin the audition", func():
		Game.audition_begin_choices()
		_render_audition_choice(), true))
	actions.add_child(_btn("Just pitch normally", func():
		var cid := int(aud.castingId)
		var ridx := int(aud.roleIdx)
		Game.state.audition = null
		_open_pitch(cid, ridx)))
	actions.add_child(_btn("Decline", _abandon_audition))

func _abandon_audition() -> void:
	Game.state.audition = null
	_close_modal()

func _render_audition_choice() -> void:
	if Game.state.get("audition") == null:
		return
	var aud: Dictionary = Game.state.audition
	var casting = Game._casting(aud.castingId)
	var c = Game.client(aud.clientId)
	var step := int(aud.step)
	if casting == null or c == null or step < 1 or step > Game.AUDITION_DIMS.size():
		return
	var dim: String = str(Game.AUDITION_DIMS[step - 1])
	var heading := {"scene":"Which scene?", "interpretation":"Which interpretation?", "appearance":"How does the client enter the room?", "emphasis":"What should linger?"}.get(dim, dim)
	var prepared_n: int = aud.choices.values().filter(func(ch): return bool(ch.get("prepared", false))).size()
	var limit := Game.audition_preparation_limit(c)
	_open_modal()
	modal_box.add_child(_lbl("🎭 Audition · decision %d/4" % step, 22, ACC))
	modal_box.add_child(_lbl(heading, 16, TEXT_C))
	modal_box.add_child(_lbl("Preparation: %d/%d used. Spontaneous decisions carry an uncertain roll." % [prepared_n, limit], 12, DIM))
	for value in Game.AUDITION_OPTIONS[dim]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		modal_box.add_child(row)
		var option_label := _lbl(Game.audition_choice_label(casting, dim, str(value)), 14)
		option_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(option_label)
		if prepared_n < limit:
			row.add_child(_btn("📖 Prepare", _audition_pick.bind(dim, str(value), true), true))
		row.add_child(_btn("🎲 Spontaneous", _audition_pick.bind(dim, str(value), false)))
	modal_box.add_child(_btn("Abort the audition", _abandon_audition))

func _audition_pick(dim: String, value: String, prepared: bool) -> void:
	var result := Game.audition_choose(dim, value, prepared)
	if not bool(result.get("ok", false)):
		_show_simple_modal("Not possible", str(result.get("msg", "This decision is no longer available.")))
		return
	if bool(result.get("done", false)):
		_render_audition_result(Game.resolve_audition())
	else:
		_render_audition_choice()

func _render_audition_result(result: Dictionary) -> void:
	_open_modal()
	var outcome := str(result.get("outcome", "clear"))
	if outcome == "win":
		modal_box.add_child(_lbl("🌟 The role belongs to your client", 22, GREEN))
		modal_box.add_child(_rich("[i]“That was not a rehearsal. That was the character.”[/i]\n\n%d of 4 directorial preferences hit. The contract carries a [b]10%% fee bonus[/b], and %s remembers the collaboration." % [int(result.matches), str(result.director)], 15))
		modal_box.add_child(_btn("Back to the castings", _close_modal, true))
	elif outcome == "narrow":
		modal_box.add_child(_lbl("🎬 A photo finish", 22, AMBER))
		modal_box.add_child(_rich("[i]“For the lead it was a blink of an eye. But we want to keep talking.”[/i]\n\nNo lasting damage to reputation or career.", 15))
		var fallbacks: Array = result.get("fallbacks", [])
		for fallback in fallbacks:
			modal_box.add_child(_btn("Accept supporting-role offer · %s" % Game.fmt_money(fallback.fee),
				_take_audition_support.bind(int(result.castingId), int(result.clientId), int(fallback.roleIdx)), true))
		if bool(result.get("favor", false)):
			modal_box.add_child(_lbl("Instead, the studio owes you an extra audition.", 13, GREEN))
		modal_box.add_child(_btn("Continue without a deal", _close_modal))
	else:
		modal_box.add_child(_lbl("The room stays cool", 22, DIM))
		modal_box.add_child(_rich("[i]“Today it was not the character I am looking for.”[/i]\n\nNo values drop. Only your next audition with %s carries a small one-time malus — after that the matter is forgotten." % str(result.director), 15))
		modal_box.add_child(_btn("Continue", _close_modal, true))

func _take_audition_support(casting_id: int, client_id: int, role_idx: int) -> void:
	var result := Game.audition_support_fallback(casting_id, client_id, role_idx)
	if bool(result.get("ok", false)):
		_show_simple_modal("Supporting role signed and sealed", "[i]“Not the role above the title — but one people can remember.”[/i]")
	else:
		_show_simple_modal("Offer expired", "The studio has since cast the supporting role differently.")

# ---------- Stage cluster: the chemistry read ----------
func _start_chem_read_ui(casting_id: int) -> void:
	_chem_selected.clear()
	_render_chem_pair_picker(casting_id)

func _render_chem_pair_picker(casting_id: int) -> void:
	var casting = Game._casting(casting_id)
	if casting == null:
		_close_modal()
		return
	var pairs: Array = Game.chem_read_candidate_pairs(casting_id).slice(0, 5)
	_open_modal()
	modal_box.add_child(_nego_header("🧪 Studio pitch: chemistry read",
		"Assemble two pairings of your own for “%s”; the studio adds a suggestion." % casting.title, [
			_chip("%d/2 pairings" % int(_chem_selected.size()), BLUE),
			_chip("%d candidate pairs" % int(pairs.size()), DIM),
		]))
	modal_box.add_child(_rich("[i]“Two good actors are far from a good pair.”[/i]", 14))
	for pair in pairs:
		var selected := _chem_selected.has(str(pair.key))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		modal_box.add_child(row)
		var names := _lbl("%s  ×  %s" % [pair.aName, pair.bName], 14, GREEN if selected else TEXT_C)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(names)
		row.add_child(_btn("✓ Chosen" if selected else "Choose pairing", _toggle_chem_pair.bind(casting_id, str(pair.key)), selected))
	if _chem_selected.size() == 2:
		modal_box.add_child(_lbl("Choose a test scene", 14, ACC))
		var primary_scene: Dictionary = {}
		var secondary_scenes: Array = []
		for scene_s in Game.CHEM_READ_SCENES:
			var scene_spec := {"label": str(Game.CHEM_READ_SCENES[scene_s]), "cb": _begin_chem_test.bind(casting_id, str(scene_s))}
			if scene_s == "love":
				primary_scene = scene_spec
			else:
				secondary_scenes.append(scene_spec)
		modal_box.add_child(_nego_actions(primary_scene, secondary_scenes, null))
	modal_box.add_child(_nego_actions({}, [
		{"label": "Single pitch instead of a chemistry read", "cb": _close_modal},
	], _close_modal))

func _toggle_chem_pair(casting_id: int, pair_key: String) -> void:
	if _chem_selected.has(pair_key):
		_chem_selected.erase(pair_key)
	elif _chem_selected.size() < 2:
		_chem_selected.append(pair_key)
	_render_chem_pair_picker(casting_id)

func _begin_chem_test(casting_id: int, scene_s: String) -> void:
	var result := Game.begin_chem_read(casting_id, _chem_selected, scene_s)
	if not bool(result.get("ok", false)):
		_show_simple_modal("Test cancelled", "One of the pairings is no longer available.")
		return
	_render_chem_signals()

func _render_chem_signals() -> void:
	if Game.chem_read == null:
		return
	_open_modal()
	modal_box.add_child(_nego_header("🎬 Studio pitch: dailies from the test room",
		"No naked chemistry numbers — only body language, shared history and whispers from the network.", [
			_chip(str(Game.CHEM_READ_SCENES[Game.chem_read.scene]), BLUE),
			_chip("%d pairings" % int(Game.chem_read.pairs.size()), DIM),
		]))
	for pair in Game.chem_read.pairs:
		var badge := " · the studio's suggestion" if bool(pair.get("studioSuggestion", false)) else ""
		modal_box.add_child(_lbl("%s × %s%s" % [pair.aName, pair.bName, badge], 15, BLUE if bool(pair.get("studioSuggestion", false)) else ACC))
		modal_box.add_child(_rich("[i]“%s”[/i]  %s  %s" % [pair.signal.text, pair.historyText, pair.personalHint], 12))
		modal_box.add_child(_btn("Cast this pairing", _choose_chem_pair.bind(str(pair.key)), true))
	modal_box.add_child(_nego_actions({}, [
		{"label": "Single pitch instead of a pair casting", "cb": _leave_chem_read},
	], _leave_chem_read))

func _leave_chem_read() -> void:
	Game.chem_read = null
	_close_modal()

func _choose_chem_pair(pair_key: String) -> void:
	var result := Game.resolve_chem_read(pair_key)
	if not bool(result.get("ok", false)):
		_show_simple_modal("Decision expired", "The studio has already closed the test room.")
		return
	var outcome_text := ""
	match str(result.outcome):
		"best":
			outcome_text = "[b]The dream pairing[/b]\n\n[i]“Exactly these two. No further tests.”[/i]\n\nBoth roles are cast, the fees rise by [b]12%%[/b] as a package, and the “The chemistry is right” signal is noted for the shoot."
		"middle":
			outcome_text = "[b]A solid cast[/b]\n\n[i]“This carries the picture. Let's draw up the contract.”[/i]\n\nBoth roles are cast at normal terms."
		_:
			outcome_text = "[b]The studio corrects the pair[/b]\n\n[i]“Your client stays. We'll cast the partner ourselves.”[/i]\n\nThe fallback applies: one of your clients safely keeps their role; only the second part is cast from outside."
	_show_outcome_modal("Studio pitch: chemistry read", outcome_text)

func _render_studio_offer(note: String) -> void:
	var ctx = Game.pitch_ctx
	_open_modal()
	var fit_score := Game.fit_score(ctx.casting, ctx.role, ctx.client)
	modal_box.add_child(_nego_header("💼 Studio pitch: offer",
		"“%s” · %s for %s" % [str(ctx.casting.title), "lead" if str(ctx.role.type) == "lead" else "supporting role", Game.client_name(ctx.client)], [
			_chip("Fee %s" % Game.fmt_money(ctx.fee), BLUE),
			_chip("Renegotiated" if bool(ctx.haggled) else "First offer", DIM),
			_nego_mood_chip(fit_score),
		]))
	if note != "":
		modal_box.add_child(_rich("[i]%s[/i]" % note, 14))
	modal_box.add_child(_rich("The studio wants [b]%s[/b] for “%s” — fee: [color=#%s]%s[/color] (your commission: %s)." % [Game.client_name(ctx.client), ctx.casting.title, ACC.to_html(false), Game.fmt_money(ctx.fee), Game.fmt_money(ctx.fee * ctx.client.commission / 100.0)], 15))
	# Rollen-Klauseln (Feature 8): lösen Jahre später Ereignisse aus
	modal_box.add_child(_lbl("📑 Contract clauses for this deal:", 13))
	var clause_flow := HFlowContainer.new()
	clause_flow.add_theme_constant_override("h_separation", 14)
	modal_box.add_child(clause_flow)
	for clk in Game.CLAUSES:
		if not Game.clause_available(clk):
			continue
		var ccb := CheckBox.new()
		ccb.text = str(Game.CLAUSES[clk].name)
		ccb.tooltip_text = str(Game.CLAUSES[clk].desc)
		ccb.button_pressed = _offer_clauses.has(clk)
		ccb.toggled.connect(func(on):
			if on and not _offer_clauses.has(clk):
				_offer_clauses.append(clk)
			elif not on:
				_offer_clauses.erase(clk))
		clause_flow.add_child(ccb)
	# Instinkt-Prognose (Feature 6c): „Wer passt besser?“ — ein Klick, freiwillig
	var alts: Array = ctx.get("alts", [])
	if alts.size() and not ctx.get("fitAsked", false):
		var alt_c = Game.client(alts[0])
		if alt_c != null:
			modal_box.add_child(_lbl("🔮 Gut check: does %s really fit better than %s? (Checked at the release)" % [Game.client_name(ctx.client), Game.client_name(alt_c)], 13, ACC))
			modal_box.add_child(_nego_actions({"label": "Yes, better", "cb": func():
				Game.note_betterfit_prediction(ctx.client, alt_c, int(ctx.casting.id))
				ctx["fitAsked"] = true
				_render_studio_offer("Prediction noted — your instinct will be put to the test at the release.")}, [
				{"label": "No", "cb": func():
					Game.add_prediction("betterfit", {"prodId": int(ctx.casting.id), "chosen": int(ctx.client.id), "other": int(alt_c.id), "otherFame": float(alt_c.fame)}, false, Game.mi() + 30, "%s does NOT fit better than %s" % [Game.client_name(ctx.client), Game.client_name(alt_c)])
					ctx["fitAsked"] = true
					_render_studio_offer("Prediction noted.")},
				{"label": "No call", "cb": func():
					ctx["fitAsked"] = true
					_render_studio_offer("")},
			], null))
	var secondary_actions: Array = []
	if not ctx.haggled:
		secondary_actions.append({"label": "💰 Demand 25% more fee", "cb": _do_haggle})
	var pkg = Game.package_options()
	if pkg.size():
		secondary_actions.append({"label": "👥 Negotiate a package deal", "cb": _render_package})
	if Game.has_favor("billing") and not ctx.client.flags.get("billingBoost", false):
		secondary_actions.append({"label": "🎬 Top billing via favor", "cb": func():
			if Game.consume_favor("billing"):
				ctx.client.flags["billingBoost"] = true
				_render_studio_offer("“Fine — your client's name goes above the title. Happy?” (+fame at release)")})
	modal_box.add_child(_nego_actions({"label": "Accept the offer", "cb": _accept_studio_offer}, secondary_actions, _cancel_pitch))

func _accept_studio_offer() -> void:
	var ctx = Game.pitch_ctx
	var client_name := Game.client_name(ctx.client)
	var film_title := str(ctx.casting.title)
	var fee := float(ctx.fee)
	var provision := fee * float(ctx.client.commission) / 100.0
	Game.pitch_ctx["offerClauses"] = _offer_clauses.duplicate()
	Game.accept_offer()
	_offer_clauses = []
	_show_outcome_modal("Studio pitch", "[b]Offer accepted[/b]\n\n%s plays in “%s” for %s. Your commission: %s." % [client_name, film_title, Game.fmt_money(fee), Game.fmt_money(provision)])

func _cancel_pitch() -> void:
	Game.pitch_ctx = null
	_offer_clauses = []
	_close_modal()

func _do_haggle() -> void:
	var res = Game.haggle()
	if res.get("lost", false):
		_show_outcome_modal("Studio pitch", "[b]Negotiation collapsed[/b]\n\n[i]“Tell your client to find another picture.”[/i]")
		return
	_render_studio_offer("“All right. %s. But not a cent more.”" % Game.fmt_money(res.get("fee", 0)) if res.success else "“No. The offer stands — take it or leave it.”")

func _render_package() -> void:
	var ctx = Game.pitch_ctx
	_open_modal()
	modal_box.add_child(_nego_header("👥 Studio pitch: package deal",
		"Main deal: %s · %s. Choose the second client." % [Game.client_name(ctx.client), Game.fmt_money(ctx.fee)], [
			_chip("Package", BLUE),
		]))
	for o in Game.package_options():
		var row := HBoxContainer.new()
		modal_box.add_child(row)
		var l := _lbl("%s — supporting role · fit %d%%" % [Game.client_name(o.c), o.fit], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(_btn("Propose", _do_package.bind(int(o.roleIdx), int(o.c.id))))
	modal_box.add_child(_nego_actions({}, [
		{"label": "Back to the studio offer", "cb": func(): _render_studio_offer("")},
	], _cancel_pitch))

func _do_package(role_idx: int, client_id: int) -> void:
	var res = Game.try_package(role_idx, client_id)
	if res.success:
		_show_outcome_modal("Studio pitch", "[b]Package deal sealed![/b]\n\n[i]“Two of your people in one picture? You are starting to scare me.”[/i]\n\nBoth deals are signed — with a 12% premium.")
	else:
		_render_studio_offer("“We won't take the second name. But the original offer still stands.”")

# ---------- Tab: Films ----------
func _render_filme() -> void:
	var st = Game.state
	if st.productions.size():
		content_box.add_child(_lbl("🎥 In production", 18, ACC))
		var grid := _grid(560.0)
		content_box.add_child(grid)
		for p in st.productions:
			var cv = _card("“%s”" % p.title, GENRE_ICONS.get(p.genre, "🎥"))
			grid.add_child(cv[0])
			var names: Array = []
			for r in p.roles:
				if r.filled != null:
					if r.filled.get("clientId") != null:
						var cl = Game.client(r.filled.clientId)
						names.append("👤 " + (Game.client_name(cl) if cl else "?"))
					else:
						names.append(r.filled.get("name", "?"))
			cv[1].add_child(_lbl("%s · %s · Budget %s" % [Game._studio(p.studioId).name, _genre_de(p.genre), Game.fmt_money(p.budget)], 12, DIM))
			cv[1].add_child(_lbl("Cast: " + ", ".join(names), 12, DIM))
			Game.ensure_prod_fields(p)
			cv[1].add_child(_chip_row([_chip("🎬 Release in ~%d wk" % int(p.weeksLeft), BLUE)]))
			# Produktions-Signale (Feature 13): Set-Gerede statt Fakten
			if p.signals.size():
				var srow := HFlowContainer.new()
				srow.add_theme_constant_override("h_separation", 6)
				cv[1].add_child(srow)
				for sig in p.signals:
					srow.add_child(_chip(("🟢 " if bool(sig.get("pos", true)) else "🔴 ") + str(sig.get("t", "")), GREEN if bool(sig.get("pos", true)) else RED))
				cv[1].add_child(_lbl("Signals are set talk — the hit rate rises with your instinct.", 10, DIM))
				var has_client_here := false
				for r in p.roles:
					if r.filled != null and r.filled.get("clientId") != null and Game.client(r.filled.clientId) != null:
						has_client_here = true
				if has_client_here:
					var pid := int(p.id)
					cv[1].add_child(_nego_actions({
						"label": "Renegotiate", "cb": _run_production_negotiation.bind(pid, "reneg"), "disabled": bool(p.reactions.get("reneg", false)),
					}, [
						{"label": "Pull the client", "cb": _run_production_negotiation.bind(pid, "pull"), "disabled": bool(p.reactions.get("pull", false))},
						{"label": "Demand participation", "cb": _run_production_negotiation.bind(pid, "share"), "disabled": bool(p.reactions.get("share", false))},
					], null))
	if st.released.size():
		content_box.add_child(_lbl("🎞 Released", 18, ACC))
		var txt := ""
		for f in st.released.slice(0, 30):
			var col := "#c0504d" if f.ratio < 1.0 else ("#7da05c" if f.ratio >= 2.0 else "#a89b7e")
			var vicon := "💥" if f.verdict == "Blockbuster" else ("✅" if f.ratio >= 2.0 else ("❌" if f.ratio < 1.0 else "▫"))
			txt += "%d  %s “%s” (%s) — Q %d · %s · [color=%s]%s %s[/color]\n" % [int(f.year), GENRE_ICONS.get(f.genre, ""), f.title, Game._studio(f.studioId).name, int(f.quality), Game.fmt_money(f.revenue), col, vicon, f.verdict]
		content_box.add_child(_rich(txt, 13))
	if st.productions.is_empty() and st.released.is_empty():
		var cv = _card("No films yet", "🎞")
		cv[1].add_child(_lbl("Place clients in castings — once a film wraps, it appears here.", 13, DIM))
		content_box.add_child(cv[0])

func _run_production_negotiation(prod_id: int, kind: String) -> void:
	var outcome := ""
	match kind:
		"reneg": outcome = Game.prod_renegotiate(prod_id)
		"pull": outcome = Game.prod_pull_client(prod_id)
		"share": outcome = Game.prod_demand_share(prod_id)
		_: return
	_show_outcome_modal("Production renegotiation", outcome)

# ---------- Tab: Finances (ledger) ----------
func _render_finanzen() -> void:
	var st = Game.state
	var grid := _grid(560.0)
	grid.columns = clampi(grid.columns, 1, 2)
	content_box.add_child(grid)

	# Kennzahlen
	var kc = _card("Key figures", "📊")
	grid.add_child(kc[0])
	var burn := Game.avg_burn(6)
	var runway := Game.months_to_broke()
	kc[1].add_child(_lbl("💰 Capital: %s" % Game.fmt_money(st.agency.cash), 14, RED if st.agency.cash < 0 else TEXT_C))
	kc[1].add_child(_lbl("🔥 Avg. expenses (6 mo.): %s / month" % Game.fmt_money(burn), 13, DIM))
	if runway >= 0.0 and runway < 900.0:
		kc[1].add_child(_lbl("⏳ Runway at the current burn: ~%d months" % roundi(runway), 13, RED if runway < 6.0 else (AMBER if runway < 12.0 else GREEN)))
	var top_cat := Game.top_income_cat(12)
	if top_cat != "":
		kc[1].add_child(_lbl("🏆 Biggest income source: %s" % Game.LEDGER_CATS.get(top_cat, top_cat), 13, DIM))

	# Laufender Monat nach Kategorie
	var lm: Dictionary = Game.live_month(Game.mi())
	var mc = _card("Current month: %s" % Game.date_str(), "🗓")
	grid.add_child(mc[0])
	mc[1].add_child(_lbl("Income %s · expenses %s · balance %s" % [Game.fmt_money(lm.income), Game.fmt_money(lm.expenses), Game.fmt_money(lm.income - lm.expenses)], 13, GREEN if lm.income >= lm.expenses else RED))
	var cat_max := 1.0
	for cat in lm.byCat:
		cat_max = maxf(cat_max, absf(float(lm.byCat[cat])))
	for cat in lm.byCat:
		var amt: float = lm.byCat[cat]
		var row := HBoxContainer.new()
		var nm := _lbl("%s %s" % ["▲" if amt >= 0 else "▼", Game.LEDGER_CATS.get(cat, cat)], 12, GREEN if amt >= 0 else RED)
		nm.custom_minimum_size = Vector2(220 * font_scale, 0)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(nm)
		var pb := _bar(absf(amt) / cat_max * 100.0, GREEN if amt >= 0 else RED, 7)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pb)
		var av := _lbl(Game.fmt_money(amt), 12, DIM)
		av.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(av)
		mc[1].add_child(row)
	if lm.byCat.is_empty():
		mc[1].add_child(_lbl("No bookings this month yet.", 12, DIM))

	# Letzte 12 Monate
	var hist: Array = st.ledgerMonthly.slice(maxi(0, st.ledgerMonthly.size() - 12))
	if hist.size():
		var hc = _card("Last %d months" % hist.size(), "📈")
		grid.add_child(hc[0])
		var cumulative := 0.0
		for m in hist:
			var saldo: float = float(m.income) - float(m.expenses)
			cumulative += saldo
			hc[1].add_child(_lbl("%s — ▲ %s · ▼ %s · balance %s · Σ %s" % [Game.mi_str(m.mi), Game.fmt_money(m.income), Game.fmt_money(m.expenses), Game.fmt_money(saldo), Game.fmt_money(cumulative)], 12, GREEN if saldo >= 0 else RED))

	# Einzelbuchungen der letzten 3 Monate
	var jc = _card("Itemized bookings (last 3 months)", "🧾")
	grid.add_child(jc[0])
	var shown := 0
	for i in range(st.ledger.size() - 1, -1, -1):
		var e: Dictionary = st.ledger[i]
		if Game.mi() - int(e.mi) > 2 or shown >= 30:
			break
		jc[1].add_child(_lbl("%s · %s%s · %s — %s" % [Game.mi_str(e.mi), "▲" if float(e.amount) >= 0 else "▼", Game.fmt_money(absf(float(e.amount))), Game.LEDGER_CATS.get(str(e.cat), str(e.cat)), e.text], 12, GREEN if float(e.amount) >= 0 else RED))
		shown += 1
	if shown == 0:
		jc[1].add_child(_lbl("No bookings yet.", 12, DIM))

# ---------- Tab: Hollywood newspaper ----------
func _render_zeitung() -> void:
	content_box.add_child(_lbl("🗞 The alternate history of Hollywood", 22, ACC))
	content_box.add_child(_lbl("Every issue grows out of real premieres, castings, rumors, client moves and power struggles of your simulation.", 13, DIM))
	if Game.state.newspaper.is_empty():
		var empty = _card("The presses are waiting", "📰")
		empty[1].add_child(_lbl("Finish the first month. After that the current issue appears here — and stays in the archive.", 13, DIM))
		content_box.add_child(empty[0])
		return
	var issue: Dictionary = Game.state.newspaper[0]
	var front = _card(str(issue.name), "🗞")
	content_box.add_child(front[0])
	front[1].add_child(_lbl(Game.mi_str(issue.mi).to_upper(), 11, ACC))
	for i in issue.headlines.size():
		var h: Dictionary = issue.headlines[i]
		var cat := str(h.get("cat", "Talk of the town"))
		var col: Color = {"Reviews":ACC, "Box office":GREEN, "Blind item":AMBER, "Scandal":RED, "Cover story":GOLD, "Awards":GOLD, "Rival deals":BLUE, "Casting":BLUE}.get(cat, TEXT_C)
		front[1].add_child(_lbl("%s  %s" % [cat.to_upper(), h.get("text", "")], 17 if i == 0 else 14, col))

	content_box.add_child(_lbl("Archive · %d older issues" % mini(23, maxi(0, Game.state.newspaper.size() - 1)), 17, ACC))
	var archive_grid := _grid(520.0)
	content_box.add_child(archive_grid)
	for old_issue in Game.state.newspaper.slice(1, 24):
		var archive_card = _card("%s · %s" % [old_issue.name, Game.mi_str(old_issue.mi)], "▤")
		archive_grid.add_child(archive_card[0])
		for headline in old_issue.headlines.slice(0, 5):
			archive_card[1].add_child(_lbl("%s · %s" % [str(headline.cat), str(headline.text)], 12, DIM))

# ---------- Tab: Chronicle ----------
func _render_chronik() -> void:
	var txt := ""
	for l in Game.state.log:
		var col := {"deal": "#7da05c", "bad": "#c0504d", "history": ACC.to_html(false)}.get(l.type, "#a89b7e")
		txt += "[color=#6b6152]%s %d[/color]  [color=%s]%s %s[/color]\n" % [Game.MONTHS[int(l.m) - 1], int(l.y), col, LOG_ICONS.get(l.type, "•"), l.text]
	content_box.add_child(_rich(txt if txt != "" else "Nothing has happened yet.", 13))

# =====================================================================
# Modals
# =====================================================================
func _open_modal() -> void:
	_clear(modal_box)
	_update_modal_width()
	modal_layer.visible = true
	modal_open = true

func _close_modal() -> void:
	modal_layer.visible = false
	modal_open = false
	_coverage_pick = -1
	_coverage_archive = false
	_coverage_note = ""
	Game.save_game()
	render()
	_show_next_modal()

func _show_simple_modal(title: String, bbcode: String) -> void:
	_open_modal()
	modal_box.add_child(_lbl(title, 22, ACC))
	modal_box.add_child(_rich(bbcode, 15))
	modal_box.add_child(_btn("Continue", _close_modal, true))

func _show_outcome_modal(title: String, bbcode: String) -> void:
	_open_modal()
	modal_box.add_child(_nego_header("✅ %s — outcome" % title, "The decision is settled.", [
		_chip("Outcome", GREEN),
	]))
	modal_box.add_child(_rich(bbcode, 15))
	modal_box.add_child(_nego_actions({"label": "Continue", "cb": _close_modal}, [], null))

func _show_next_modal() -> void:
	if modal_open or modal_queue.is_empty():
		return
	var ev: Dictionary = modal_queue.pop_front()
	_open_modal()
	modal_box.add_child(_nego_header("💬 %s" % str(ev.title), "Make a decision; the first option is the direct recommendation.", [
		_chip("%d options" % int(ev.choices.size()), BLUE),
	]))
	modal_box.add_child(_rich(ev.text, 15))
	var primary: Dictionary = {}
	var secondary: Array = []
	for i in ev.choices.size():
		var ch: Dictionary = ev.choices[i]
		var spec := {"label": str(ch.label), "cb": _resolve_choice.bind(ev, i), "disabled": bool(ch.get("disabled", false))}
		if i == 0:
			primary = spec
		else:
			secondary.append(spec)
	modal_box.add_child(_nego_actions(primary, secondary, null))

func _resolve_choice(ev: Dictionary, idx: int) -> void:
	var ch: Dictionary = ev.choices[idx]
	if ch.get("action", "") == "restart":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
		get_tree().reload_current_scene()
		return
	if ch.has("fn"):
		var outcome = ch.fn.call()
		if outcome is String and outcome != "":
			_show_outcome_modal(str(ev.title), outcome)
			return
	_close_modal()


# =====================================================================
# Feature 9: multi-party negotiation (UI)
# =====================================================================
func _render_table(note: String) -> void:
	var t = Game.table
	var ctx = Game.pitch_ctx
	_open_modal()
	var weakest_mood := 100.0
	for party_key in t.parties:
		weakest_mood = minf(weakest_mood, float(t.parties[party_key].sat))
	modal_box.add_child(_nego_header("🎩 Multi-party negotiation",
		"“%s” · lead for %s · withdrawing costs nothing extra" % [ctx.casting.title, Game.client_name(ctx.client)], [
			_chip("%d concessions" % int(t.points), RED if int(t.points) < 1 else BLUE),
			_chip("Fee %s" % Game.fmt_money(t.fee), GREEN),
			_chip("%s billing" % ("First" if int(t.billing) == 1 else "Second"), DIM),
			_nego_mood_chip(weakest_mood),
		]))
	if note != "":
		modal_box.add_child(_rich("[i]%s[/i]" % note, 14))
	# Parteien-Karten mit Zufriedenheits-Balken
	var grid := _grid(340.0)
	modal_box.add_child(grid)
	for pk in t.parties:
		var p: Dictionary = t.parties[pk]
		var cv = _card(str(p.name), {"studio": "🏛", "director": "🎬", "client": "⭐", "star": "🌟"}.get(str(pk), "◆"))
		cv[0].custom_minimum_size.x = 190.0 * font_scale
		grid.add_child(cv[0])
		cv[1].add_child(_lbl("“%s”" % str(p.demand), 12, DIM))
		var sat := float(p.sat)
		var veto := float(p.veto)
		cv[1].add_child(_bar(sat, RED if sat < veto + 8.0 else (GREEN if sat >= 60.0 else AMBER)))
		cv[1].add_child(_lbl("Satisfaction %d/100 · veto below %d" % [roundi(sat), roundi(veto)], 11, RED if sat < veto + 8.0 else DIM))
	# Zugeständnisse (kosten Punkte)
	modal_box.add_child(_lbl("Concessions — every gesture costs 1 point:", 13))
	var no_points: bool = int(t.points) < 1
	var row1 := HFlowContainer.new()
	row1.add_theme_constant_override("h_separation", 8)
	row1.add_theme_constant_override("v_separation", 4)
	modal_box.add_child(row1)
	var b_up := _btn("💰 Fee +10% (client)", func(): _table_action("fee_up"))
	b_up.disabled = no_points
	row1.add_child(b_up)
	var b_down := _btn("💸 Fee −10% (studio)", func(): _table_action("fee_down"))
	b_down.disabled = no_points
	row1.add_child(b_down)
	if t.parties.has("star"):
		var b_b1 := _btn("🌟 First billing (client)", func(): _table_action("billing_first"))
		b_b1.disabled = no_points or int(t.billing) == 1
		row1.add_child(b_b1)
		var b_b2 := _btn("▫ Second billing (co-star)", func(): _table_action("billing_second"))
		b_b2.disabled = no_points or int(t.billing) == 2
		row1.add_child(b_b2)
	var row2 := HFlowContainer.new()
	row2.add_theme_constant_override("h_separation", 8)
	row2.add_theme_constant_override("v_separation", 4)
	modal_box.add_child(row2)
	var clause_ids: Array = []
	var clause_ob := OptionButton.new()
	for clk in Game.CLAUSES:
		if Game.clause_available(clk) and not t.clauses.has(clk):
			clause_ids.append(clk)
			clause_ob.add_item(Game.clause_label(clk))
	row2.add_child(clause_ob)
	var b_cl := _btn("📑 Grant a clause (client)", func():
		if clause_ids.size():
			_table_action("clause", str(clause_ids[clause_ob.selected])))
	b_cl.disabled = no_points or clause_ids.is_empty()
	row2.add_child(b_cl)
	# Punktelose Werkzeuge: Gefallen & Chemie-Argument
	var row3 := HFlowContainer.new()
	row3.add_theme_constant_override("h_separation", 8)
	row3.add_theme_constant_override("v_separation", 4)
	modal_box.add_child(row3)
	for pk2 in t.parties:
		var bf := _btn("🤝 Favor for %s" % str(t.parties[pk2].name), _table_action.bind("use_favor", str(pk2)))
		bf.disabled = bool(t.favorUsed) or Game.state.favors.is_empty()
		row3.add_child(bf)
	var bc := _btn("🧬 Sway the director (chemistry & DNA)", func(): _table_action("chem_argument"))
	bc.disabled = bool(t.chemUsed)
	row3.add_child(bc)
	modal_box.add_child(_nego_actions({"label": "Close the contract", "cb": _close_table}, [], _cancel_table))

func _table_action(action: String, target: String = "") -> void:
	var res := Game.table_concede(action, target)
	_render_table("" if res.get("ok", false) else str(res.get("msg", "")))

func _close_table() -> void:
	var table_state = Game.table
	var casting = Game._casting(int(table_state.castingId)) if table_state != null else null
	var film_title := str(casting.title) if casting != null else "the project"
	var client_at_table = Game.client(int(table_state.clientId)) if table_state != null else null
	var client_name := Game.client_name(client_at_table) if client_at_table != null else "The client"
	var fee := float(table_state.fee) if table_state != null else 0.0
	var res := Game.close_table()
	if res.get("success", false):
		Game.table = null
		_show_outcome_modal("Multi-party negotiation", "[b]Contract closed[/b]\n\n%s takes the lead in “%s” for %s." % [client_name, film_title, Game.fmt_money(fee)])
		return
	if res.has("veto"):
		_render_table_veto(res)
	else:
		_render_table(str(res.get("msg", "")))

func _render_table_veto(res: Dictionary) -> void:
	var t = Game.table
	var pname := str(t.parties.get(res.veto, {}).get("name", "One party"))
	_open_modal()
	var weakest_mood := 100.0
	for party_key in t.parties:
		weakest_mood = minf(weakest_mood, float(t.parties[party_key].sat))
	modal_box.add_child(_nego_header("💥 Multi-party negotiation — outcome", "A veto ended the main deal; the fallbacks remain open.", [
		_chip("Veto: %s" % pname, RED),
		_nego_mood_chip(weakest_mood),
	]))
	modal_box.add_child(_rich("[i]“We are not coming together like this. My final word.”[/i]\n\n[b]%s[/b] casts the veto — the financially best deal is worthless if the people at the table are not convinced.\n\nThere is always a way back:" % pname, 15))
	var primary: Dictionary = {}
	var secondary: Array = []
	for fb in res.get("fallbacks", []):
		match str(fb.kind):
			"support":
				primary = {"label": "Supporting role for the same client", "cb": _table_support_fallback.bind(int(fb.roleIdx))}
			"other":
				secondary.append({"label": "Pitch another client", "cb": _table_other_fallback})
	modal_box.add_child(_nego_actions(primary, secondary, _cancel_table))

func _table_support_fallback(role_idx: int) -> void:
	Game.table_support_fallback(role_idx)
	Game.table = null
	_close_modal()

func _table_other_fallback() -> void:
	Game.table_withdraw()
	Game.table = null
	_close_modal()
	_switch_tab("castings")

func _cancel_table() -> void:
	Game.table_withdraw()
	Game.table = null
	_close_modal()

# =====================================================================
# Weekly Planner (UI)
# =====================================================================
func _render_planer() -> void:
	var st = Game.state
	Game.ensure_planner()
	var hv = _card("Weekly planner — %s" % Game.date_str(), "🗓")
	content_box.add_child(hv[0])
	hv[1].add_child(_lbl("The coming week in detail: 7 days with morning, afternoon and evening — for you and every free client. Shooting weeks are booked automatically. Empty slots go to the autopilot: rest when exhaustion is above 50, PR otherwise. Galas happen in the evening.", 12, DIM))
	var pcard = _card("🕴 You (agency)", "")
	content_box.add_child(pcard[0])
	_planner_grid(pcard[1], "player", 0, st.planner.player)
	_planner_fill_row(pcard[1], "player", 0, Game.PLANNER_PLAYER)
	for c in st.clients:
		var ccard = _card("⭐ %s" % Game.client_name(c), "")
		content_box.add_child(ccard[0])
		if not Game.is_free(c):
			ccard[1].add_child(_lbl("🎬 Shooting this week — the calendar belongs to the studio.", 12, DIM))
			continue
		_planner_grid(ccard[1], "client", int(c.id), st.planner.clients.get(str(int(c.id)), []))
		_planner_fill_row(ccard[1], "client", int(c.id), Game.PLANNER_CLIENT)
	# Legende
	var leg = _card("What the actions do", "ℹ")
	content_box.add_child(leg[0])
	var lt := "[b]Your slots:[/b] "
	for k in Game.PLANNER_PLAYER:
		var i1: Dictionary = Game.PLANNER_PLAYER[k]
		lt += "%s %s (%s) · " % [i1.icon, i1.name, i1.desc]
	lt = lt.trim_suffix(" · ") + "\n[b]Client slots:[/b] "
	for k2 in Game.PLANNER_CLIENT:
		var i2: Dictionary = Game.PLANNER_CLIENT[k2]
		lt += "%s %s (%s) · " % [i2.icon, i2.name, i2.desc]
	leg[1].add_child(_rich(lt.trim_suffix(" · "), 12))

# 8-Spalten-Raster: Zeilenlabel (Tagesabschnitt) + Mo…So, Zellen als Icon-Buttons
func _planner_grid(parent: VBoxContainer, who: String, cid: int, slots: Array) -> void:
	var acts: Dictionary = Game.PLANNER_PLAYER if who == "player" else Game.PLANNER_CLIENT
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	grid.add_child(_lbl("", 11, DIM))
	for d in 7:
		var hd := _lbl(Game.PLANNER_DAYS[d], 12, ACC)
		hd.autowrap_mode = TextServer.AUTOWRAP_OFF
		hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(hd)
	for part in 3:
		var pl := _lbl(Game.PLANNER_PARTS[part], 11, DIM)
		pl.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(pl)
		for d in 7:
			var idx := d * 3 + part
			var slot = slots[idx] if idx < slots.size() else null
			var txt := "·"
			var tip := "free — the autopilot takes over"
			if slot != null:
				var info: Dictionary = acts.get(str(slot.get("a", "")), {})
				txt = str(info.get("icon", "•"))
				var tn := _planner_target_name(slot)
				tip = str(info.get("name", "?")) + ((" → " + tn) if tn != "" else "")
			var b := _btn(txt, _open_planner_picker.bind(who, cid, d, part))
			b.tooltip_text = "%s %s: %s" % [Game.PLANNER_DAYS[d], Game.PLANNER_PARTS[part], tip]
			b.custom_minimum_size = Vector2(40 * font_scale, 0)
			grid.add_child(b)

# Komfortzeile: leere Slots eines Tracks mit einer Aktion füllen / Woche leeren
func _planner_fill_row(parent: VBoxContainer, who: String, cid: int, acts: Dictionary) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	parent.add_child(row)
	var lbl := _lbl("Fill empty slots:", 11, DIM)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(lbl)
	for k in acts:
		if who == "player" and (k == "dinner" or k == "pflege"):
			continue  # brauchen ein Ziel — über den Slot-Dialog planen
		var info: Dictionary = acts[k]
		var action := str(k)
		row.add_child(_btn("%s %s" % [info.icon, info.name], func():
			Game.planner_fill(who, cid, action)
			render()))
	row.add_child(_btn("✕ Clear the week", func():
		Game.planner_fill(who, cid, null, null, false)
		render()))

func _planner_target_name(slot: Dictionary) -> String:
	var t := str(slot.get("t", ""))
	if t == "":
		return ""
	match str(slot.get("a", "")):
		"dinner":
			if Game.state.studioRel.has(t):
				return Game._studio(t).name
		"pflege":
			var c = Game.client(t)
			if c != null:
				return Game.client_name(c)
	return ""

func _open_planner_picker(who: String, cid: int, day: int, part: int) -> void:
	_open_modal()
	var title_s := "You (agency)"
	if who == "client":
		var c = Game.client(cid)
		title_s = Game.client_name(c) if c != null else "?"
	modal_box.add_child(_lbl("🗓 Plan %s %s: %s" % [Game.PLANNER_DAYS[day], Game.PLANNER_PARTS[part], title_s], 20, ACC))
	var acts: Dictionary = Game.PLANNER_PLAYER if who == "player" else Game.PLANNER_CLIENT
	for k in acts:
		var info: Dictionary = acts[k]
		if who == "client" and k == "gala" and part != 2:
			continue  # Galas finden abends statt
		if who == "player" and k == "dinner":
			modal_box.add_child(_lbl("%s %s — %s:" % [info.icon, info.name, info.desc], 13))
			var trow := HFlowContainer.new()
			trow.add_theme_constant_override("h_separation", 6)
			modal_box.add_child(trow)
			for s in Game.active_studios():
				trow.add_child(_btn(str(s.name), func():
					Game.planner_slot_set("player", 0, day, part, "dinner", s.id)
					_close_modal()))
		elif who == "player" and k == "pflege":
			modal_box.add_child(_lbl("%s %s — %s:" % [info.icon, info.name, info.desc], 13))
			var trow2 := HFlowContainer.new()
			trow2.add_theme_constant_override("h_separation", 6)
			modal_box.add_child(trow2)
			for c2 in Game.state.clients:
				trow2.add_child(_btn(Game.client_name(c2), func():
					Game.planner_slot_set("player", 0, day, part, "pflege", int(c2.id))
					_close_modal()))
		else:
			modal_box.add_child(_btn("%s %s — %s" % [info.icon, info.name, info.desc], func():
				Game.planner_slot_set(who, cid, day, part, k)
				_close_modal()))
	modal_box.add_child(_btn("Clear slot", func():
		Game.planner_slot_set(who, cid, day, part, null)
		_close_modal()))
	modal_box.add_child(_btn("Cancel", _close_modal))
