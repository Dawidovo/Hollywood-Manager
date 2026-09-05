extends Node

func _ready() -> void:
	var main = load("res://Main.tscn").instantiate()
	add_child(main)
	get_window().mode = Window.MODE_WINDOWED
	for screen_size in [Vector2i(1280,720), Vector2i(1024,600), Vector2i(1920,1080)]:
		get_window().size = screen_size
		await get_tree().create_timer(0.4).timeout
		main._on_era_selected(1950)
		main._show_backstory_picker(1950)
		await get_tree().create_timer(0.3).timeout
		capture(main, screen_size, "backstory")
		main._close_modal()
		main._on_era_selected(2010)
		Game.state.agency.rep = 100
		main._open_negotiation(str(Game.available_actors()[0].id))
		await get_tree().create_timer(0.3).timeout
		capture(main, screen_size, "negotiation2010")
		main._close_modal()
	print("UI_SIZE_DONE")
	get_tree().quit()

func capture(main, size_v: Vector2i, label_s: String) -> void:
	var rect: Rect2 = main.modal_panel.get_global_rect()
	print("UI_SIZE;", label_s, ";requested=", size_v, ";viewport=", get_viewport().get_visible_rect(), ";modal=", rect, ";bottom=", rect.end.y)
	get_viewport().get_texture().get_image().save_png("res://../size-%s-%dx%d.png" % [label_s,size_v.x,size_v.y])
