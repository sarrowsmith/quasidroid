extends Node2D


enum {GRAPPLE, RAM, BLADE, PROBE, PROJECTILE, EMP}

const stats_map = {
	Grapple = ["grapple", GRAPPLE, 1, 0],
	Ram = ["ram", RAM, 1, 1],
	Blade = ["thermal lance", BLADE, 1, 1],
	Probe = ["logic probe", PROBE, 1, 0],
	Plasma = ["plasma beam", BLADE, 6, 2],
	Laser = ["laser", BLADE, 6, 2],
	Dual = ["plasma barrage", BLADE, 6, 2],
	Ion = ["ion cannon", RAM, 6, 3],
	Projectile = ["rail gun", PROJECTILE, 6, 1],
	EMP = ["EMP", EMP, 6, 3],
}

var location = Vector2.ZERO


func get_weapon_name(weapon=null):
	if not weapon:
		weapon = owner.get_weapon()
	return stats_map[weapon][0]


func get_damage_type():
	return stats_map[owner.get_weapon()][1]


func get_range():
	return stats_map[owner.get_weapon()][2]


func get_armour_required():
	return stats_map[owner.get_weapon()][3]


func shoot():
	match owner.level.location_type(location):
		Level.FLOOR:
			var weapon_range = get_range()
			if location.distance_squared_to(owner.location) < weapon_range * weapon_range:
				return false
			else:
				owner.end_move() # Otherwise handled by shot->hit
		Level.PLAYER:
			if owner.is_player:
				return false
			attack(owner.level.world.player)
		Level.ROGUE:
			var rogue = owner.level.rogue_at(location)
			if rogue and rogue != owner and rogue.get_state() != Robot.DEAD:
				return splash(rogue)
		_:
			owner.end_move()
	return true


func splash(rogue):
	match owner.get_weapon():
		"Dual", "Ion":
			for r in owner.level.rogues:
				if location.distance_squared_to(r.location) < 4:
					attack(r)
		"Laser":
			attack(rogue)
			return false
		_:
			attack(rogue)
	return true


func attack(other):
	if other.get_state() == Robot.DEAD:
		return
	var ours = null
	var theirs = other.stats.stats.duplicate()
	match get_damage_type():
		GRAPPLE:
			ours = owner.stats.stats.duplicate()
			other.hit(1)
			owner.hit(1)
			grapple(other)
		RAM:
			other.hit(2)
			attack_a(other)
		BLADE:
			other.hit(3)
			attack_b(other)
		PROBE:
			other.hit(2)
			probe(other)
		PROJECTILE:
			other.hit(3)
			projectile(other)
		EMP:
			other.hit(4)
			emp(other)
	other.stats.normalise(theirs)
	if ours:
		owner.stats.normalise(ours)
	owner.level.world.report_attack(owner, other, ours, theirs)


# There's all sorts of possibilities for adjusting the deviation on
# these random distributions that I've not got time to get my head
# round right now. Just throwing some wild guesses in.
# (The idea behind using health is the "desperate fight".)

func grapple_effect(stats, initiative=0):
	# weight penalty is effectively a trade off against armour and speed
	return owner.level.rng.randfn(stats.stats.logic * (initiative +  stats.stats.power) / stats.weight(), 0.1 + log(stats.health()))


func modify_attack(theirs):
	var ours = owner.stats
	var ac = get_armour_required()
	var attack = 1 + ours.stats.strength - theirs.equipment.armour
	if theirs.equipment.armour >= ac:
		attack -= theirs.stats.protection - 2
	if get_range() == 1:
		attack += 1
	return attack


func attack_a(other):
	var attack = modify_attack(other.stats)
	for k in other.stats.stats:
		if other.stats.stats[k] <= 0:
			continue
		var defence = other.stats.stats[k] / 3.0 if k in Stats.critical_stats else other.stats.stats[k]
		if defence > 0 and owner.level.rng.randfn(attack / defence) > 0.5:
			other.stats.stats[k] -= 1


func attack_b(other):
	var attack = modify_attack(other.stats)
	var vulnerabilities = []
	for stat in other.stats.stats:
		vulnerabilities.append([other.stats.stats[stat], stat])
	vulnerabilities.sort()
	while attack > 0 and not other.stats.disabled():
		for v in vulnerabilities:
			var k = v[1]
			if other.stats.stats[k] <= 0:
				continue
			other.stats.stats[k] -= (owner.level.rng.randfn(attack, 0.1 + log(other.stats.health())) if v[1] in Stats.critical_stats else 1)
			if attack == 0 or other.stats.disabled():
				break
			attack -= 1


func grapple(other):
# warning-ignore:unused_variable
	var attack = grapple_effect(other.stats, 1)
# warning-ignore:unused_variable
	var defence = grapple_effect(owner.stats, 0)
	# TODO: work out how to turn attack - defence into damage


func probe(other):
	other.stats.stats.logic -= owner.level.rng.randfn(owner.stats.stats.strength, 0.1 + log(other.stats.health()))


func projectile(other):
	var attack = modify_attack(other.stats)
	if attack > 0:
		other.stats.stats.protection -= owner.level.rng.randfn(attack, 0.1 + other.stats.equipment.armour)
		other.stats.stats.chassis -= owner.level.rng.randfn(attack, log(1.1 + other.stats.stats.protection))
		if other.stats.equipment.armour > 0 and owner.level.rng.randfn(attack) > attack:
			other.stats.equipment.armour -= 1


func emp(other):
	var attack = modify_attack(other.stats)
	if attack > 0:
		other.stats.stats.logic -= owner.level.rng.randfn(attack, log(other.stats.stats.logic))
		other.stats.stats.power -= owner.level.rng.randfn(attack, log(other.stats.stats.chassis))

