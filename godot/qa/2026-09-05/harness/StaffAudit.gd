extends Node

func _ready() -> void:
	for trial in 20:
		Game.new_game("QA staff", 1950)
		var s: Dictionary = Staff.hire("care")
		s.mode = "auto"
		s.skill = 0.0
		s.loyalty = 0.0
		s.load = 100.0
		var ct: Dictionary = Staff._coldest_contact()
		var before: float = Network.dim(ct, "liking")
		seed(trial)
		Staff._work_care(s, [])
		if Network.dim(ct, "liking") < before:
			print("STAFF_MISHAP;seed=",trial,";liking_before=",before,";after=",Network.dim(ct,"liking"),";digest=",Game.state.weekDigest)
			break
	get_tree().quit()
