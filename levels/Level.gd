class_name Level
extends Node2D


signal rogues_move_end()

export(int) var level_seed = 0
export(bool) var rooms = false
export(int) var level = 0

enum Prototype {LEVEL, LIFT, ACCESS, ROGUE}
enum {FLOOR, WALL, LIFT, ACCESS, PLAYER, ROGUE}
enum {LOCKED, OPEN, RESET, this_is_really_a_bitmask, CLEAR}

onready var cursor = $Cursor

var rng = RandomNumberGenerator.new()
var map: TileMap = null
var world = null
var parent: Level = null
var children = []
var n_children = 0
var prototypes = [null, null, null, null]
var lifts = []
var access = {}
var map_name = ""
var rogues = []
var state = LOCKED
var awaiting = {}


func _ready():
	prototypes = [
		load("res://levels/Level.tscn"),
		load("res://levels/Lift.tscn"),
		load("res://levels/AccessPoint.tscn"),
		load("res://robots/Rogue.tscn")
	]
	world = find_parent("World")


func is_clear() -> bool:
	return (state & CLEAR and
		n_children > 0 and children[0].is_clear() and
		n_children > 1 and children[1].is_clear())


func gather_stats() -> Dictionary:
	var level_stats = {
		"levels opened": 0,
		"levels reset": 0,
		"levels cleared": 0,
		"rogues deactivated": 0,
	}
	var all_stats = {}
	if state & OPEN:
		level_stats["levels opened"] = 1
	if state & RESET:
		level_stats["levels reset"] = 1
	if state & CLEAR:
		level_stats["levels cleared"] = 1
	for r in rogues:
		if not r.get_state(): # 0 == Robot.DEAD:
			level_stats["rogues deactivated"] += 1
	all_stats[map_name] = level_stats
	if children:
		for child in children:
			if child:
				var child_stats = child.gather_stats()
				for child_name in child_stats:
					all_stats[child_name] = child_stats[child_name]
	return all_stats


# warning-ignore:shadowed_variable
func create(from: Level, rooms: bool):
	set_visible(false)
	map = $Rooms if rooms else $Caves
	map.set_visible(true)
	parent = from
	self.rooms = rooms
	if parent == null:
		level = 1
		map_name = "1"
		state |= OPEN
	else:
		level = parent.level + 1
		prototypes = parent.prototypes
		map_name = str(level)
		if not rooms:
			var depth = 1
			var up = parent
			while up and not up.rooms:
				depth += 1
				up = up.parent
			map_name += "-%s" % char("A".ord_at(0) + depth - 1)
	level_seed = world.rng.randi()
	rng.seed = level_seed


func generate():
	set_visible(true)
	if children: # ie already generated
		for l in lifts:
			l.close()
		return
	while true:
		rng.seed = level_seed
		map.generate(rng)
		if level == world.world_depth:
			children = [null, null]
		else:
			children = []
			n_children = 0
			for i in 2:
				var child = prototypes[Prototype.LEVEL].instance()
				world.add_child(child)
				child.create(self, i == 1 and level < world.world_depth - 1)
				n_children += 1
				children.append(child)
				if not rooms:
					children.append(null)
					break
		if place_features() and generate_rogues():
			break
		clear()
		level_seed = rng.randi()


func clear():
	for feature_set in [lifts, access.values(), rogues]:
		for item in feature_set:
			if item:
				item.queue_free()
	lifts.clear()
	access.clear()
	rogues.clear()


func place_features() -> bool:
	var n_lifts = (3 if rooms else 2) if level < world.world_depth else 1
	var separation = 10
	while len(lifts) < n_lifts:
		var lift_n = len(lifts)
		while lift_n == len(lifts) and separation > 5:
			for _i in $Caves.iterations:
				var probe = Vector2(
					rng.randi_range(1, map.map_w - 1),
					rng.randi_range(1, map.map_h - 1))
				for l in lifts:
					if probe.distance_squared_to(l.location) < separation * separation:
						probe = null
						break
				if probe and check_nearby(probe.x, probe.y, 2)[FLOOR] == 25:
					new_lift(probe)
					break
			separation -= 1
		if lift_n == len(lifts):
			return false
	var n_access = rng.randi_range(4, 8)
	for _n in n_access:
		for _i in range($Caves.iterations):
			var probe = Vector2(
				rng.randi_range(1, map.map_w - 1),
				rng.randi_range(1, map.map_h - 1))
			if location_type(probe) != FLOOR:
				continue
			for a in access:
				if probe.distance_squared_to(a) < 36:
					probe = null
					break
			if not probe:
				continue
			for l in lifts:
				if probe.distance_squared_to(l.location) < 100:
					probe = null
					break
			if not probe:
				continue
			var counts = check_nearby(probe.x, probe.y, 1)
			var walls = counts[WALL]
			if 0 < walls and walls < 5 and walls + counts[FLOOR] == 9:
				access[probe] = new_feature(probe, Prototype.ACCESS)
				break
	return not access.empty()


func generate_rogues() -> bool:
	var n_rogues = rng.randi_range(15, 25)
	for _n in n_rogues:
		for _i in $Caves.iterations:
			var probe = Vector2(
				rng.randi_range(1, map.map_w - 1),
				rng.randi_range(1, map.map_h - 1))
			if location_type(probe) != FLOOR or location_type(probe + Vector2.UP) == LIFT:
				continue
			if probe.distance_squared_to(lifts[0].location) > 25:
				var r = new_feature(probe, Prototype.ROGUE)
				r.generate(self, probe)
				r.connect("end_move", self, "rogue_end_move")
				rogues.append(r)
				break
	return not rogues.empty()


func await_rogues():
	awaiting.clear()
	for r in rogues:
		if r.get_state(): # 0 == Robot.DEAD:
			awaiting[r] = true


func rogue_end_move(rogue):
	if not rogue.is_idle() and awaiting.erase(rogue) and awaiting.empty():
		emit_signal("rogues_move_end")


func rogue_at(location: Vector2): # -> Rogue (cyclic refereence)
	for r in rogues:
		if r.location == location:
			return r
	return null


func check_nearby(x: float, y: float, r: float) -> Array:
	var counts = [0, 0, 0, 0, 0, 0]
	for i in 2*r+1:
		for j in 2*r+1:
			var location = Vector2(x+i-r, y+j-r)
			counts[location_type(location)] += 1
	return counts


func location_type(location: Vector2): # -> enum
	if access.has(location):
		return ACCESS if access[location] else LIFT
	if location == world.player.location:
		return PLAYER
	if rogue_at(location):
		return ROGUE
	return WALL if map.get_cellv(location) != TileMap.INVALID_CELL else FLOOR


func activate(location: Vector2) -> bool:
	if not access.has(location):
		return false # Shouldn't be possible, but apparently is
	access[location].reset()
	for ap in access.values():
		if ap and not ap.active:
			return false
	state |= RESET
	for lift in lifts:
		if lift.to:
			lift.unlock()
	return true

func lift_at(location: Vector2): # -> Lift (cyclic reference)
	if not access.has(location) or access[location]:
		return null
	for l in lifts:
		if l.location == location:
			return l
	return null


func new_lift(location: Vector2): # -> Lift (cyclic reference)
	var lift = new_feature(location, Prototype.LIFT)
	lift.location = location
	set_lift(lift, null if lifts.empty() else children[len(lifts) - 1])


func set_lift(lift, to):
	lift.from = self
	if to:
		lift.to = children[len(lifts) - 1]
	else:
		lift.set_up(parent, level > 1)
	for o in [Vector2.ZERO, Vector2.UP]:
		map.set_cellv(lift.location + o, map.Tiles.ROOF)
		map.update_bitmask_area(lift.location + o)
	access[lift.location] = null
	lifts.append(lift)


func new_feature(location: Vector2, type) -> Node:
	var feature = prototypes[type].instance()
	add_child(feature)
	feature.position = location_to_position(location)
	return feature


func location_to_position(location: Vector2) -> Vector2:
	return map.map_to_world(location)


func position_to_location(position: Vector2) -> Vector2:
	return map.world_to_map(position)


func move_cursor(movement: Vector2):
	set_cursor(position_to_location(cursor.position) + movement)


func set_cursor(location: Vector2):
	if location:
		cursor.location = location
		cursor.position = location_to_position(location)
	world.player.set_cursor()


func find_level(level_name: String) -> Level:
	match level_name:
		"^":
			return null
		map_name:
			return self
	for i in n_children:
		var found = children[i].find_level(level_name)
		if found:
			return found
	return null


func load_lifts(file: File):
	var n_lifts = file.get_8()
	for _i in n_lifts:
		var lift = new_feature(Vector2.ZERO, Prototype.LIFT)
		set_lift(lift, find_level(lift.load(self, file)))


func save_lifts(file: File):
	file.store_8(len(lifts))
	for lift in lifts:
		lift.save(file)


func load_access(file: File):
	var save_form = file.get_var()
	for location in save_form:
		var ap = new_feature(location, Prototype.ACCESS)
		if save_form[location]:
			ap.reset()
		access[location] = ap


func save_access(file: File):
	var save_form = {}
	for ap in access:
		if access[ap]:
			save_form[ap] = access[ap].active
	file.store_var(save_form)


func load_rogues(file: File):
	var n_rogues = file.get_32()
	for i in n_rogues:
		var rogue = new_feature(Vector2.ZERO, Prototype.ROGUE)
		rogue.level = self
		rogue.load(file)
		rogue.connect("end_move", self, "rogue_end_move", [], CONNECT_DEFERRED)
		rogues.append(rogue)


func save_rogues(file: File):
	file.store_32(len(rogues))
	for r in rogues:
		r.save(file)


func load(file: File):
	set_visible(false)
	level_seed = file.get_32()
	rooms = bool(file.get_8())
	map = $Rooms if rooms else $Caves
	map.set_visible(true)
	level = file.get_32()
	state = file.get_8()
	map_name = file.get_pascal_string()
	rng.seed = level_seed
	if file.get_8():
		map.generate(rng)
	n_children = file.get_8()
	for _i in n_children:
		var child = prototypes[Prototype.LEVEL].instance()
		world.add_child(child)
		children.append(child)
		child.parent = self
		child.load(file)
	load_lifts(file)
	load_access(file)
	load_rogues(file)


func save(file: File):
	file.store_32(level_seed)
	file.store_8(int(rooms))
	file.store_32(level)
	file.store_8(state)
	file.store_pascal_string(map_name)
	# n_children is number of non-null chidlren.
	file.store_8(len(children))
	file.store_8(n_children)
	for i in n_children:
		children[i].save(file)
	save_lifts(file)
	save_access(file)
	save_rogues(file)


func _on_Background_click(_position, button):
	world.player.cursor_activate(button)


func _on_Background_move(position):
	set_cursor(position_to_location(position) + Vector2(1, 1))
