class_name DataLoader
# =====================================================================
# Hollywood Manager — Daten-Lader
# Lädt Spieldaten aus JSON-Dateien unter res://data/<kategorie>/ und
# zusätzlich aus user://data/<kategorie>/ (Mod-Overlay, gewinnt bei Konflikt).
# Alle *.json einer Kategorie werden zusammengeführt: gleicher Schlüssel
# ⇒ Feld-Merge (Überschreiben + Anreichern), neuer Schlüssel ⇒ Anhängen.
# Format pro Datei: JSON-Array von Objekten oder {"entries":[...]};
# Dict-Kategorien (z. B. genres) sind ein einzelnes JSON-Objekt.
# Details für Datenpakete: res://data/README.md
# =====================================================================


static func _dirs(cat: String) -> Array:
	return ["res://data/%s" % cat, "user://data/%s" % cat]


static func _files(cat: String) -> Array:
	var out: Array = []
	for dir_path in _dirs(cat):
		var da := DirAccess.open(dir_path)
		if da == null:
			continue
		var names: Array = []
		for fn in da.get_files():
			if fn.to_lower().ends_with(".json"):
				names.append(fn)
		names.sort()
		for fn in names:
			out.append(dir_path.path_join(fn))
	return out


static func _read_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("DataLoader: %s lässt sich nicht öffnen." % path)
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_warning("DataLoader: Ungültiges JSON in %s — Datei übersprungen." % path)
	return parsed


# JSON liefert nur floats — ganze Zahlen zurück in ints wandeln,
# damit Vergleiche/Formatierung wie bei den alten GDScript-Literalen laufen.
static func _intify(v):
	if v is float and v == floorf(v) and absf(v) < 9e15:
		return int(v)
	if v is Array:
		for i in v.size():
			v[i] = _intify(v[i])
		return v
	if v is Dictionary:
		for k in v.keys():
			v[k] = _intify(v[k])
		return v
	return v


static func _key_of(e: Dictionary, key_fields: Array) -> String:
	var parts: Array = []
	for kf in key_fields:
		if not e.has(kf) or e[kf] == null:
			return ""
		parts.append(str(e[kf]))
	return "|".join(parts)


# Listen-Kategorie laden (actors, studios, events, …).
# defaults: Felder, die fehlende Werte auffüllen. required: Pflichtfelder
# für NEUE Einträge (Teil-Einträge, die nur einen bestehenden Schlüssel
# anreichern — z. B. eine Filmografie-Datei — brauchen nur die key_fields).
static func load_entries(cat: String, key_fields: Array = ["id"], defaults: Dictionary = {}, required: Array = []) -> Array:
	var by_key: Dictionary = {}
	var pending: Dictionary = {}
	var order: Array = []
	for path in _files(cat):
		var parsed = _read_json(path)
		if parsed == null:
			continue
		var entries: Array = []
		if parsed is Array:
			entries = parsed
		elif parsed is Dictionary and parsed.get("entries") is Array:
			entries = parsed.entries
		else:
			push_warning("DataLoader: %s enthält weder ein Array noch {\"entries\":[...]} — übersprungen." % path)
			continue
		for i in entries.size():
			var e = entries[i]
			if not (e is Dictionary):
				push_warning("DataLoader: %s[%d] ist kein Objekt — Eintrag übersprungen." % [path, i])
				continue
			e = _intify(e)
			var key := _key_of(e, key_fields)
			if key == "":
				push_warning("DataLoader: %s[%d] — Schlüsselfeld(er) %s fehlen — Eintrag übersprungen." % [path, i, str(key_fields)])
				continue
			if by_key.has(key):
				by_key[key].merge(e, true)
				continue
			var missing: Array = []
			for rf in required:
				if not e.has(rf) or e[rf] == null:
					missing.append(rf)
			if missing.size():
				if not pending.has(key):
					pending[key] = {}
				pending[key].merge(e, true)
				continue
			var full: Dictionary = defaults.duplicate(true)
			if pending.has(key):
				full.merge(pending[key], true)
				pending.erase(key)
			full.merge(e, true)
			by_key[key] = full
			order.append(key)
	for key in pending:
		var missing: Array = []
		for rf in required:
			if not pending[key].has(rf) or pending[key][rf] == null:
				missing.append(rf)
		push_warning("DataLoader: unvollständiger Eintrag („%s“) — Pflichtfeld(er) %s fehlen — Eintrag übersprungen." % [key, str(missing)])
	var out: Array = []
	for k in order:
		out.append(by_key[k])
	return out


# Dict-Kategorie laden (genres, titles, names, ethnicities, …):
# jede Datei ist ein JSON-Objekt; spätere Dateien überschreiben key-weise.
static func load_dict(cat: String) -> Dictionary:
	var out: Dictionary = {}
	for path in _files(cat):
		var parsed = _read_json(path)
		if parsed is Dictionary:
			out.merge(_intify(parsed), true)
		elif parsed != null:
			push_warning("DataLoader: %s muss ein JSON-Objekt sein — übersprungen." % path)
	return out
