class_name Level
extends Node2D


export(int) var level_seed = 0
export(bool) var rooms = false
export(int) var level = 0

enum Prototype {LEVEL, LIFT, ACCESS, ROGUE}
enum {FLOOR, WALL, LIFT, ACCESS, PLAYER, ROGUE}

onready var cursor = $Cursor

var map = null
var world = null
var parent = null
var children = null
var prototypes = null
var lifts = []
var access = {}
var map_name = ""
var rogues = []


func _ready():
	prototypes = [
		load("res://levels/Level.tscn"),
		load("res://levels/Lift.tscn"),
		load("res://levels/AccessPoint.tscn"),
		load("res://robots/Rogue.tscn")
	]
	world = find_parent("World")


func create(from, rooms):
	set_visible(false)
	map = get_node("Rooms" if rooms else "Caves")
	map.set_visible(true)
	parent = from
	self.rooms = rooms
	if parent == null:
		level = 1
		map_name = "1"
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
			var A = "-A".to_ascii()
			A.set(1, A[1]+depth-1)
			map_name += A.get_string_from_ascii()
	level_seed = randi()


func generate():
	set_visible(true)
	if children:
		return
	seed(level_seed)
	map.generate()
	if level == 7:
		children = [null, null]
	else:
		children = []
		for i in 2:
			var child = prototypes[Prototype.LEVEL].instance()
			child.create(self, i == 1 and level < 6)
			world.add_child(child)
			children.append(child)
			if not rooms:
				children.append(null)
				break
	place_features()
	generate_rogues()


func place_features():
	var n_lifts = (3 if rooms else 2) if level < 7 else 1
	while len(lifts) < n_lifts:
		while true:
			var probe = Vector2(
				Util.randi_range(1, map.map_w - 1),
				Util.randi_range(1, map.map_h - 1))
			for l in lifts:
				if probe.distance_squared_to(l.location) < 100:
					probe = null
					break
			if probe and check_nearby(probe.x, probe.y, 2)[FLOOR] == 25:
				lifts.append(new_lift(probe))
				access[probe] = null
				break
	var n_access = Util.randi_range(4, 8)
	for _n in n_access:
		for _i in range($Caves.iterations):
			var probe = Vector2(
				Util.randi_range(1, map.map_w - 1),
				Util.randi_range(1, map.map_h - 1))
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
	var n_rogues = Util.randi_range(15, 25)
	while len(rogues) < n_rogues:
		while true:
			var probe = Vector2(
				Util.randi_range(1, map.map_w - 1),
				Util.randi_range(1, map.map_h - 1))
			if location_type(probe) != FLOOR:
				continue
			if probe.distance_squared_to(lifts[0].location) > 25:
				var r = new_feature(probe, Prototype.ROGUE)
				r.equipment.extras.append(null)
				r.level = self
				r.set_location(probe)
				r.set_sprite()
				rogues.append(r)
				break


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
	for r in rogues:
		if location == r.location:
			return ROGUE
	return WALL if map.get_cellv(location) != TileMap.INVALID_CELL else FLOOR


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
			lift.state = Lift.CLOSED
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


func _on_Background_click(position, button):
	world.player.cursor_activate(button)


func _on_Background_move(position):
	set_cursor(position_to_location(position) + Vector2(1, 1))
