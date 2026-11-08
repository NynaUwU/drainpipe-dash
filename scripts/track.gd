extends RefCounted
## The track: centreline, zones (round/square/narrow pipes, sewer halls, wooden decks),
## course generator and procedural mesh builders.
## Gameplay runs in "tube units" (round pipe radius = 1). World metres = tube units * K.

const K := 5.0
const SIDES := 16
const DA := TAU / 16.0
const WA := 1.5 * TAU / 16.0        # half-angle of the water channel in a round pipe
const RING := 0.5                   # ring spacing in tube units
const OPEN_EDGE := 2.5 * TAU / 16.0 # in sewer halls the pipe is a shallow open channel up to this angle
const HALL_R := 6.0
const HALL_UP := 2.5
const RIVER_Y := -2.6
const SQ := 0.9                     # half-size of a square culvert
const DECK_Y := 0.9                 # wooden deck height below the centreline
const DECK_W := 0.95                # wooden deck half-width
const BLEND := 3.0                  # shape morph length between zones

const HALL_OK := ["coins", "low", "grate", "gap", "boost", "dlow", "debris", "slime", "beam"]
const DECK_OK := ["coins", "crate", "crates2", "gap", "beam", "low", "grate"]
const LONG := ["slalom", "scurve", "slime_ramp", "gapwall", "chute", "debris", "gratebeam", "fan"]

var L: Dictionary = {}
var zones: Array = []
var drops: Array = []
var bends: Array = []
var chambers: Array = []
var planks: Array = []
var total := 0.0


# ================================================================ setup + zones
func setup(level: Dictionary, extra: float) -> void:
	L = level
	zones.clear()
	drops.clear()
	bends.clear()
	chambers.clear()
	planks.clear()
	var s := 0.0
	for z in level["zones"]:
		var zz := {"type": z[0], "mat": z[1], "s0": s, "s1": s + float(z[2]), "scale": float(z[3]) if z.size() > 3 else 1.0}
		if zz["type"] == "hall" or zz["type"] == "planks":
			zz["scale"] = 1.0
		zones.append(zz)
		s = zz["s1"]
	level["len"] = s
	var lastz: Dictionary = zones[zones.size() - 1]
	var tail := {"type": "pipe", "mat": lastz["mat"], "s0": s, "s1": s + extra, "scale": lastz["scale"]}
	if lastz["type"] == "square":
		tail["type"] = "square"
	if lastz["type"] == "planks" or lastz["type"] == "hall":
		tail["mat"] = "brick"
		tail["scale"] = 1.0
	zones.append(tail)
	total = s + extra
	for z in zones:
		if z["type"] == "hall":
			chambers.append(z)
		elif z["type"] == "planks":
			planks.append(z)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level["seed"]) * 31 + 5
	s = 70.0
	while s < float(level["len"]) - 40.0:
		var dl := 10.0 + rng.randf() * 6.0
		var zt := zone_type(s)
		if (zt == "pipe" or zt == "square") and zone_type(s + dl + 4.0) == zt and zone_type(s - 4.0) == zt:
			drops.append({"s": s, "len": dl, "depth": 1.5 + rng.randf() * 2.0 + float(level["diff"]) * 0.4})
		s += 100.0 + rng.randf() * 60.0


func zone_index(s: float) -> int:
	for i in zones.size():
		if s < zones[i]["s1"]:
			return i
	return zones.size() - 1


func zone_at(s: float) -> Dictionary:
	return zones[zone_index(s)]


func zone_type(s: float) -> String:
	return zone_at(s)["type"]


func mat_at(s: float) -> String:
	return zone_at(s)["mat"]


func in_chamber(s: float, margin := 0.0) -> bool:
	for c in chambers:
		if s > c["s0"] - margin and s < c["s1"] + margin:
			return true
	return false


func in_planks(s: float, margin := 0.0) -> bool:
	for c in planks:
		if s > c["s0"] - margin and s < c["s1"] + margin:
			return true
	return false


func near_open_end(s: float) -> bool:
	# pipe stretches next to decks are seen from outside, so they get an outer shell
	return in_planks(s, 14.0) and not in_planks(s)


static func _zt(z: Dictionary) -> float:
	return 1.0 if z["type"] == "square" else 0.0


## x = squareness (0 round .. 1 square), y = radius scale
func params(s: float) -> Vector2:
	var i := zone_index(s)
	var z: Dictionary = zones[i]
	var t := _zt(z)
	var k: float = z["scale"]
	if i > 0 and s < float(z["s0"]) + BLEND:
		var p: Dictionary = zones[i - 1]
		if p["type"] != "planks" and z["type"] != "planks":
			var u := smooth01((s - float(z["s0"])) / BLEND)
			t = lerpf(_zt(p), t, u)
			k = lerpf(float(p["scale"]), k, u)
	return Vector2(t, k)


func in_square(s: float) -> bool:
	return params(s).x > 0.01


func scale_at(s: float) -> float:
	if in_planks(s):
		return 1.0
	return params(s).y


static func wall_rt(a: float, t: float, k: float) -> float:
	if t <= 0.0:
		return k
	var sq := SQ / maxf(absf(sin(a)), absf(cos(a)))
	return k * lerpf(1.0, sq, t)


static func water_y(t: float, k: float) -> float:
	return k * lerpf(cos(WA), 0.8, t)


static func water_x(t: float, k: float) -> float:
	return k * lerpf(sin(WA), 0.72, t)


static func deck_edge() -> float:
	return atan(DECK_W / DECK_Y)


## distance from the centre to whatever Glob rides on at (s, a): wall, water or deck.
## Off the side of a deck this returns a big number (nothing underneath).
func sr(s: float, a: float) -> float:
	if in_planks(s):
		var cd := cos(a)
		if cd > 0.2:
			var rd := DECK_Y / cd
			if absf(sin(a)) * rd <= DECK_W + 0.001:
				return rd
		return 9.0
	var p := params(s)
	var w := wall_rt(a, p.x, p.y)
	var ca := cos(a)
	if ca > 0.05:
		var chord := water_y(p.x, p.y) / ca
		if chord < w and absf(sin(a)) * chord <= water_x(p.x, p.y) + 0.001:
			return chord
	return w


func wall_r(s: float, a: float) -> float:
	if in_planks(s):
		return minf(sr(s, a), 1.0)
	var p := params(s)
	return wall_rt(a, p.x, p.y)


## kept for code that only ever runs in round pipes
static func surf_r(a: float) -> float:
	var aa := absf(wrapf(a, -PI, PI))
	if aa < WA:
		return cos(WA) / cos(aa)
	return 1.0


# ================================================================ centreline
static func smooth01(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func env(s: float) -> float:
	return smooth01(s / 60.0)


func cx(s: float) -> float:
	var ax: Array = L["ax"]
	var kx: Array = L["kx"]
	var px: Array = L["px"]
	var x: float = env(s) * (ax[0] * sin(s * kx[0] + px[0]) + ax[1] * sin(s * kx[1] + px[1]))
	for b in bends:
		var u := (s - float(b["s"])) / float(b["len"])
		if u > 0.0 and u < 1.0:
			x += float(b["amp"]) * sin(TAU * u) * pow(sin(PI * u), 2.0)
	return x


func cy(s: float) -> float:
	var y: float = env(s) * float(L["ay"]) * sin(s * float(L["ky"]) + float(L["py"])) - float(L["grade"]) * s
	for d in drops:
		y -= float(d["depth"]) * smooth01((s - float(d["s"])) / float(d["len"]))
	return y


func center(s: float) -> Vector3:
	return Vector3(cx(s), cy(s), -s) * K


func curv(s: float) -> float:
	return cx(s + 1.0) - 2.0 * cx(s) + cx(s - 1.0)


func slope(s: float) -> float:
	return (cy(s + 0.25) - cy(s - 0.25)) / 0.5


## [centre, tangent, right, up]
func frame(s: float) -> Array:
	var c := center(s)
	var t := (center(s + 0.05) - center(s - 0.05)).normalized()
	var r := t.cross(Vector3.UP).normalized()
	var u := r.cross(t).normalized()
	return [c, t, r, u]


static func radial(f: Array, a: float) -> Vector3:
	return f[2] * sin(a) - f[3] * cos(a)


func point(s: float, a: float, r: float) -> Vector3:
	var f := frame(s)
	return f[0] + radial(f, a) * (r * K)


static func ang_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


# ================================================================ course
func _edge_for(zt: String) -> float:
	if zt == "hall":
		return OPEN_EDGE
	if zt == "planks":
		return deck_edge()
	return PI


func gen_course(level: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level["seed"]) * 9973 + 7
	var obs: Array = []
	var coins: Array = []
	var length: float = level["len"]
	var hz: Dictionary = level["hazards"]
	var long_gaps: bool = level.get("long_gaps", false)
	var s := 26.0
	for i in 8:
		coins.append({"s": s + i * 1.8, "a": 0.0, "h": 0.0})
	s += 22.0
	var last := ""
	while s < length - 26.0:
		var dd: float = float(level["diff"]) + s / length
		var zt := zone_type(s)
		var same := zone_type(s + 26.0) == zt and zone_type(s - 3.0) == zt
		var pick := _pick(rng, hz, last, zt, same)
		last = pick
		var used := 0.0
		var sg := -1.0 if rng.randf() < 0.5 else 1.0
		var edge := _edge_for(zt)
		match pick:
			"coins":
				var a0 := (rng.randf() - 0.5) * 1.8
				var wav := 0.0 if rng.randf() < 0.5 else 0.7
				for i in 8:
					coins.append({"s": s + i * 1.6, "a": a0 + sin(i * 0.6) * wav, "h": 0.0})
				used = 12.0
			"low", "grate":
				_block(obs, pick, s, 0.5 if pick == "low" else 0.3, 0.0, edge, 0.25 if pick == "low" else 0.28)
				coins.append({"s": s - 1.6, "a": 0.0, "h": 0.3})
				coins.append({"s": s + 0.3, "a": 0.0, "h": 0.48})
				coins.append({"s": s + 2.2, "a": 0.0, "h": 0.3})
				used = 3.0
			"lowside":
				_block(obs, "low", s, 0.5, sg * 0.45, 1.15, 0.25)
				for i in 3:
					coins.append({"s": s - 2.0 + i * 2.0, "a": -sg * 1.25, "h": 0.0})
				used = 3.0
			"side":
				var c := sg * (0.25 + rng.randf() * 0.5)
				var w := 0.85 + dd * 0.08
				_block(obs, "wall", s, 1.2, c, w, 0.92)
				for i in 4:
					coins.append({"s": s - 4.5 + i * 1.5, "a": c - sg * (w + 0.45), "h": 0.0})
				used = 3.0
			"slot":
				var c2 := (rng.randf() - 0.5) * 1.0
				var open := 0.85 - dd * 0.06
				_block(obs, "wall", s, 1.0, c2 + PI, PI - open, 0.92)
				for i in 8:
					coins.append({"s": s - 11.0 + i * 1.4, "a": c2 * (0.3 + 0.7 * i / 7.0), "h": 0.0})
				used = 3.0
			"gap":
				var gl := (3.6 + dd * 0.25) if long_gaps else (2.2 + dd * 0.4)
				used = _gap_full(obs, coins, s, gl, edge)
			"gapside":
				var gs := snappedf(s, RING)
				var glen := snappedf(6.0 + dd * 2.0, RING)
				var gw := (roundf((0.75 + dd * 0.08) / DA - 0.5) + 0.5) * DA
				_block(obs, "gap", gs, glen, 0.0, gw, 0.0)
				for i in 5:
					coins.append({"s": gs + i * glen / 4.0, "a": sg * (gw + 0.45), "h": 0.0})
				used = glen
			"boost":
				_block(obs, "boost", s, 2.1, 0.0, 0.34, 0.0)
				for i in 6:
					coins.append({"s": s + 4.0 + i * 2.4, "a": 0.0, "h": 0.0})
				used = 18.0
			"slalom":
				for i in 3:
					_block(obs, "wall", s + i * 11.0, 1.2, sg * 0.55, 0.8, 0.92)
					coins.append({"s": s + i * 11.0 - 2.0, "a": -sg * 0.95, "h": 0.0})
					sg = -sg
				used = 24.0
			"dlow":
				_block(obs, "low", s, 0.5, 0.0, edge, 0.25)
				_block(obs, "low", s + 10.0, 0.5, 0.0, edge, 0.25)
				coins.append({"s": s + 0.3, "a": 0.0, "h": 0.48})
				coins.append({"s": s + 10.3, "a": 0.0, "h": 0.48})
				used = 11.0
			"gapwall":
				var g := _gap_full(obs, coins, s, 2.2 + dd * 0.4, edge)
				_block(obs, "wall", s + g + 9.0, 1.2, sg * 0.5, 0.9, 0.92)
				coins.append({"s": s + g + 7.0, "a": -sg * 1.1, "h": 0.0})
				used = g + 11.0
			"fan":
				# giant extraction fan: pass between the turning blades
				var om := sg * (0.7 + dd * 0.22)
				obs.append({"type": "fan", "s0": s, "s1": s + 0.35, "c": 0.0, "w": PI, "h": 9.0,
					"bw": 0.34, "om": om, "ph": rng.randf() * TAU})
				if dd > 1.2 and rng.randf() < 0.5:
					obs.append({"type": "fan", "s0": s + 7.0, "s1": s + 7.35, "c": 0.0, "w": PI, "h": 9.0,
						"bw": 0.34, "om": -om, "ph": rng.randf() * TAU})
					used = 9.0
				else:
					used = 3.0
			"debris":
				for i in 3:
					obs.append({"type": "debris", "s0": s + i * 5.0, "s1": s + i * 5.0 + 0.45,
						"c": 0.0, "c0": (rng.randf() - 0.5) * 0.4, "amp": 0.35 + rng.randf() * 0.25,
						"om": 1.1 + rng.randf() * 0.9 + dd * 0.2, "ph": rng.randf() * TAU,
						"w": 0.17, "h": 0.22, "kind": rng.randi() % 3})
				used = 12.0
			"scurve":
				bends.append({"s": s, "len": 18.0, "amp": sg * 0.9})
				var side := -sg
				for i in 4:
					var ws := s + 3.0 + i * 4.3
					_block(obs, "wall", ws, 0.8, side * 0.5, 0.7, 0.92)
					coins.append({"s": ws - 1.2, "a": -side * 0.85, "h": 0.0})
					side = -side
				used = 20.0
			"crate":
				var cc := (rng.randf() - 0.5) * 1.1
				if zt == "planks":
					cc = clampf(cc, -0.4, 0.4)
				_crate(obs, s, cc)
				coins.append({"s": s + 0.4, "a": cc, "h": 0.6})
				coins.append({"s": s - 1.8, "a": cc, "h": 0.3})
				used = 3.0
			"crates2":
				_crate(obs, s, -0.36)
				_crate(obs, s, 0.36)
				coins.append({"s": s + 0.4, "a": 0.0, "h": 0.62})
				used = 3.0
			"beam":
				var y0 := -sr(s, 0.0) + 0.36
				obs.append({"type": "beam", "s0": s, "s1": s + 0.35, "c": 0.0, "w": PI, "h": 0.0, "y0": y0, "y1": y0 + 0.2})
				for i in 3:
					coins.append({"s": s - 1.5 + i * 1.5, "a": 0.0, "h": 0.0})
				used = 2.0
			"gratebeam":
				_block(obs, "grate", s, 0.3, 0.0, edge, 0.28)
				coins.append({"s": s + 0.3, "a": 0.0, "h": 0.48})
				var yb := -sr(s + 7.0, 0.0) + 0.36
				obs.append({"type": "beam", "s0": s + 7.0, "s1": s + 7.35, "c": 0.0, "w": PI, "h": 0.0, "y0": yb, "y1": yb + 0.2})
				used = 9.0
			"gusher":
				obs.append({"type": "gusher", "s0": s - 0.7, "s1": s + 0.7, "c": sg * 1.3, "w": PI, "h": 0.0,
					"period": 2.6 - dd * 0.2, "on": 0.9, "ph": rng.randf() * 3.0})
				for i in 3:
					coins.append({"s": s - 2.0 + i * 2.0, "a": -sg * 0.3, "h": 0.0})
				used = 4.0
			"slime":
				obs.append({"type": "slime", "s0": s, "s1": s + 6.0, "c": 0.0, "w": 0.62, "h": 0.0})
				for i in 3:
					coins.append({"s": s + i * 2.5, "a": sg * 0.95, "h": 0.0})
				used = 7.0
			"slime_ramp":
				# a slime pool eats your speed right before a ramp over a wide gap
				obs.append({"type": "slime", "s0": s, "s1": s + 5.0, "c": 0.0, "w": 0.62, "h": 0.0})
				obs.append({"type": "ramp", "s0": s + 7.0, "s1": s + 8.4, "c": 0.0, "w": 0.75, "h": 0.22})
				var gs2 := snappedf(s + 8.9, RING)
				_block(obs, "gap", gs2, 5.5, 0.0, PI, 0.0)
				for i in 5:
					var t := i / 4.0
					coins.append({"s": gs2 + t * 5.5, "a": 0.0, "h": 0.3 + sin(t * PI) * 0.5})
				used = 8.9 + 5.5 + 2.0
			"chute":
				# blind drop: the pipe dives steeply, and there is a wall right at the bottom
				drops.append({"s": s, "len": 3.5, "depth": 3.6 + dd * 0.5})
				_block(obs, "wall", s + 5.6, 1.0, sg * 0.45, 0.8, 0.92)
				for i in 3:
					coins.append({"s": s + 4.0 + i * 1.2, "a": -sg * 0.9, "h": 0.0})
				used = 8.0
		s += used + 9.0 + rng.randf() * 6.0 - dd * 1.2
	obs.sort_custom(func(a, b): return a["s0"] < b["s0"])
	for c in coins:
		if in_chamber(c["s"], 1.0):
			c["a"] = clampf(c["a"], -0.72, 0.72)
		elif in_planks(c["s"], 0.5):
			c["a"] = clampf(c["a"], -0.6, 0.6)
	return {"obs": obs, "coins": coins, "len": length}


func _crate(obs: Array, s: float, c: float) -> void:
	obs.append({"type": "crate", "s0": s, "s1": s + 0.9, "c": c, "w": 0.27, "h": 0.42})


func _gap_full(obs: Array, coins: Array, s: float, glen_raw: float, edge: float) -> float:
	var gs := snappedf(s, RING)
	var glen := snappedf(glen_raw, RING)
	_block(obs, "gap", gs, glen, 0.0, edge, 0.0)
	for i in 5:
		var t := i / 4.0
		coins.append({"s": gs - 1.5 + t * (glen + 3.0), "a": 0.0, "h": 0.15 + sin(t * PI) * 0.35})
	return glen


func _block(obs: Array, type: String, s0: float, length: float, c: float, w: float, h: float) -> void:
	obs.append({"type": type, "s0": s0, "s1": s0 + length, "c": c, "w": w, "h": h})


func _pick(rng: RandomNumberGenerator, hz: Dictionary, last: String, zt: String, same: bool) -> String:
	var ws := []
	var tot := 0.0
	for k in hz.keys():
		var name: String = k
		if name == last and name != "coins":
			continue
		if zt == "hall" and not (name in HALL_OK):
			continue
		if zt == "planks" and not (name in DECK_OK):
			continue
		if not same and name in LONG:
			continue
		ws.append([name, float(hz[k])])
		tot += float(hz[k])
	if ws.is_empty():
		return "coins"
	var r := rng.randf() * tot
	for w in ws:
		r -= w[1]
		if r <= 0.0:
			return w[0]
	return ws[0][0]


## lamps, ceiling grates, outflows, guide markers, leaks and broken panels
func gen_decor(length: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(L["seed"]) * 17 + 3
	var lamps: Array = []
	var grates: Array = []
	var outflows: Array = []
	var markers: Array = []
	var leaks: Array = []
	var broken: Array = []
	var s := 8.0
	var side := 1.0
	while s < length:
		var zt := zone_type(s)
		if zt == "pipe" or zt == "square":
			lamps.append({"s": s, "a": PI if in_square(s) else side * 2.25})
			side = -side
		s += 8.0 + rng.randf() * 2.0
	s = 30.0
	while s < length:
		var z := zone_at(s)
		if z["type"] == "pipe" and float(z["scale"]) >= 0.95 and z["mat"] != "copper" and zone_type(s + 2.0) == "pipe" \
				and not in_square(s) and not in_planks(s, 4.0):
			grates.append({"s0": snappedf(s, RING), "s1": snappedf(s, RING) + 1.0, "c": PI, "w": 1.5 * DA})
		s += 28.0 + rng.randf() * 20.0
	s = 15.0
	while s < length:
		var z2 := zone_at(s)
		if (z2["type"] == "pipe" or z2["type"] == "square") and float(z2["scale"]) >= 0.9 and not in_planks(s, 3.0):
			outflows.append({"s": s, "a": (1.0 if rng.randf() < 0.5 else -1.0) * 1.72})
		s += 13.0 + rng.randf() * 10.0
	if L.get("markers", false):
		s = 6.0
		while s < length:
			var zt3 := zone_type(s)
			if zt3 == "pipe" or zt3 == "square":
				markers.append({"s": s, "a": -1.15})
				markers.append({"s": s, "a": 1.15})
			s += 3.0
	if L.get("leaks", false):
		s = 20.0
		while s < length:
			var zt4 := zone_type(s)
			if zt4 == "pipe" or zt4 == "square":
				leaks.append({"s": s, "a": (1.0 if rng.randf() < 0.5 else -1.0) * (1.5 + rng.randf() * 0.8)})
			s += 14.0 + rng.randf() * 14.0
	if L.get("broken", false):
		s = 18.0
		while s < length:
			var z5 := zone_at(s)
			if z5["type"] == "pipe" and not in_planks(s, 3.0):
				var w := (0.5 + rng.randf()) * DA
				broken.append({"s0": snappedf(s, RING), "s1": snappedf(s, RING) + snappedf(1.0 + rng.randf() * 2.0, RING),
					"c": (1.0 if rng.randf() < 0.5 else -1.0) * (1.9 + rng.randf() * 0.9), "w": w})
			s += 9.0 + rng.randf() * 12.0
	return {"lamps": lamps, "grates": grates, "outflows": outflows, "markers": markers, "leaks": leaks, "broken": broken}


# ================================================================ mesh helpers
static func _add_quad(v: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array, col: PackedColorArray,
		p: Array, nn: Vector3, uvs: Array, c: Color) -> void:
	# Godot treats clockwise triangles (seen from the front) as front faces.
	var order := [0, 1, 3, 1, 2, 3]
	if (p[1] - p[0]).cross(p[3] - p[0]).dot(nn) > 0.0:
		order = [0, 3, 1, 1, 3, 2]
	for k in order:
		v.append(p[k])
		n.append(nn)
		uv.append(uvs[k])
		col.append(c)


static func _mesh_from(v: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array, col: PackedColorArray) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	var m := ArrayMesh.new()
	if v.size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _in_holes(holes: Array, s: float, a: float) -> bool:
	for h in holes:
		if s > h["s0"] and s < h["s1"] and absf(ang_diff(a, h["c"])) < h["w"]:
			return true
	return false


static func _face_normal(p: Array, toward: Vector3) -> Vector3:
	var nn: Vector3 = (p[2] - p[0]).cross(p[3] - p[1])
	if nn.length_squared() < 1e-10:
		nn = (p[1] - p[0]).cross(p[3] - p[0])
	nn = nn.normalized()
	if nn.dot(toward - p[0]) < 0.0:
		nn = -nn
	return nn


func _grime(a: float, ring: int, j: int) -> Color:
	var aa := absf(a)
	var c := Color(1, 1, 1)
	if aa < 1.2:
		var t := 1.0 - clampf((aa - WA) / 0.6, 0.0, 1.0)
		c = c.lerp(Color(0.62, 0.66, 0.5), t * 0.7)
	if aa > 1.9:
		c = c * lerpf(1.0, 0.55, clampf((aa - 1.9) / 1.2, 0.0, 1.0))
	var hsh := fposmod(sin(float(ring) * 12.9898 + float(j) * 78.233) * 43758.5453, 1.0)
	var streak := fposmod(sin(float(j) * 3.17 + floor(ring / 9.0) * 1.7) * 9821.13, 1.0)
	c = c * (0.82 + hsh * 0.18) * (0.75 if streak > 0.85 else 1.0)
	if ring % 16 == 0 or ring % 16 == 1:
		c = c * 0.6
	c.a = 1.0
	return c


# ================================================================ pipe + water
## mats: Dictionary of zone material key -> Material
func build_pipe(parent: Node3D, holes: Array, length: float, mats: Dictionary, water_mat: Material) -> void:
	var rings := int(length / RING) + 1
	var per := 24
	var c0 := 0
	while c0 < rings - 1:
		var c1 := mini(c0 + per, rings - 1)
		_pipe_chunk(parent, c0, c1, holes, mats, water_mat)
		c0 = c1


func _pipe_chunk(parent: Node3D, c0: int, c1: int, holes: Array, mats: Dictionary, water_mat: Material) -> void:
	var groups := {}   # material key -> [v, n, uv, col]
	var wv := PackedVector3Array()
	var wn := PackedVector3Array()
	var wuv := PackedVector2Array()
	var wc := PackedColorArray()
	var frames := []
	var ps := []
	for i in range(c0, c1 + 1):
		frames.append(frame(i * RING))
		ps.append(params(i * RING))
	for i in range(c1 - c0):
		var ring := c0 + i
		var sA := ring * RING
		var sB := sA + RING
		var sm := sA + RING * 0.5
		if in_planks(sm):
			continue
		var fA: Array = frames[i]
		var fB: Array = frames[i + 1]
		var pA: Vector2 = ps[i]
		var pB: Vector2 = ps[i + 1]
		var open := in_chamber(sm)
		var shell := open or near_open_end(sm)
		var key := mat_at(sm)
		if not groups.has(key):
			groups[key] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray()]
		var g: Array = groups[key]
		var ywA := water_y(pA.x, pA.y)
		for j in SIDES:
			var a0 := (j + 0.5) * DA - PI
			var a1 := a0 + DA
			var m := a0 + DA * 0.5
			if open and absf(m) > OPEN_EDGE:
				continue
			if _in_holes(holes, sm, m):
				continue
			var dA0 := radial(fA, a0)
			var dA1 := radial(fA, a1)
			var dB0 := radial(fB, a0)
			var dB1 := radial(fB, a1)
			var u0 := float(j) / SIDES * 8.0
			var u1 := float(j + 1) / SIDES * 8.0
			var uvs := [Vector2(u0, sA * K / 5.0), Vector2(u1, sA * K / 5.0), Vector2(u1, sB * K / 5.0), Vector2(u0, sB * K / 5.0)]
			var rA0 := wall_rt(a0, pA.x, pA.y)
			var rA1 := wall_rt(a1, pA.x, pA.y)
			var rB0 := wall_rt(a0, pB.x, pB.y)
			var rB1 := wall_rt(a1, pB.x, pB.y)
			var under := cos(a0) * rA0 > ywA + 0.02 and cos(a1) * rA1 > ywA + 0.02
			if not under:
				var p := [fA[0] + dA0 * (rA0 * K), fA[0] + dA1 * (rA1 * K), fB[0] + dB1 * (rB1 * K), fB[0] + dB0 * (rB0 * K)]
				_add_quad(g[0], g[1], g[2], g[3], p, _face_normal(p, fA[0]), uvs, _grime(m, ring, j))
			if shell:
				var q := [fA[0] + dA0 * (rA0 * K * 1.12), fA[0] + dA1 * (rA1 * K * 1.12), fB[0] + dB1 * (rB1 * K * 1.12), fB[0] + dB0 * (rB0 * K * 1.12)]
				var on := -_face_normal(q, fA[0])
				_add_quad(g[0], g[1], g[2], g[3], q, on, uvs, Color(0.5, 0.48, 0.45))
		if open:
			for sg in [-1.0, 1.0]:
				var ae: float = sg * OPEN_EDGE
				if _in_holes(holes, sm, ae * 0.95):
					continue
				var p2 := [fA[0] + radial(fA, ae) * K, fA[0] + radial(fA, ae) * (K * 1.12),
					fB[0] + radial(fB, ae) * (K * 1.12), fB[0] + radial(fB, ae) * K]
				var rn: Vector3 = (fA[2] * cos(ae) + fA[3] * sin(ae)) * sg
				_add_quad(g[0], g[1], g[2], g[3], p2, rn, [Vector2(0, sA), Vector2(0.3, sA), Vector2(0.3, sB), Vector2(0, sB)], Color(0.8, 0.78, 0.72))
		if not _in_holes(holes, sm, 0.0):
			var xa := water_x(pA.x, pA.y)
			var xb := water_x(pB.x, pB.y)
			var yb := water_y(pB.x, pB.y)
			var pA0: Vector3 = fA[0] + (fA[2] * -xa - fA[3] * ywA) * K
			var pA1: Vector3 = fA[0] + (fA[2] * xa - fA[3] * ywA) * K
			var pB0: Vector3 = fB[0] + (fB[2] * -xb - fB[3] * yb) * K
			var pB1: Vector3 = fB[0] + (fB[2] * xb - fB[3] * yb) * K
			var wuvs := [Vector2(0, sA * K / 6.0), Vector2(1, sA * K / 6.0), Vector2(1, sB * K / 6.0), Vector2(0, sB * K / 6.0)]
			_add_quad(wv, wn, wuv, wc, [pA0, pA1, pB1, pB0], fA[3], wuvs, Color.WHITE)
	for key in groups.keys():
		var g2: Array = groups[key]
		if g2[0].size() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh_from(g2[0], g2[1], g2[2], g2[3])
		mi.material_override = mats.get(key, mats["brick"])
		parent.add_child(mi)
	if wv.size() > 0:
		var wi := MeshInstance3D.new()
		wi.mesh = _mesh_from(wv, wn, wuv, wc)
		wi.material_override = water_mat
		wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(wi)


## Thick lip around an open pipe end (where a deck starts or ends)
func mouth(parent: Node3D, s: float, mat: Material, facing_back: bool) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var f := frame(s)
	var p := params(s - 0.3 if not facing_back else s + 0.3)
	var nn: Vector3 = -f[1] if facing_back else f[1]
	for j in SIDES:
		var a0 := (j + 0.5) * DA - PI
		var a1 := a0 + DA
		var r0 := wall_rt(a0, p.x, p.y)
		var r1 := wall_rt(a1, p.x, p.y)
		var q := [f[0] + radial(f, a0) * (r0 * K), f[0] + radial(f, a1) * (r1 * K),
			f[0] + radial(f, a1) * (r1 * K * 1.12), f[0] + radial(f, a0) * (r0 * K * 1.12)]
		_add_quad(v, n, uv, col, q, nn, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.2), Vector2(0, 0.2)], Color(0.6, 0.6, 0.6))
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_from(v, n, uv, col)
	mi.material_override = mat
	parent.add_child(mi)


# ================================================================ blocks
## Extruded arc block on the pipe wall. Radii in tube units (1 = wall).
## With follow = true the radii are measured from the actual surface/wall at that spot.
func arc_block(s0: float, s1: float, c: float, w: float, r_in: float, r_out: float, mat: Material, faces := "all", follow := false) -> MeshInstance3D:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var segs := maxi(2, int(ceil(2.0 * w / 0.2)))
	var f0 := frame(s0)
	var f1 := frame(s1)
	var white := Color.WHITE
	var depth := (r_out - r_in) * K
	var lenw := (s1 - s0) * K
	for k in segs:
		var a0 := c - w + 2.0 * w * k / segs
		var a1 := c - w + 2.0 * w * (k + 1) / segs
		var am := (a0 + a1) * 0.5
		var arc0 := (a0 - c + w) * K
		var arc1 := (a1 - c + w) * K
		var ri0 := (minf(sr(s0, a0), 1.5) - (1.0 - r_in)) if follow else r_in
		var ri1 := (minf(sr(s0, a1), 1.5) - (1.0 - r_in)) if follow else r_in
		var ro0 := (wall_r(s0, a0) + r_out - 1.0) if follow else r_out
		var ro1 := (wall_r(s0, a1) + r_out - 1.0) if follow else r_out
		var i00: Vector3 = f0[0] + radial(f0, a0) * (ri0 * K)
		var i01: Vector3 = f0[0] + radial(f0, a1) * (ri1 * K)
		var i10: Vector3 = f1[0] + radial(f1, a0) * (ri0 * K)
		var i11: Vector3 = f1[0] + radial(f1, a1) * (ri1 * K)
		var o00: Vector3 = f0[0] + radial(f0, a0) * (ro0 * K)
		var o01: Vector3 = f0[0] + radial(f0, a1) * (ro1 * K)
		var o10: Vector3 = f1[0] + radial(f1, a0) * (ro0 * K)
		var o11: Vector3 = f1[0] + radial(f1, a1) * (ro1 * K)
		_add_quad(v, n, uv, col, [i00, i01, i11, i10], -radial(f0, am),
			[Vector2(arc0, 0) / 2.0, Vector2(arc1, 0) / 2.0, Vector2(arc1, lenw) / 2.0, Vector2(arc0, lenw) / 2.0], white)
		if faces == "all":
			_add_quad(v, n, uv, col, [o00, o01, i01, i00], -f0[1],
				[Vector2(arc0, 0) / 2.0, Vector2(arc1, 0) / 2.0, Vector2(arc1, depth) / 2.0, Vector2(arc0, depth) / 2.0], white)
			_add_quad(v, n, uv, col, [o10, o11, i11, i10], f1[1],
				[Vector2(arc0, 0) / 2.0, Vector2(arc1, 0) / 2.0, Vector2(arc1, depth) / 2.0, Vector2(arc0, depth) / 2.0], white.darkened(0.3))
		if w < 3.1 and (k == 0 or k == segs - 1):
			var ae := a0 if k == 0 else a1
			var sgn := -1.0 if k == 0 else 1.0
			var tn: Vector3 = (f0[2] * cos(ae) + f0[3] * sin(ae)) * sgn
			var rie := (minf(sr(s0, ae), 1.5) - (1.0 - r_in)) if follow else r_in
			var roe := (wall_r(s0, ae) + r_out - 1.0) if follow else r_out
			var e0: Vector3 = f0[0] + radial(f0, ae) * (rie * K)
			var e1: Vector3 = f0[0] + radial(f0, ae) * (roe * K)
			var e2: Vector3 = f1[0] + radial(f1, ae) * (roe * K)
			var e3: Vector3 = f1[0] + radial(f1, ae) * (rie * K)
			_add_quad(v, n, uv, col, [e0, e1, e2, e3], tn,
				[Vector2(0, 0), Vector2(depth, 0) / 2.0, Vector2(depth, lenw) / 2.0, Vector2(0, lenw) / 2.0], white.darkened(0.15))
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_from(v, n, uv, col)
	mi.material_override = mat
	return mi


## Flat strip lying on the riding surface (boost pads, slime, hazard paint).
## rise > 0 tilts it up into a ramp that reaches `rise` above the surface at s1.
func floor_strip(s0: float, s1: float, c: float, w: float, lift: float, mat: Material, rise := 0.0) -> MeshInstance3D:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var steps := 6
	var across := maxi(1, int(ceil(2.0 * w / 0.2)))
	for i in steps:
		var ta := float(i) / steps
		var tb := float(i + 1) / steps
		var sa := lerpf(s0, s1, ta)
		var sb := lerpf(s0, s1, tb)
		var fa := frame(sa)
		var fb := frame(sb)
		for k in across:
			var aL := c - w + 2.0 * w * k / across
			var aR := c - w + 2.0 * w * (k + 1) / across
			var p := []
			for q in [[fa, aL, sa, ta], [fa, aR, sa, ta], [fb, aR, sb, tb], [fb, aL, sb, tb]]:
				var ff: Array = q[0]
				var aa: float = q[1]
				p.append(ff[0] + radial(ff, aa) * ((minf(sr(q[2], aa), 1.5) - lift - rise * q[3]) * K))
			var uL := float(k) / across
			var uR := float(k + 1) / across
			_add_quad(v, n, uv, col, p, _face_normal(p, fa[0]),
				[Vector2(uL, ta), Vector2(uR, ta), Vector2(uR, tb), Vector2(uL, tb)], Color.WHITE)
	if rise > 0.0:   # vertical lip at the end of a ramp
		var fe := frame(s1)
		for k in across:
			var aL2 := c - w + 2.0 * w * k / across
			var aR2 := c - w + 2.0 * w * (k + 1) / across
			var p3 := [fe[0] + radial(fe, aL2) * (sr(s1, aL2) * K), fe[0] + radial(fe, aR2) * (sr(s1, aR2) * K),
				fe[0] + radial(fe, aR2) * ((sr(s1, aR2) - rise) * K), fe[0] + radial(fe, aL2) * ((sr(s1, aL2) - rise) * K)]
			_add_quad(v, n, uv, col, p3, fe[1], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.2), Vector2(0, 0.2)], Color(0.6, 0.6, 0.6))
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_from(v, n, uv, col)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Generic tube following the track (hall vaults, side pipes, ribs). Offsets/radius in tube units.
func tube(parent: Node3D, s0: float, s1: float, step: float, radius: float, sides: int,
		off_r: float, off_u: float, mat: Material, inward: bool, uv_a := 6.0, uv_s := 0.1) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var rings := maxi(1, int(ceil((s1 - s0) / step)))
	var prev := []
	for i in rings + 1:
		var s := minf(s0 + i * step, s1)
		var f := frame(s)
		var c: Vector3 = f[0] + (f[2] * off_r + f[3] * off_u) * K
		var ring := []
		for j in sides + 1:
			var a := TAU * j / sides
			ring.append([c + radial(f, a) * (radius * K), radial(f, a), s])
		if i > 0:
			for j in sides:
				var am := TAU * (j + 0.5) / sides
				var dir: Vector3 = (prev[j][1] + prev[j + 1][1]).normalized()
				var shade := 0.55 + 0.45 * clampf(cos(am) * 0.5 + 0.5, 0.0, 1.0)
				var cc := Color(shade, shade, shade)
				var sa: float = prev[j][2]
				var sb: float = ring[j][2]
				_add_quad(v, n, uv, col, [prev[j][0], prev[j + 1][0], ring[j + 1][0], ring[j][0]],
					-dir if inward else dir,
					[Vector2(float(j) / sides * uv_a, sa * K * uv_s), Vector2(float(j + 1) / sides * uv_a, sa * K * uv_s),
					 Vector2(float(j + 1) / sides * uv_a, sb * K * uv_s), Vector2(float(j) / sides * uv_a, sb * K * uv_s)], cc)
		prev = ring
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_from(v, n, uv, col)
	mi.material_override = mat
	parent.add_child(mi)


## Flat annulus closing a hall's end wall around the pipe.
func cap(parent: Node3D, s: float, mat: Material, facing_back: bool) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var f := frame(s)
	var ci: Vector3 = f[0]
	var co: Vector3 = f[0] + f[3] * (HALL_UP * K)
	var sides := 24
	var nn: Vector3 = -f[1] if facing_back else f[1]
	for j in sides:
		var a0 := TAU * j / sides
		var a1 := TAU * (j + 1) / sides
		var p := [ci + radial(f, a0) * (1.12 * K), ci + radial(f, a1) * (1.12 * K), co + radial(f, a1) * (HALL_R * K), co + radial(f, a0) * (HALL_R * K)]
		var uvs := []
		for q in p:
			var d: Vector3 = q - f[0]
			uvs.append(Vector2(d.dot(f[2]), d.dot(f[3])) / 5.0)
		_add_quad(v, n, uv, col, p, nn, uvs, Color(0.7, 0.7, 0.7))
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_from(v, n, uv, col)
	mi.material_override = mat
	parent.add_child(mi)


## Flat strip following the track at a height (river, walkways, decks). x/y in tube units.
func ribbon(parent: Node3D, s0: float, s1: float, xa: float, xb: float, y: float, mat: Material, uv_s := 0.166, up := true) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var step := 1.0
	var s := s0
	while s < s1 - 0.001:
		var sb := minf(s + step, s1)
		var fa := frame(s)
		var fb := frame(sb)
		var p := [fa[0] + (fa[2] * xa + fa[3] * y) * K, fa[0] + (fa[2] * xb + fa[3] * y) * K,
			fb[0] + (fb[2] * xb + fb[3] * y) * K, fb[0] + (fb[2] * xa + fb[3] * y) * K]
		_add_quad(v, n, uv, col, p, fa[3] if up else -fa[3],
			[Vector2(0, s * K * uv_s), Vector2(1, s * K * uv_s), Vector2(1, sb * K * uv_s), Vector2(0, sb * K * uv_s)], Color.WHITE)
		s = sb
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_from(v, n, uv, col)
	mi.material_override = mat
	parent.add_child(mi)


## Basis aligned to the track: +X right, +Y up, -Z forward.
func track_basis(s: float) -> Basis:
	var f := frame(s)
	return Basis(f[2], f[3], -f[1])


## Basis whose +Y points from the wall toward the pipe centre and -Z points forward.
func wall_basis(s: float, a: float) -> Basis:
	var f := frame(s)
	var y: Vector3 = -radial(f, a)
	var z: Vector3 = -f[1]
	var x := y.cross(z).normalized()
	z = x.cross(y).normalized()
	return Basis(x, y, z)
