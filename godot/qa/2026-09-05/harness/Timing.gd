extends Node

func _ready() -> void:
	for start_week in [1, 4]:
		for delay in [1, 4, 5, 6, 12]:
			seed(9052026)
			Game.new_game("QA timing", 1950)
			Jukebox._current_key = Jukebox.key_for_year(1950)
			Game.state.week = start_week
			EvEngine.apply_effects([{"op":"followup", "event":"tonfilm_training", "delay_weeks":delay}], {"ctid":123, "sender":"QA Contact"})
			print("TIMING_CONTEXT;", Game.state.followups[-1].ctx)
			var found := 0
			for step in 20:
				var evs: Array = Game.end_week()
				for ev in evs:
					if str(ev.get("title", "")) == "The test reel":
						found = step + 1
				if found > 0:
					break
			print("TIMING;start_week=", start_week, ";delay_weeks=", delay, ";actual_end_week_calls=", found)
	print("TIMING_DONE")
	get_tree().quit()
