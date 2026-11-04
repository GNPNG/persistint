class_name DollComposer
extends RefCounted
## Deterministic CPU composition and pixel diagnostics; no scene or renderer required.

static func rgba(image: Image) -> Image:
	var copy := image.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8)
	return copy

static func compose(layers: Array, size: Vector2i) -> Image:
	var output := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	for image: Image in layers:
		assert(image.get_size() == size, "Doll layer dimensions differ")
		output.blend_rect(image, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	return output

static func pixel_report(image: Image, slot: String, skin: Array, limits: Dictionary) -> Dictionary:
	var data := rgba(image).get_data()
	var w := image.get_width()
	var h := image.get_height()
	var area := 0
	var border := 0
	var ring := 0
	var light := 0
	var green := 0
	var skin_pixels := 0
	var levels: Dictionary = {}
	var garments := slot in ["top", "bottom", "dress", "shoes"]
	var tolerance2 := pow(float(limits.skin_rgb_distance), 2)
	for y in h:
		for x in w:
			var i := (y * w + x) * 4
			var a := int(data[i + 3])
			if a == 0:
				if x > 0 and y > 0 and x < w - 1 and y < h - 1 and (data[i - 1] > 127 or data[i + 7] > 127 or data[i - w * 4 + 3] > 127 or data[i + w * 4 + 3] > 127):
					levels[0] = true
				continue
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				border += 1
			if a > 25 and int(data[i + 1]) - maxi(data[i], data[i + 2]) > int(limits.green_excess):
				green += 1
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
			if not edge:
				edge = data[i - 4 + 3] <= 127 or data[i + 4 + 3] <= 127 or data[i - w * 4 + 3] <= 127 or data[i + w * 4 + 3] <= 127
			if a < 255 or edge:
				levels[a] = true
			if a <= 127:
				continue
			area += 1
			if edge:
				ring += 1
				if 0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2] > 255.0 * float(limits.light_threshold):
					light += 1
			if garments:
				for color: Array in skin:
					var distance := pow(float(data[i]) - float(color[0]), 2) + pow(float(data[i + 1]) - float(color[1]), 2) + pow(float(data[i + 2]) - float(color[2]), 2)
					if distance <= tolerance2:
						skin_pixels += 1
						break
	var fringe := float(light) / maxi(ring, 1)
	var skin_share := float(skin_pixels) / maxi(area, 1)
	var failures: Array[String] = []
	if border > 0:
		failures.append("frame_border")
	if levels.size() < int(limits.minimum_boundary_alpha_levels):
		failures.append("boundary_alpha_levels")
	if fringe > float(limits.maximum_fringe_ratio):
		failures.append("fringe")
	if green > 0:
		failures.append("green_residue")
	if garments and skin_share > float(limits.maximum_skin_share):
		failures.append("skin_leak")
	return {"failures": failures, "opaque_area": area, "border_pixels": border, "boundary_alpha_levels": levels.size(), "outline_ring": ring, "light_ring": light, "fringe_ratio": fringe, "skin_share": skin_share, "green_pixels": green}

static func stray_report(image: Image, limits: Dictionary) -> Array:
	var data := rgba(image).get_data()
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var queue := PackedInt32Array()
	queue.resize(w * h)
	var parts: Array = []
	var total := 0
	for seed in w * h:
		if seen[seed] or data[seed * 4 + 3] <= 127:
			continue
		var head := 0
		var tail := 1
		queue[0] = seed
		seen[seed] = 1
		var points := PackedVector2Array()
		while head < tail:
			var p := queue[head]
			head += 1
			var x := p % w
			var y := p / w
			points.append(Vector2(x, y))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var yy := y + dy
					var q := yy * w + xx
					if xx >= 0 and yy >= 0 and xx < w and yy < h and not seen[q] and data[q * 4 + 3] > 127:
						seen[q] = 1
						queue[tail] = q
						tail += 1
		parts.append(points)
		total += tail
	var failures: Array = []
	for i in parts.size():
		if parts[i].size() >= total * float(limits.minimum_component_share):
			continue
		var near := false
		for j in parts.size():
			if i == j or parts[j].size() < total * float(limits.minimum_component_share):
				continue
			for a: Vector2 in parts[i]:
				for b: Vector2 in parts[j]:
					if a.distance_squared_to(b) <= pow(float(limits.maximum_stray_gap), 2):
						near = true
						break
				if near:
					break
			if near:
				break
		if not near:
			failures.append({"component": i, "area": parts[i].size()})
	return failures

static func region_report(image: Image, regions: Image, body: Image, rule: Dictionary, labels: Dictionary, limits: Dictionary, front_mask: Image = null) -> Dictionary:
	var size := Vector2i((image.get_width() + 1) / 2, (image.get_height() + 1) / 2)
	var item := rgba(image)
	var map := rgba(regions)
	var base := rgba(body)
	item.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	map.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	base.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var a := item.get_data()
	var r := map.get_data()
	var b := base.get_data()
	var allowed := PackedByteArray()
	if front_mask != null:
		var mask := rgba(front_mask)
		mask.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
		allowed = mask.get_data()
	var totals: Dictionary = {}
	var covered: Dictionary = {}
	var forbidden: Dictionary = {}
	var front_overlap: Dictionary = {}
	for name: String in labels:
		totals[name] = 0
		covered[name] = 0
		forbidden[name] = 0
		front_overlap[name] = 0
	for p in size.x * size.y:
		var id := int(r[p * 4])
		for name: String in labels:
			if int(labels[name]) != id:
				continue
			if b[p * 4 + 3] > 127:
				totals[name] += 1
				if a[p * 4 + 3] > 127:
					covered[name] += 1
			if a[p * 4 + 3] > 127:
				forbidden[name] += 1
				if allowed.is_empty() or allowed[p * 4 + 3] <= 127:
					front_overlap[name] += 1
	var failures: Array[String] = []
	for name: String in rule.get("covers", []):
		if totals[name] > 0 and 1.0 - float(covered[name]) / totals[name] > float(limits.maximum_uncovered_share):
			failures.append("coverage:" + name)
	for name: String in rule.get("never", []):
		if forbidden[name] > 0:
			failures.append("forbidden:" + name)
	for name: String in rule.get("front_never", []):
		if front_overlap[name] > 0:
			failures.append("front_forbidden:" + name)
	for name: String in rule.get("max_share", {}):
		if totals[name] > 0 and float(forbidden[name]) / totals[name] > float(rule.max_share[name]):
			failures.append("overlap:" + name)
	return {"failures": failures, "region_pixels": totals, "covered_pixels": covered, "overlap_pixels": forbidden}

static func overhang_pixels(image: Image, body: Image, allowance: float) -> int:
	var size := Vector2i((body.get_width() + 1) / 2, (body.get_height() + 1) / 2)
	var base := rgba(body)
	var item := rgba(image)
	base.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	item.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var b := base.get_data()
	var a := item.get_data()
	var distances := PackedFloat32Array()
	distances.resize(size.x * size.y)
	distances.fill(1000000.0)
	for p in distances.size():
		if b[p * 4 + 3] > 127:
			distances[p] = 0.0
	for reverse in [false, true]:
		var sign_value := -1 if reverse else 1
		var ys := range(size.y - 1, -1, -1) if reverse else range(size.y)
		var xs := range(size.x - 1, -1, -1) if reverse else range(size.x)
		for y: int in ys:
			for x: int in xs:
				var p := y * size.x + x
				for delta: Vector2i in [Vector2i(-sign_value, 0), Vector2i(0, -sign_value), Vector2i(-sign_value, -sign_value), Vector2i(sign_value, -sign_value)]:
					var xx := x + delta.x
					var yy := y + delta.y
					if xx >= 0 and yy >= 0 and xx < size.x and yy < size.y:
						var cost := 1.41421356 if delta.x != 0 and delta.y != 0 else 1.0
						distances[p] = minf(distances[p], distances[yy * size.x + xx] + cost)
	var count := 0
	for p in distances.size():
		if a[p * 4 + 3] > 127 and distances[p] * 2.0 > allowance:
			count += 1
	return count
