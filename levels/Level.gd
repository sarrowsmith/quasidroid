class_name Level
extends Node2D


export(int) var level_seed = 0
export(bool) var rooms = false
export(int) var level = 0

enum Prototype {LEVEL, LIFT, ACCESS}

var map = null
var world = null
var parent = null
var children = null
var prototypes = null
var lifts = []
var access = {}
var map_name = ""


func _ready():
	prototypes = [
		load("res://levels/Level.tscn"),
		load("res://levels/Lift.tscn"),
		load("res://levels/AccessPoint.tscn"),
	]


func create(from, rooms):
	set_visible(false)
	map = get_node("Rooms" if rooms else "Caves")
	map.set_visible(true)
	parent = from
	self.rooms = rooms
	if parent == null:
		level = 1
		world = owner
		map_name = "1"
	else:
		level = parent.level + 1
		prototypes = parent.prototypes
		world = parent.world
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


func place_features():
	var n_lifts = (3 if rooms else 2) if level < 7 else 1
	while len(lifts) < n_lifts:
		while true:
			var probe = Vector2(
				Util.randi_range(1, map.map_w - 1),
				Util.randi_range(1, map.map_h - 1))
			if check_nearby(probe.x, probe.y, 2) == 0:
				lifts.append(new_lift(probe))
				access[probe] = null
				break
	var n_access = Util.randi_range(5, 9)
	for _i in n_access:
		while true:
			var probe = Vector2(
				Util.randi_range(1, map.map_w - 1),
				Util.randi_range(1, map.map_h - 1))
			var adjacencies = check_nearby(probe.x, probe.y, 1)
			if 0 < adjacencies and adjacencies < 5:
				access[probe] = new_feature(probe, Prototype.ACCESS)
				break


func check_nearby(x, y, r):
	var count = 0
	for i in 2*r:
		for j in 2*r:
			var cell = Vector2(x+i-r, y+j-r)
			if map.get_cellv(cell) != TileMap.INVALID_CELL or access.has(cell):
				count += 1
	return count


func new_lift(location):
	var lift = new_feature(location, Prototype.LIFT)
	lift.location = location
	lift.from = self
	if len(lifts) == 0:
		lift.to = parent
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


func _on_Background_click(position, button):
	print(map.world_to_map(position))


func _on_Background_move(position):
	pass
