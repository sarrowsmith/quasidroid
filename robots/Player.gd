extends Robot


signal move(position)


func _ready():
	weapons = $Weapons
	is_player = true
	base = "0"
	equipment.weapon = "Laser"


func _process(delta):
	._process(delta)
	if state == WAIT:
		emit_signal("move", position)


func turn():
	.turn()
	if combat == WEAPON:
		combat = GRAPPLE
	equip()
	check_location()
	show_stats(false)


func equip(_auto=true):
	.equip(combat == WEAPON and not $Weapons.melee)
	show_combat_mode()
	set_cursor()


const move_map = {
	move_up = Vector2.UP,
	move_down = Vector2.DOWN,
	move_left = Vector2.LEFT,
	move_right = Vector2.RIGHT
}
const click_map = {
	cursor_select = BUTTON_LEFT,
	cursor_option = BUTTON_RIGHT,
}
func _unhandled_input(event):
	if state != IDLE:
		return
	for e in move_map:
		if event.is_action_pressed(e):
			action(move_map[e])
			break
	for e in click_map:
		if event.is_action_pressed(e):
			cursor_activate(click_map[e])
	if event is InputEventKey and event.pressed:
		match event.scancode:
			KEY_Z:
				combat = (combat + 1) % 3
				equip()


const cursor_types = {
	Level.FLOOR: "Default",
	Level.WALL: "Wall",
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
			if lift and lift.state == Lift.OPEN:
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


func cursor_activate(button):
	if button == BUTTON_RIGHT:
		show_info()
	else:
		match level.cursor.mode:
			"Info":
				show_info()
			"Move", "Target":
				if state == IDLE:
					action(null)


func show_info():
	var info = "Nothing to see here"
	var location_type = level.location_type(level.cursor.location)
	match location_type:
		Level.LIFT:
			var lift = level.lift_at(level.cursor.location)
			if lift:
				info = lift.get_info()
		Level.ACCESS:
			var ap = level.access[level.cursor.location]
			if ap:
				info = """An access point

Resetting all the access points on a level will unlock downwards lifts.
This access point %s.

You can also recharge here.
""" % ("has been reset" if ap.active else "is being reset" if level.cursor.location == location else "needs resetting")
		Level.PLAYER, Level.ROGUE:
			show_stats(true)
			return
	level.world.show_position()
	level.world.show_info(info)


func show_combat_mode():
	var mode = "Ram"
	if combat == GRAPPLE:
		mode = "Grapple"
	elif equipment.weapon and (combat == MELEE if $Weapons.melee else combat == WEAPON):
		mode = equipment.weapon
	level.world.set_value("Combat", mode, true)


func change_level(level):
	self.level = level
	set_location(level.lifts[0].location + Vector2.DOWN)
	level.set_cursor(level.lifts[0].location)
	show_combat_mode()
	show_stats(true)
	level.world.show_stats(true)


func check_location():
	if not level.access.has(location):
		return
	var lift =  level.lift_at(location)
	if lift:
		change_level(lift.to)
	else:
		#recharge
		level.set_cursor(location)
		show_info()
		level.activate(location)
