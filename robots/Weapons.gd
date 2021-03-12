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


func get_weapon_name():
	return stats_map[owner.get_weapon()][0]


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
				owner.state = Robot.IDLE if owner.moves else Robot.DONE # Otherwise handled by shot->hit
		Level.PLAYER:
			if owner.is_player:
				return false
			attack(owner.level.world.player)
		Level.ROGUE:
			var rogue = owner.level.rogue_at(location)
			if rogue and rogue != owner:
				attack(rogue)
				return splash()
	return true


func splash():
	match owner.get_weapon():
		"Dual", "Ion":
			for r in owner.level.rogues:
				if location.distance_squared_to(r.location) < 4:
					attack(r)
		"Laser":
			return false
	return true


func attack(other):
	var ours = owner.stats.stats.duplicate()
	var theirs = other.stats.stats.duplicate()
	match get_damage_type():
		GRAPPLE:
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
	owner.level.world.report_attack(owner, other, ours, theirs)


# There's all sorts of possibilities for adjusting the deviation on
# these random distributions that I've not got time to get my head
# round right now. Just throwing some wild guesses in.
# (The idea behind using health is the "desperate fight".)

func grapple_effect(stats, initiative=0):
	# weight penalty is effectively a trade off against armour and speed
	return owner.level.rng(stats.logic * (initiative +  stats.power) / stats.weight(), 0.1 + log(stats.health()))


func modify_attack(theirs):
	var ours = owner.stats
	var ac = get_armour_required()
	var attack = 1 + ours.stats.strength - theirs.equipment.armour
	if theirs.equipment.armour >= ac:
		attack -= theirs.protection - 2
	return attack


func attack_a(other):
	var attack = modify_attack(other.stats)
	for k in other.stats:
		var defence = other.stats[k] / 3.0 if k in Stats.critical_stats else other.stats[k]
		if defence > 0 and owner.level.rng(attack / defence) > 0.5:
			other.stats[k] -= 1


func attack_b(other):
	var attack = modify_attack(other.stats)
	var vulnerabilities = []
	for stat in other.stats:
		vulnerabilities.append([other.stats[stat], stat])
	vulnerabilities.sort()
	while attack > 0 and not other.stats.disabled():
		for v in vulnerabilities:
			other[v[1]] -= (owner.level.rng(attack, 0.1 + log(other.stats.health())) if v[1] in Stats.critical_stats else 1)
			if attack == 0 or other.stats.disabled():
				break
			attack -= 1


func grapple(other):
	var attack = grapple_effect(other.stats, 1)
	var defence = grapple_effect(owner.stats, 0)
	# TODO: work out how to turn attack - defence into damage


func probe(other):
	other.stats.logic -= owner.level.rng.randfn(owner.stats.strength, 0.1 + log(other.stats.health))


func projectile(other):
	var attack = modify_attack(other.stats)
	if attack > 0:
		other.stats.protection -= owner.level.rng(attack, 0.1 + other.equipment.armour)
		other.stats.chassis -= owner.level.rng(attack, log(1.1 + other.equipment.protection))
		if other.equipment.armour > 0 and owner.level.rng(attack) > attack:
			other.equipment.armour -= 1


func emp(other):
	var attack = modify_attack(other.stats)
	if attack > 0:
		other.stats.logic -= owner.level.rng(attack, log(other.stats.logic))
		other.stats.power -= owner.level.rng(attack, log(other.stats.chassis))

