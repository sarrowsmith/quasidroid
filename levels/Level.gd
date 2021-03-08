class_name Level
extends Node2D


export(int) var level_seed = 0
export(bool) var rooms = false
export(int) var level = 0

enum Prototype {CAVES, ROOMS, LIFT, ACCESS}

var world = null
var parent = null
var children = null
var prototypes = null
var lifts = []
var access = {}


func _ready():
	prototypes = [
		load("res://levels/CavesLevel.tscn"),
		load("res://levels/RoomsLevel.tscn"),
		load("res://levels/Lift.tscn"),
		load("res://levels/AccessPoint.tscn"),
	]


func create(from):
	set_visible(false)
	parent = from
	if parent == null:
		level = 1
		world = owner
	else:
		level = parent.level + 1
		prototypes = parent.prototypes
		world = parent.world
	level_seed = randi()


func generate():
	set_visible(true)
	if children:
		return
	seed(level_seed)
	$Map.generate()
	if level == 7:
		children = [null, null]
	else:
		children = []
		for i in [Prototype.CAVES, Prototype.ROOMS if level < 6 else Prototype.CAVES]:
			var child = prototypes[i].instance()
			child.rooms = i == Prototype.ROOMS
			child.create(self)
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
				Util.randi_range(1, $Map.map_w - 1),
				Util.randi_range(1, $Map.map_h - 1))
			if check_nearby(probe.x, probe.y, 2) == 0:
				lifts.append(new_lift(probe))
				break
	var n_access = Util.randi_range(5, 9)
	for _i in n_access:
		while true:
			var probe = Vector2(
				Util.randi_range(1, $Map.map_w - 1),
				Util.randi_range(1, $Map.map_h - 1))
			var adjacencies = check_nearby(probe.x, probe.y, 1)
			if 0 < adjacencies and adjacencies < 5:
				access[probe] = new_feature(probe, Prototype.ACCESS)
				break


func check_nearby(x, y, r):
	var count = 0
	for i in 2*r:
		for j in 2*r:
			if $Map.get_cell(x+i-r, y+j-r) != TileMap.INVALID_CELL:
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
		$Map.set_cellv(location + o, $Map.Tiles.ROOF)
		$Map.update_bitmask_area(location + o)
	return lift


func new_feature(location, type):
	var feature = prototypes[type].instance()
	feature.position = location_to_position(location)
	return feature


func location_to_position(location):
	return $Map.map_to_world(location)

func _on_Background_click(position, button):
	print($Map.world_to_map(position))


func _on_Background_move(position):
	pass
