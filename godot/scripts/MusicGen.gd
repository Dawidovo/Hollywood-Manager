extends Node
# =====================================================================
# Hollywood Manager (Godot) — Epochen-Soundtrack.
# Primär: echte gemeinfreie/CC0-Aufnahmen pro Epoche (assets/music/,
# Quellen & Lizenzen in assets/CREDITS.md). Fehlt eine Datei, greift
# als Fallback die generative Offline-Synthese (AudioStreamWAV).
# =====================================================================

# Gemeinfreie/CC0-Tracks pro Epoche; "db" gleicht Lautheitsunterschiede
# der historischen Aufnahmen gegenüber den modernen Produktionen aus.
const TRACKS := {
	"ragtime": {"path": "res://assets/music/era_ragtime.ogg", "db": 0.0,
		"title": "Scott Joplin — Maple Leaf Rag (Pianola-Aufnahme, 1916 · gemeinfrei)"},
	"noir": {"path": "res://assets/music/era_noir.ogg", "db": 2.0,
		"title": "Gershwin & Paul Whiteman Orch. — Rhapsody in Blue (Erstaufnahme, 1924 · gemeinfrei)"},
	"synth": {"path": "res://assets/music/era_synth.ogg", "db": -3.0,
		"title": "Loyalty Freak Music — One Cool Minute (CC0)"},
	"modern": {"path": "res://assets/music/era_modern.ogg", "db": -3.0,
		"title": "Loyalty Freak Music — Softly (CC0)"},
}

const SAMPLE_RATE := 22050

const CHORDS := {
	"M": [0, 4, 7], "M7": [0, 4, 7, 11], "m": [0, 3, 7], "m7": [0, 3, 7, 10], "7": [0, 4, 7, 10],
}

const PRESETS := {
	"ragtime": {"tempo": 168.0, "swing": 0.0, "root": 48, "gain": 0.9,
		"prog": [[0,"M"],[0,"M"],[5,"M"],[7,"7"],[0,"M"],[9,"7"],[2,"7"],[7,"7"]],
		"stabs": [1,3,5,7], "stab_len": 0.09, "melody": 0.55, "melody_oct": 24, "pad": false, "arp": false},
	"noir": {"tempo": 82.0, "swing": 0.32, "root": 45, "gain": 1.0,
		"prog": [[0,"m7"],[5,"m7"],[3,"M7"],[10,"7"],[0,"m7"],[8,"M7"],[7,"7"],[7,"7"]],
		"stabs": [0,4], "stab_len": 0.9, "melody": 0.3, "melody_oct": 24, "pad": false, "arp": false},
	"synth": {"tempo": 102.0, "swing": 0.0, "root": 45, "gain": 0.8,
		"prog": [[0,"m"],[0,"m"],[8,"M"],[3,"M"],[10,"M"],[10,"M"],[7,"m"],[8,"M"]],
		"stabs": [0], "stab_len": 2.2, "melody": 0.35, "melody_oct": 12, "pad": true, "arp": false},
	"modern": {"tempo": 72.0, "swing": 0.0, "root": 48, "gain": 0.9,
		"prog": [[0,"m7"],[8,"M7"],[3,"M7"],[10,"M"],[0,"m7"],[8,"M7"],[5,"m7"],[7,"M"]],
		"stabs": [], "stab_len": 0.4, "melody": 0.0, "melody_oct": 12, "pad": true, "arp": true},
}

var player: AudioStreamPlayer
var _cache: Dictionary = {}  # key -> [AudioStream, db_offset, is_recording]
var _current_key := ""
var _track_db := 0.0
var enabled := true
var volume := 0.35

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "Master"
	add_child(player)
	set_volume(volume)

func key_for_year(y: int) -> String:
	if y < 1935: return "ragtime"
	if y < 1968: return "noir"
	if y < 2000: return "synth"
	return "modern"

func start(year: int) -> void:
	_current_key = ""
	set_era(year)

func set_era(year: int) -> void:
	var key := key_for_year(year)
	if key == _current_key:
		return
	_current_key = key
	if not _cache.has(key):
		_cache[key] = _load_track(key)
	player.stream = _cache[key][0]
	_track_db = float(_cache[key][1])
	set_volume(volume)
	if enabled:
		player.play()

# Echte Aufnahme laden; wenn nicht vorhanden (z. B. Assets fehlen),
# auf die alte Offline-Synthese zurückfallen.
func _load_track(key: String) -> Array:
	var info: Dictionary = TRACKS[key]
	if ResourceLoader.exists(str(info.path)):
		var s: AudioStream = load(str(info.path))
		if s is AudioStreamOggVorbis:
			s.loop = true
			return [s, float(info.db), true]
	return [_render_loop(PRESETS[key]), 0.0, false]

func current_title() -> String:
	if _current_key == "":
		return ""
	if _cache.has(_current_key) and bool(_cache[_current_key][2]):
		return str(TRACKS[_current_key].title)
	return "Generierte Epochen-Musik"

func set_volume(v: float) -> void:
	volume = v
	player.volume_db = linear_to_db(clampf(v, 0.0001, 1.0)) - 6.0 + _track_db

func toggle() -> bool:
	enabled = not enabled
	if enabled:
		player.play()
	else:
		player.stop()
	return enabled

# ---------- Offline-Synthese ----------
func _midi_hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

func _render_loop(p: Dictionary) -> AudioStreamWAV:
	var steps_per_bar := 8
	var step_dur: float = 60.0 / p.tempo / 2.0
	var bars: int = p.prog.size()
	var total_sec: float = bars * steps_per_bar * step_dur
	var n := int(total_sec * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1925

	for s in bars * steps_per_bar:
		var bar := s / steps_per_bar
		var in_bar := s % steps_per_bar
		var chord_def: Array = p.prog[bar]
		var chord: Array = CHORDS[chord_def[1]]
		var root: int = p.root + int(chord_def[0])
		var swing_off: float = p.swing * step_dur if (s % 2 == 1) else 0.0
		var t0: float = s * step_dur + swing_off
		# Bass
		if in_bar % 2 == 0:
			var b := root if in_bar % 4 == 0 else root + 7
			_add_note(buf, t0, 0.16 if p.tempo > 120 else 0.5, _midi_hz(b), 0.22, 1)
		# Akkorde / Pad
		if p.pad and in_bar == 0:
			for iv in chord:
				_add_note(buf, t0, p.stab_len, _midi_hz(root + 12 + iv), 0.05, 2)
		elif p.stabs.has(in_bar):
			for iv in chord:
				_add_note(buf, t0, p.stab_len, _midi_hz(root + 12 + iv), 0.07, 0)
		# Arpeggio / Melodie
		if p.arp:
			var iv2: int = chord[in_bar % chord.size()]
			_add_note(buf, t0, 0.9, _midi_hz(root + 24 + iv2), 0.06, 0)
		elif rng.randf() < p.melody:
			var iv3: int = chord[rng.randi() % chord.size()]
			var oct := 12 if rng.randf() < 0.3 else 0
			_add_note(buf, t0, 0.12 if p.tempo > 120 else 0.45, _midi_hz(root + int(p.melody_oct) + iv3 + oct), 0.09, 0)

	# In 16-bit-PCM wandeln (mit sanftem Limiter)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var g: float = p.gain
	for i in n:
		var v: float = clampf(buf[i] * g, -0.95, 0.95)
		var s16 := int(v * 32767.0)
		bytes[i * 2] = s16 & 0xFF
		bytes[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

# wave: 0 = Dreieck, 1 = Sinus, 2 = Sägezahn (weich)
func _add_note(buf: PackedFloat32Array, t0: float, dur: float, hz: float, amp: float, wave: int) -> void:
	var start := int(t0 * SAMPLE_RATE)
	var len := int(dur * SAMPLE_RATE)
	var attack := int(0.012 * SAMPLE_RATE)
	for i in len:
		var idx := start + i
		if idx >= buf.size():
			return
		var ph: float = fmod(hz * float(i) / SAMPLE_RATE, 1.0)
		var v: float
		match wave:
			1:
				v = sin(ph * TAU)
			2:
				v = (2.0 * ph - 1.0) * 0.6 + sin(ph * TAU) * 0.4
			_:
				v = 4.0 * absf(ph - 0.5) - 1.0
		var env: float = minf(1.0, float(i) / attack) * pow(1.0 - float(i) / len, 1.6)
		buf[idx] += v * amp * env
