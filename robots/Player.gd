extends Robot


signal move(position)
signal change_level(level)

var baseline = null


func _ready():
	weapons = $Weapons
	is_player = true
	base = "0"
	stats = Stats.new()
	stats.equipment.weapons.append("Plasma")
	baseline = stats.stats.duplicate()
	add_to_group("player")


func _process(delta):
	._process(delta)
	if state == WAIT:
		emit_signal("move", position)


func turn():
	.turn()
	update()


func update():
	if combat >= WEAPON:
		combat = GRAPPLE
	equip()
	check_location()
	show_stats(false)


func equip(_auto=true):
	.equip(combat >= WEAPON)
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
				combat = (combat + 1) % len(stats.equipment.weapons)
				equip()
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
	match location_type:
		Level.LIFT:
			var lift = level.lift_at(level.cursor.location)
			if lift and lift.state == Lift.OPEN:
				location_type = Level.PLAYER
		Level.FLOOR, Level.ACCESS:
			if location.distance_squared_to(level.cursor.location) <= stats.stats.speed:
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
		Level.PLAYER:
			show_stats(true)
			return
		Level.ROGUE:
			var rogue = level.rogue_at()
			if rogue:
				rogue.show_stats(true)
				return
	level.world.show_info(info)


func show_combat_mode():
	level.world.set_value("weapons", stats.equipment.weapons[combat], true)


func change_level(level):
	var lift = level.lifts[0]
	if self.level and self.level.parent == level:
		for i in len(level.children):
			if level.children[i] == self.level:
				lift = level.lifts[i+1]
				break
	self.level = level
	level_up((level.level + 1) / 2)
	set_location(lift.location + Vector2.DOWN)
	level.set_cursor(lift.location)
	show_stats(true)
	level.world.show_stats(true)
	show_info()


func check_location():
	if not level.access.has(location):
		var rogue = level.rogue_at(location)
		if rogue and rogue.state == DEAD:
			scavenge(rogue)
		if level.access.has(level.cursor.location):
			show_info()
		return
	var lift =  level.lift_at(location)
	if lift:
		state = DONE
		emit_signal("change_level", lift.to)
	else:
		recharge()
		level.set_cursor(location)
		show_info()
		if level.activate(location):
			level.world.show_info("""All access points on level %s reset

Downwards lift%s unlocked.
""" % [level.map_name, "s" if level.rooms else ""], true)


func recharge():
	for stat in stats.stats:
		if stats.stats[stat] < baseline[stat]:
			stats.stats[stat] = baseline[stat]
	show_stats(true)


func scavenge(other):
	other.show_stats(true)
	var theirs = other.stats.equipment.duplicate()
	var ours = stats.equipment
	for i in len(theirs.weapons):
		if not theirs.weapons[i] in ours.weapons:
			ours.weapons.append(theirs.weapons[i])
			other.stats.equipment.weapons.remove(i)
	for i in len(theirs.equipment):
		if not theirs.equipment[i] in ours.equipment:
			ours.equipment.append(theirs.equipment[i])
			other.stats.equipment.equipment.remove(i)
	if theirs.drive > ours.drive:
		ours.drive = theirs.drive
	if theirs.armour > ours.armour:
		ours.armour = theirs.armour


func level_up(to):
	if to > stats.level:
		stats.level += 1
		for stat in baseline:
			baseline[stat] += 3 if stat in stats.critical_stats else 1
	recharge()
