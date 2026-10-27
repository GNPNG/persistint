extends SceneTree
## Conquest review slice (scenes/test/conquest.tscn): the rules in scripts/test/conquest/
## conquest_sim.gd, stepped directly with no frames. Posture changes the outcome and the draft;
## an order's delay grows with the leader's distance from the side's first leader, and the order
## lands only when the courier does; a starving band refuses orders; a won settlement changes hands
## and over half the residents wins; an emptied settlement makes no food and no people; the rival
## goes for a settlement. When the scene file exists, it loads with the island and three panels.
## The review route (bead 877.4): ?scene=conquest resolves through DevScene to the scene, the Web
## preset keeps review scenes out of the player build, and a --channel deploy puts them back in.
## conquest.json agrees with the rules, the art and cast.json.
## Run: godot --headless --path project -s tests/test_conquest.gd

const Sim := preload("res://scripts/test/conquest/conquest_sim.gd")
const SETUP := "res://scripts/test/conquest/conquest.json"
const SCENE := "res://scenes/test/conquest.tscn"
## Loaded in _run with load(), after the autoloads exist (the Cast autoload is read there too).
const DEV_SCENE := "res://scripts/autoload/dev_scene.gd"
const PRESETS := "res://export_presets.cfg"
const DEPLOY := "../tools/deploy_site.sh"
const CAST := "res://data/cast.json"
const RIG := "res://assets/characters/%s_rig.png"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_posture()
	_delay()
	_starving()
	_conquest_and_win()
	_emptied()
	_setup_and_ai()
	_routing()
	_data()
	await _scene()
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


## A bare sim: no randomness, no AI, no eating unless asked.
func _sim() -> Object:
	var s: Object = Sim.new(7)
	s.roll_spread = 0.0
	s.ai_interval = 1e9
	return s


func _posture() -> void:
	# 5 followers against a settlement of 10 (defense 5): Polite pushes 4, Persistent 6.75.
	var a: Object = _sim()
	var sa: Object = a.add_settlement("A", Vector2(0, 0), 10, 10, Sim.NEUTRAL)
	var la: Object = a.add_leader(Sim.PLAYER, "Polite", Vector2(0, 0), 5, 50, "", "", "polite")
	_check(not a.contest_settlement(la, sa) and sa.owner == Sim.NEUTRAL, "Polite with 5 is turned away by 10 residents")
	_check(la.men < 5, "the turned-away band lost followers (%d left)" % la.men)
	var b: Object = _sim()
	var sb: Object = b.add_settlement("B", Vector2(0, 0), 10, 10, Sim.NEUTRAL)
	var lb: Object = b.add_leader(Sim.PLAYER, "Persistent", Vector2(0, 0), 5, 50, "", "", "persistent")
	_check(b.contest_settlement(lb, sb) and sb.owner == Sim.PLAYER, "Persistent with 5 wins the same settlement")
	# The same win, Firm against Persistent: Persistent drafts more and leaves fewer behind.
	var c: Object = _sim()
	var sc: Object = c.add_settlement("C", Vector2(0, 0), 10, 10, Sim.NEUTRAL)
	var lc: Object = c.add_leader(Sim.PLAYER, "Firm", Vector2(0, 0), 20, 50, "", "", "firm")
	var d: Object = _sim()
	var sd: Object = d.add_settlement("D", Vector2(0, 0), 10, 10, Sim.NEUTRAL)
	var ld: Object = d.add_leader(Sim.PLAYER, "Persistent", Vector2(0, 0), 20, 50, "", "", "persistent")
	c.contest_settlement(lc, sc)
	d.contest_settlement(ld, sd)
	_check(sd.pop < sc.pop and ld.men > lc.men, "Persistent drafts more than Firm (left %d vs %d; band %d vs %d)" % [sd.pop, sc.pop, ld.men, lc.men])
	# Band against band of equal size: the posture push decides it.
	var e: Object = _sim()
	var e1: Object = e.add_leader(Sim.PLAYER, "P", Vector2(0, 0), 8, 10, "", "", "persistent")
	var e2: Object = e.add_leader(Sim.RIVAL, "R", Vector2(0, 0), 8, 30, "", "", "polite")
	e.add_settlement("Home", Vector2(100, 0), 5, 5, Sim.RIVAL)
	var w: Object = e.contest_leaders(e2, e1)
	_check(w == e1 and e2.men < 8, "between equal bands, Persistent beats Polite")
	_check(e1.food >= 40.0 and e2.food == 0.0, "the winner takes the loser's food (%.0f)" % e1.food)


func _delay() -> void:
	var s: Object = _sim()
	var first: Object = s.add_leader(Sim.PLAYER, "First", Vector2(0, 0), 5, 50)
	var near: Object = s.add_leader(Sim.PLAYER, "Near", Vector2(100, 0), 5, 50)
	var far: Object = s.add_leader(Sim.PLAYER, "Far", Vector2(500, 0), 5, 50)
	_check(s.command_delay(first) == 0.0, "the first leader hears at once")
	_check(s.command_delay(near) > 0.0 and s.command_delay(far) > s.command_delay(near) * 4.0,
			"delay grows with distance (%.2fs at 100 px, %.2fs at 500 px)" % [s.command_delay(near), s.command_delay(far)])
	s.issue_order(first, {"kind": "move", "pos": Vector2(0, 50)})
	_check(not first.order.is_empty(), "the first leader's order applies now")
	var wait: float = s.command_delay(far)
	s.issue_order(far, {"kind": "move", "pos": Vector2(500, 300)})
	_check(far.order.is_empty() and s.couriers.size() == 1, "the far order is a courier on the way")
	_steps(s, wait * 0.5)
	_check(far.order.is_empty(), "halfway there, the far leader has not heard yet")
	_steps(s, wait * 0.5 + 0.2)
	_check(not far.order.is_empty() and s.couriers.is_empty(), "the far leader acts once the courier lands")


func _starving() -> void:
	var s: Object = _sim()
	var l: Object = s.add_leader(Sim.PLAYER, "Hungry", Vector2(0, 0), 5, 0)
	_check(s.issue_order(l, {"kind": "move", "pos": Vector2(100, 0)}) == "starving" and l.order.is_empty(), "a starving band refuses an order")
	var fed: Object = s.add_leader(Sim.PLAYER, "Fed", Vector2(0, 0), 5, 0.5)
	_steps(s, 10.0)
	_check(fed.food == 0.0 and s.issue_order(fed, {"kind": "move", "pos": Vector2(100, 0)}) == "starving", "a band that eats its food through stops obeying")
	_check(fed.men < 5, "a starving band loses followers over time (%d left)" % fed.men)


func _conquest_and_win() -> void:
	var s: Object = _sim()
	s.add_settlement("Home", Vector2(0, 0), 4, 10, Sim.PLAYER)
	var big: Object = s.add_settlement("Big", Vector2(200, 0), 10, 10, Sim.NEUTRAL)
	s.add_settlement("Other", Vector2(400, 0), 6, 10, Sim.RIVAL)
	s.add_leader(Sim.RIVAL, "R", Vector2(400, 0), 3, 100)
	var l: Object = s.add_leader(Sim.PLAYER, "L", Vector2(0, 0), 12, 100, "", "", "polite")
	_check(s.outcome == "" and s.share(Sim.PLAYER) < 0.5, "at the start no one holds half (%.0f%%)" % (s.share(Sim.PLAYER) * 100))
	s.issue_order(l, {"kind": "settlement", "id": big.id})
	_steps(s, 12.0)
	_check(big.owner == Sim.PLAYER, "walking up to a settlement and winning makes it ours")
	_check(s.outcome == "won", "holding over half the residents wins (%.0f%%)" % (s.share(Sim.PLAYER) * 100))
	var t: Object = _sim()
	t.add_settlement("Home", Vector2(0, 0), 4, 10, Sim.PLAYER)
	var lone: Object = t.add_leader(Sim.PLAYER, "Lone", Vector2(0, 0), 1, 10, "", "", "polite")
	var bully: Object = t.add_leader(Sim.RIVAL, "Bully", Vector2(0, 0), 10, 10, "", "", "persistent")
	t.contest_leaders(bully, lone)
	t.step(0.1)
	_check(lone.out and t.outcome == "lost", "with every leader of ours out, the game is lost")


func _emptied() -> void:
	var s: Object = _sim()
	var empty: Object = s.add_settlement("Empty", Vector2(0, 0), 0, 5, Sim.PLAYER)
	var full: Object = s.add_settlement("Full", Vector2(500, 0), 6, 20, Sim.PLAYER)
	s.add_settlement("Far away", Vector2(2000, 0), 50, 0, Sim.NEUTRAL)  # so no one has won yet
	s.add_leader(Sim.PLAYER, "Away", Vector2(3000, 0), 1, 1000)  # nor lost
	_steps(s, 30.0)
	_check(empty.pop == 0 and is_equal_approx(empty.food, 5.0), "an emptied settlement makes no food and no people")
	_check(full.food > 20.0 and full.pop > 6, "a lived-in one makes both (food %.0f, residents %d)" % [full.food, full.pop])
	# Persistent can empty a small settlement outright.
	var t: Object = _sim()
	var small: Object = t.add_settlement("Small", Vector2(0, 0), 2, 5, Sim.NEUTRAL)
	var l: Object = t.add_leader(Sim.PLAYER, "L", Vector2(0, 0), 10, 50, "", "", "persistent")
	t.contest_settlement(l, small)
	_check(small.pop == 0, "Persistent drafting can empty a settlement")


func _setup_and_ai() -> void:
	var s: Object = Sim.new(3)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/island_layout.json"))
	s.set_walk_mask(layout["mask"], 32.0)
	s.load_setup(JSON.parse_string(FileAccess.get_file_as_string(SETUP)))
	_check(s.settlements.size() >= 6 and s.settlements.size() <= 8, "the island has %d settlements" % s.settlements.size())
	_check(s.side_leaders(Sim.PLAYER).size() == 3 and s.side_leaders(Sim.RIVAL).size() in [1, 2], "three leaders for us, %d for the rival" % s.side_leaders(Sim.RIVAL).size())
	var walk_ok := true
	for x: Object in s.settlements:
		walk_ok = walk_ok and s.walkable(x.pos)
	for x: Object in s.leaders:
		walk_ok = walk_ok and s.walkable(x.pos)
	for x: Object in s.beasts:
		walk_ok = walk_ok and s.walkable(x.pos)
	_check(walk_ok, "every settlement, leader and animal starts on land")
	_check(s.days_per_cycle == 28 and 25 in s.lean_days, "the setup's numbers load")
	s.ai_think()
	var moving: Array = s.side_leaders(Sim.RIVAL).filter(func(l: Object) -> bool: return not l.order.is_empty())
	_check(not moving.is_empty(), "the rival goes after a settlement")
	_steps(s, 60.0)
	var rival_owned: int = s.settlements.filter(func(x: Object) -> bool: return x.owner == Sim.RIVAL).size()
	_check(rival_owned >= 2, "in a minute the rival has taken a settlement (%d owned)" % rival_owned)


## The review route for ?scene=conquest (web) and -- --scene=conquest (desktop): DevScene takes the
## name and opens scenes/test/conquest.tscn. The Web preset leaves scenes/test/ and scripts/test/
## out of the player build; tools/deploy_site.sh --channel=<name> clears that filter for its own
## export and puts the preset back after, so a review channel carries the scene and the player
## site never does.
func _routing() -> void:
	var dev = load(DEV_SCENE)
	_check(dev != null, "DevScene's script loads")
	if dev == null:
		return
	var test_dir := str(dev.get_script_constant_map().get("TEST_DIR", ""))
	var scene_name := str(dev.sanitize("conquest"))
	_check(scene_name == "conquest", "DevScene takes ?scene=conquest")
	_check(str(dev.sanitize("test/conquest.tscn")) == "conquest", "DevScene takes the same name written as a path")
	var path := test_dir + scene_name + ".tscn"
	_check(path == SCENE and ResourceLoader.exists(path), "?scene=conquest opens %s" % path)
	var presets := ConfigFile.new()
	var web := ""
	if presets.load(PRESETS) == OK:
		for section: String in presets.get_sections():
			if str(presets.get_value(section, "name", "")) == "Web":
				web = section
	var exclude := str(presets.get_value(web, "exclude_filter", "")) if web != "" else ""
	var excluded := exclude.split(",")
	_check(web != "" and excluded.has("scenes/test/*") and excluded.has("scripts/test/*"),
			"the Web preset keeps review scenes out of the player build (exclude_filter %s)" % exclude)
	var deploy := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join(DEPLOY))
	_check(deploy.contains("--channel=") and deploy.contains("s#^exclude_filter=.*#exclude_filter=\"\"#")
			and deploy.contains("export_presets.cfg.orig"),
			"a --channel deploy clears that filter for its own export and puts the preset back")


## conquest.json against the rules, the art and cast.json: the postures are the rules' three, each
## with a label and its numbers; two sides; every leader's side and posture are the setup's, both
## her castes have a rig, and a name_cast is a cast.json id; names are unique; every settlement is
## held by a side or by no one and starts with residents; each side starts holding one (a hungry
## band heads for its own); lean days fall inside the cycle.
func _data() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SETUP))
	var postures: Dictionary = d.get("postures", {})
	var have: Array = postures.keys()
	var want: Array = []
	for p: String in Sim.POSTURES:
		want.append(p)
	have.sort()
	want.sort()
	_check(have == want, "the setup's postures are the rules' own %s" % str(want))
	for p: String in postures:
		var r: Dictionary = postures[p]
		_check(str(r.get("label", "")) != "" and r.has("push") and r.has("draft") and r.has("gathers"),
				"posture %s has a label, push, draft and gathers" % p)
	var sides: Dictionary = d.get("sides", {})
	_check(sides.size() == 2 and sides.has("player") and sides.has("rival"), "two sides, player and rival")
	var cast: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAST))
	var cast_ids: Dictionary = cast if cast is Dictionary else {}
	var cast_node: Node = root.get_node_or_null("/root/Cast")
	_check(cast_node != null, "the Cast autoload is there")
	var leader_names := {}
	for l: Dictionary in d.get("leaders", []):
		var who := str(l.get("name", ""))
		if l.has("name_cast"):
			var id := str(l["name_cast"])
			var full := str(cast_node.full(id)) if cast_node != null else id
			_check(cast_ids.has(id) and full != id, "%s's name comes from cast.json (%s: %s)" % [who, id, full])
			who = full
		_check(sides.has(str(l.get("side", ""))), "%s is on one of the two sides" % who)
		_check(postures.has(str(l.get("posture", "firm"))), "%s starts in one of the setup's postures" % who)
		for key: String in ["caste", "follower_caste"]:
			var caste := str(l.get(key, ""))
			var rig: String = RIG % caste
			_check(caste != "" and ResourceLoader.exists(rig), "%s's %s has a rig (%s)" % [who, key, rig])
		_check(not leader_names.has(who), "%s is the only leader with that name" % who)
		leader_names[who] = true
	var held := {}
	var place_names := {}
	for s: Dictionary in d.get("settlements", []):
		var place := str(s.get("name", ""))
		var holder := str(s.get("owner", "neutral"))
		_check(holder == "neutral" or sides.has(holder), "%s is held by a side or by no one (%s)" % [place, holder])
		_check(int(s.get("pop", 0)) > 0, "%s starts with residents" % place)
		_check(place != "" and not place_names.has(place), "%s is the only settlement with that name" % place)
		place_names[place] = true
		held[holder] = true
	for side: String in sides:
		_check(held.has(side), "the %s side starts holding a settlement, a home for its hungry bands" % side)
	var tune: Dictionary = d.get("tuning", {})
	var cycle := int(tune.get("days_per_cycle", 28))
	var lean_ok := true
	for v: Variant in tune.get("lean_days", []):
		lean_ok = lean_ok and int(v) >= 1 and int(v) <= cycle
	_check(lean_ok, "every lean day falls inside the %d-day cycle" % cycle)


func _scene() -> void:
	if not ResourceLoader.exists(SCENE):
		print("SKIP the scene (not built yet)")
		return
	change_scene_to_file(SCENE)
	for i in 6:
		await process_frame
	var sc := current_scene
	_check(sc != null and sc.has_method("select_leader"), "the conquest scene opens")
	if sc == null:
		return
	_check(sc.find_children("*", "TileMapLayer", true, false).size() >= 1, "it shows the island's tiles")
	_check(sc.find_children("Panel_*", "", true, false).size() == 3, "one panel per leader of ours")
	sc.select_leader(0)
	_check(sc.selected == 0, "selecting the first leader works")
	for i in 30:
		await process_frame
	_check(sc.sim.time > 0.0, "the scene runs the rules")


func _steps(s: Object, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		s.step(0.1)
		t += 0.1


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
