extends Node
# =====================================================================
# Karriere-DNA (Chunk 03) — Autoload "CareerDNA".
# Das Alleinstellungsmerkmal der Godot-Version: fünf bipolare Image-
# Achsen je Klient. Rollen prägen das öffentliche Bild (Hauptrolle
# doppelt so stark wie Nebenrolle — der Faktor kommt als mult von
# release_film), Prestige macht elitär/einzigartig, Blockbuster machen
# populär, Untätigkeit lässt das Bild Richtung Neutral verblassen.
# Prägungs-Stärken: Balance.gd (DNA_*). Zustandsfrei bis auf das
# übergebene Klienten-Dict.
# =====================================================================

const DNA_AXES = [
	{"key":"romantik","pos":"Romantic","neg":"Menacing"},
	{"key":"popular", "pos":"Popular","neg":"Elitist"},
	{"key":"verlass", "pos":"Reliable","neg":"Unpredictable"},
	{"key":"unikat",  "pos":"Unique","neg":"Interchangeable"},
	{"key":"familie", "pos":"Family-friendly","neg":"Controversial"},
]

# Was eine Rolle dieses Genres dem öffentlichen Bild einprägt (pro Film, Hauptrolle ×1).
const GENRE_DNA = {
	"romance":  {"romantik":8.0,  "familie":3.0,  "popular":2.0},
	"comedy":   {"popular":6.0,   "familie":5.0},
	"musical":  {"familie":6.0,   "popular":4.0,  "romantik":2.0},
	"drama":    {"popular":-3.0,  "unikat":4.0},
	"western":  {"romantik":-3.0, "verlass":4.0,  "popular":3.0},
	"action":   {"romantik":-4.0, "popular":5.0,  "familie":-1.0},
	"thriller": {"romantik":-5.0, "unikat":2.0,   "familie":-2.0},
	"horror":   {"romantik":-7.0, "familie":-5.0, "unikat":3.0},
	"crime":    {"romantik":-6.0, "familie":-4.0, "unikat":2.0},
	"scifi":    {"popular":4.0,   "unikat":3.0},
	"adventure":{"popular":5.0,   "familie":3.0},
}

# Monatlicher Verfall Richtung Neutral, wenn ein Klient nichts dreht.
const DECAY_PER_MONTH := 0.4


func initial_dna(actor: Dictionary) -> Dictionary:
	# Ausgangsbild aus den angestammten Genres plus deterministisches Rauschen
	var dna := {}
	for ax in DNA_AXES:
		dna[ax.key] = 0.0
	for g in actor.genres:
		var vec: Dictionary = GENRE_DNA.get(g, {})
		for k in vec:
			dna[k] = clampf(dna[k] + vec[k] * 3.0, -45.0, 45.0)
	for ax in DNA_AXES:
		dna[ax.key] = clampf(dna[ax.key] + float(Util.hashs(str(actor.id) + ax.key) % 21) - 10.0, -55.0, 55.0)
	return dna


func imprint_dna(c: Dictionary, genre: String, mult: float, prestige: int, ratio: float) -> void:
	var vec: Dictionary = GENRE_DNA.get(genre, {})
	for k in vec:
		c.dna[k] = clampf(c.dna[k] + vec[k] * mult, -100.0, 100.0)
	if prestige >= 2:
		c.dna.unikat = clampf(c.dna.unikat + Balance.DNA_PRESTIGE_UNIKAT * mult, -100.0, 100.0)
		c.dna.popular = clampf(c.dna.popular + Balance.DNA_PRESTIGE_POPULAR * mult, -100.0, 100.0)
	if ratio >= Balance.DNA_BLOCKBUSTER_RATIO:
		c.dna.popular = clampf(c.dna.popular + Balance.DNA_BLOCKBUSTER_POPULAR * mult, -100.0, 100.0)
	if ratio < 1.0:
		c.dna.verlass = clampf(c.dna.verlass + Balance.DNA_FLOP_VERLASS * mult, -100.0, 100.0)


# Wie gut passt das öffentliche Bild zu einer Rolle dieses Genres?
# Rückgabe ca. -25 … +25, fließt in die Casting-Passung ein.
func dna_fit(c: Dictionary, genre: String, studio_style: String) -> float:
	var vec: Dictionary = GENRE_DNA.get(genre, {})
	var s := 0.0
	for k in vec:
		s += (vec[k] / 8.0) * (c.dna[k] / 100.0) * 14.0
	s += c.dna.unikat / 30.0
	s += (-c.dna.popular if studio_style == "prestige" else c.dna.popular) / 25.0
	return s


func dna_label(c: Dictionary) -> String:
	# Prägnanteste Achse als Kurz-Etikett („Der Bedrohliche")
	var best_key := ""
	var best_val := 0.0
	for ax in DNA_AXES:
		if absf(c.dna[ax.key]) > absf(best_val):
			best_val = c.dna[ax.key]
			best_key = ax.key
	if absf(best_val) < 25.0:
		return "Blank slate"
	for ax in DNA_AXES:
		if ax.key == best_key:
			return ax.pos if best_val > 0 else ax.neg
	return ""


# Karriere-DNA verblasst langsam Richtung Neutral, wenn nichts nachkommt.
func decay(c: Dictionary) -> void:
	for ax in DNA_AXES:
		c.dna[ax.key] = move_toward(c.dna[ax.key], 0.0, DECAY_PER_MONTH)
