extends RefCounted
## Conquest review slice: the rules, with no scene in them, so the headless test steps them
## directly (tests/test_conquest.gd) and the scene (conquest.gd) only draws what they say.
##
## Sides lead bands of followers across the island. A band persuades a settlement to contribute
## (a strength roll: followers x posture push against residents x defense); the winner takes the
## settlement and drafts some of its residents, the loser's followers drift home. Bands eat; a
## band with no food stops taking orders and heads for its own nearest settlement. Orders to a
## leader far from the side's first leader travel by courier, slower with distance. A side wins
## holding settlements with over half of all residents; a side with every leader out loses.
## Tuning and names come from conquest.json (load_setup); every number here is its default.

const PLAYER := 0
const RIVAL := 1
const NEUTRAL := -1
const POSTURES: Array[String] = ["polite", "firm", "persistent"]

## posture -> push (strength factor), draft (share of residents taken on a win), gathers (idle
## followers collect food at an owned settlement).
var posture_rules := {
	"polite": {"push": 0.8, "draft": 0.15, "gathers": true},
	"firm": {"push": 1.0, "draft": 0.35, "gathers": true},
	"persistent": {"push": 1.35, "draft": 0.7, "gathers": false},
}
var speed := 34.0  # world px per second
var courier_speed := 140.0  # world px per second
var arrive_range := 20.0
var contact_range := 26.0
var eat_rate := 0.02  # food per follower per second
var lean_factor := 2.0  # eating multiplier on lean days
var day_seconds := 20.0
var days_per_cycle := 28
var lean_days: Array = [22, 23, 24, 25, 26, 27, 28]
var settlement_defense := 0.5  # strength per resident
var produce_rate := 0.04  # food per resident per second
var grow_seconds := 12.0  # one new resident per this long while the store holds 2 per resident
var gather_rate := 2.0  # food per second an idle band collects at its own settlement
var gather_range := 56.0
var livestock_food := 25.0
var scatter_share := 0.6  # share of a beaten band that drifts home
var desert_seconds := 4.0  # a starving band loses one follower this often
var roll_spread := 0.25  # each roll is strength x (1 +- spread)
var ai_interval := 1.5
var cell := 32.0

var rng := RandomNumberGenerator.new()
var time := 0.0
var settlements: Array = []  # of Settlement
var leaders: Array = []  # of Leader
var beasts: Array = []  # of Beast
var couriers: Array = []  # of Courier
var events: Array[String] = []  # newest last; the scene shows the tail
var outcome := ""  # "", "won" or "lost" (for PLAYER)
var side_names := {PLAYER: "Player", RIVAL: "Rival"}

var _astar: AStarGrid2D
var _ai_t := 0.0


class Settlement:
	var id := 0
	var name := ""
	var pos := Vector2.ZERO
	var pop := 0
	var food := 0.0
	var owner := -1
	var grow_t := 0.0


class Leader:
	var id := 0
	var side := 0
	var name := ""
	var caste := ""
	var follower_caste := ""
	var pos := Vector2.ZERO
	var men := 0
	var food := 0.0
	var posture := "firm"
	var order := {}  # {} idle, or {kind: move|settlement|leader|beast, id, pos}
	var path: Array = []  # of Vector2 waypoints toward order
	var path_goal := Vector2.INF
	var out := false
	var starve_t := 0.0
	var facing := Vector2.DOWN

	func starving() -> bool:
		return not out and men > 0 and food <= 0.0


class Beast:
	var id := 0
	var pos := Vector2.ZERO
	var home := Vector2.ZERO
	var goal := Vector2.ZERO
	var alive := true


class Courier:
	var leader_id := 0
	var order := {}
	var from := Vector2.ZERO
	var t := 0.0
	var duration := 0.0


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


## --- Setup ---

## Reads tuning and the starting layout from a conquest.json dictionary.
func load_setup(d: Dictionary) -> void:
	var tune: Dictionary = d.get("tuning", {})
	for key: String in tune:
		if key in self:
			set(key, type_convert(tune[key], typeof(get(key))))
	lean_days = lean_days.map(func(v: Variant) -> int: return int(v))
	if d.has("postures"):
		posture_rules = d["postures"]
	for side_key: String in d.get("sides", {}):
		side_names[_side_of(side_key)] = str(d["sides"][side_key]["name"])
	for s: Dictionary in d.get("settlements", []):
		add_settlement(str(s["name"]), _cell_pos(s["cell"]), int(s["pop"]), float(s["food"]), _side_of(str(s.get("owner", "neutral"))))
	for l: Dictionary in d.get("leaders", []):
		var at: Vector2 = _cell_pos(l["cell"])
		add_leader(_side_of(str(l["side"])), str(l["name"]), at, int(l["men"]), float(l["food"]),
				str(l.get("caste", "")), str(l.get("follower_caste", "")), str(l.get("posture", "firm")))
	for c: Array in d.get("livestock", []):
		add_beast(_cell_pos(c))


## Walkable cells from an island_layout.json mask ("L" land and "S" sand walk; the rest is water
## or surf). Without a mask, bands walk straight lines.
func set_walk_mask(mask: Array, cell_px: float) -> void:
	cell = cell_px
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, (mask[0] as String).length(), mask.size())
	_astar.cell_size = Vector2(cell_px, cell_px)
	_astar.offset = Vector2(cell_px, cell_px) / 2.0
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in mask.size():
		var row: String = mask[y]
		for x in row.length():
			if not row[x] in ["L", "S"]:
				_astar.set_point_solid(Vector2i(x, y), true)


func walkable(p: Vector2) -> bool:
	if _astar == null:
		return true
	var c := Vector2i(floori(p.x / cell), floori(p.y / cell))
	return _astar.is_in_boundsv(c) and not _astar.is_point_solid(c)


func add_settlement(sname: String, pos: Vector2, pop: int, food: float, owner: int) -> Settlement:
	var s := Settlement.new()
	s.id = settlements.size()
	s.name = sname
	s.pos = pos
	s.pop = pop
	s.food = food
	s.owner = owner
	settlements.append(s)
	return s


func add_leader(side: int, lname: String, pos: Vector2, men: int, food: float, caste := "", follower_caste := "", posture := "firm") -> Leader:
	var l := Leader.new()
	l.id = leaders.size()
	l.side = side
	l.name = lname
	l.pos = pos
	l.men = men
	l.food = food
	l.caste = caste
	l.follower_caste = follower_caste
	l.posture = posture
	leaders.append(l)
	return l


func add_beast(pos: Vector2) -> Beast:
	var b := Beast.new()
	b.id = beasts.size()
	b.pos = pos
	b.home = pos
	b.goal = pos
	beasts.append(b)
	return b


## --- Queries ---

func day() -> int:
	return int(time / day_seconds) % days_per_cycle + 1


func is_lean() -> bool:
	return day() in lean_days


func side_leaders(side: int) -> Array:
	return leaders.filter(func(l: Leader) -> bool: return l.side == side and not l.out)


## The side's first leader still in play: orders start from her.
func lead_leader(side: int) -> Leader:
	var live := side_leaders(side)
	return live[0] if not live.is_empty() else null


func total_pop() -> int:
	var n := 0
	for s: Settlement in settlements:
		n += s.pop
	return n


func owned_pop(side: int) -> int:
	var n := 0
	for s: Settlement in settlements:
		if s.owner == side:
			n += s.pop
	return n


func share(side: int) -> float:
	var t := total_pop()
	return float(owned_pop(side)) / float(t) if t > 0 else 0.0


func strength(l: Leader) -> float:
	return l.men * float(posture_rules[l.posture]["push"])


func defense(s: Settlement) -> float:
	return s.pop * settlement_defense


## Seconds an order takes to reach leader l: none for the side's first leader, else the courier's
## trip from her.
func command_delay(l: Leader) -> float:
	var lead := lead_leader(l.side)
	if lead == null or lead == l:
		return 0.0
	return lead.pos.distance_to(l.pos) / courier_speed


## --- Orders ---

## Gives leader l an order ({kind, id} or {kind: "move", pos}). Returns "" when sent, else why not:
## "out", "starving".
func issue_order(l: Leader, order: Dictionary) -> String:
	if l.out:
		return "out"
	if l.starving():
		events.append("%s's band is starving and will not listen." % l.name)
		return "starving"
	var delay := command_delay(l)
	if delay <= 0.0:
		_apply_order(l, order)
	else:
		var c := Courier.new()
		c.leader_id = l.id
		c.order = order
		c.from = lead_leader(l.side).pos
		c.duration = delay
		couriers.append(c)
	return ""


func set_posture(l: Leader, posture: String) -> void:
	if posture in posture_rules:
		l.posture = posture


func _apply_order(l: Leader, order: Dictionary) -> void:
	l.order = order
	l.path = []
	l.path_goal = Vector2.INF


func _order_target_pos(l: Leader) -> Vector2:
	match str(l.order.get("kind", "")):
		"move":
			return l.order["pos"]
		"settlement":
			return (settlements[l.order["id"]] as Settlement).pos
		"leader":
			return (leaders[l.order["id"]] as Leader).pos
		"beast":
			return (beasts[l.order["id"]] as Beast).pos
	return l.pos


## --- Simulation ---

func step(dt: float) -> void:
	if outcome != "":
		return
	time += dt
	_step_couriers(dt)
	_step_settlements(dt)
	for l: Leader in leaders:
		if not l.out:
			_step_leader(l, dt)
	_step_beasts(dt)
	_ai_t += dt
	if _ai_t >= ai_interval:
		_ai_t = 0.0
		ai_think()
	_check_outcome()


func _step_couriers(dt: float) -> void:
	for c: Courier in couriers.duplicate():
		c.t += dt
		if c.t >= c.duration:
			couriers.erase(c)
			var l: Leader = leaders[c.leader_id]
			if l.out:
				continue
			if l.starving():
				events.append("A letter reached %s, but her band is too hungry to listen." % l.name)
				continue
			_apply_order(l, c.order)


func _step_settlements(dt: float) -> void:
	for s: Settlement in settlements:
		if s.pop <= 0:
			continue  # emptied: no food, no new residents
		s.food = minf(s.food + s.pop * produce_rate * dt, s.pop * 10.0 + 20.0)
		if s.food >= s.pop * 2.0:
			s.grow_t += dt
			if s.grow_t >= grow_seconds:
				s.grow_t = 0.0
				s.pop += 1


func _step_leader(l: Leader, dt: float) -> void:
	l.food = maxf(l.food - l.men * eat_rate * dt * (lean_factor if is_lean() else 1.0), 0.0)
	if l.starving():
		l.starve_t += dt
		if l.starve_t >= desert_seconds:
			l.starve_t = 0.0
			_send_home(l, 1)
			if l.men <= 0:
				_knock_out(l, "%s's band has all drifted home, hungry." % l.name)
				return
		# Hungry bands stop listening and head for their own nearest settlement.
		var home := _nearest_settlement(l.pos, l.side)
		if home != null and str(l.order.get("kind", "")) != "settlement":
			_apply_order(l, {"kind": "settlement", "id": home.id})
	else:
		l.starve_t = 0.0
	if not l.order.is_empty():
		_move_and_resolve(l, dt)
	if l.order.is_empty():
		_gather(l, dt)


func _move_and_resolve(l: Leader, dt: float) -> void:
	var kind := str(l.order["kind"])
	if kind == "leader" and (leaders[l.order["id"]] as Leader).out:
		l.order = {}
		return
	if kind == "beast" and not (beasts[l.order["id"]] as Beast).alive:
		l.order = {}
		return
	var goal := _order_target_pos(l)
	var reach := contact_range if kind == "leader" else arrive_range
	if l.pos.distance_to(goal) <= reach:
		_arrive(l)
		return
	_walk(l, goal, dt)


func _walk(l: Leader, goal: Vector2, dt: float) -> void:
	if _astar != null and (l.path_goal == Vector2.INF or l.path_goal.distance_to(goal) > cell):
		l.path_goal = goal
		var from := _cell_of(l.pos)
		var to := _cell_of(goal)
		l.path = []
		if _astar.is_in_boundsv(from) and _astar.is_in_boundsv(to):
			for p: Vector2 in _astar.get_point_path(from, to, true):
				l.path.append(p)
		if not l.path.is_empty():
			l.path.pop_front()  # the cell it stands in
		l.path.append(goal)
	var next: Vector2 = l.path[0] if not l.path.is_empty() else goal
	var d := next - l.pos
	var stride := speed * dt
	if d.length() <= stride:
		l.pos = next
		if not l.path.is_empty():
			l.path.pop_front()
	else:
		l.facing = d.normalized()
		l.pos += l.facing * stride


func _arrive(l: Leader) -> void:
	var kind := str(l.order["kind"])
	var id: int = l.order.get("id", -1)
	l.order = {}
	match kind:
		"settlement":
			var s: Settlement = settlements[id]
			if s.owner != l.side:
				contest_settlement(l, s)
		"leader":
			var other: Leader = leaders[id]
			if other.side != l.side and not other.out:
				contest_leaders(l, other)
		"beast":
			var b: Beast = beasts[id]
			if b.alive:
				b.alive = false
				l.food += livestock_food
				events.append("%s's band took an animal for the pot (+%d food)." % [l.name, int(livestock_food)])


func _gather(l: Leader, dt: float) -> void:
	if not bool(posture_rules[l.posture]["gathers"]):
		return
	var s := _nearest_settlement(l.pos, l.side)
	if s == null or s.pos.distance_to(l.pos) > gather_range or s.food <= 0.0:
		return
	var take := minf(gather_rate * dt, s.food)
	s.food -= take
	l.food += take


func _step_beasts(dt: float) -> void:
	for b: Beast in beasts:
		if not b.alive:
			continue
		if b.pos.distance_to(b.goal) < 2.0:
			var g := b.home + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
			if walkable(g):
				b.goal = g
		else:
			b.pos = b.pos.move_toward(b.goal, 10.0 * dt)


func _roll(v: float) -> float:
	return v * (1.0 + rng.randf_range(-roll_spread, roll_spread))


## Leader l tries to persuade settlement s to contribute. Returns true when s is hers.
func contest_settlement(l: Leader, s: Settlement) -> bool:
	var push := _roll(strength(l))
	var hold := _roll(defense(s))
	if push > hold:
		var before := s.pop
		s.owner = l.side
		var draft := mini(s.pop, ceili(s.pop * float(posture_rules[l.posture]["draft"])))
		s.pop -= draft
		l.men += draft
		var food_take := s.food * float(posture_rules[l.posture]["draft"])
		s.food -= food_take
		l.food += food_take
		var losses := mini(l.men - 1, int(before * settlement_defense * 0.25))
		l.men -= maxi(losses, 0)
		events.append("%s persuaded %s to contribute (+%d followers)." % [l.name, s.name, draft])
		if s.pop == 0:
			events.append("%s is empty now: no more food or people from it." % s.name)
		return true
	var lost := ceili(l.men * scatter_share)
	_send_home(l, lost)
	events.append("%s was turned away at %s; %d followers drifted home." % [l.name, s.name, lost])
	if l.men <= 0:
		_knock_out(l, "%s has no one left and is out." % l.name)
	return false


## Two bands meet. The weaker roll's followers mostly drift home and the winner takes her food.
## Returns the winner.
func contest_leaders(a: Leader, b: Leader) -> Leader:
	var sa := _roll(strength(a))
	var sb := _roll(strength(b))
	var win := a if sa >= sb else b
	var lose := b if win == a else a
	var lost := ceili(lose.men * scatter_share)
	_send_home(lose, lost)
	win.men -= mini(win.men - 1, int(minf(sa, sb) * 0.2))
	var food := lose.food
	win.food += food
	lose.food = 0.0
	lose.order = {}
	events.append("%s faced down %s: %d of hers drifted home, %d food changed hands." % [win.name, lose.name, lost, int(food)])
	if lose.men <= 0:
		_knock_out(lose, "%s has no one left and is out." % lose.name)
	return win


## n followers leave leader l and go back to the nearest settlement of her side (or any).
func _send_home(l: Leader, n: int) -> void:
	n = mini(n, l.men)
	l.men -= n
	var s := _nearest_settlement(l.pos, l.side)
	if s == null:
		s = _nearest_settlement(l.pos, -2)
	if s != null:
		s.pop += n


func _knock_out(l: Leader, why: String) -> void:
	_send_home(l, l.men)
	l.out = true
	l.order = {}
	couriers = couriers.filter(func(c: Courier) -> bool: return c.leader_id != l.id)
	events.append(why)


## Nearest settlement owned by side, or any settlement when side is -2.
func _nearest_settlement(p: Vector2, side: int) -> Settlement:
	var best: Settlement = null
	for s: Settlement in settlements:
		if (side == -2 or s.owner == side) and (best == null or s.pos.distance_to(p) < best.pos.distance_to(p)):
			best = s
	return best


func _check_outcome() -> void:
	if side_leaders(PLAYER).is_empty() or share(RIVAL) > 0.5:
		outcome = "lost"
	elif share(PLAYER) > 0.5:
		outcome = "won"


## --- Rival AI: go for the nearest weak settlement; Persistent when clearly stronger. ---

func ai_think() -> void:
	for l: Leader in side_leaders(RIVAL):
		if l.starving():
			continue
		# Hungry: go home and gather.
		if l.food < l.men * eat_rate * 15.0:
			var home := _nearest_settlement(l.pos, RIVAL)
			if home != null:
				set_posture(l, "firm")
				if l.order.is_empty() and home.pos.distance_to(l.pos) > gather_range * 0.5:
					_apply_order(l, {"kind": "settlement", "id": home.id})
				continue
		if not l.order.is_empty():
			continue
		# A weaker player band close by: face it down.
		var prey: Leader = null
		for p: Leader in side_leaders(PLAYER):
			if p.pos.distance_to(l.pos) < 160.0 and p.men * 1.2 < l.men and (prey == null or p.men < prey.men):
				prey = p
		if prey != null:
			set_posture(l, "persistent")
			_apply_order(l, {"kind": "leader", "id": prey.id})
			continue
		var target := _ai_target(l)
		if target == null:
			continue
		set_posture(l, "persistent" if l.men >= defense(target) * 1.5 else "firm")
		_apply_order(l, {"kind": "settlement", "id": target.id})


func _ai_target(l: Leader) -> Settlement:
	var best: Settlement = null
	var best_score := INF
	for s: Settlement in settlements:
		if s.owner == RIVAL or s.pop <= 0:
			continue
		var ratio := defense(s) / maxf(l.men, 1.0)
		var score := s.pos.distance_to(l.pos) * (1.0 + ratio * 2.0)
		if ratio >= 1.0:
			score *= 4.0  # too strong for now
		if score < best_score:
			best_score = score
			best = s
	return best


## --- Helpers ---

func _side_of(key: String) -> int:
	match key:
		"player":
			return PLAYER
		"rival":
			return RIVAL
	return NEUTRAL


func _cell_pos(c: Variant) -> Vector2:
	var arr: Array = c
	return Vector2(float(arr[0]), float(arr[1])) * cell


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.y / cell))
