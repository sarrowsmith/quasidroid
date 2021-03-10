extends Robot


signal move(position)


enum {GRAPPLE, MELEE, WEAPON}

var combat = GRAPPLE


func _ready():
	base = "0"
	equipment["weapon"] = "Plasma"
	turn(true)


func _process(delta):
	._process(delta)
	if state == WAIT:
		emit_signal("move", position)


func turn(init=false):
	.turn()
	if combat == WEAPON:
		combat = GRAPPLE
	equip(init)
	show_stats(false)


func equip(init=false):
	.equip(combat == WEAPON and not $Weapons.melee)
	if not init:
		show_combat_mode()
		set_cursor()


func change_level(level):
	self.level = level
	set_location(level.lifts[0].location + Vector2.DOWN)
	level.set_cursor(level.lifts[0].location)
	show_combat_mode()
	show_stats(true)
	level.world.show_stats(true)


const move_map = {
	"move_up": Vector2.UP,
	"move_down": Vector2.DOWN,
	"move_left": Vector2.LEFT,
	"move_right": Vector2.RIGHT
}
func _unhandled_input(event):
	if state != IDLE:
		return
	for e in move_map:
		if event.is_action_pressed(e):
			if combat == WEAPON:
				fire(move_map[e])
				break
			move(move_map[e])
	if event is InputEventKey and event.pressed:
		match event.scancode:
			KEY_Z:
				combat = (combat + 1) % 3
				equip()


const cursor_types = {
	Level.FLOOR: "Default",
	Level.WALL: null,
	Level.LIFT: "Info",
	Level.ACCESS: "Info",
	Level.PLAYER: "Move",
	Level.ROGUE: "Target"
}
func set_cursor():
	var location_type = level.location_type(level.cursor.location)
	match location_type:
		Level.LIFT:
			var lift = level.lift_at(level.cursor.location)
			if lift and lift.open:
				location_type = Level.PLAYER
		Level.FLOOR, Level.ACCESS:
			if location.distance_squared_to(level.cursor.location) <= stats["speed"]:
				location_type = Level.PLAYER
		Level.ROGUE:
			if location.x == level.cursor.location.x or location.y == level.cursor.location.y:
				if location.distance_squared_to(level.cursor.location) > 1:
					if combat == WEAPON:
						if location.x == level.cursor.location.x:
							for y in range(min(location.y, level.cursor.location.y), max(location.y, level.cursor.location.y)):
								if y != location.y and y != level.cursor.location.y and level.location_type(Vector2(location.x, y)) != Level.FLOOR:
									location_type = Level.ACCESS
									break
						if location.y == level.cursor.location.y:
							for x in range(min(location.x, level.cursor.location.x), max(location.x, level.cursor.location.x)):
								if x != location.x and x != level.cursor.location.x and level.location_type(Vector2(x, location.y)) != Level.FLOOR:
									location_type = Level.ACCESS
									break
					else:
						location_type = Level.ACCESS
			else:
				location_type = Level.ACCESS
	level.cursor.set_mode(cursor_types[location_type])


func cursor_active(button):
	var location_type = level.location_type(level.cursor.location)
	match level.cursor.mode:
		"Info":
			pass
		"Move":
			pass
		"Target":
			pass


func show_info():
	pass


func show_combat_mode():
	var mode = "Ram"
	if combat == GRAPPLE:
		mode = "Grapple"
	elif equipment.weapon and (combat == MELEE if $Weapons.melee else combat == WEAPON):
		mode = equipment.weapon
	level.world.set_value("Combat", mode, true)
