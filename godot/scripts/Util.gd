extends Node
# =====================================================================
# Zustandslose Helfer (Chunk 02) — Autoload "Util".
# Alles hier ist frei von Spielzustand: Zufalls-Wrapper (globales RNG,
# damit seed() in Tests/Sim deterministisch bleibt), deterministische
# Hashes und die Ökonomie-/Karriere-Mathematik. Funktionen, die state
# oder Backstory lesen (required_rep, grade_range …), wohnen in Game.gd.
# =====================================================================

const GRADE_BANDS = [[92,"A+"],[85,"A"],[80,"A−"],[75,"B+"],[70,"B"],[65,"B−"],[60,"C+"],[55,"C"],[50,"C−"],[45,"D+"],[40,"D"],[35,"D−"],[0,"F"]]

# Cache der verdeckten Schauspieler-Attribute (deterministisch je Actor-Id).
var _attr_cache: Dictionary = {}


# ---------- Zufall ----------
func pick(arr: Array):
	return arr[randi() % arr.size()]

func chance(p: float) -> bool:
	return randf() < p

func rndf(a: float, b: float) -> float:
	return randf_range(a, b)

func rndi(a: int, b: int) -> int:
	return randi_range(a, b)

func hashs(s: String) -> int:
	var h := 5381
	for ch in s.to_utf8_buffer():
		h = int((h * 33 + ch) % 4294967296)
	return h


# ---------- Körperdaten (deterministisch je Actor-Id) ----------
func body_of(a: Dictionary) -> Dictionary:
	var seed := hashs(str(a.get("id", "")))
	var height_min := 168 if str(a.get("g", "m")) == "m" else 155
	var generated_height := height_min + seed % 26
	var height := int(a.get("height_cm", 0))
	if height <= 0:
		height = generated_height
	var bmi := 19.0 + float(int(seed / 97) % 71) / 10.0
	var weight := int(a.get("weight_kg", 0))
	if weight <= 0:
		weight = roundi(bmi * pow(float(height) / 100.0, 2.0))
	return {"height": height, "weight": weight}


# ---------- Ökonomie & Karriere-Mathematik ----------
func infl(year: float) -> float:
	return pow(1.03, year - 1925.0)

func fame_at(actor: Dictionary, year: float) -> int:
	if year < actor.debut:
		return 0
	var rise: float = maxf(3.0, (actor.peak - actor.debut) / 2.2)
	var fall := 14.0
	var d: float = year - actor.peak
	var s: float = rise if d < 0 else fall
	var f: float = actor.peakFame * exp(-0.5 * (d / s) * (d / s))
	return clampi(roundi(f), 5, 100)

func age_of(actor: Dictionary, year: float) -> int:
	return int(year - actor.birth)

func ask_fee(fame: float, year: float) -> float:
	return maxf(infl(year) * Balance.FEE_BASE * pow(fame / 100.0, Balance.FEE_EXPONENT), Balance.FEE_MIN * infl(year))

func grade(v: float) -> String:
	for band in GRADE_BANDS:
		if v >= band[0]:
			return band[1]
	return "F"

func fmt_money(v: float) -> String:
	var sign := "-" if v < 0 else ""
	v = absf(v)
	if v >= 1e9:
		return "%s$%sB" % [sign, _num(v / 1e9)]
	if v >= 1e6:
		return "%s$%sM" % [sign, _num(v / 1e6)]
	if v >= 1e4:
		return "%s$%dK" % [sign, roundi(v / 1000.0)]
	return "%s$%d" % [sign, roundi(v)]

func _num(x: float) -> String:
	return str(snappedf(x, 0.01))


# ---------- Verdeckte Attribute (deterministisch) ----------
func attrs(actor: Dictionary) -> Dictionary:
	if not _attr_cache.has(actor.id):
		_attr_cache[actor.id] = {
			"charisma": clampi(roundi(30.0 + (hashs(str(actor.id) + "cha") % 100) * 0.5 + (actor.peakFame - 60.0) * 0.4), 5, 98),
			"discipline": clampi(roundi(95.0 - actor.ego * 0.55 - (hashs(str(actor.id) + "dis") % 100) * 0.25), 5, 95),
			"presence": clampi(roundi(actor.talent * 0.35 + actor.peakFame * 0.4 + (hashs(str(actor.id) + "pre") % 100) * 0.25 - 5.0), 5, 98),
		}
	return _attr_cache[actor.id]
