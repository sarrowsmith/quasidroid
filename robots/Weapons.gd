extends Node2D


enum {GRAPPLE, RAM, BLADE, PROBE, PROJECTILE, EMP}

const stats_map = {
	Grapple = ["grapple", GRAPPLE, 1],
	Ram = ["ram", RAM, 1],
	Blade = ["thermal lance", BLADE, 1],
	Probe = ["logic probe", PROBE, 1],
	Plasma = ["plasma beam", BLADE, 6],
	Laser = ["laser", BLADE, 6],
	Dual = ["plasma barrage", BLADE, 6],
	Ion = ["ion cannon", RAM, 6],
	Projectile = ["rail gun", PROJECTILE, 6],
	EMP = ["EMP", EMP, 6],
}

var location = Vector2.ZERO


func get_weapon_name():
	return stats_map[owner.get_weapon()][0]


func get_damage_type():
	return stats_map[owner.get_weapon()][1]


func get_range():
	return stats_map[owner.get_weapon()][2]


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
			owner.level.world.player.shot(owner)
		Level.ROGUE:
			var rogue = owner.level.rogue_at(location)
			if rogue and rogue != owner:
				rogue.shot(owner)
				return splash()
	return true


func splash():
	match owner.get_weapon():
		"Dual", "Ion":
			for r in owner.level.rogues:
				if location.distance_squared_to(r.location) < 4:
					r.shot(owner)
		"Laser":
			return false
	return true


#func grapple_effect(owner, initiative=0):
#	# should be random with bias
#	# weight penalty is effectively a trade off against armour and speed
#	return owner['logic'] * (initiative +  owner['power']) / owner.weight()
#
#
#func attack(owner, other):
#	if owner.weapon is None:
#		ram(owner, other)
#	else:
#		owner.weapon(owner, other)
#
#
#func modify_attack(owner, other, ac):
#	attack = 1 + owner['weapon'] - other.armour
#	if other.armour >= ac:
#		attack -= other['armour'] - 2
#	return attack
#
#
#func attack_a(owner, other, ac):
#	var attack = modify_attack(owner, other, ac)
#	for k in defender.stats:
#		var defence = defender[k] / 3 if k in critical_stats else defender[k]
#		if defence > 0 and attack / defence > 0.5: # should be probability
#			defender[k] -= 1
#
#
#func attack_b(owner, other, ac, reversed=false):
#	# TODO: some randomness here would be nice (decrease effectiveness of attack)
#	var attack = modify_attack(owner, other, ac)
#	var vulnerabilities = other.stats.items #list(order(sorted( (v, k) for k, v in other.stats.items() )))
#	while attack > 0 and not other.disabled():
#		for v in vulnerabilities:
#			other[v[1]] -= (attack if v[1] in critical_stats else 1)
#			if attack == 0 or other.disabled():
#				break
#			attack -= 1
#
#
#func ram(attacker, defender):
#	attacker.attack_a(defender, 1)
#
#
#func grapple(attacker, defender):
#	var attack = grapple(attacker, 1)
#	var defence = grapple(defender, 0)
#	# TODO: work out how to turn attack - defence into damage
#
#
#func probe(attacker, defender):
#	defender['logic'] = defender['logic'] - attacker['weapon']
#
#
#func blade(attacker, defender):
#	attacker.attack_b(defender, 1)
#
#
#func plasma(attacker, defender):
#	attacker.attack_b(defender, 2)
#
#
#func multi(attacker, defender):
#	attacker.attack_b(defender, 2)
#
#
#func laser(attacker, defender):
#	attacker.attack_b(defender, 2, order=reversed)
#
#
#func ion_cannon(attacker, defender):
#	attacker.attack_a(defender, 3)
#
#
#func projectile(attacker, defender):
#	attack = attacker.modify_attack(defender, 1)
#	if attack > 0:
#		defender['chassis'] -= attack
#		if defender['armour'] > 0:
#			defender['armour'] -= 1
#
#
#func emp(attacker, defender):
#	attack = attacker.modify_attack(defender, 3)
#	if attack > 0:
#		defender['logic'] -= attack
#
