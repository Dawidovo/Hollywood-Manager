extends Node
# =====================================================================
# Hollywood Manager (Godot) — Datenbank-Fassade
# Alle Inhalte liegen als JSON unter res://data/<kategorie>/ und lassen
# sich durch weitere *.json-Dateien ergänzen/überschreiben — auch per
# Mod-Overlay unter user://data/<kategorie>/. Siehe res://data/README.md.
# Kern-Dateien neu erzeugen: tools/ExportData.gd
# Echte Personen: birth/death/debut historisch; talent/ego etc. Spielwerte.
# =====================================================================

var ACTORS: Array = []
var STUDIOS: Array = []
var GENRES: Dictionary = {}
var TITLES: Dictionary = {}
var REAL_TITLES: Array = []
var NPC_FIRST_M: Array = []
var NPC_FIRST_F: Array = []
var NPC_LAST: Array = []
var HISTORY: Array = []
var ERAS: Array = []
var BACKSTORIES: Array = []
var EVENTS: Array = []
var ETHNICITIES: Dictionary = {}
var CAREER_LEVELS: Array = []
var REPUTATION_TITLES: Dictionary = {}
var LOCATIONS: Array = []
var LOCATION_BY_ID: Dictionary = {}
var CONTACT_ROLES: Dictionary = {}
var CONTACT_PERSONS: Dictionary = {}
var CONTACT_CHANNELS: Dictionary = {}
var CONTACT_START_ROSTER: Array = []


func _init() -> void:
	reload()


func reload() -> void:
	ACTORS = DataLoader.load_entries("actors", ["id"],
		{"death": null, "films": [], "ethnicity": "white", "genres": [], "ego": 50, "height_cm": 0, "weight_kg": 0},
		["id", "name", "birth", "g", "debut", "talent", "peak", "peakFame"])
	STUDIOS = DataLoader.load_entries("studios", ["id"],
		{"from": 0, "to": 9999, "style": "commercial"}, ["id", "name"])
	GENRES = DataLoader.load_dict("genres")
	TITLES = DataLoader.load_dict("titles")
	REAL_TITLES = DataLoader.load_entries("real_titles", ["t", "y"], {}, ["t", "y", "g"])
	var names := DataLoader.load_dict("names")
	NPC_FIRST_M = names.get("first_m", [])
	NPC_FIRST_F = names.get("first_f", [])
	NPC_LAST = names.get("last", [])
	HISTORY = DataLoader.load_entries("history", ["year", "month"], {"market": 1.0}, ["year", "month", "text"])
	ERAS = DataLoader.load_entries("eras", ["year"], {"title": ""}, ["year", "name", "desc"])
	BACKSTORIES = DataLoader.load_entries("backstories", ["id"],
		{"icon": "🎬", "desc": "", "start": {}, "trait": {}, "weakness": {}, "client_capacity_mod": 0, "chains": []},
		["id", "name"])
	EVENTS = DataLoader.load_entries("events", ["id"],
		{"cd": 6, "weight": {}, "conditions": {}, "choices": [], "followup_only": false},
		["id", "title", "text"])
	ETHNICITIES = DataLoader.load_dict("ethnicities")
	CAREER_LEVELS = DataLoader.load_entries("career", ["id"],
		{"salary": 600, "living": 350, "req": {}}, ["id", "name"])
	REPUTATION_TITLES = DataLoader.load_dict("reputation")
	LOCATIONS = DataLoader.load_entries("locations", ["id"],
		{"cost": 0, "energy": 0, "desc": "", "icon": "📍", "weekly": {}, "action": null}, ["id", "name"])
	LOCATION_BY_ID = {}
	for loc in LOCATIONS:
		LOCATION_BY_ID[str(loc.id)] = loc
	var contacts := DataLoader.load_dict("contacts")
	CONTACT_ROLES = contacts.get("roles", {})
	CONTACT_PERSONS = contacts.get("persons", {})
	CONTACT_CHANNELS = contacts.get("channels", {})
	CONTACT_START_ROSTER = contacts.get("start_roster", [])
