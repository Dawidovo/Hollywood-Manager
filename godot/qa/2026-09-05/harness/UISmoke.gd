extends Node

const TABS := ["buero", "privat", "lifestyle", "invest", "kontakte", "post", "orte", "klienten", "rumors", "zeitung", "quests", "pool", "castings", "filme", "planer", "finanzen", "chronik"]

func _ready() -> void:
	var main = load("res://Main.tscn").instantiate()
	add_child(main)
	var starts := 0
	var renders := 0
	for year in [1925, 1950, 1980, 2010]:
		var stories: Array = [""]
		for bs in Data.BACKSTORIES:
			stories.append(str(bs.id))
		for story in stories:
			seed(1000 + year)
			Game.new_game("QA UI", year, story)
			Jukebox._current_key = Jukebox.key_for_year(year)
			main._enter_game()
			starts += 1
			for tab in TABS:
				print("UI_RENDER_BEGIN;", year, ";", story, ";", tab)
				main._switch_tab(tab)
				await get_tree().process_frame
				renders += 1
			print("UI_START_DONE;", year, ";", story)
	print("UI_SMOKE_DONE;starts=", starts, ";renders=", renders)
	get_tree().quit()
