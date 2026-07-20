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
		c.dna = {"romantik": 62.0, "popular": 45.0, "verlass": -20.0, "unikat": 12.0, "familie": 30.0}
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
		shot_rumor.impactApplied = true
		Game.add_rumor(int(shot_client.id), "Ein Studiobote behauptet, der nächste Vertrag werde heimlich anderswo verhandelt.", false, "wechsel", ["Studios", "Regisseure"], 42.0, true)
		_switch_tab("rumors")
		await _take_shot("rumors")
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
	for key in [["date", "📅 Datum"], ["cash", "💰 Kapital"], ["rep", "⭐ Ruf"], ["network", "🤝 Gefallen"], ["market", "📈 Markt"], ["clients", "👥 Klienten"]]:
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
	header_stats.next.disabled = st.over
	side_scroll.custom_minimum_size = Vector2(_sidebar_w(), 0)

	_clear(tab_bar)
	var known_rumors: int = st.rumors.filter(func(r): return r.knownToPlayer).size()
	var tabs := [["buero", "🏢 Agentur"], ["klienten", "👥 Klienten (%d)" % st.clients.size()], ["rumors", "🗣 Gerüchte (%d)" % known_rumors],
		["pool", "🎭 Talentpool"], ["castings", "🎬 Castings (%d)" % st.castings.size()], ["filme", "🎞 Filme"], ["finanzen", "💰 Finanzen"], ["chronik", "📰 Chronik"]]
	for t in tabs:
		tab_bar.add_child(_btn(t[1], _switch_tab.bind(t[0]), t[0] == current_tab))

	_clear(content_box)
	match current_tab:
		"buero": _render_buero()
		"klienten": _render_klienten()
		"rumors": _render_rumors()
		"pool": _render_pool()
		"castings": _render_castings()
		"filme": _render_filme()
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

# ---------- Tab: Gerüchte ----------
func _render_rumors() -> void:
	content_box.add_child(_lbl("🗣 Das Flüstern der Stadt", 22, ACC))
	content_box.add_child(_lbl("Gerüchte werden von Menschen getragen. Auch eine Lüge kann Karrieren beschädigen, wenn Hollywood sie oft genug wiederholt.", 13, DIM))
	var known: Array = Game.state.rumors.filter(func(r): return r.knownToPlayer)
	known.sort_custom(func(a, b): return float(a.belief) > float(b.belief))
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
			chips.append(_chip("⚠ Wirkt bereits", RED))
		box.add_child(_chip_row(chips))
		box.add_child(_lbl("Glaubwürdigkeit %d/100" % roundi(rumor.belief), 12, RED if rumor.belief >= 60 else DIM))
		box.add_child(_bar(rumor.belief, RED if rumor.belief >= 60 else ACC_DIM, 10))
		box.add_child(_lbl("👥 Bekannte Träger: %s" % ", ".join(rumor.holders), 12, DIM))
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		box.add_child(actions)
		actions.add_child(_btn("📢 Dementieren", _on_rumor_action.bind(int(rumor.id), "deny")))
		actions.add_child(_btn("🤫 Unterdrücken", _on_rumor_action.bind(int(rumor.id), "suppress"), true))
		actions.add_child(_btn("🌀 Gegengerücht", _on_rumor_action.bind(int(rumor.id), "counter")))
		actions.add_child(_btn("⏳ Aussitzen", _on_rumor_action.bind(int(rumor.id), "wait")))

func _on_rumor_action(rid: int, action: String) -> void:
	var outcome := ""
	match action:
		"deny": outcome = Game.deny_rumor(rid)
		"suppress": outcome = Game.suppress_rumor(rid)
		"counter": outcome = Game.counter_rumor(rid)
		"wait": outcome = Game.wait_out_rumor(rid)
	_show_simple_modal("Die Geschichte hinter der Geschichte", outcome)

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
	var all = Game.available_actors()
	if pool_filter.strip_edges() != "":
		var f := pool_filter.to_lower()
		all = all.filter(func(a): return a.name.to_lower().contains(f))
	var grid := _grid(440.0)
	list.add_child(grid)
	for a in all.slice(0, 48):
		var fame := Game.fame_at(a, st.year)
		var req := Game.required_rep(fame)
		var locked: bool = st.agency.rep < req
		var cv = _card(a.name, "🔒" if locked else "")
		grid.add_child(cv[0])
		var box: VBoxContainer = cv[1]
		var chips: Array = []
		if st.year < a.peak:
			chips.append(_chip("📈 Aufsteigend", GREEN))
		elif fame < a.peakFame * 0.6:
			chips.append(_chip("📉 Verblassend", DIM))
		if locked:
			chips.append(_chip("🔒 Ruf ≥ %d nötig" % req, RED))
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
			box.add_child(_btn("Anwerben", _open_negotiation.bind(a.id)))

# ---------- Verhandlung v2 ----------
func _open_negotiation(actor_id: String) -> void:
	var n = Game.start_negotiation(actor_id)
	if n.get("locked", false):
		_show_simple_modal("Kein Termin", "[i]„%s lässt ausrichten: Man kennt Ihre Agentur nicht.“[/i]\n\nStars dieses Kalibers (Ruhm %d) verhandeln erst mit Agenturen ab Ruf %d (aktuell: %d)." % [n.actor.name, n.fame, n.reqRep, int(Game.state.agency.rep)])
		return
	nego_form = {"commission": 10, "bonus": 0, "years": 3, "perks": [], "promise": null}
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
	return {"commission": nego_form.commission, "bonus": nego_form.bonus, "years": nego_form.years, "perks": nego_form.perks.duplicate(), "promise": nego_form.promise}

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
	var prom_s: String = ("\n\n📜 Dein Versprechen (%s) wurde protokolliert." % Game.PROMISES[terms.promise].label) if terms.get("promise") != null else ""
	_show_simple_modal("Vertrag unterschrieben!", "[i]„Also gut. Machen Sie mich unsterblich.“[/i]\n\n%s ist jetzt Klient — %d %% Provision, %d Jahre%s%s.%s" % [a.name, int(terms.commission), int(terms.years), (", %s Bonus" % Game.fmt_money(terms.bonus)) if terms.bonus > 0 else "", perks_s, prom_s])

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
			var nl := _lbl("%s %s — Passung %d %% · %s %+d · 💰 %s · 🔋 %d" % [ficon, Game.client_name(e.c), e.fit, dicon, e.dna, Game.fmt_money(e.estFee), roundi(e.c.exhaustion)], 13, TEXT_C if e.fit >= 35 else DIM)
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
	_render_studio_offer("")

func _render_studio_offer(note: String) -> void:
	var ctx = Game.pitch_ctx
	_open_modal()
	modal_box.add_child(_lbl("💼 Angebot des Studios", 22, ACC))
	if note != "":
		modal_box.add_child(_rich("[i]%s[/i]" % note, 14))
	modal_box.add_child(_rich("Das Studio will [b]%s[/b] für „%s“ — Gage: [color=#%s]%s[/color] (deine Provision: %s)." % [Game.client_name(ctx.client), ctx.casting.title, ACC.to_html(false), Game.fmt_money(ctx.fee), Game.fmt_money(ctx.fee * ctx.client.commission / 100.0)], 15))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	modal_box.add_child(actions)
	actions.add_child(_btn("✅ Annehmen", func(): Game.accept_offer(); _close_modal(), true))
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
