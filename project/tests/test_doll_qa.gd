extends SceneTree
## Headless catalog QA, reports every finding; unapproved catalog items stay review-only.
const Composer = preload("res://scripts/systems/doll_composer.gd")
# Temporary exception authorized by coordinator; task 7 must empty this list.
const EXPECTED_FAILURES = {"body_base": {"owner": "task 7 Canon migration (persistint-game-1rjz)", "findings": ["fringe", "boundary_alpha_levels"]}}
# Task 3 Daughter review findings are enumerated, never a blanket needs_review bypass.
const REVIEW_FINDINGS = {
 "hair_daughter": ["hair:green_residue", "hair:forbidden:eye_band", "hair:overlap:face", "hair_back:green_residue"],
 "dress_daughter": ["dress:green_residue", "dress:coverage:torso", "dress:forbidden:hand_l", "dress:forbidden:hand_r"],
 "shoes_daughter_l": ["shoes:frame_border", "shoes:green_residue", "shoes:skin_leak", "shoes:coverage:foot_l", "shoes:forbidden:thigh_l", "shoes:overhang"],
 "shoes_daughter_r": ["shoes:frame_border", "shoes:green_residue", "shoes:skin_leak", "shoes:coverage:foot_r", "shoes:forbidden:thigh_r", "shoes:overhang"],
 "hair_daughter+dress_daughter": ["forbidden:eye_band"]
}
var _root := ""
var _images: Dictionary = {}
var _context_fingerprint := ""
var _failures := 0

func _load(file: String) -> Image:
	var full := _root.path_join("project").path_join(file.trim_prefix("res://")) if file.begins_with("res://") else _root.path_join(file)
	if not _images.has(full):
		var image := Image.load_from_file(full)
		if image == null or image.is_empty():
			push_error("Missing QA image: " + full)
			return null
		_images[full] = Composer.rgba(image)
	return _images[full]

func _json(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_root.path_join(file)))

func _check(condition: bool, name: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: " + name)

func _evaluate(report: Dictionary) -> void:
	var id: String = report.id
	var allowed: Array = []
	report["disposition"] = "checked"
	if EXPECTED_FAILURES.has(id):
		allowed = EXPECTED_FAILURES[id].findings
		report["disposition"] = "known"
		report["owner"] = EXPECTED_FAILURES[id].owner
		print("KNOWN: %s %s owner=%s metrics=%s" % [id, report.findings, EXPECTED_FAILURES[id].owner, report.get("metrics", {})])
	elif (typeof(report.get("needs_review")) == TYPE_STRING or report.get("needs_review") == true) and REVIEW_FINDINGS.has(id):
		allowed = REVIEW_FINDINGS[id]
		report["disposition"] = "review"
		print("REVIEW: %s %s" % [id, report.findings])
	var unexpected: Array = report.findings.filter(func(finding: String) -> bool: return not allowed.has(finding))
	report["unexpected_findings"] = unexpected
	_check(unexpected.is_empty(), id + ": " + str(unexpected))

func _item(id: String, entry: Dictionary, rig: Dictionary, body: Image, regions: Image) -> Dictionary:
	var layers: Array = []
	var findings: Array = []
	var metrics: Dictionary = {}
	for layer: Dictionary in entry.layers:
		var image := _load(layer.file)
		if image == null:
			findings.append("missing_layer")
			continue
		if image.get_size() != body.get_size():
			findings.append("frame_dimensions")
			continue
		layers.append(image)
		var pixel := Composer.pixel_report(image, entry.slot, rig.skin.base, rig.qa)
		metrics[layer.layer] = pixel
		for failure: String in pixel.failures:
			findings.append(layer.layer + ":" + failure)
		var rule: Dictionary = rig.slots[entry.slot].duplicate(true)
		if entry.get("side", null) != null and rule.get("per_side", false):
			rule.covers = ["foot_" + str(entry.side)]
		var front_mask: Image = null
		if layer.layer == "hair_back":
			rule = {"covers": [], "never": []}
		elif layer.layer == "hair":
			var mask_path: Variant = entry.get("split", {}).get("front_mask", null)
			if mask_path != null:
				front_mask = _load(str(mask_path))
		var region := Composer.region_report(image, regions, body, rule, rig.regions.labels, rig.qa, front_mask)
		metrics[layer.layer]["regions"] = region
		for failure: String in region.failures:
			findings.append(layer.layer + ":" + failure)
		if rule.get("overhang_px", null) != null:
			var overhang := Composer.overhang_pixels(image, body, float(rule.overhang_px))
			metrics[layer.layer]["overhang_pixels_half_scale"] = overhang
			if overhang > 0:
				findings.append(layer.layer + ":overhang")
		var strays := Composer.stray_report(image, rig.qa)
		if strays.any(func(part: Dictionary) -> bool: return not entry.get("declared_components", []).has(part.component)):
			findings.append(layer.layer + ":stray_components")
	if entry.get("source", {}).get("method", "") == "legacy-sheet":
		var fit: Dictionary = entry.get("fit", {})
		if not fit.has("scale") or not fit.has("sheet_scale") or float(fit.get("sheet_scale", 0)) <= 0:
			findings.append("legacy_scale_missing")
		var relative := float(fit.get("scale", 1.0)) / maxf(float(fit.get("sheet_scale", 1.0)), 0.000001)
		metrics["legacy_scale_ratio"] = relative
		if absf(relative - 1.0) > float(rig.qa.maximum_legacy_scale_deviation) + 0.000001:
			findings.append("legacy_scale")
	return {"id": id, "findings": findings, "metrics": metrics, "needs_review": entry.get("needs_review", null)}

func _fingerprint(entry: Dictionary) -> String:
	var value := _context_fingerprint + JSON.stringify(entry)
	for layer: Dictionary in entry.layers:
		value += FileAccess.get_sha256(_root.path_join("project").path_join(str(layer.file).trim_prefix("res://")))
	return value.sha256_text()

func _pair(a_id: String, a: Dictionary, b_id: String, b: Dictionary, rig: Dictionary, body: Image, regions: Image) -> Dictionary:
	var front_layers: Array = []
	var layers: Array = []
	var garments: Array = []
	var hair: Image = null
	var hat: Image = null
	for layer_name: String in rig.layers:
		if layer_name == "body":
			layers.append(body)
		for entry: Dictionary in [a, b]:
			for layer: Dictionary in entry.layers:
				if layer.layer != layer_name:
					continue
				var image := _load(layer.file)
				layers.append(image)
				if layer_name != "hair_back":
					front_layers.append(image)
				if layer_name in ["top", "bottom", "dress", "shoes"]:
					garments.append(image)
				if layer_name == "hair":
					hair = image
				if layer_name == "hat":
					hat = image
	var combined := Composer.compose(layers, body.get_size())
	var front := Composer.compose(front_layers, body.get_size())
	var region := Composer.region_report(front, regions, body, {"never": ["eye_band"]}, rig.regions.labels, rig.qa)
	var findings: Array = region.failures
	if not garments.is_empty():
		var garment_image := Composer.compose(garments, body.get_size())
		var skin_report := Composer.pixel_report(garment_image, "dress", rig.skin.base, rig.qa)
		if skin_report.failures.has("skin_leak"):
			findings.append("combined_skin_leak")
	if hair != null and hat != null:
		var hair_data := Composer.rgba(hair).get_data()
		var hat_data := Composer.rgba(hat).get_data()
		var crown_y := hat.get_height()
		for p in hat.get_width() * hat.get_height():
			if hat_data[p * 4 + 3] > 127:
				crown_y = mini(crown_y, p / hat.get_width())
		var visible_above := 0
		for p in crown_y * hat.get_width():
			if hair_data[p * 4 + 3] > 127 and hat_data[p * 4 + 3] <= 127:
				visible_above += 1
		if visible_above > 0:
			findings.append("hair_above_hat")
	return {"id": a_id + "+" + b_id, "findings": findings, "image": combined, "needs_review": a.get("needs_review", null) != null or b.get("needs_review", null) != null}

func _init() -> void:
	_root = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	if OS.get_environment("DOLL_QA_ROOT") != "":
		_root = OS.get_environment("DOLL_QA_ROOT")
	var start := Time.get_ticks_msec()
	var rig := _json("project/data/doll/rig_chibi.json")
	var catalog := _json("project/data/doll/items.json")
	_context_fingerprint = JSON.stringify(rig) + FileAccess.get_sha256(_root.path_join(rig.body_file)) + FileAccess.get_sha256(_root.path_join(rig.regions.file))
	var body := _load(rig.body_file)
	var regions := _load(rig.regions.file)
	var reports: Array = []
	var body_report := Composer.pixel_report(body, "body", rig.skin.base, rig.qa)
	reports.append({"id": "body_base", "findings": body_report.failures, "metrics": body_report})
	_evaluate(reports[0])
	var tiles: Array = [body]
	for id: String in catalog:
		var report := _item(id, catalog[id], rig, body, regions)
		reports.append(report)
		_evaluate(report)
		var ordered: Array = []
		for layer_name: String in rig.layers:
			if layer_name == "body":
				ordered.append(body)
			for layer: Dictionary in catalog[id].layers:
				if layer.layer == layer_name:
					ordered.append(_load(layer.file))
		tiles.append(Composer.compose(ordered, body.get_size()))
	var baseline: Dictionary = {}
	if FileAccess.file_exists(_root.path_join("project/data/doll/qa_baseline.json")):
		baseline = _json("project/data/doll/qa_baseline.json")
	var fingerprints: Dictionary = {}
	var full := OS.get_environment("DOLL_QA_FULL") == "1"
	var ids := catalog.keys()
	for id: String in ids:
		fingerprints[id] = _fingerprint(catalog[id])
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Dictionary = catalog[ids[i]]
			var b: Dictionary = catalog[ids[j]]
			var slots: Array = [a.slot, b.slot]
			var relevant := (slots.has("hair") and (slots.has("hat") or slots.has("dress") or slots.has("top"))) or (slots.has("top") and slots.has("bottom"))
			var changed: bool = baseline.get(ids[i], "") != fingerprints[ids[i]] or baseline.get(ids[j], "") != fingerprints[ids[j]]
			if not relevant or not (full or changed):
				continue
			var pair := _pair(ids[i], a, ids[j], b, rig, body, regions)
			tiles.append(pair.image)
			pair.erase("image")
			reports.append(pair)
			_evaluate(pair)
	var out := _root.path_join(".cache/doll_qa")
	DirAccess.make_dir_recursive_absolute(out)
	var contact := Image.create(240 * tiles.size(), 254, false, Image.FORMAT_RGBA8)
	contact.fill(Color("334466"))
	for i in tiles.size():
		var tile := tiles[i].duplicate() as Image
		tile.resize(240, 254, Image.INTERPOLATE_LANCZOS)
		contact.blend_rect(tile, Rect2i(0, 0, 240, 254), Vector2i(i * 240, 0))
	contact.save_png(out.path_join("contact.png"))
	var elapsed := Time.get_ticks_msec() - start
	var result := {"reports": reports, "duration_ms": elapsed, "failures": _failures, "scope": "full" if full else "changed_pairs", "fingerprints": fingerprints}
	var file := FileAccess.open(out.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ") + "\n")
	print("QA elapsed %dms; contact %s" % [elapsed, out.path_join("contact.png")])
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
