class_name Player
extends Robot


signal move(alive)
signal change_level(level)

var scavenge_location = Vector2.ZERO


func _ready():
	weapons = $Weapons
	is_player = true
	base = "0"
	stats = Stats.new()
	stats.type_name = "Player"
	stats.baseline = stats.stats.duplicate()
	stats.equipment.weapons.append("Ion")
	add_to_group("player")


func _process(delta):
	._process(delta)
	if get_state() == WAIT:
		emit_signal("move", true)


func start():
	update()
	if moves <= 0:
		end_move(true)


func update():
	equip()
	check_location()
	show_stats(false)


func equip():
	.equip()
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
func _unhandled_input(event: InputEvent):
	if get_state() != IDLE:
		return
	var shift = InputEventKey and event.shift
	for e in move_map:
		if event.is_action_pressed(e):
			signalled = false
			if shift and weapons.get_range() > 1:
				shoot(move_map[e])
			else:
				action(move_map[e])
			break
	for e in click_map:
		if event.is_action_pressed(e):
			cursor_activate(click_map[e])
	if event is InputEventKey and event.pressed:
		match event.scancode:
			KEY_Z:
				combat = (combat + (-1 if shift else 1)) % len(stats.equipment.weapons)
				equip()
				show_stats(true)
			KEY_SPACE:
				signalled = false
				action(Vector2.ZERO)
				show_stats(true)


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
	var in_range = location.distance_squared_to(level.cursor.location) <= stats.stats.speed
	match location_type:
		Level.LIFT:
			var lift = level.lift_at(level.cursor.location)
			if lift and lift.state == Lift.OPEN:
				location_type = Level.PLAYER
		Level.FLOOR, Level.ACCESS:
			if in_range:
				location_type = Level.PLAYER
		Level.ROGUE:
			var rogue = level.rogue_at(level.cursor.location)
			if rogue and rogue.get_state() == DEAD:
				location_type = Level.PLAYER if in_range else Level.ACCESS
			elif location.x == level.cursor.location.x or location.y == level.cursor.location.y:
				if location.distance_squared_to(level.cursor.location) > 1:
					if weapons.get_range() > 1:
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
	if button == BUTTON_RIGHT or level.world.zoomed:
		show_info()
	else:
		match level.cursor.mode:
			"Info":
				show_info()
			"Move", "Target":
				if get_state() == IDLE:
					show_info()
					signalled = false
					var direction = (level.cursor.location - location).clamped(1.0)
					if level.cursor.mode == "Target" and weapons.get_range() > 1:
						if direction == Vector2.ZERO:
							direction = facing
						shoot(direction)
					else:
						action(direction)


func show_info(optional=false):
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
		Level.PLAYER:
			show_stats(true)
			return
		Level.ROGUE:
			var rogue = level.rogue_at(level.cursor.location)
			if rogue:
				rogue.show_stats(true)
				return
	if not optional:
		level.world.show_info(info)


func show_combat_mode():
	level.world.set_value("weapons", weapons.get_weapon_name(), true)


func change_level(level: Level):
	var lift = level.lifts[0]
	if self.level and self.level.parent == level:
		for i in len(level.children):
			if level.children[i] == self.level:
				lift = level.lifts[i+1]
				break
	self.level = level
	scavenge_location = Vector2.ZERO
	level_up((level.level + 1) / 2)
	set_location(lift.location + Vector2.DOWN)
	level.set_cursor(lift.location)
	show_stats(true)
	level.world.show_stats(true)
	show_info()


func check_location():
	if not level.access.has(location):
		if level.access.has(level.cursor.location):
			show_info(true)
		if location != scavenge_location:
			var rogue = level.rogue_at(location)
			if rogue:
				if rogue.get_state() == DEAD:
					scavenge(rogue)
					scavenge_location = location
				else:
					show_info()
		return
	var lift =  level.lift_at(location)
	if lift:
		end_move(true)
		level.world.log_info("Transferring to "+lift.level_name(lift.to))
		emit_signal("change_level", lift.to)
	else:
		recharge()
		level.set_cursor(location)
		show_info(true)
		if level.activate(location):
			level.world.log_info("""All access points on level %s reset

Downwards lift%s unlocked.
""" % [level.map_name, "s" if level.rooms else ""])


func recharge():
	for stat in stats.stats:
		if stats.stats[stat] < stats.baseline[stat]:
			stats.stats[stat] = stats.baseline[stat]
	show_stats(true)


func scavenge(other: Robot):
	other.show_stats(true)
	var scavenged = stats.scavenge(other)
	if len(scavenged):
		level.world.log_info("""You have scavenged:
\t%s""" % scavenged.join("\n\t"))
		moves -= 1
	else:
		level.world.show_info("Nothing worth scavenging here")
	show_stats(true)


func level_up(to: int):
	if to > stats.level:
		stats.level += 1
		for stat in stats.baseline:
			stats.baseline[stat] += 3 if stat in stats.critical_stats else 1
	recharge()


func on_die():
	set_sprite()
	yield(get_tree().create_timer(1.75), "timeout")
	emit_signal("move", false)


func _on_Player_end_move(_robot):
	update()
