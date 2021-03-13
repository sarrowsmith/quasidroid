class_name Level
extends Node2D


export(int) var level_seed = 0
export(bool) var rooms = false
export(int) var level = 0

enum Prototype {LEVEL, LIFT, ACCESS, ROGUE}
enum {FLOOR, WALL, LIFT, ACCESS, PLAYER, ROGUE}
enum {LOCKED, OPEN, RESET, this_is_really_a_bitmask, CLEAR}

onready var cursor = $Cursor

var rng = RandomNumberGenerator.new()
var map = null
var world = null
var parent = null
var children = null
var prototypes = null
var lifts = []
var access = {}
var map_name = ""
var rogues = []
var state = LOCKED


func _ready():
	prototypes = [
		load("res://levels/Level.tscn"),
		load("res://levels/Lift.tscn"),
		load("res://levels/AccessPoint.tscn"),
		load("res://robots/Rogue.tscn")
	]
	world = find_parent("World")


func is_clear():
	return (state & CLEAR and children and
		children[0] and children[0].is_clear() and
		children[1] and children[1].is_clear())


# warning-ignore:shadowed_variable
func create(from, rooms):
	set_visible(false)
	map = get_node("Rooms" if rooms else "Caves")
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
		map_name = String(level)
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
	rng.seed = level_seed
	map.generate(rng)
	if level == world.world_depth:
		children = [null, null]
	else:
		children = []
		for i in 2:
			var child = prototypes[Prototype.LEVEL].instance()
			world.add_child(child)
			child.create(self, i == 1 and level < world.world_depth - 1)
			children.append(child)
			if not rooms:
				children.append(null)
				break
	place_features()
	generate_rogues()


func place_features():
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
					lifts.append(new_lift(probe))
					access[probe] = null
					break
			separation -= 1
		if separation <= 5:
			break # Better an incomplete game than a hung one?
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


func generate_rogues():
	var n_rogues = rng.randi_range(15, 25)
	while len(rogues) < n_rogues:
		for _i in $Caves.iterations:
			var probe = Vector2(
				rng.randi_range(1, map.map_w - 1),
				rng.randi_range(1, map.map_h - 1))
			if location_type(probe) != FLOOR:
				continue
			if probe.distance_squared_to(lifts[0].location) > 25:
				var r = new_feature(probe, Prototype.ROGUE)
				r.generate(self, probe)
				rogues.append(r)
				break


func rogue_at(location=null):
	if not location:
		location = cursor.location
	for r in rogues:
		if r.location == location:
			return r
	return null


func check_nearby(x, y, r):
	var counts = [0, 0, 0, 0, 0, 0]
	for i in 2*r+1:
		for j in 2*r+1:
			var location = Vector2(x+i-r, y+j-r)
			counts[location_type(location)] += 1
	return counts


func location_type(location):
	if access.has(location):
		return ACCESS if access[location] else LIFT
	if location == world.player.location:
		return PLAYER
	if rogue_at(location):
		return ROGUE
	return WALL if map.get_cellv(location) != TileMap.INVALID_CELL else FLOOR


func activate(location):
	if not access.has(location):
		return false# Shouldn't be possible, but apparently is
	access[location].active = true
	for ap in access.values():
		if ap and not ap.active:
			return false
	state |= RESET
	for lift in lifts:
		lift.unlock()
		if lift.to and lift.to.state == LOCKED:
			lift.to.state = OPEN
	return true

func lift_at(location):
	if not access.has(location) or access[location]:
		return null
	for l in lifts:
		if l.location == location:
			return l
	return null


func new_lift(location):
	var lift = new_feature(location, Prototype.LIFT)
	lift.location = location
	lift.from = self
	if len(lifts) == 0:
		lift.to = parent
		if level > 1:
			lift.unlock()
		lift.direction = "up"
	else:
		lift.to = children[len(lifts) - 1]
	for o in [Vector2.ZERO, Vector2.UP]:
		map.set_cellv(location + o, map.Tiles.ROOF)
		map.update_bitmask_area(location + o)
	return lift


func new_feature(location, type):
	var feature = prototypes[type].instance()
	add_child(feature)
	feature.position = location_to_position(location)
	return feature


func location_to_position(location):
	return map.map_to_world(location)


func position_to_location(position):
	return map.world_to_map(position)


func move_cursor(movement):
	set_cursor(position_to_location(cursor.position) + movement)


func set_cursor(location=null):
	if location:
		cursor.location = location
		cursor.position = location_to_position(location)
	world.player.set_cursor()


func _on_Background_click(_position, button):
	world.player.cursor_activate(button)


func _on_Background_move(position):
	set_cursor(position_to_location(position) + Vector2(1, 1))
