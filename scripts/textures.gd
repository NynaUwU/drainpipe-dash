extends RefCounted
## Procedural low-res textures (no image files needed). Everything tiles seamlessly.

const S := 128


static func _noise(seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	return n


## seamless noise in 0..1 by blending four offset samples
static func _tn(n: FastNoiseLite, x: float, y: float) -> float:
	var fx := x / S
	var fy := y / S
	var a := n.get_noise_2d(x, y)
	var b := n.get_noise_2d(x - S, y)
	var c := n.get_noise_2d(x, y - S)
	var d := n.get_noise_2d(x - S, y - S)
	var v := a * (1.0 - fx) * (1.0 - fy) + b * fx * (1.0 - fy) + c * (1.0 - fx) * fy + d * fx * fy
	return clampf(v * 0.7 + 0.5, 0.0, 1.0)


static func _hash(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)


static func _tex(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _normal_from_height(h: PackedFloat32Array, strength: float) -> ImageTexture:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		for x in S:
			var l := h[y * S + (x + S - 1) % S]
			var r := h[y * S + (x + 1) % S]
			var u := h[((y + S - 1) % S) * S + x]
			var d := h[((y + 1) % S) * S + x]
			var nv := Vector3((l - r) * strength, (u - d) * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
	return _tex(img)


## Old sewer brick. Returns [albedo, normal, roughness]
static func brick(seed: int) -> Array:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var rough := Image.create(S, S, false, Image.FORMAT_L8)
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	var n := _noise(seed, 0.05)
	var n2 := _noise(seed + 9, 0.22)
	for y in S:
		var row := y / 16
		var off := (row % 2) * 16
		for x in S:
			var bx := (x + off) % 32
			var by := y % 16
			var mortar := bx < 2 or by < 2
			var bid := ((x + off) / 32) % 4 + row * 5
			var g := _tn(n, x, y)
			var g2 := _tn(n2, x, y)
			var c: Color
			var h := 0.0
			if mortar:
				c = Color(0.22, 0.21, 0.18) * (0.7 + g * 0.5)
				h = 0.0
			else:
				var v := 0.75 + _hash(bid) * 0.35
				c = Color(0.55, 0.42, 0.33).lerp(Color(0.45, 0.45, 0.42), _hash(bid + 77)) * v
				c = c * (0.65 + g * 0.55) * (0.85 + g2 * 0.25)
				h = 0.6 + g2 * 0.4
				if bx < 4 or by < 4 or bx > 29 or by > 13:
					h *= 0.8
			# dark wet stains
			if g < 0.3:
				c = c.darkened(0.35)
			c.a = 1.0
			img.set_pixel(x, y, c)
			hgt[y * S + x] = h
			var rv := 0.35 if mortar else 0.55 + g2 * 0.3
			if g < 0.3:
				rv *= 0.5
			rough.set_pixel(x, y, Color(rv, rv, rv))
	return [_tex(img), _normal_from_height(hgt, 2.5), _tex(rough)]


## Rusty riveted steel plates
static func rust(seed: int, base := Color(0.42, 0.44, 0.45), stain := Color(0.55, 0.26, 0.10), amount := 0.5) -> Array:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	var n := _noise(seed, 0.04)
	var n2 := _noise(seed + 3, 0.18)
	for y in S:
		for x in S:
			var g := _tn(n, x, y)
			var g2 := _tn(n2, x, y)
			var steel := base * (0.8 + g2 * 0.3)
			var rst := stain.lerp(stain.darkened(0.45), g2)
			var t := smoothstep(0.92 - amount, 1.12 - amount, g)
			var c := steel.lerp(rst, t)
			var h := 0.5 + g2 * 0.2 - t * 0.15
			var seam := (y % 64) < 2 or (x % 64) < 2
			if seam:
				c = c.darkened(0.5)
				h = 0.1
			var rx := x % 32
			var ry := y % 64
			if (rx - 16) * (rx - 16) + (ry - 7) * (ry - 7) < 7:
				c = c.lightened(0.15)
				h = 1.0
			c.a = 1.0
			img.set_pixel(x, y, c)
			hgt[y * S + x] = h
	return [_tex(img), _normal_from_height(hgt, 3.0)]


## Poured concrete for the square culverts: formwork seams, tie holes, drip stains.
static func concrete(seed: int) -> Array:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	var n := _noise(seed, 0.07)
	var streak := _noise(seed + 5, 0.03)
	for y in S:
		for x in S:
			var g := _tn(n, x, y)
			var st := _tn(streak, x, y * 0.12)
			var v := 0.5 + g * 0.3
			var h := 0.5 + g * 0.3
			if y % 64 < 2 or x % 128 < 2:
				v *= 0.55
				h = 0.1
			var tx := x % 64 - 32
			var ty := y % 64 - 32
			if tx * tx + ty * ty < 5:
				v *= 0.4
				h = 0.0
			if st < 0.35:
				v *= 0.7
			var c := Color(v, v * 0.98, v * 0.93)
			img.set_pixel(x, y, c)
			hgt[y * S + x] = h
	return [_tex(img), _normal_from_height(hgt, 2.0)]


## Weathered wooden boards (seams run across the texture's V axis). Returns [albedo, normal]
static func wood(seed: int, tint := Color(0.5, 0.36, 0.22)) -> Array:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	var grain := _noise(seed, 0.02)
	grain.frequency = 0.03
	var n2 := _noise(seed + 7, 0.12)
	for y in S:
		var board := y / 16
		var bt := 0.8 + _hash(board + seed) * 0.35
		for x in S:
			var g := _tn(grain, x * 0.25, y * 4.0)
			var g2 := _tn(n2, x, y)
			var c := tint * bt * (0.7 + g * 0.5) * (0.85 + g2 * 0.25)
			var h := 0.6 + g * 0.3
			if y % 16 < 2:
				c = c * 0.35
				h = 0.0
			var nx := (x + board * 23) % 64
			if (nx - 6) * (nx - 6) + (y % 16 - 8) * (y % 16 - 8) < 3:
				c = Color(0.15, 0.14, 0.13)
				h = 0.9
			c.a = 1.0
			img.set_pixel(x, y, c)
			hgt[y * S + x] = h
	return [_tex(img), _normal_from_height(hgt, 2.0)]


## Shipping crate: boards with a dark frame and a diagonal brace
static func crate(seed: int) -> ImageTexture:
	var w := wood(seed, Color(0.55, 0.42, 0.26))
	var img: Image = w[0].get_image()
	img.decompress()
	if img.has_mipmaps():
		img.clear_mipmaps()
	for y in S:
		for x in S:
			var frame := x < 12 or x > S - 13 or y < 12 or y > S - 13
			var brace := absf(float(x) - float(y)) < 8.0
			if frame or brace:
				var c := img.get_pixel(x, y) * 0.75
				c.a = 1.0
				img.set_pixel(x, y, c)
			if frame and (x % 40 == 6 or y % 40 == 6) and (x < 12 or x > S - 13) != (y < 12 or y > S - 13):
				img.set_pixel(x, y, Color(0.2, 0.2, 0.2))
	return _tex(img)


## Night-city facade: dark walls with a few lit windows
static func windows(seed: int) -> ImageTexture:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		for x in S:
			var c := Color(0.025, 0.03, 0.045)
			if x % 16 >= 4 and x % 16 < 12 and y % 16 >= 4 and y % 16 < 13:
				var hs := _hash((x / 16) * 31 + (y / 16) * 7 + seed)
				if hs > 0.72:
					c = Color(1.0, 0.82, 0.5) * (0.6 + hs * 0.4)
				else:
					c = Color(0.05, 0.06, 0.08)
			img.set_pixel(x, y, c)
	return _tex(img)


## Yellow/black hazard stripes with grime
static func hazard(seed: int) -> ImageTexture:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var n := _noise(seed, 0.06)
	for y in S:
		for x in S:
			var g := _tn(n, x, y)
			var stripe := ((x + y) % 64) < 32
			var c := Color(0.95, 0.72, 0.08) if stripe else Color(0.07, 0.07, 0.07)
			c = c * (0.6 + g * 0.5)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return _tex(img)


static func checker() -> ImageTexture:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		for x in S:
			var on := ((x / 32) + (y / 32)) % 2 == 0
			img.set_pixel(x, y, Color(0.95, 0.95, 0.92) if on else Color(0.05, 0.05, 0.06))
	return _tex(img)


static func grate() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var bar := (x % 16) < 4 or (y % 32) < 3
			img.set_pixel(x, y, Color(0.12, 0.12, 0.12, 1.0) if bar else Color(0, 0, 0, 0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func water_normal() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.02
	n.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 6.0
	t.noise = n
	return t
