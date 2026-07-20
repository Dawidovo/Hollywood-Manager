# =====================================================================
# Einmal-/Regenerations-Tool: schreibt die Data-Arrays als JSON nach res://data/.
# Aufruf:  godot --headless --path . --script tools/ExportData.gd
# Nach der Umstellung von Data.gd auf die JSON-Fassade dient das Tool nur
# noch zum Neuformatieren (JSON → JSON Round-Trip).
# =====================================================================
extends SceneTree


func _initialize() -> void:
	var data = load("res://scripts/Data.gd").new()
	_write("res://data/actors/core.json", data.ACTORS)
	_write("res://data/studios/core.json", data.STUDIOS)
	_write("res://data/genres/core.json", data.GENRES)
	_write("res://data/titles/core.json", data.TITLES)
	_write("res://data/real_titles/core.json", data.REAL_TITLES)
	_write("res://data/names/core.json", {"first_m": data.NPC_FIRST_M, "first_f": data.NPC_FIRST_F, "last": data.NPC_LAST})
	_write("res://data/history/core.json", data.HISTORY)
	_write("res://data/eras/core.json", data.ERAS)
	data.free()
	quit(0)


func _write(path: String, payload) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("ExportData: Kann %s nicht schreiben." % path)
		return
	f.store_string(JSON.stringify(payload, "\t") + "\n")
	f.close()
	print("geschrieben: ", path)
