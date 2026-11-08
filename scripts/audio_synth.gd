extends RefCounted
## Synthesises every sound effect at startup (no audio files needed).

const RATE := 22050


static func _wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


static func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


static func _normalize(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	for i in b.size():
		b[i] = b[i] / m * peak
	return b


## crossfade the tail into the head so the loop is seamless
static func _loopify(b: PackedFloat32Array, fade_sec: float) -> PackedFloat32Array:
	var f := int(fade_sec * RATE)
	var out := b.slice(f)
	var n := out.size()
	for i in f:
		var t := float(i) / f
		out[n - f + i] = out[n - f + i] * (1.0 - t) + b[i] * t
	return out


static func make_all() -> Dictionary:
	var d := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234

	# rushing water loop (brown noise)
	var b := _buf(2.4)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		lp = lp * 0.97 + rng.randf_range(-1.0, 1.0) * 0.03
		lp2 = lp2 * 0.6 + rng.randf_range(-1.0, 1.0) * 0.4
		b[i] = lp * 4.0 + lp2 * 0.12
	d["rush"] = _wav(_normalize(_loopify(b, 0.3), 0.8), true)

	# low sewer drone with a slow beat + rumble
	b = _buf(4.0)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lp * 0.995 + rng.randf_range(-1.0, 1.0) * 0.005
		b[i] = sin(TAU * 55.0 * t) * 0.35 + sin(TAU * 55.75 * t) * 0.3 + sin(TAU * 82.5 * t) * 0.12 + sin(TAU * 27.5 * t) * 0.3 + lp * 6.0
	d["drone"] = _wav(_normalize(_loopify(b, 0.4), 0.7), true)

	# pouring water loop (outflow pipes)
	b = _buf(1.6)
	lp = 0.0
	var am := 0.0
	for i in b.size():
		lp = lp * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45
		if i % 300 == 0:
			am = rng.randf_range(0.5, 1.0)
		b[i] = lp * am
	d["pour"] = _wav(_normalize(_loopify(b, 0.2), 0.6), true)

	# drip "plink"
	b = _buf(0.4)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 600.0 + 1500.0 * exp(-t * 9.0)
		ph += TAU * f / RATE
		b[i] = sin(ph) * exp(-t * 16.0)
	d["drip"] = _wav(_normalize(b, 0.8), false)

	# coin
	b = _buf(0.3)
	for i in b.size():
		var t := float(i) / RATE
		var f := 1320.0 if t < 0.07 else 1760.0
		var s := sin(TAU * f * t)
		b[i] = (s + 0.4 * signf(s)) * exp(-t * (30.0 if t < 0.07 else 9.0)) * 0.7
	d["coin"] = _wav(_normalize(b, 0.7), false)

	# jump
	b = _buf(0.25)
	ph = 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(260.0, 720.0, t / 0.25) / RATE
		b[i] = sin(ph) * (1.0 - t / 0.25)
	d["jump"] = _wav(_normalize(b, 0.6), false)

	# splash / land
	b = _buf(0.4)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lp * 0.4 + rng.randf_range(-1.0, 1.0) * 0.6
		b[i] = lp * exp(-t * 9.0)
	d["splash"] = _wav(_normalize(b, 0.7), false)

	# metal clang (hit)
	b = _buf(1.3)
	var parts := [[170.0, 1.0, 3.0], [433.0, 0.7, 4.0], [701.0, 0.5, 5.5], [1093.0, 0.35, 7.0], [1577.0, 0.25, 9.0]]
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for p in parts:
			v += sin(TAU * p[0] * t) * p[1] * exp(-t * p[2])
		if t < 0.03:
			v += rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.03) * 1.5
		b[i] = v
	d["clang"] = _wav(_normalize(b, 0.85), false)

	# boost whoosh
	b = _buf(0.8)
	lp = 0.0
	ph = 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := lerpf(0.05, 0.6, t / 0.8)
		lp = lp * (1.0 - k) + rng.randf_range(-1.0, 1.0) * k
		ph += TAU * lerpf(180.0, 900.0, t / 0.8) / RATE
		b[i] = (lp * 0.8 + sin(ph) * 0.25) * sin(PI * t / 0.8)
	d["boost"] = _wav(_normalize(b, 0.7), false)

	# falling
	b = _buf(1.1)
	ph = 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (620.0 * exp(-t * 2.2) + 60.0 + sin(t * 40.0) * 15.0) / RATE
		b[i] = sin(ph) * (1.0 - t / 1.1)
	d["fall"] = _wav(_normalize(b, 0.6), false)

	# beeps
	for name in ["beep", "go"]:
		var dur := 0.14 if name == "beep" else 0.45
		var fr := 660.0 if name == "beep" else 1320.0
		b = _buf(dur)
		for i in b.size():
			var t := float(i) / RATE
			var s := sin(TAU * fr * t)
			b[i] = (s * 0.7 + signf(s) * 0.3) * (1.0 - t / dur)
		d[name] = _wav(_normalize(b, 0.5), false)

	# finish fanfare
	b = _buf(1.2)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for n in 4:
			var st := n * 0.13
			if t >= st:
				var tt := t - st
				var s := sin(TAU * notes[n] * tt)
				v += (s * 0.6 + signf(s) * 0.2) * exp(-tt * (2.0 if n == 3 else 7.0))
		b[i] = v
	d["finish"] = _wav(_normalize(b, 0.6), false)

	# game over
	b = _buf(1.4)
	var dn := [392.0, 329.6, 261.6, 196.0]
	for i in b.size():
		var t := float(i) / RATE
		var n := mini(3, int(t / 0.22))
		var tt := t - n * 0.22
		b[i] = sin(TAU * dn[n] * tt) * exp(-tt * (1.5 if n == 3 else 5.0))
	d["over"] = _wav(_normalize(b, 0.6), false)

	# distant pipe groan
	b = _buf(2.6)
	ph = 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 48.0 - t * 4.0 + sin(t * 7.0) * 2.0
		ph += TAU * f / RATE
		b[i] = (sin(ph) + 0.5 * sin(ph * 2.01) + 0.25 * sin(ph * 3.03)) * sin(PI * t / 2.6)
	d["groan"] = _wav(_normalize(b, 0.7), false)

	# big extraction fan hum (loop)
	b = _buf(2.0)
	for i in b.size():
		var t := float(i) / RATE
		var saw := fposmod(t * 50.0, 1.0) * 2.0 - 1.0
		b[i] = (saw * 0.4 + sin(TAU * 100.0 * t) * 0.3 + sin(TAU * 150.0 * t) * 0.15) * (0.75 + 0.25 * sin(TAU * 3.0 * t))
	d["hum"] = _wav(_normalize(b, 0.6), true)

	# pipe leak hiss (loop)
	b = _buf(1.6)
	lp = 0.0
	for i in b.size():
		var w := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.8 + w * 0.2
		b[i] = (w - lp) * (0.8 + 0.2 * sin(float(i) / RATE * 23.0))
	d["hiss"] = _wav(_normalize(_loopify(b, 0.2), 0.5), true)

	# appliance rumble from the kitchen overhead (loop)
	b = _buf(4.0)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lp * 0.996 + rng.randf_range(-1.0, 1.0) * 0.004
		b[i] = lp * 9.0 + sin(TAU * 31.25 * t) * 0.35 + sin(TAU * 62.5 * t) * 0.12 * (0.5 + 0.5 * sin(TAU * 0.5 * t))
	d["rumble"] = _wav(_normalize(_loopify(b, 0.4), 0.75), true)

	# night wind over the walkways (loop)
	b = _buf(3.0)
	lp = 0.0
	lp2 = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lp * 0.9 + rng.randf_range(-1.0, 1.0) * 0.1
		lp2 = lp2 * 0.995 + lp * 0.005
		b[i] = (lp - lp2) * (0.6 + 0.4 * sin(TAU * t / 3.0))
	d["wind_loop"] = _wav(_normalize(_loopify(b, 0.4), 0.55), true)

	# heavy thump (appliance above / deck landing)
	b = _buf(0.7)
	ph = 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (70.0 * exp(-t * 4.0) + 35.0) / RATE
		b[i] = sin(ph) * exp(-t * 6.0) + (rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.5)
	d["thump"] = _wav(_normalize(b, 0.8), false)

	# slime squelch
	b = _buf(0.35)
	lp = 0.0
	ph = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lp * 0.7 + rng.randf_range(-1.0, 1.0) * 0.3
		ph += TAU * (160.0 - t * 200.0 + sin(t * 90.0) * 30.0) / RATE
		b[i] = (lp * 0.6 + sin(ph) * 0.5) * sin(PI * t / 0.35)
	d["squelch"] = _wav(_normalize(b, 0.7), false)

	# wooden creak
	b = _buf(0.8)
	ph = 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (190.0 - t * 50.0 + sin(t * 31.0) * 12.0) / RATE
		var saw := fposmod(ph / TAU, 1.0) * 2.0 - 1.0
		b[i] = saw * (0.5 + 0.5 * signf(sin(t * 140.0))) * sin(PI * t / 0.8)
	d["creak"] = _wav(_normalize(b, 0.5), false)

	# water gusher burst
	b = _buf(1.0)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lp * 0.3 + rng.randf_range(-1.0, 1.0) * 0.7
		b[i] = lp * minf(1.0, t * 20.0) * exp(-t * 2.0)
	d["gush"] = _wav(_normalize(b, 0.8), false)
	return d
