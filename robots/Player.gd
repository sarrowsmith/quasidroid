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
	if level:
		check_location()
		show_stats(false)


func equip():
	.equip()
	if level:
		level.world.set_weapon()
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
const weapon_select_map = {
	weapon_select_down = -1,
	weapon_select_up = +1,
}
func _unhandled_input(event: InputEvent):
	if get_state() != IDLE:
		return
	for e in move_map:
		if event.is_action_pressed(e):
			var shift = InputEventKey and event.shift
			signalled = false
			if shift and weapons.get_range() > 1:
				shoot(move_map[e])
			else:
# warning-ignore:return_value_discarded
				action(move_map[e])
			break
	for e in click_map:
		if event.is_action_pressed(e):
			cursor_activate(click_map[e])
	for e in weapon_select_map:
		if event.is_action_pressed(e):
			combat = (combat + weapon_select_map[e]) % len(stats.equipment.weapons)
			equip()
			show_stats(true)
	if event is InputEventKey and event.pressed and event.scancode == KEY_SPACE:
		signalled = false
# warning-ignore:return_value_discarded
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
	if not level:
		return
	var location_type = level.location_type(level.cursor.location)
	var distance_squared = location.distance_squared_to(level.cursor.location)
	var in_range = distance_squared <= stats.stats.speed
	match location_type:
		Level.LIFT:
			var lift = level.lift_at(level.cursor.location)
			if lift and lift.state != Lift.LOCKED:
				location_type = Level.PLAYER
		Level.FLOOR, Level.ACCESS:
			if in_range:
				location_type = Level.PLAYER
		Level.ROGUE:
			var rogue = level.rogue_at(level.cursor.location)
			if rogue and rogue.get_state() == DEAD:
				location_type = Level.PLAYER if (in_range or (stats.stats.speed == 0 and distance_squared == 1)) else Level.ACCESS
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
					var direction = (level.cursor.location - location).normalized()
					if level.cursor.mode == "Target" and weapons.get_range() > 1:
						if direction == Vector2.ZERO:
							direction = facing
						shoot(direction)
					else:
# warning-ignore:return_value_discarded
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
				info = """[b][i]An access point[/i][/b]

Resetting all the access points on a level will unlock downwards lifts.
[b]This access point %s.[/b]

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
	level.world.show_info(info, optional)


func change_level(level: Level, fade: bool):
	set_visible(false)
	var lift = level.lifts[0]
	if self.level and self.level.parent == level:
		for i in len(level.children):
			if level.children[i] == self.level:
				lift = level.lifts[i+1]
				break
	self.level = level
	scavenge_location = Vector2.ZERO
	level_up((level.level + 1) / 2)
	level.set_cursor(lift.location)
	show_stats(true)
	level.world.show_stats(true)
	show_info()
	if not fade:
		set_location(lift.location + Vector2.DOWN)
		set_visible(true)
		return
	set_state(WAIT)
	set_location(lift.location)
	if lift.open():
		yield(lift.anim, "animation_finished")
	facing = Vector2.DOWN
	set_sprite()
	set_visible(true)
	signalled = false
	move(lift.location + Vector2.DOWN, false)
	while get_state() == WAIT:
		yield(self, "end_move")
	if lift.close():
		yield(lift.anim, "animation_finished")
	end_move(true)


func operate_lift(target: Vector2):
	var lift = level.lift_at(target)
	if lift:
		if lift.state == Lift.OPEN:
			move(target, false)
		else:
			set_state(WAIT)
			if lift.open():
				yield(lift.anim, "animation_finished")
				show_info(true)
				end_move()
			else:
				set_state(IDLE)


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
		moves = 0
		level.world.log_info("Transferring to [b]%s[/b]" % lift.level_name(lift.to))
		emit_signal("change_level", lift.to)
	else:
		recharge()
		level.set_cursor(location)
		show_info(true)
		if level.activate(location):
			level.world.log_info("""All access points on level %s reset

[b]Downwards lift%s unlocked.[/b]
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
\t[b][i]%s[/i][/b]""" % scavenged.join("\n\t"))
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
	yield(get_tree().create_timer(0.5), "timeout")
	emit_signal("move", false)


func _on_Player_end_move(_robot):
	update()
