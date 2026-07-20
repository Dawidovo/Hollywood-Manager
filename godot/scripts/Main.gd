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
const ERA_THEMES := {
	"ragtime": {"name": "Stummfilm-Ära", "icon": "🎞", "accent": Color("cfcfcf"), "accent_dim": Color("8a8a86"),
		"panel": Color("242220"), "panel2": Color("2f2c29"), "header": Color("191817"), "bg": Color("151413")},
	"noir": {"name": "Goldenes Zeitalter", "icon": "🎬", "accent": Color("d4af37"), "accent_dim": Color("9c823a"),
		"panel": Color("2a241b"), "panel2": Color("332c21"), "header": Color("1a1610"), "bg": Color("16130f")},
	"synth": {"name": "Blockbuster-Ära", "icon": "🌆", "accent": Color("ff9d45"), "accent_dim": Color("b06a2c"),
		"panel": Color("232030"), "panel2": Color("2c2841"), "header": Color("161425"), "bg": Color("121019")},
	"modern": {"name": "Streaming-Ära", "icon": "📡", "accent": Color("e05a5a"), "accent_dim": Color("97423f"),
		"panel": Color("21252b"), "panel2": Color("2a2f38"), "header": Color("14171c"), "bg": Color("101317")},
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
var _nego_widgets: Dictionary = {}
var font_scale := 1.0
var _resize_timer: Timer

# ---------------------------------------------------------------------
func _ready() -> void:
	bg_rect = ColorRect.new()
	bg_rect.color = ERA_THEMES["noir"].bg
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_rect)
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
	var args := OS.get_cmdline_user_args()
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
	elif args.has("--shot-rumors"):
		_on_era_selected(1950)
		Game.start_negotiation("monroe")
		Game.sign_client({"commission": 10, "bonus": 0, "years": 5, "perks": ["assistant", "pr"], "promise": null})
		var shot_client: Dictionary = Game.state.clients[0]
		Game.reveal_secret(shot_client, "beziehung", 2)
		var shot_rumor := Game.add_rumor(int(shot_client.id), "Louella Parsons hört von nächtlichen Treffen in einem Bungalow am Strand.", true, "affäre", ["Assistenten", "Journalisten", "Partygäste"], 67.0, true, "beziehung")
		shot_rumor.industryBelief = 38.0
		shot_rumor.impactApplied = true
		Game.add_rumor(int(shot_client.id), "Ein Studiobote behauptet, der nächste Vertrag werde heimlich anderswo verhandelt.", false, "wechsel", ["Studios", "Regisseure"], 24.0, true, "", 72.0)
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
		Game.add_rumor(int(news_client.id), "Eine Kolumnistin sammelt Material für eine Geschichte, die noch keinen Namen nennt.", false, "skandal", ["Journalisten", "Partygäste"], 44.0, true, "", 31.0)
		Game.tick_rivals([], true)
		Newspaper.build_newspaper()
		_switch_tab("zeitung")
		await _take_shot("zeitung")
	elif args.has("--shot-nego"):
		_on_era_selected(1950)
		_open_negotiation("monroe")
		Game.nego.counter = Game.build_counter({"commission": 12, "bonus": 0, "years": 2, "perks": [], "promise": null})
		_render_negotiation("Monroe: „Versprechen Sie mir nichts, was Sie nicht halten können.“")
		await _take_shot("nego")
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
		Game.planner_slot_set("player", 0, 0, "scouting")
		Game.planner_slot_set("player", 0, 1, "dinner", Game.active_studios()[0].id)
		Game.planner_slot_set("client", int(Game.state.clients[0].id), 0, "pr")
		Game.planner_slot_set("client", int(Game.state.clients[1].id), 1, "training")
		_switch_tab("planer")
		await _take_shot("planer")
	elif args.has("--shot-verhandlung"):
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
		await _take_shot("verhandlung")

func _take_shot(name_s: String) -> void:
	await get_tree().create_timer(1.2).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_%s.png" % name_s)
	print("SHOT_SAVED user://shot_%s.png" % name_s)
	get_tree().quit()

# ---------------------------------------------------------------------
# Responsiveness: Schriftgröße & Spaltenzahl folgen der Fensterbreite
# ---------------------------------------------------------------------
func _recalc_scale() -> void:
	var w := float(get_viewport_rect().size.x)
	font_scale = clampf(w / 1680.0, 0.9, 1.4)

func _on_resized_settled() -> void:
	_recalc_scale()
	if Game.state != null and game_root.visible and not modal_open:
		render()

func _cols(card_w: float = 500.0) -> int:
	var avail := float(get_viewport_rect().size.x) - _sidebar_w() - 70.0
	return clampi(int(avail / (card_w * font_scale)), 1, 4)

func _sidebar_w() -> float:
	return clampf(float(get_viewport_rect().size.x) * 0.21, 350.0, 540.0)

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
	bg_rect.color = t.bg
	header_sb.bg_color = t.header
	header_sb.border_color = ACC
	modal_sb.border_color = ACC
	modal_sb.bg_color = PANEL_C

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
	b.add_theme_font_size_override("font_size", int(14 * font_scale))
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACC if primary else PANEL2_C
	sb.border_color = ACC if primary else ACC_DIM
	sb.set_border_width_all(1)
	sb.set_content_margin_all(int(7 * font_scale))
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = ACC.lightened(0.2) if primary else ACC_DIM
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_color_override("font_color", Color("16130f") if primary else TEXT_C)
	b.add_theme_color_override("font_hover_color", Color("16130f"))
	return b

func _card(title: String = "", icon: String = "") -> Array:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_C
	sb.border_color = PANEL2_C.lightened(0.08)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(int(12 * font_scale))
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(4 * font_scale))
	p.add_child(v)
	if title != "":
		v.add_child(_lbl(("%s " % icon if icon != "" else "") + title, 18, ACC))
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

func _chip_row(chips: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for c in chips:
		h.add_child(c)
	return h

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
	return "%s %s" % [GENRE_ICONS.get(g, ""), Data.GENRES[g].de]

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
	v.add_child(title)
	var tag := _lbl("Du machst keine Filme. Du machst Karrieren.", 18, DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	v.add_child(_lbl("Name deiner Agentur:", 13, DIM))
	name_edit = LineEdit.new()
	name_edit.text = "Morgenstern & Partner"
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(340, 36)
	v.add_child(name_edit)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for era in Data.ERAS:
		var theme: Dictionary = ERA_THEMES[Jukebox.key_for_year(int(era.year))]
		var cv = _card("%s %d" % [theme.icon, int(era.year)])
		var card: PanelContainer = cv[0]
		var box: VBoxContainer = cv[1]
		card.custom_minimum_size = Vector2(290, 180)
		box.add_child(_lbl(era.name, 15, theme.accent))
		box.add_child(_lbl(era.desc, 12, DIM))
		box.add_child(_btn("In %d starten" % int(era.year), _on_era_selected.bind(int(era.year)), true))
		grid.add_child(card)
	if Game.has_save():
		v.add_child(_btn("Gespeichertes Spiel fortsetzen", _on_load_save, true))

func _on_era_selected(year: int) -> void:
	Game.new_game(name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Meine Agentur", year)
	Jukebox.start(year)
	_enter_game()

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
	for key in [["date", "📅 Datum"], ["cash", "💰 Kapital"], ["rep", "⭐ Ruf"], ["network", "🤝 Gefallen"], ["market", "📈 Markt"], ["clients", "👥 Klienten"], ["instinct", "🧠 Instinkt"]]:
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
	hb.add_child(music_btn)
	var vol := HSlider.new()
	vol.min_value = 0
	vol.max_value = 100
	vol.value = 35
	vol.custom_minimum_size = Vector2(90, 20)
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol.value_changed.connect(func(v): Jukebox.set_volume(v / 100.0))
	hb.add_child(vol)
	hb.add_child(_btn("💾 Speichern", func(): Game.save_game()))
	var next_btn := _btn("Monat beenden ▸", _on_end_month, true)
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
	modal_panel.custom_minimum_size = Vector2(780, 0)
	center.add_child(modal_panel)
	modal_box = VBoxContainer.new()
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.custom_minimum_size = Vector2(740, 0)
	modal_box.add_theme_constant_override("separation", 8)
	modal_panel.add_child(modal_box)

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
	header_stats.agency.text = st.agency.name
	header_stats.agency.add_theme_color_override("font_color", ACC)
	header_stats.date.text = Game.date_str()
	header_stats.cash.text = Game.fmt_money(st.agency.cash)
	header_stats.cash.add_theme_color_override("font_color", RED if st.agency.cash < 0 else ACC)
	header_stats.rep.text = "%d/100" % int(st.agency.rep)
	header_stats.network.text = "%d%s" % [st.favors.size(), (" · ⚠%d Schulden" % st.debts.size()) if st.debts.size() else ""]
	header_stats.network.add_theme_color_override("font_color", AMBER if st.debts.size() else TEXT_C)
	header_stats.market.text = "%d %%%s" % [roundi(st.market * 100.0), "  ⚠" if int(st.strikeMonths) > 0 else ""]
	header_stats.market.add_theme_color_override("font_color", RED if st.market < 0.85 or int(st.strikeMonths) > 0 else (GREEN if st.market > 1.1 else TEXT_C))
	header_stats.clients.text = str(st.clients.size())
	header_stats.instinct.text = "%d/100" % int(st.get("instinct", 20))
	header_stats.instinct.add_theme_color_override("font_color", GREEN if int(st.get("instinct", 20)) >= 55 else TEXT_C)
	header_stats.next.disabled = st.over
	side_scroll.custom_minimum_size = Vector2(_sidebar_w(), 0)

	_clear(tab_bar)
	var known_rumors: int = st.rumors.filter(func(r): return r.knownToPlayer).size()
	var tabs := [["buero", "🏢 Agentur"], ["klienten", "👥 Klienten (%d)" % st.clients.size()], ["rumors", "🗣 Gerüchte (%d)" % known_rumors],
		["zeitung", "🗞 Zeitung"], ["pool", "🎭 Talentpool"], ["castings", "🎬 Castings (%d)" % st.castings.size()], ["filme", "🎞 Filme"], ["planer", "🗓 Planer"], ["finanzen", "💰 Finanzen"], ["chronik", "📰 Chronik"]]
	for t in tabs:
		tab_bar.add_child(_btn(t[1], _switch_tab.bind(t[0]), t[0] == current_tab))

	_clear(content_box)
	match current_tab:
		"buero": _render_buero()
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

func _on_end_month() -> void:
	var events: Array = Game.end_month()
	render()
	if events.size():
		modal_queue.append_array(events)
		_show_next_modal()

# ---------- Sidebar ----------
func _render_sidebar() -> void:
	_clear(sidebar_box)
	var st = Game.state
	var cv = _card("Pipeline", "🎬")
	sidebar_box.add_child(cv[0])
	var any := false
	for cs in st.castings:
		var open := 0
		for r in cs.roles:
			if r.filled == null:
				open += 1
		cv[1].add_child(_lbl("%s „%s“ — Casting: noch %d Mon., %d Rolle(n) offen" % [GENRE_ICONS.get(cs.genre, "🎬"), cs.title, int(cs.deadline), open], 12, AMBER if open > 0 else DIM))
		any = true
	for p in st.productions:
		cv[1].add_child(_lbl("🎥 „%s“ — Premiere in ~%d Mon." % [p.title, int(p.monthsLeft)], 12, BLUE))
		any = true
	if not any:
		cv[1].add_child(_lbl("Nichts in Arbeit. Zeit für Akquise.", 12, DIM))
	# Set-Signale laufender Produktionen (Feature 13) — unzuverlässig, aber laut
	var sig_lines: Array = []
	for p in st.productions:
		for sig in p.get("signals", []):
			var sig_icon := "🟢" if bool(sig.get("pos", true)) else "🔴"
			sig_lines.append([int(sig.get("mi", 0)), "%s „%s“: %s" % [sig_icon, p.title, str(sig.get("t", ""))]])
	if sig_lines.size():
		sig_lines.sort_custom(func(a, b): return a[0] > b[0])
		var sv = _card("Set-Signale (Gerüchteküche)", "📡")
		sidebar_box.add_child(sv[0])
		for sl in sig_lines.slice(0, 5):
			sv[1].add_child(_lbl(str(sl[1]), 12, GREEN if str(sl[1]).begins_with("🟢") else RED))
	var deadlines: Array = []
	for c in st.clients:
		for pr in c.promises:
			if not pr.fulfilled and not pr.get("broken", false):
				deadlines.append([int(pr.due), "📜 %s: %s" % [Game.client_name(c), pr.label]])
		if int(c.contractEnd) - Game.mi() <= 12:
			deadlines.append([int(c.contractEnd), "📄 Vertrag %s läuft aus" % Game.client_name(c)])
	if deadlines.size():
		deadlines.sort_custom(func(a, b): return a[0] < b[0])
		var dv = _card("Fristen", "⏳")
		sidebar_box.add_child(dv[0])
		for d in deadlines.slice(0, 6):
			var urgent: bool = d[0] - Game.mi() <= 3
			dv[1].add_child(_lbl("%s — %s" % [d[1], Game.mi_str(d[0])], 12, RED if urgent else DIM))
	var tv = _card("Ticker", "📰")
	sidebar_box.add_child(tv[0])
	for l in st.log.slice(0, 12):
		var col: Color = {"deal": GREEN, "bad": RED, "history": ACC}.get(l.type, DIM)
		tv[1].add_child(_lbl("%s %s %d — %s" % [LOG_ICONS.get(l.type, "•"), Game.MONTHS_DE[int(l.m) - 1].substr(0, 3), int(l.y), l.text], 12, col))

# ---------- Tab: Agentur ----------
func _render_buero() -> void:
	var st = Game.state
	var grid := _grid(560.0)
	grid.columns = clampi(grid.columns, 1, 3)
	content_box.add_child(grid)

	var c1 = _card(st.agency.name, "🏢")
	grid.add_child(c1[0])
	c1[1].add_child(_lbl("Gegründet %d · %s" % [int(st.startYear), Game.date_str()], 12, DIM))
	c1[1].add_child(_lbl("💰 Kapital: %s" % Game.fmt_money(st.agency.cash), 14, RED if st.agency.cash < 0 else TEXT_C))
	c1[1].add_child(_lbl("⭐ Ruf: %d/100 — bestimmt, welche Stars mit dir reden" % int(st.agency.rep), 14))
	c1[1].add_child(_bar(st.agency.rep, ACC))
	c1[1].add_child(_lbl("Bürokosten/Monat: %s (davon Perks: %s)" % [Game.fmt_money(Game.overhead()), Game.fmt_money(Game.perk_costs())], 13, DIM))

	# Konkrete Gefallen & Schulden statt eines abstrakten Netzwerk-Werts
	var cg = _card("Gefallen & Schulden", "🤝")
	grid.add_child(cg[0])
	if st.favors.is_empty() and st.debts.is_empty():
		cg[1].add_child(_lbl("Niemand schuldet dir etwas — und du niemandem. In dieser Stadt ist das fast verdächtig.", 13, DIM))
	for f in st.favors:
		var exp_s: String = (" · verfällt %s" % Game.mi_str(f.expiresMi)) if int(f.expiresMi) >= 0 else ""
		cg[1].add_child(_lbl("🤝 %s — %s%s" % [f["from"].get("name", "?"), Game.FAVOR_KINDS.get(str(f.kind), {}).get("de", str(f.kind)), exp_s], 12, GREEN))
	for d in st.debts:
		cg[1].add_child(_lbl("⚠ Du schuldest %s: %s" % [d["from"].get("name", "?"), Game.FAVOR_KINDS.get(str(d.kind), {}).get("de", str(d.kind))], 12, AMBER))

	var c2 = _card("Marktlage %d %%" % roundi(st.market * 100.0), "📈")
	grid.add_child(c2[0])
	if int(st.strikeMonths) > 0:
		c2[1].add_child(_chip("⚠ Streik: noch %d Monat(e)" % int(st.strikeMonths), RED))
	c2[1].add_child(_bar(clampf(st.market * 60.0, 0.0, 100.0), RED if st.market < 0.85 else (GREEN if st.market > 1.1 else ACC_DIM)))
	c2[1].add_child(_lbl("👥 Klienten: %d · 🎥 Produktionen: %d · 🎞 Vermittelte Filme: %d" % [st.clients.size(), st.productions.size(), st.released.size()], 13, DIM))
	var awards := 0
	for c in st.clients:
		awards += int(c.get("awards", 0))
	c2[1].add_child(_lbl("🏆 Gewonnene Awards: %d" % awards, 13, DIM))
	var gw = Game.genre_weights()
	var keys := gw.keys()
	keys.sort_custom(func(a, b): return gw[a] > gw[b])
	var demand: Array = []
	for k in keys.slice(0, 5):
		demand.append(_genre_de(k))
	c2[1].add_child(_lbl("Gefragt: " + " · ".join(demand), 13, DIM))

	var c3 = _card("Studio-Beziehungen", "🏛")
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

	var c4 = _card("Offene Versprechen", "📜")
	grid.add_child(c4[0])
	var any_pr := false
	for c in st.clients:
		for pr in c.promises:
			if not pr.fulfilled and not pr.get("broken", false):
				var urgent: bool = int(pr.due) - Game.mi() <= 3
				c4[1].add_child(_lbl("📜 %s: %s — fällig %s" % [Game.client_name(c), pr.label, Game.mi_str(pr.due)], 13, RED if urgent else DIM))
				any_pr = true
	if not any_pr:
		c4[1].add_child(_lbl("Keine. Ein Agent ohne Versprechen ist ein Agent ohne Klienten.", 13, DIM))

	var ci = _card("Moralische Identität", "🪞")
	grid.add_child(ci[0])
	var top_labels := Game.identity_top_labels()
	ci[1].add_child(_lbl("Deine Agentur gilt als: %s" % ("noch unbeschrieben" if top_labels.is_empty() else " & ".join(top_labels)), 14, ACC))
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

	var cr = _card("Rivalisierende Agenturen", "⚔")
	grid.add_child(cr[0])
	for rival in st.rivals:
		var info: Dictionary = Game.RIVAL_STYLE_INFO.get(str(rival.style), {"label":str(rival.style), "icon":"◆"})
		var rr := HBoxContainer.new()
		var rival_text := _lbl("%s %s · %s · %d Klienten" % [info.icon, rival.name, info.label, rival.clients.size()], 12, DIM)
		rival_text.custom_minimum_size = Vector2(280 * font_scale, 0)
		rival_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		rr.add_child(rival_text)
		var rel_value := (float(rival.rel) + 100.0) * 0.5
		var rel_bar := _bar(rel_value, GREEN if float(rival.rel) >= 20.0 else (RED if float(rival.grudge) >= 60.0 else ACC_DIM), 8)
		rel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rr.add_child(rel_bar)
		cr[1].add_child(rr)
		cr[1].add_child(_lbl("Verhältnis %+d · Groll %d/100%s" % [roundi(float(rival.rel)), roundi(float(rival.grudge)), (" · Hausstudio: " + Game._studio(str(rival.studioId)).name) if str(rival.get("studioId", "")) != "" else ""], 11, RED if float(rival.grudge) >= 60.0 else DIM))

	var cp = _card("Machtfiguren", "🎬")
	grid.add_child(cp[0])
	if st.powerFigures.is_empty():
		cp[1].add_child(_lbl("Noch führt keiner deiner Stars Regie oder Produktion.", 12, DIM))
	for figure in st.powerFigures:
		var role_label := "Regie" if str(figure.role) == "director" else "Produktion"
		var figure_rival = Game.rival_by_id(str(figure.rivalId))
		var allegiance := "deinem Haus verbunden" if bool(figure.agencyFriendly) else ("bei %s" % figure_rival.name if figure_rival != null else "unabhängig")
		cp[1].add_child(_lbl("🎥 %s · %s · %d Credits · %s" % [figure.name, role_label, int(figure.credits), allegiance], 12, GREEN if bool(figure.agencyFriendly) else RED))

	# Instinkt & Prognosen (Feature 6): wächst nur durch richtige Vorhersagen
	var ci2 = _card("Instinkt %d/100" % int(st.get("instinct", 20)), "🧠")
	grid.add_child(ci2[0])
	ci2[1].add_child(_bar(float(st.get("instinct", 20)), GREEN if int(st.get("instinct", 20)) >= 55 else ACC_DIM))
	ci2[1].add_child(_lbl("Wächst nur durch richtige Prognosen. Schärft Talentpool-Noten (Spannweite ±%d), Drehbuch-Einsichten und Bauchgefühle." % roundi(Game.pool_spread()), 12, DIM))
	var open_preds: Array = st.get("predictions", []).filter(func(pr): return not pr.get("resolved", false))
	var done_preds: Array = st.get("predictions", []).filter(func(pr): return pr.get("resolved", false))
	var hits := done_preds.filter(func(pr): return pr.get("correct", false)).size()
	if done_preds.size():
		ci2[1].add_child(_lbl("Bilanz: %d/%d richtig" % [hits, done_preds.size()], 13, GREEN if hits * 2 >= done_preds.size() else AMBER))
	if open_preds.is_empty():
		ci2[1].add_child(_lbl("Keine offenen Prognosen. Drehbeginne und Signings fragen dein Bauchgefühl.", 12, DIM))
	for pr in open_preds.slice(0, 5):
		ci2[1].add_child(_lbl("🔮 %s — Auflösung ~%s" % [str(pr.get("note", "Prognose")), Game.mi_str(int(pr.get("dueMi", 0)))], 12, ACC))

# ---------- Tab: Klienten (inkl. Karriere-DNA & Dossier) ----------
func _render_klienten() -> void:
	var st = Game.state
	if st.clients.is_empty():
		var cv = _card("Noch keine Klienten", "👥")
		cv[1].add_child(_lbl("Geh in den Talentpool und überzeuge jemanden, dass du seine Karriere in Gold verwandelst.", 13, DIM))
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
		chips.append(_chip("🎬 Am Set bis %s" % Game.mi_str(c.busyUntil), BLUE) if busy else _chip("🟢 Verfügbar", GREEN))
		if c.heat >= 4:
			chips.append(_chip("🔥 Heiß +%d" % roundi(c.heat), RED))
		elif c.heat <= -4:
			chips.append(_chip("❄ Kalt %d" % roundi(c.heat), BLUE))
		if c.exhaustion > 60:
			chips.append(_chip("⚠ Überlastet", RED))
		if c.flags.get("typecast", false):
			chips.append(_chip("🎭 Typecast", AMBER))
		if c.flags.get("tvIncome") != null and int(c.flags.tvIncome.months) > 0:
			chips.append(_chip("📺 TV-Serie: %d Mon." % int(c.flags.tvIncome.months), BLUE))
		if str(c.flags.get("powerFigure", "")) != "":
			chips.append(_chip("🎬 Machtfigur: %s" % ("Regie" if str(c.flags.powerFigure) == "director" else "Produktion"), GOLD))
		chips.append(_chip("📈 Aufsteigend", GREEN) if st.year < a.peak else _chip("📉 Nach dem Zenit", DIM))
		box.add_child(_chip_row(chips))
		box.add_child(_lbl("%d J. · %s" % [Game.age_of(a, st.year), " · ".join(a.genres.map(_genre_de))], 12, DIM))
		box.add_child(_lbl("Talent %s · Charisma %s · Disziplin %s · Präsenz %s" % [
			Game.grade_range(Game.eff_talent(c), 4, str(a.id) + "tal"), Game.grade_range(Game.attrs(a).charisma, 4, str(a.id) + "cha"),
			Game.grade_range(Game.attrs(a).discipline, 4, str(a.id) + "dis"), Game.grade_range(Game.attrs(a).presence, 4, str(a.id) + "pre")], 12, DIM))
		box.add_child(_lbl("📄 %d %% Provision · bis %s · 💰 Gage %s" % [int(c.commission), Game.mi_str(c.contractEnd), Game.fmt_money(Game.ask_fee(c.fame, st.year))], 12, DIM))
		if c.perks.size():
			box.add_child(_lbl("🎁 " + ", ".join(c.perks.map(func(p): return Game.PERKS[p].de)), 12, GREEN))
		var row := GridContainer.new()
		row.columns = 5
		row.add_theme_constant_override("h_separation", 14)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(row)
		for stat in [["⭐ Ruhm", c.fame, ACC], ["❤ Loyalität", c.loyalty, RED if c.loyalty < 35 else GREEN], ["🔐 Vertrauen", c.trust, RED if c.trust < 25 else GREEN], ["😊 Laune", c.mood, RED if c.mood < 35 else ACC_DIM], ["🔋 Erschöpfung", c.exhaustion, RED if c.exhaustion > 60 else BLUE]]:
			var sv := VBoxContainer.new()
			sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sl := _lbl("%s %d" % [stat[0], roundi(stat[1])], 11, DIM)
			sl.autowrap_mode = TextServer.AUTOWRAP_OFF
			sv.add_child(sl)
			sv.add_child(_bar(stat[1], stat[2]))
			row.add_child(sv)
		box.add_child(_lbl("🧬 Karriere-DNA — öffentliches Image: „%s“" % Game.dna_label(c), 13, ACC))
		for ax in Game.DNA_AXES:
			box.add_child(_dna_row(ax, c.dna[ax.key]))
		var narrative: Dictionary = c.get("narrative", {})
		if not narrative.is_empty():
			var narrative_info: Dictionary = Game.NARRATIVE_TYPES.get(str(narrative.type), {"label":str(narrative.type), "desc":""})
			var narrative_color := GREEN if str(narrative.status) == "abgeschlossen" else ACC
			box.add_child(_lbl("📖 %s%s" % [narrative_info.label, " · abgeschlossen" if str(narrative.status) == "abgeschlossen" else ""], 13, narrative_color))
			box.add_child(_lbl(str(narrative_info.desc), 11, DIM))
			box.add_child(_bar(float(narrative.get("progress", 0.0)), narrative_color, 8))
		elif Game.narrative_candidate_types(c).size():
			box.add_child(_lbl("📖 Mögliches Karrierenarrativ ausrufen (PR-Budget)", 13, ACC))
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
			box.add_child(_lbl("🔒 Vertrauliches Dossier", 13, ACC))
			for secret in c.secrets:
				var info: Dictionary = Game.SECRET_TYPES.get(str(secret.type), {"label": str(secret.type)})
				var status_text := {"geheim": "unter Verschluss", "entschärft": "vorbereitet", "publik": "öffentlich"}.get(str(secret.status), str(secret.status))
				var status_color := GREEN if str(secret.status) == "entschärft" else (RED if str(secret.status) == "publik" else DIM)
				var sicon: String = SECRET_ICONS.get(str(secret.type), "◆")
				var secret_row := HBoxContainer.new()
				var secret_label := _lbl("%s %s · Schwere %d · %s (seit %s)" % [sicon, info.label, int(secret.severity), status_text, Game.mi_str(secret.knownSince)], 12, status_color)
				secret_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				secret_row.add_child(secret_label)
				if str(secret.status) == "geheim":
					secret_row.add_child(_btn("Vorbereiten", _on_secret_action.bind(int(c.id), str(secret.type), "prepare")))
				if str(secret.status) != "publik":
					secret_row.add_child(_btn("An Presse verkaufen …", _on_secret_action.bind(int(c.id), str(secret.type), "sell")))
				box.add_child(secret_row)
		for f in c.films.slice(0, 3):
			var fcol := GREEN if f.verdict in ["Hit", "Blockbuster"] else (RED if f.verdict == "Flop" else DIM)
			box.add_child(_lbl("🎞 „%s“ (%d) — %s, Q %d" % [f.title, int(f.year), f.verdict, int(f.quality)], 12, fcol))

func _on_narrative(cid: int, type_s: String) -> void:
	_show_simple_modal("Eine Karriere wird zur Geschichte", Game.declare_narrative(cid, type_s))

# ---------- Tab: Gerüchte ----------
func _render_rumors() -> void:
	content_box.add_child(_lbl("🗣 Das Flüstern der Stadt", 22, ACC))
	content_box.add_child(_lbl("Publikum und Branche glauben nicht dasselbe. Eine Lüge kann an den Kinokassen verpuffen und trotzdem hinter Studiotüren eine Karriere beenden.", 13, DIM))
	var launch_card = _card("Gerücht lancieren", "🕸")
	content_box.add_child(launch_card[0])
	launch_card[1].add_child(_lbl("Streue bewusst ein Gerücht über freie oder rivalisierend vertretene Talente. Riskant: Wird die Agentur enttarnt, leiden Ruf, Vertrauen und moralische Identität.", 12, DIM))
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
		var empty = _card("Noch ist das Vorzimmer still", "🤫")
		empty[1].add_child(_lbl("Gute Assistenten, Studiokontakte und ein starkes Netzwerk lassen dich früher hören, was die Stadt erzählt.", 13, DIM))
		content_box.add_child(empty[0])
		return
	var grid := _grid(620.0)
	content_box.add_child(grid)
	for rumor in known:
		var cv = _card(Game.rumor_subject_name(rumor), "🗣")
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		box.add_child(_rich("[i]„%s“[/i]" % rumor.text, 14))
		var chips: Array = [_chip("Thema: %s" % str(rumor.topic).capitalize(), BLUE), _chip("⏳ %d Monat(e) im Umlauf" % int(rumor.age), DIM)]
		if Game.player_knows_rumor_truth(rumor):
			chips.append(_chip("🔒 Aus deinem Dossier bestätigt", GREEN))
		if rumor.belief >= 60:
			chips.append(_chip("⚠ Öffentlich wirksam", RED))
		if float(rumor.get("industryBelief", 0.0)) >= 60:
			chips.append(_chip("🏛 Branchenintern wirksam", AMBER))
		box.add_child(_chip_row(chips))
		box.add_child(_lbl("Öffentlichkeit %d/100" % roundi(rumor.belief), 12, RED if rumor.belief >= 60 else DIM))
		box.add_child(_bar(rumor.belief, RED if rumor.belief >= 60 else ACC_DIM, 10))
		box.add_child(_lbl("Branche %d/100" % roundi(float(rumor.get("industryBelief", 0.0))), 12, AMBER if float(rumor.get("industryBelief", 0.0)) >= 60 else DIM))
		box.add_child(_bar(float(rumor.get("industryBelief", 0.0)), AMBER if float(rumor.get("industryBelief", 0.0)) >= 60 else BLUE, 10))
		box.add_child(_lbl("👥 Bekannte Träger: %s" % ", ".join(rumor.holders), 12, DIM))
		var actions := HFlowContainer.new()
		actions.add_theme_constant_override("h_separation", 6)
		actions.add_theme_constant_override("v_separation", 6)
		box.add_child(actions)
		actions.add_child(_btn("📢 Dementieren", _on_rumor_action.bind(int(rumor.id), "deny")))
		actions.add_child(_btn("🏛 Studiogespräche", _on_rumor_action.bind(int(rumor.id), "studio")))
		actions.add_child(_btn("🤫 Unterdrücken", _on_rumor_action.bind(int(rumor.id), "suppress"), true))
		actions.add_child(_btn("🌀 Gegengerücht", _on_rumor_action.bind(int(rumor.id), "counter")))
		actions.add_child(_btn("⏳ Aussitzen", _on_rumor_action.bind(int(rumor.id), "wait")))

func _on_rumor_action(rid: int, action: String) -> void:
	var outcome := ""
	match action:
		"deny": outcome = Game.deny_rumor(rid)
		"studio": outcome = Game.studio_talk_rumor(rid)
		"suppress": outcome = Game.suppress_rumor(rid)
		"counter": outcome = Game.counter_rumor(rid)
		"wait": outcome = Game.wait_out_rumor(rid)
	_show_simple_modal("Die Geschichte hinter der Geschichte", outcome)

func _on_rumor_launch(actor_id: String) -> void:
	_show_simple_modal("Ein Satz macht die Runde", Game.launch_rumor(actor_id, str(Game.pick(["skandal", "wechsel", "affäre"]))))

func _on_secret_action(cid: int, type_s: String, action: String) -> void:
	var outcome := Game.prepare_secret(cid, type_s) if action == "prepare" else Game.sell_secret(cid, type_s)
	_show_simple_modal("Streng vertraulich", outcome)

# ---------- Tab: Talentpool ----------
func _render_pool() -> void:
	var st = Game.state
	var filter_row := HBoxContainer.new()
	content_box.add_child(filter_row)
	var fe := LineEdit.new()
	fe.placeholder_text = "🔍 Name suchen …"
	fe.text = pool_filter
	fe.custom_minimum_size = Vector2(240, 32)
	fe.text_changed.connect(func(t): pool_filter = t; _refresh_pool_list())
	filter_row.add_child(fe)
	filter_row.add_child(_lbl("  Große Namen verhandeln nur mit Agenturen von Rang. Werte = Brancheneinschätzung (Spannweite).", 12, DIM))
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
			chips.append(_chip("📈 Aufsteigend", GREEN))
		elif fame < a.peakFame * 0.6:
			chips.append(_chip("📉 Verblassend", DIM))
		if locked:
			chips.append(_chip("🔒 Ruf ≥ %d nötig" % req, RED))
		if owner != null:
			chips.append(_chip("⚔ Bei %s unter Vertrag" % owner.name, AMBER))
		if chips.size():
			box.add_child(_chip_row(chips))
		var death_s: String = (" †%d" % int(a.death)) if a.death != null else ""
		box.add_child(_lbl("%d J. · *%d%s · %s" % [Game.age_of(a, st.year), int(a.birth), death_s, " · ".join(a.genres.map(_genre_de))], 12, DIM))
		box.add_child(_lbl("⭐ Ruhm %d/100" % fame, 12, DIM))
		box.add_child(_bar(fame, ACC))
		box.add_child(_lbl("Talent %s · Charisma %s · Disziplin %s · Präsenz %s" % [
			Game.grade_range(a.talent, 9, str(a.id) + "tal"), Game.grade_range(Game.attrs(a).charisma, 9, str(a.id) + "cha"),
			Game.grade_range(Game.attrs(a).discipline, 9, str(a.id) + "dis"), Game.grade_range(Game.attrs(a).presence, 9, str(a.id) + "pre")], 12, DIM))
		box.add_child(_lbl("💰 Gagen-Niveau ca. %s" % Game.fmt_money(Game.ask_fee(fame, st.year)), 12, DIM))
		if locked:
			var lb := _btn("🔒 Ruf %d nötig" % req, func(): pass)
			lb.disabled = true
			box.add_child(lb)
		else:
			box.add_child(_btn("Abwerben" if owner != null else "Anwerben", _open_negotiation.bind(a.id)))

# ---------- Verhandlung v2 ----------
func _open_negotiation(actor_id: String) -> void:
	var n = Game.start_negotiation(actor_id)
	if n.get("locked", false):
		var rival_note := (" Der bestehende Vertrag bei %s erhöht die Hürde." % n.rivalName) if str(n.get("rivalName", "")) != "" else ""
		_show_simple_modal("Kein Termin", "[i]„%s lässt ausrichten: Man kennt Ihre Agentur nicht.“[/i]\n\nStars dieses Kalibers (Ruhm %d) verhandeln erst mit Agenturen ab Ruf %d (aktuell: %d).%s" % [n.actor.name, n.fame, n.reqRep, int(Game.state.agency.rep), rival_note])
		return
	nego_form = {"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null, "clauses": []}
	_render_negotiation("")

func _render_negotiation(hint: String) -> void:
	var n = Game.nego
	var a: Dictionary = n.actor
	_open_modal()
	modal_box.add_child(_lbl("🤝 Verhandlung: %s" % a.name, 22, ACC))
	modal_box.add_child(_lbl("Runde %d/%d · ⭐ Ruhm %d · Talent %s · %d Jahre · 💰 Gagen-Niveau %s" % [int(n.round), int(n.maxRounds), n.fame, Game.grade_range(a.talent, 6, str(a.id) + "tal"), Game.age_of(a, Game.state.year), Game.fmt_money(n.ask)], 12, DIM))
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

	var comm_lbl := _lbl("Provision: %d %%" % nego_form.commission, 13)
	left.add_child(comm_lbl)
	var comm := HSlider.new()
	comm.min_value = 5
	comm.max_value = 20
	comm.value = nego_form.commission
	comm.value_changed.connect(func(v): nego_form.commission = int(v); comm_lbl.text = "Provision: %d %%" % int(v); _update_mood())
	left.add_child(comm)
	var max_bonus: int = maxi(1000, roundi(n.ask * 0.4 / 1000.0) * 1000)
	var bonus_lbl := _lbl("Signing-Bonus: %s" % Game.fmt_money(nego_form.bonus), 13)
	left.add_child(bonus_lbl)
	var bonus := HSlider.new()
	bonus.min_value = 0
	bonus.max_value = max_bonus
	bonus.step = maxi(1000, roundi(max_bonus / 40000.0) * 1000)
	bonus.value = nego_form.bonus
	bonus.value_changed.connect(func(v): nego_form.bonus = int(v); bonus_lbl.text = "Signing-Bonus: %s" % Game.fmt_money(v); _update_mood())
	left.add_child(bonus)
	left.add_child(_lbl("Vertragslaufzeit:", 13))
	var years := OptionButton.new()
	for y in Game.CONTRACT_YEARS:
		years.add_item("%d Jahre" % y)
	years.selected = Game.CONTRACT_YEARS.find(int(nego_form.years))
	years.item_selected.connect(func(i): nego_form.years = Game.CONTRACT_YEARS[i]; _update_mood())
	left.add_child(years)
	left.add_child(_lbl("📜 Versprechen (wird protokolliert!):", 13))
	var prom := OptionButton.new()
	prom.add_item("Kein Versprechen")
	var pkeys := Game.PROMISES.keys()
	for pk in pkeys:
		prom.add_item(Game.PROMISES[pk].label)
	prom.selected = 0 if nego_form.promise == null else pkeys.find(nego_form.promise) + 1
	prom.item_selected.connect(func(i): nego_form.promise = null if i == 0 else pkeys[i - 1]; _update_mood())
	left.add_child(prom)

	right.add_child(_lbl("🎁 Zusatzleistungen (Perks):", 13))
	for pk in Game.PERKS:
		var perk: Dictionary = Game.PERKS[pk]
		var cb := CheckBox.new()
		var cost_s: String = (" · %s/Mon." % Game.fmt_money(perk.cost * Game.infl(Game.state.year))) if perk.cost > 0 else " · kostenlos"
		cb.text = perk.de + cost_s
		cb.tooltip_text = perk.desc
		cb.button_pressed = nego_form.perks.has(pk)
		cb.toggled.connect(func(on):
			if on and not nego_form.perks.has(pk):
				nego_form.perks.append(pk)
			elif not on:
				nego_form.perks.erase(pk)
			_update_mood())
		right.add_child(cb)

	right.add_child(_lbl("📑 Vertragsklauseln (lösen später Ereignisse aus):", 13))
	for clk in Game.CLAUSES:
		if not Game.clause_available(clk):
			continue
		var clause: Dictionary = Game.CLAUSES[clk]
		var ccb := CheckBox.new()
		ccb.text = clause.de
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
		right.add_child(_lbl("Abbild-Rechte werden erst ab 1995 verhandelbar.", 11, DIM))

	var mood := _lbl("", 14, ACC)
	mood.name = "MoodLabel"
	modal_box.add_child(mood)
	_nego_widgets = {"mood": mood}
	_update_mood()

	if n.counter != null:
		var cbox = _card("Gegenvorschlag von %s" % a.name, "↩")
		modal_box.add_child(cbox[0])
		cbox[1].add_child(_rich("[i]%s[/i]" % n.counter.text, 14))
		var affordable: bool = n.counter.bonus <= Game.state.agency.cash
		var acc := _btn("Gegenvorschlag annehmen" + ("" if affordable else " (zu teuer)"), _accept_counter, true)
		acc.disabled = not affordable
		cbox[1].add_child(acc)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	modal_box.add_child(actions)
	actions.add_child(_btn("Eigenes Angebot machen", _submit_offer, true))
	actions.add_child(_btn("Abbrechen", _close_modal))

func _update_mood() -> void:
	if not _nego_widgets.has("mood") or not is_instance_valid(_nego_widgets.mood):
		return
	var ml = Game.mood_label(Game.evaluate_offer(_offer()))
	var icon := {"begeistert": "😃", "interessiert": "🙂", "abwägend": "🤔", "ablehnend": "😒"}.get(ml[0], "")
	_nego_widgets.mood.text = "Stimmung: %s %s" % [icon, ml[0]]
	_nego_widgets.mood.add_theme_color_override("font_color", GREEN if ml[1] == "pos" else (RED if ml[1] == "neg" else ACC))

func _offer() -> Dictionary:
	return {"commission": nego_form.commission, "bonus": nego_form.bonus, "years": nego_form.years, "perks": nego_form.perks.duplicate(), "promise": nego_form.promise, "clauses": nego_form.get("clauses", []).duplicate()}

func _submit_offer() -> void:
	var offer := _offer()
	var res = Game.make_offer(offer)
	if res.get("broke", false):
		_show_simple_modal("Zu wenig Kapital", "Der Signing-Bonus übersteigt deine Kasse.")
		return
	if res.get("accepted", false):
		_show_signed(offer)
	elif res.get("final", false):
		_show_simple_modal("Abgelehnt", "[i]%s[/i]\n\n%s hat genug gehört. Vielleicht nächstes Jahr — mit besserem Ruf." % [res.hint, Game.nego.actor.name])
	else:
		_render_negotiation(res.hint)

func _accept_counter() -> void:
	var res = Game.accept_counter()
	if res.get("broke", false):
		return
	_show_signed(Game.nego.counter)

func _show_signed(terms: Dictionary) -> void:
	var a: Dictionary = Game.nego.actor
	var perks_s: String = (", Perks: " + ", ".join(terms.perks.map(func(p): return Game.PERKS[p].de))) if terms.perks.size() else ""
	var clause_s: String = ("\n\n📑 Vereinbarte Klauseln: " + ", ".join(terms.get("clauses", []).map(func(cl): return Game.clause_label(str(cl))))) if terms.get("clauses", []).size() else ""
	var prom_s: String = ("\n\n📜 Dein Versprechen (%s) wurde protokolliert." % Game.PROMISES[terms.promise].label) if terms.get("promise") != null else ""
	_show_simple_modal("Vertrag unterschrieben!", "[i]„Also gut. Machen Sie mich unsterblich.“[/i]\n\n%s ist jetzt Klient — %d %% Provision, %d Jahre%s%s.%s%s" % [a.name, int(terms.commission), int(terms.years), (", %s Bonus" % Game.fmt_money(terms.bonus)) if terms.bonus > 0 else "", perks_s, clause_s, prom_s])
	# Star-Prognose (Feature 6b): beim Signing unter Ruhm 40 das Bauchgefühl befragen
	var pev = Game.pop_pending_star_prediction()
	if pev != null:
		modal_queue.append(pev)

# ---------- Tab: Castings ----------
func _render_castings() -> void:
	var st = Game.state
	if int(st.strikeMonths) > 0:
		var cv0 = _card("Streik!", "⚠")
		cv0[1].add_child(_lbl("Für %d weitere Monate ruhen alle Castings." % int(st.strikeMonths), 13, DIM))
		content_box.add_child(cv0[0])
		return
	if st.castings.is_empty():
		var cv1 = _card("Keine offenen Castings", "🎬")
		cv1[1].add_child(_lbl("Nächsten Monat schreiben die Studios neue Projekte aus.", 13, DIM))
		content_box.add_child(cv1[0])
		return
	var grid := _grid(620.0)
	content_box.add_child(grid)
	for cs in st.castings:
		var studio = Game._studio(cs.studioId)
		var cv = _card("„%s“" % cs.title, GENRE_ICONS.get(cs.genre, "🎬"))
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		var rel: float = st.studioRel[cs.studioId]
		box.add_child(_chip_row([
			_chip(_genre_de(cs.genre), BLUE),
			_chip("★".repeat(int(cs.prestige)) + "☆".repeat(3 - int(cs.prestige)), ACC),
			_chip("⏳ %d Mon." % int(cs.deadline), RED if int(cs.deadline) <= 1 else DIM),
			_chip("🏛 Beziehung %d" % int(rel), GREEN if rel >= 60 else (RED if rel < 30 else DIM)),
		]))
		box.add_child(_lbl("%s · Budget %s" % [studio.name, Game.fmt_money(cs.budget)], 12, DIM))
		if cs.has("director"):
			box.add_child(_lbl("🎬 Regie: %s%s" % [cs.director.name, " · bevorzugt deine Agentur" if bool(cs.director.agencyFriendly) else " · aus einem Rivalenhaus"], 12, GREEN if bool(cs.director.agencyFriendly) else RED))
		if cs.has("producer"):
			box.add_child(_lbl("💼 Produktion: %s%s" % [cs.producer.name, " · bevorzugt deine Agentur" if bool(cs.producer.agencyFriendly) else " · aus einem Rivalenhaus"], 12, GREEN if bool(cs.producer.agencyFriendly) else RED))
		for i in cs.roles.size():
			var r: Dictionary = cs.roles[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			box.add_child(row)
			var desc := "%s %s (%s, %d–%d J.) · ab ⭐ %d · ca. %s" % ["🎯" if r.type == "lead" else "▫", "Hauptrolle" if r.type == "lead" else "Nebenrolle", "♂" if r.gender == "m" else "♀", int(r.ageMin), int(r.ageMax), int(r.minFame), Game.fmt_money(r.fee)]
			var dl := _lbl(desc, 12, TEXT_C if r.type == "lead" else DIM)
			dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(dl)
			if r.filled == null:
				row.add_child(_btn("Klient pitchen", _open_pitch.bind(int(cs.id), i)))
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
	modal_box.add_child(_lbl("🎬 Pitch: „%s“" % cs.title, 22, ACC))
	modal_box.add_child(_lbl("%s · ab ⭐ %d · Basis-Gage ca. %s" % ["🎯 Hauptrolle" if role.type == "lead" else "▫ Nebenrolle", int(role.minFame), Game.fmt_money(role.fee)], 12, DIM))
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
		modal_box.add_child(_lbl("🔍 Drehbuch-Einsicht (Gefallen): Qualitätsbasis ca. %d/100 — Prestige plus Drehbuch-Roll, bevor Besetzung und Markt wirken." % insight, 13, ACC))
	if options.is_empty():
		modal_box.add_child(_lbl("Kein verfügbarer Klient passt auf diese Rolle — oder wurde bereits abgelehnt. Klienten mit Drehbuch-Mitsprache lehnen Rollen mit Passung < 35 ab.", 13, DIM))
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
			var nl := _lbl("%s %s — Passung %d %% · %s %+d · 💰 %s · 🔋 %d%s" % [ficon, Game.client_name(e.c), e.fit, dicon, e.dna, Game.fmt_money(e.estFee), roundi(e.c.exhaustion), chem_s], 13, TEXT_C if e.fit >= 35 else DIM)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nl)
			row.add_child(_btn("Vorschlagen", _do_pitch.bind(casting_id, role_idx, int(e.c.id))))
		modal_box.add_child(_lbl("🧬 = Karriere-DNA/Image-Abgleich. Ein Westernstar überzeugt nicht über Nacht als Romantiker.", 12, DIM))
	# Gefallen: Drehbuch-Einsicht vor dem Pitch
	if insight < 0 and Game.has_favor("scriptAccess"):
		modal_box.add_child(_btn("🔍 Gefallen einlösen: Drehbuch-Einsicht", func():
			if Game.consume_favor("scriptAccess"):
				_open_pitch(casting_id, role_idx, Game.script_insight(cs))))
	# Gefallen: abgelehnte Klienten erneut pitchen lassen
	var rejected_clients: Array = []
	for cid in role.rejected:
		var rc = Game.client(cid)
		if rc != null:
			rejected_clients.append(rc)
	if rejected_clients.size():
		modal_box.add_child(_lbl("Bereits abgelehnt:", 13, DIM))
		for rc in rejected_clients:
			var rrow := HBoxContainer.new()
			rrow.add_theme_constant_override("separation", 10)
			modal_box.add_child(rrow)
			var rl := _lbl("❌ %s — vom Studio abgelehnt" % Game.client_name(rc), 13, DIM)
			rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rrow.add_child(rl)
			if Game.has_favor("extraAudition"):
				var rid := int(rc.id)
				rrow.add_child(_btn("🤝 Gefallen: erneut pitchen", func():
					if Game.use_extra_audition(role, rid):
						_open_pitch(casting_id, role_idx, insight)
					else:
						_show_simple_modal("Kein Gefallen", "Niemand schuldet dir mehr ein zusätzliches Vorsprechen.")))
			else:
				rrow.add_child(_lbl("(Gefallen „Zusätzliches Vorsprechen“ nötig)", 11, DIM))
	modal_box.add_child(_btn("Abbrechen", _close_modal))

func _do_pitch(casting_id: int, role_idx: int, client_id: int) -> void:
	var res = Game.submit_pitch(casting_id, role_idx, client_id)
	if not res.success:
		_show_simple_modal("Absage", "[i]„Wir hatten uns die Rolle … anders vorgestellt. Danke für Ihre Zeit.“[/i]")
		return
	_offer_clauses = []
	# Große Hauptrollen: Mehrparteien-Verhandlung (Feature 9)
	if Game.pitch_ctx != null and Game.pitch_ctx.get("table", false):
		Game.start_table()
		_render_table("")
		return
	_render_studio_offer("")

func _render_studio_offer(note: String) -> void:
	var ctx = Game.pitch_ctx
	_open_modal()
	modal_box.add_child(_lbl("💼 Angebot des Studios", 22, ACC))
	if note != "":
		modal_box.add_child(_rich("[i]%s[/i]" % note, 14))
	modal_box.add_child(_rich("Das Studio will [b]%s[/b] für „%s“ — Gage: [color=#%s]%s[/color] (deine Provision: %s)." % [Game.client_name(ctx.client), ctx.casting.title, ACC.to_html(false), Game.fmt_money(ctx.fee), Game.fmt_money(ctx.fee * ctx.client.commission / 100.0)], 15))
	# Rollen-Klauseln (Feature 8): lösen Jahre später Ereignisse aus
	modal_box.add_child(_lbl("📑 Vertragsklauseln für diesen Deal:", 13))
	var clause_flow := HFlowContainer.new()
	clause_flow.add_theme_constant_override("h_separation", 14)
	modal_box.add_child(clause_flow)
	for clk in Game.CLAUSES:
		if not Game.clause_available(clk):
			continue
		var ccb := CheckBox.new()
		ccb.text = str(Game.CLAUSES[clk].de)
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
			modal_box.add_child(_lbl("🔮 Bauchgefühl: Passt %s wirklich besser als %s? (Wird beim Kinostart geprüft)" % [Game.client_name(ctx.client), Game.client_name(alt_c)], 13, ACC))
			var brow := HBoxContainer.new()
			brow.add_theme_constant_override("separation", 8)
			modal_box.add_child(brow)
			brow.add_child(_btn("Ja, besser", func():
				Game.note_betterfit_prediction(ctx.client, alt_c, int(ctx.casting.id))
				ctx["fitAsked"] = true
				_render_studio_offer("Prognose notiert — dein Instinkt wird beim Kinostart auf die Probe gestellt.")))
			brow.add_child(_btn("Nein", func():
				Game.add_prediction("betterfit", {"prodId": int(ctx.casting.id), "chosen": int(ctx.client.id), "other": int(alt_c.id), "otherFame": float(alt_c.fame)}, false, Game.mi() + 30, "%s passt NICHT besser als %s" % [Game.client_name(ctx.client), Game.client_name(alt_c)])
				ctx["fitAsked"] = true
				_render_studio_offer("Prognose notiert.")))
			brow.add_child(_btn("Keine Angabe", func():
				ctx["fitAsked"] = true
				_render_studio_offer("")))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	modal_box.add_child(actions)
	actions.add_child(_btn("✅ Annehmen", func():
		Game.pitch_ctx["offerClauses"] = _offer_clauses.duplicate()
		Game.accept_offer()
		_offer_clauses = []
		_close_modal(), true))
	if not ctx.haggled:
		actions.add_child(_btn("💰 +25 % fordern", _do_haggle))
	var pkg = Game.package_options()
	if pkg.size():
		actions.add_child(_btn("👥 Package-Deal …", _render_package))
	if Game.has_favor("billing") and not ctx.client.flags.get("billingBoost", false):
		actions.add_child(_btn("🎬 Gefallen: Top-Billing", func():
			if Game.consume_favor("billing"):
				ctx.client.flags["billingBoost"] = true
				_render_studio_offer("„Na gut — der Name Ihres Klienten steht über dem Titel. Zufrieden?“ (+Ruhm beim Release)")))
	actions.add_child(_btn("Absagen", func(): Game.pitch_ctx = null; _close_modal()))

func _do_haggle() -> void:
	var res = Game.haggle()
	if res.get("lost", false):
		_show_simple_modal("Verhandlung geplatzt", "[i]„Sagen Sie Ihrem Klienten, er soll sich einen anderen Film suchen.“[/i]")
		return
	_render_studio_offer("„Also gut. %s. Aber kein Cent mehr.“" % Game.fmt_money(res.get("fee", 0)) if res.success else "„Nein. Das Angebot steht — nehmen Sie es oder lassen Sie es.“")

func _render_package() -> void:
	var ctx = Game.pitch_ctx
	_open_modal()
	modal_box.add_child(_lbl("👥 Package-Deal schnüren", 22, ACC))
	modal_box.add_child(_lbl("Hauptdeal: %s (%s). Wähle den zweiten Klienten:" % [Game.client_name(ctx.client), Game.fmt_money(ctx.fee)], 13, DIM))
	for o in Game.package_options():
		var row := HBoxContainer.new()
		modal_box.add_child(row)
		var l := _lbl("%s — Nebenrolle · Passung %d %%" % [Game.client_name(o.c), o.fit], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(_btn("Vorschlagen", _do_package.bind(int(o.roleIdx), int(o.c.id))))
	modal_box.add_child(_btn("Zurück", func(): _render_studio_offer("")))

func _do_package(role_idx: int, client_id: int) -> void:
	var res = Game.try_package(role_idx, client_id)
	if res.success:
		_show_simple_modal("Package-Deal perfekt!", "[i]„Zwei Ihrer Leute in einem Film? Sie werden mir langsam unheimlich.“[/i]\n\nBeide Deals sind unter Dach und Fach — mit 12 % Aufschlag.")
	else:
		_render_studio_offer("„Den zweiten Namen nehmen wir nicht. Aber das ursprüngliche Angebot steht noch.“")

# ---------- Tab: Filme ----------
func _render_filme() -> void:
	var st = Game.state
	if st.productions.size():
		content_box.add_child(_lbl("🎥 In Produktion", 18, ACC))
		var grid := _grid(560.0)
		content_box.add_child(grid)
		for p in st.productions:
			var cv = _card("„%s“" % p.title, GENRE_ICONS.get(p.genre, "🎥"))
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
			cv[1].add_child(_lbl("Besetzung: " + ", ".join(names), 12, DIM))
			cv[1].add_child(_chip_row([_chip("🎬 Kinostart in ~%d Mon." % int(p.monthsLeft), BLUE)]))
			# Produktions-Signale (Feature 13): Set-Gerede statt Fakten
			Game.ensure_prod_fields(p)
			if p.signals.size():
				var srow := HFlowContainer.new()
				srow.add_theme_constant_override("h_separation", 6)
				cv[1].add_child(srow)
				for sig in p.signals:
					srow.add_child(_chip(("🟢 " if bool(sig.get("pos", true)) else "🔴 ") + str(sig.get("t", "")), GREEN if bool(sig.get("pos", true)) else RED))
				cv[1].add_child(_lbl("Signale sind Set-Gerede — die Trefferquote steigt mit deinem Instinkt.", 10, DIM))
				var has_client_here := false
				for r in p.roles:
					if r.filled != null and r.filled.get("clientId") != null and Game.client(r.filled.clientId) != null:
						has_client_here = true
				if has_client_here:
					var pid := int(p.id)
					var arow := HBoxContainer.new()
					arow.add_theme_constant_override("separation", 6)
					cv[1].add_child(arow)
					var b1 := _btn("💰 Nachverhandeln", func(): _show_simple_modal("Nachverhandeln", Game.prod_renegotiate(pid)))
					b1.disabled = bool(p.reactions.get("reneg", false))
					arow.add_child(b1)
					var b2 := _btn("🚪 Klient rausziehen", func(): _show_simple_modal("Ausstieg", Game.prod_pull_client(pid)))
					b2.disabled = bool(p.reactions.get("pull", false))
					arow.add_child(b2)
					var b3 := _btn("📈 Beteiligung fordern", func(): _show_simple_modal("Beteiligung", Game.prod_demand_share(pid)))
					b3.disabled = bool(p.reactions.get("share", false))
					arow.add_child(b3)
	if st.released.size():
		content_box.add_child(_lbl("🎞 Veröffentlicht", 18, ACC))
		var txt := ""
		for f in st.released.slice(0, 30):
			var col := "#c0504d" if f.ratio < 1.0 else ("#7da05c" if f.ratio >= 2.0 else "#a89b7e")
			var vicon := "💥" if f.verdict == "Blockbuster" else ("✅" if f.ratio >= 2.0 else ("❌" if f.ratio < 1.0 else "▫"))
			txt += "%d  %s „%s“ (%s) — Q %d · %s · [color=%s]%s %s[/color]\n" % [int(f.year), GENRE_ICONS.get(f.genre, ""), f.title, Game._studio(f.studioId).name, int(f.quality), Game.fmt_money(f.revenue), col, vicon, f.verdict]
		content_box.add_child(_rich(txt, 13))
	if st.productions.is_empty() and st.released.is_empty():
		var cv = _card("Noch keine Filme", "🎞")
		cv[1].add_child(_lbl("Platziere Klienten in Castings — sobald ein Film abgedreht ist, erscheint er hier.", 13, DIM))
		content_box.add_child(cv[0])

# ---------- Tab: Finanzen (Ledger-Bilanz) ----------
func _render_finanzen() -> void:
	var st = Game.state
	var grid := _grid(560.0)
	grid.columns = clampi(grid.columns, 1, 2)
	content_box.add_child(grid)

	# Kennzahlen
	var kc = _card("Kennzahlen", "📊")
	grid.add_child(kc[0])
	var burn := Game.avg_burn(6)
	var runway := Game.months_to_broke()
	kc[1].add_child(_lbl("💰 Kapital: %s" % Game.fmt_money(st.agency.cash), 14, RED if st.agency.cash < 0 else TEXT_C))
	kc[1].add_child(_lbl("🔥 Ø-Ausgaben (6 Mon.): %s / Monat" % Game.fmt_money(burn), 13, DIM))
	if runway >= 0.0 and runway < 900.0:
		kc[1].add_child(_lbl("⏳ Reichweite bei aktuellem Burn: ~%d Monate" % roundi(runway), 13, RED if runway < 6.0 else (AMBER if runway < 12.0 else GREEN)))
	var top_cat := Game.top_income_cat(12)
	if top_cat != "":
		kc[1].add_child(_lbl("🏆 Größte Einnahmequelle: %s" % Game.LEDGER_CATS.get(top_cat, top_cat), 13, DIM))

	# Laufender Monat nach Kategorie
	var lm: Dictionary = Game.live_month(Game.mi())
	var mc = _card("Laufender Monat: %s" % Game.date_str(), "🗓")
	grid.add_child(mc[0])
	mc[1].add_child(_lbl("Einnahmen %s · Ausgaben %s · Saldo %s" % [Game.fmt_money(lm.income), Game.fmt_money(lm.expenses), Game.fmt_money(lm.income - lm.expenses)], 13, GREEN if lm.income >= lm.expenses else RED))
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
		mc[1].add_child(_lbl("Diesen Monat noch keine Buchungen.", 12, DIM))

	# Letzte 12 Monate
	var hist: Array = st.ledgerMonthly.slice(maxi(0, st.ledgerMonthly.size() - 12))
	if hist.size():
		var hc = _card("Letzte %d Monate" % hist.size(), "📈")
		grid.add_child(hc[0])
		var cumulative := 0.0
		for m in hist:
			var saldo: float = float(m.income) - float(m.expenses)
			cumulative += saldo
			hc[1].add_child(_lbl("%s — ▲ %s · ▼ %s · Saldo %s · Σ %s" % [Game.mi_str(m.mi), Game.fmt_money(m.income), Game.fmt_money(m.expenses), Game.fmt_money(saldo), Game.fmt_money(cumulative)], 12, GREEN if saldo >= 0 else RED))

	# Einzelbuchungen der letzten 3 Monate
	var jc = _card("Einzelbuchungen (letzte 3 Monate)", "🧾")
	grid.add_child(jc[0])
	var shown := 0
	for i in range(st.ledger.size() - 1, -1, -1):
		var e: Dictionary = st.ledger[i]
		if Game.mi() - int(e.mi) > 2 or shown >= 30:
			break
		jc[1].add_child(_lbl("%s · %s%s · %s — %s" % [Game.mi_str(e.mi), "▲" if float(e.amount) >= 0 else "▼", Game.fmt_money(absf(float(e.amount))), Game.LEDGER_CATS.get(str(e.cat), str(e.cat)), e.text], 12, GREEN if float(e.amount) >= 0 else RED))
		shown += 1
	if shown == 0:
		jc[1].add_child(_lbl("Noch keine Buchungen.", 12, DIM))

# ---------- Tab: Hollywood-Zeitung ----------
func _render_zeitung() -> void:
	content_box.add_child(_lbl("🗞 Die alternative Geschichte Hollywoods", 22, ACC))
	content_box.add_child(_lbl("Jede Ausgabe entsteht aus echten Premieren, Besetzungen, Gerüchten, Klientenwechseln und Machtkämpfen deiner Simulation.", 13, DIM))
	if Game.state.newspaper.is_empty():
		var empty = _card("Die Druckmaschinen warten", "📰")
		empty[1].add_child(_lbl("Beende den ersten Monat. Danach erscheint hier die aktuelle Ausgabe — und bleibt im Archiv erhalten.", 13, DIM))
		content_box.add_child(empty[0])
		return
	var issue: Dictionary = Game.state.newspaper[0]
	var front = _card(str(issue.name), "🗞")
	content_box.add_child(front[0])
	front[1].add_child(_lbl(Game.mi_str(issue.mi).to_upper(), 11, ACC))
	for i in issue.headlines.size():
		var h: Dictionary = issue.headlines[i]
		var cat := str(h.get("cat", "Stadtgespräch"))
		var col: Color = {"Kritik":ACC, "Kasse":GREEN, "Blind Item":AMBER, "Skandal":RED, "Titelstory":GOLD, "Awards":GOLD, "Rivalen-Deals":BLUE, "Casting":BLUE}.get(cat, TEXT_C)
		front[1].add_child(_lbl("%s  %s" % [cat.to_upper(), h.get("text", "")], 17 if i == 0 else 14, col))

	content_box.add_child(_lbl("Archiv · %d ältere Ausgaben" % mini(23, maxi(0, Game.state.newspaper.size() - 1)), 17, ACC))
	var archive_grid := _grid(520.0)
	content_box.add_child(archive_grid)
	for old_issue in Game.state.newspaper.slice(1, 24):
		var archive_card = _card("%s · %s" % [old_issue.name, Game.mi_str(old_issue.mi)], "▤")
		archive_grid.add_child(archive_card[0])
		for headline in old_issue.headlines.slice(0, 5):
			archive_card[1].add_child(_lbl("%s · %s" % [str(headline.cat), str(headline.text)], 12, DIM))

# ---------- Tab: Chronik ----------
func _render_chronik() -> void:
	var txt := ""
	for l in Game.state.log:
		var col := {"deal": "#7da05c", "bad": "#c0504d", "history": ACC.to_html(false)}.get(l.type, "#a89b7e")
		txt += "[color=#6b6152]%s %d[/color]  [color=%s]%s %s[/color]\n" % [Game.MONTHS_DE[int(l.m) - 1], int(l.y), col, LOG_ICONS.get(l.type, "•"), l.text]
	content_box.add_child(_rich(txt if txt != "" else "Noch nichts passiert.", 13))

# =====================================================================
# Modals
# =====================================================================
func _open_modal() -> void:
	_clear(modal_box)
	modal_layer.visible = true
	modal_open = true

func _close_modal() -> void:
	modal_layer.visible = false
	modal_open = false
	Game.save_game()
	render()
	_show_next_modal()

func _show_simple_modal(title: String, bbcode: String) -> void:
	_open_modal()
	modal_box.add_child(_lbl(title, 22, ACC))
	modal_box.add_child(_rich(bbcode, 15))
	modal_box.add_child(_btn("Weiter", _close_modal, true))

func _show_next_modal() -> void:
	if modal_open or modal_queue.is_empty():
		return
	var ev: Dictionary = modal_queue.pop_front()
	_open_modal()
	modal_box.add_child(_lbl(ev.title, 22, ACC))
	modal_box.add_child(_rich(ev.text, 15))
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	modal_box.add_child(actions)
	for i in ev.choices.size():
		var ch: Dictionary = ev.choices[i]
		actions.add_child(_btn(ch.label, _resolve_choice.bind(ev, i), i == 0))

func _resolve_choice(ev: Dictionary, idx: int) -> void:
	var ch: Dictionary = ev.choices[idx]
	if ch.get("action", "") == "restart":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
		get_tree().reload_current_scene()
		return
	if ch.has("fn"):
		var outcome = ch.fn.call()
		if outcome is String and outcome != "":
			modal_open = false
			_open_modal()
			modal_box.add_child(_lbl("…", 22, ACC))
			modal_box.add_child(_rich(outcome, 15))
			modal_box.add_child(_btn("Weiter", _close_modal, true))
			return
	_close_modal()


# =====================================================================
# Feature 9: Mehrparteien-Verhandlung (UI)
# =====================================================================
func _render_table(note: String) -> void:
	var t = Game.table
	var ctx = Game.pitch_ctx
	_open_modal()
	modal_box.add_child(_lbl("🎩 Der große Verhandlungstisch", 22, ACC))
	modal_box.add_child(_lbl("„%s“ — Hauptrolle für %s. Zugeständnisse übrig: %d · Gage am Tisch: %s · Vorspann: %s Nennung" % [ctx.casting.title, Game.client_name(ctx.client), int(t.points), Game.fmt_money(t.fee), "erste" if int(t.billing) == 1 else "zweite"], 13, DIM))
	if note != "":
		modal_box.add_child(_rich("[i]%s[/i]" % note, 14))
	# Parteien-Karten mit Zufriedenheits-Balken
	var grid := _grid(340.0)
	modal_box.add_child(grid)
	for pk in t.parties:
		var p: Dictionary = t.parties[pk]
		var cv = _card(str(p.name), {"studio": "🏛", "director": "🎬", "client": "⭐", "star": "🌟"}.get(str(pk), "◆"))
		grid.add_child(cv[0])
		cv[1].add_child(_lbl("„%s“" % str(p.demand), 12, DIM))
		var sat := float(p.sat)
		var veto := float(p.veto)
		cv[1].add_child(_bar(sat, RED if sat < veto + 8.0 else (GREEN if sat >= 60.0 else AMBER)))
		cv[1].add_child(_lbl("Zufriedenheit %d/100 · Veto unter %d" % [roundi(sat), roundi(veto)], 11, RED if sat < veto + 8.0 else DIM))
	# Zugeständnisse (kosten Punkte)
	modal_box.add_child(_lbl("Zugeständnisse — jede Geste kostet 1 Punkt:", 13))
	var no_points: bool = int(t.points) < 1
	var row1 := HFlowContainer.new()
	row1.add_theme_constant_override("h_separation", 8)
	row1.add_theme_constant_override("v_separation", 4)
	modal_box.add_child(row1)
	var b_up := _btn("💰 Gage +10 % (Klient)", func(): _table_action("fee_up"))
	b_up.disabled = no_points
	row1.add_child(b_up)
	var b_down := _btn("💸 Gage −10 % (Studio)", func(): _table_action("fee_down"))
	b_down.disabled = no_points
	row1.add_child(b_down)
	if t.parties.has("star"):
		var b_b1 := _btn("🌟 Erste Nennung (Klient)", func(): _table_action("billing_first"))
		b_b1.disabled = no_points or int(t.billing) == 1
		row1.add_child(b_b1)
		var b_b2 := _btn("▫ Zweite Nennung (Co-Star)", func(): _table_action("billing_second"))
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
	var b_cl := _btn("📑 Klausel gewähren (Klient)", func():
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
		var bf := _btn("🤝 Gefallen an %s" % str(t.parties[pk2].name), _table_action.bind("use_favor", str(pk2)))
		bf.disabled = bool(t.favorUsed) or Game.state.favors.is_empty()
		row3.add_child(bf)
	var bc := _btn("🧬 Regisseur umstimmen (Chemie & DNA)", func(): _table_action("chem_argument"))
	bc.disabled = bool(t.chemUsed)
	row3.add_child(bc)
	# Abschluss / Abbruch
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	modal_box.add_child(actions)
	actions.add_child(_btn("✅ Vertrag abschließen", _close_table, true))
	actions.add_child(_btn("🚶 Zurückziehen (ohne Zusatzschaden)", func():
		Game.table_withdraw()
		Game.table = null
		_close_modal()))

func _table_action(action: String, target: String = "") -> void:
	var res := Game.table_concede(action, target)
	_render_table("" if res.get("ok", false) else str(res.get("msg", "")))

func _close_table() -> void:
	var res := Game.close_table()
	if res.get("success", false):
		Game.table = null
		_close_modal()
		return
	if res.has("veto"):
		_render_table_veto(res)
	else:
		_render_table(str(res.get("msg", "")))

func _render_table_veto(res: Dictionary) -> void:
	var t = Game.table
	var pname := str(t.parties.get(res.veto, {}).get("name", "Eine Partei"))
	_open_modal()
	modal_box.add_child(_lbl("💥 Veto — der Deal platzt", 22, RED))
	modal_box.add_child(_rich("[i]„So kommen wir nicht zusammen. Mein letztes Wort.“[/i]\n\n[b]%s[/b] legt das Veto ein — der finanziell beste Deal nützt nichts, wenn die Menschen am Tisch nicht überzeugt sind.\n\nEs gibt immer einen Rückweg:" % pname, 15))
	for fb in res.get("fallbacks", []):
		match str(fb.kind):
			"support":
				modal_box.add_child(_btn("▫ Trostpreis: Nebenrolle für denselben Klienten", func():
					Game.table_support_fallback(int(fb.roleIdx))
					Game.table = null
					_close_modal(), true))
			"other":
				modal_box.add_child(_btn("👥 Zurück zu den Castings — anderen Klienten pitchen", func():
					Game.table_withdraw()
					Game.table = null
					_close_modal()
					_switch_tab("castings")))
			"withdraw":
				modal_box.add_child(_btn("🚶 Ganz zurückziehen — ohne Zusatzschaden", func():
					Game.table_withdraw()
					Game.table = null
					_close_modal()))

# =====================================================================
# Weekly Planner (UI)
# =====================================================================
func _render_planer() -> void:
	var st = Game.state
	Game.ensure_planner()
	var hv = _card("Wochenplaner — %s" % Game.date_str(), "🗓")
	content_box.add_child(hv[0])
	hv[1].add_child(_lbl("Vier Wochen-Slots pro Monat — für dich und jeden freien Klienten. Dreh-Wochen sind automatisch belegt. Was leer bleibt, übernimmt die Automatik: Erholung bei Erschöpfung über 50, sonst PR.", 12, DIM))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	hv[1].add_child(grid)
	grid.add_child(_lbl("", 12, DIM))
	for w in 4:
		var hw := _lbl("Woche %d" % (w + 1), 13, ACC)
		hw.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(hw)
	# Zeile: Spieler
	var pl := _lbl("🕴 Du (Agentur)", 13)
	pl.autowrap_mode = TextServer.AUTOWRAP_OFF
	grid.add_child(pl)
	for w in 4:
		var slot = st.planner.player[w]
		var txt := "· frei ·"
		if slot != null:
			var info: Dictionary = Game.PLANNER_PLAYER.get(str(slot.get("a", "")), {})
			txt = "%s %s" % [str(info.get("icon", "•")), str(info.get("de", str(slot.get("a", ""))))]
			var tn := _planner_target_name(slot)
			if tn != "":
				txt += " → " + tn
		var b := _btn(txt, _open_planner_picker.bind("player", 0, w))
		b.custom_minimum_size = Vector2(160 * font_scale, 0)
		grid.add_child(b)
	# Zeilen: Klienten
	for c in st.clients:
		var nm := _lbl("⭐ %s" % Game.client_name(c), 13)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(nm)
		var busy := not Game.is_free(c)
		var slots: Array = st.planner.clients.get(str(int(c.id)), [null, null, null, null])
		for w in 4:
			if busy:
				var bl := _lbl("🎬 Dreh", 12, DIM)
				bl.autowrap_mode = TextServer.AUTOWRAP_OFF
				grid.add_child(bl)
			else:
				var slot = slots[w] if w < slots.size() else null
				var txt := "· auto ·"
				if slot != null:
					var info2: Dictionary = Game.PLANNER_CLIENT.get(str(slot.get("a", "")), {})
					txt = "%s %s" % [str(info2.get("icon", "•")), str(info2.get("de", "?"))]
				var b2 := _btn(txt, _open_planner_picker.bind("client", int(c.id), w))
				b2.custom_minimum_size = Vector2(160 * font_scale, 0)
				grid.add_child(b2)
	# Legende
	var leg = _card("Was die Aktionen bringen", "ℹ")
	content_box.add_child(leg[0])
	var lt := "[b]Deine Slots:[/b] "
	for k in Game.PLANNER_PLAYER:
		var i1: Dictionary = Game.PLANNER_PLAYER[k]
		lt += "%s %s (%s) · " % [i1.icon, i1.de, i1.desc]
	lt = lt.trim_suffix(" · ") + "\n[b]Klienten-Slots:[/b] "
	for k2 in Game.PLANNER_CLIENT:
		var i2: Dictionary = Game.PLANNER_CLIENT[k2]
		lt += "%s %s (%s) · " % [i2.icon, i2.de, i2.desc]
	leg[1].add_child(_rich(lt.trim_suffix(" · "), 12))

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

func _open_planner_picker(who: String, cid: int, week: int) -> void:
	_open_modal()
	var title_s := "Du (Agentur)"
	if who == "client":
		var c = Game.client(cid)
		title_s = Game.client_name(c) if c != null else "?"
	modal_box.add_child(_lbl("🗓 Woche %d planen: %s" % [week + 1, title_s], 20, ACC))
	var acts: Dictionary = Game.PLANNER_PLAYER if who == "player" else Game.PLANNER_CLIENT
	for k in acts:
		var info: Dictionary = acts[k]
		if who == "player" and k == "dinner":
			modal_box.add_child(_lbl("%s %s — %s:" % [info.icon, info.de, info.desc], 13))
			var trow := HFlowContainer.new()
			trow.add_theme_constant_override("h_separation", 6)
			modal_box.add_child(trow)
			for s in Game.active_studios():
				trow.add_child(_btn(str(s.name), func():
					Game.planner_slot_set("player", 0, week, "dinner", s.id)
					_close_modal()))
		elif who == "player" and k == "pflege":
			modal_box.add_child(_lbl("%s %s — %s:" % [info.icon, info.de, info.desc], 13))
			var trow2 := HFlowContainer.new()
			trow2.add_theme_constant_override("h_separation", 6)
			modal_box.add_child(trow2)
			for c2 in Game.state.clients:
				trow2.add_child(_btn(Game.client_name(c2), func():
					Game.planner_slot_set("player", 0, week, "pflege", int(c2.id))
					_close_modal()))
		else:
			modal_box.add_child(_btn("%s %s — %s" % [info.icon, info.de, info.desc], func():
				Game.planner_slot_set(who, cid, week, k)
				_close_modal()))
	modal_box.add_child(_btn("Slot leeren", func():
		Game.planner_slot_set(who, cid, week, null)
		_close_modal()))
	modal_box.add_child(_btn("Abbrechen", _close_modal))
