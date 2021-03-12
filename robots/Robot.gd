class_name Robot
extends Node2D


enum {DEAD, IDLE, WAIT, DONE}
enum {GRAPPLE, MELEE, WEAPON}

var location = Vector2.ZERO
var level = null
var base = "2"
var mode = "Idle"
var firing = "Idle"
var facing = Vector2.DOWN
var destination = Vector2.ZERO
var sprite = null
var weapon = null
var combat = GRAPPLE
var stats = null
var moves = 0
var state = DEAD
var is_player = false
# This *must* be overridden by derived classes
var weapons = null


func _process(_delta):
	if level == null:
		return
	if mode == "Move":
		position += facing
		if position == level.location_to_position(destination):
			location = destination
			mode = "Idle"
			set_sprite()
			if not moves:
				state = DONE
			level.set_cursor()
		return
	if firing == "Fire":
		weapon.position += facing * 4
		var target = level.position_to_location(weapon.global_position)
		if level.position_to_location(weapon.position) == weapons.location:
			return
		weapons.location = target
		if not weapons.shoot():
			return
		firing = "Idle"
		weapons.location = location
		equip(true)


func turn():
	state = IDLE
	moves = stats.stats.speed


const facing_map = {
	Vector2.ZERO: "Down",
	Vector2.DOWN: "Down",
	Vector2.UP: "Up",
	Vector2.LEFT: "Left",
	Vector2.RIGHT: "Right",
}
func get_sprite(path):
	return get_node("%s/%s" % [path, facing_map[facing]])


func set_sprite():
	if sprite:
		sprite.set_visible(false)
	if weapon:
		weapon.set_visible(false)
	var dead = state == DEAD
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


func equip(on):
	set_sprite()
	if weapon:
		weapon.position = Vector2.ZERO
		weapon.set_visible(on)


func get_weapon():
	return stats.equipment.weapons[combat]


# warning-ignore:shadowed_variable
func set_location(destination):
	self.destination = destination
	location = destination
	position = level.location_to_position(location)


func move(target):
	mode = "Move"
	state = WAIT
	destination = target


func action(direction):
	if direction == null:
		if not is_player:
			return
		direction = level.cursor.location - location
	if combat >= WEAPON:
		if direction == Vector2.ZERO:
			direction = facing
		shoot(direction)
		return
	facing = direction
	var target = location + direction
	moves -= 1
	match level.location_type(target):
		Level.FLOOR, Level.ACCESS:
			move(target)
		Level.LIFT:
			if is_player:
				var lift = level.lift_at(target)
				if lift:
					if lift.state == Lift.OPEN:
						move(target)
					else:
						lift.open()
						lift.get_node("Open").connect("animation_finished", self, "lift_open", [], CONNECT_DEFERRED|CONNECT_ONESHOT)
						state = WAIT
		Level.PLAYER:
			if is_player:
				if not moves:
					state = DONE
			else:
				attack(level.world.player)
		Level.ROGUE:
			if is_player:
				var rogue = level.rogue_at(target)
				if rogue:
					if rogue.state == DEAD:
						move(target)
					else:
						attack(rogue)
		_:
			moves += 1 # because we've already paid for the move, pay back the no-op
	set_sprite()


func lift_open():
	state = DONE


func shoot(direction):
	facing = direction
	firing = "Fire"
	weapons.location = location + direction
	state = WAIT
	moves -= 1
	equip(true)


const item_name_map = {
	drive = ["none", "basic", "improved", "advanced"],
	armour = ["none", "standard", "ablative", "active"],
}
func item_to_string(item):
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
	else:
		level.world.set_value("Type", "%s (%d)" % [stats.type_name, stats.level], false)
	if visible:
		level.world.show_stats(is_player)


func shot():
	hit(3)


func attack(other):
	state = WAIT
	return grapple(other) if combat == GRAPPLE else melee(other)


func grapple(other):
	other.hit(1)
	hit(1)


func melee(other):
	other.hit(2)


func hit(count):
	var zapped = get_sprite("Robot/Hit")
	if not zapped:
		return
	level.world.player.state = WAIT
	zapped.set_visible(true)
	zapped.play()
	while count > 0:
		yield(zapped, "animation_finished")
		count -= 1
	zapped.stop()
	zapped.set_visible(false)
	level.world.player.state = IDLE if level.world.player.moves else DONE
	state = IDLE if moves else DONE
