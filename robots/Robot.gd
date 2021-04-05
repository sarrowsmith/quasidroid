class_name Robot
extends Node2D


signal end_move(robot)

enum {DEAD, IDLE, WAIT, DONE}
enum {GRAPPLE, MELEE, WEAPON}

export(float) var move_speed = 25
export(float) var weapon_speed = 200

var location = Vector2.ZERO
var level = null
var base = "2"
var mode = "Idle"
var firing = "Idle"
var facing = Vector2.DOWN
var destination = Vector2.ZERO
var sprite: Node2D = null
var weapon: Node2D = null
var combat = MELEE
var stats = null
var moves = 0
var state = DONE
var signalled = false
# This *must* be overridden by derived classes
var weapons = null
var is_player = false


func set_state(value):
	state = value

func get_state():
	return state

func end_move(end_turn=false):
	if stats.stats.speed < 1:
		stats.stats.speed = 0
	if end_turn:
		moves = 0
	if state == DEAD:
		return
	if moves > 0:
		if state == WAIT:
			state = IDLE
	else:
		moves = 0
		state = DONE
	if not signalled:
		emit_signal("end_move", self)
		signalled = true


func _process(delta):
	if not level or get_state() == DEAD:
		return
	if mode == "Move":
		var target = level.location_to_position(destination)
		var to_go = position.distance_squared_to(target)
		position += facing * move_speed * delta * ((0 if stats.stats.speed < 1 else 3) + stats.stats.speed)
		var current = position.distance_squared_to(target)
		if to_go < current or current < 4:
			set_location(destination)
			mode = "Idle"
			set_sprite()
			end_move()
			if is_player and moves > 0:
				show_stats(true)
				# Yes, this is us, but the indirection sorts the type out
				level.world.player.check_location()
			level.set_cursor(Vector2.ZERO)
		return
	if firing == "Fire":
		weapon.position += facing * weapon_speed * delta
		var target = level.position_to_location(weapon.global_position)
		if target.distance_squared_to(weapons.location) < 1:
			return
		weapons.location = target
		if not weapons.shoot():
			return
		firing = "Idle"
		weapons.location = location
		equip()


func turn() -> bool:
	if is_player:
		pass
	signalled = false
	if state == DEAD:
		return true
	if level and stats.implicit_damage(is_player, level.world):
		if check_stats():
			var display_name = "You" if is_player else ("A " +  stats.type_name)
			level.world.report_deactivated(display_name, is_player)
		hit(1, false)
	if state == DONE:
		set_state(IDLE)
		moves = max(stats.stats.speed, 1)
	return false


const facing_map = {
	Vector2.ZERO: "Down",
	Vector2.DOWN: "Down",
	Vector2.UP: "Up",
	Vector2.LEFT: "Left",
	Vector2.RIGHT: "Right",
	Vector2(1, 1): "Down",
	Vector2(-1, 1): "Down",
	Vector2(1, -1): "Right",
	Vector2(-1, -1): "Left",
}
func unit(v: Vector2) -> Vector2:
	return Vector2(int(sign(v.x)), int(sign(v.y)))
func get_sprite(path: String) -> Node:
	return get_node("%s/%s" % [path, facing_map[unit(facing)]])


func set_sprite():
	if sprite:
		sprite.set_visible(false)
	if weapon:
		weapon.set_visible(false)
	var dead = get_state() == DEAD
	var path = "Robot/Dead" if dead else base
	if stats.equipment.extras:
		path += "-X"
	sprite = get_node(path) if dead else get_sprite("Robot/%s/%s" % [path, mode])
	sprite.set_visible(true)
	if dead or combat < WEAPON:
		if weapon:
			weapon.set_visible(false)
			weapon = null
		return
	weapon = get_sprite("Weapons/%s/%s" % [get_weapon(), firing])
	if weapon:
		weapon.position = Vector2.ZERO
		weapon.set_visible(true)


func equip():
	set_sprite()


func get_weapon() -> String:
	return stats.equipment.weapons[combat]


# warning-ignore:shadowed_variable
func set_location(destination: Vector2):
	self.destination = destination
	location = destination
	position = level.location_to_position(location)


func target():
	return location + facing


func move(target: Vector2, check_speed: bool):
	if stats.stats.speed < 1:
		if check_speed:
			stats.stats.speed = 0
			end_move(true)
			return
		stats.stats.speed = max(stats.stats.speed, 0.8)
	mode = "Move"
	set_state(WAIT)
	destination = target


func shoot(direction: Vector2):
	facing = direction
	firing = "Fire"
	set_sprite()
	if weapon:
		weapons.location = target()
		set_state(WAIT)
		moves -= 1
	else: # no idea how this can happen, but I suspect in does
		firing = "Idle"
		set_sprite()


func action(direction: Vector2, really=true) -> int: # -> enum
	facing = direction
	var target = target()
	if really:
		moves -= 1
	var target_type = level.location_type(target)
	match target_type:
		Level.FLOOR, Level.ACCESS:
			if really:
				move(target, target_type == Level.FLOOR)
		Level.LIFT:
			if is_player:
				level.world.player.operate_lift(target)
		Level.PLAYER:
			if is_player:
				end_move()
			else:
				while combat > MELEE and weapons.get_range() > 1:
					combat -= 1
				weapons.attack(level.world.player)
				combat = len(stats.equipment.weapons) - 1
		Level.ROGUE:
			if is_player:
				var rogue = level.rogue_at(target)
				if rogue:
					if rogue.get_state() == DEAD:
						move(target, false)
					else:
						weapons.attack(rogue)
		_:
			if really:
				moves += 1 # because we've already paid for the move, pay back the no-op
	set_sprite()
	return target_type


const item_name_map = {
	drive = ["none", "basic", "improved", "advanced"],
	armour = ["none", "standard", "ablative", "active"],
}
func item_to_string(item: String) -> String:
	match item:
		"extras":
			if stats.equipment.extras:
				return PoolStringArray(stats.equipment.extras).join(", ")
			return "none"
		"weapons":
			return weapons.get_weapon_name()
	return item_name_map[item][stats.equipment[item]]


func show_stats(visible=false):
	if not level:
		return
	for stat in stats.stats:
		level.world.set_value(stat, stats.stats[stat], is_player)
	for item in stats.equipment:
		level.world.set_value(item, item_to_string(item), is_player)
	if is_player:
		level.world.set_value("Moves", moves, true)
	elif stats.level:
		level.world.set_value("Type", "%s (%d)" % [stats.type_name, stats.level], false)
	else:
		level.world.set_value("Type", "%s +" % stats.type_name, false)
	if visible:
		level.world.show_stats(is_player)


func hit(count: int, end_if_disabled=true):
	var zapped = get_sprite("Robot/Hit")
	if zapped:
		zapped.set_visible(true)
		zapped.play()
		for _i in count:
			yield(zapped, "animation_finished")
		zapped.stop()
		zapped.set_visible(false)
	if get_state() == DEAD:
		die()
	elif end_if_disabled and stats.stats.speed == 0:
		end_move(true)


func die():
	var die = get_node("Robot/%s%s/Die" % [base, "-X" if stats.equipment.extras else ""])
	if sprite:
		sprite.set_visible(false)
	if weapon:
		weapon.set_visible(false)
	if die:
		die.set_visible(true)
		die.play()
		yield(die, "animation_finished")
		die.set_visible(false)
	on_die()


func on_die():
	set_sprite()


func check_stats() -> bool:
	if get_state() == DEAD or stats.disabled():
		set_state(DEAD)
		combat = MELEE
		return true
	if combat >= len(stats.equipment.weapons):
		if is_player:
			combat = GRAPPLE
		equip()
	if stats.stats.speed == 0:
		end_move(true)
	return false


func load(file: File):
	set_location(file.get_var())
	facing = file.get_var()
	set_state(file.get_8())
	moves = file.get_8()
	stats.load(file)
	if check_stats():
		set_sprite()
	else:
		equip()


func save(file: File):
	file.store_var(location)
	file.store_var(facing)
	file.store_8(get_state())
	file.store_8(moves)
	stats.save(file)
