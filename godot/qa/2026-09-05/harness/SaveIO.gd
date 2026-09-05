extends Node

func _ready() -> void:
	Game.new_game("QA write failure", 1950)
	print("SAVE_IO_BEFORE")
	Game.save_game()
	print("SAVE_IO_AFTER;no_return_status_available")
	get_tree().quit()
