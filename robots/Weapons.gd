extends Node2D


enum {GRAPPLE, RAM, BLADE, PROBE, PROJECTILE, EMP}

const stats_map = {
	Grapple = ["grapple", GRAPPLE],
	Ram = ["ram", RAM],
	Blade = ["thermal lance", BLADE],
	Probe = ["logic probe", PROBE],
	Plasma = ["plasma beam", BLADE],
	Laser = ["laser", BLADE],
	Dual = ["plasma barrage", BLADE],
	Ion = ["ion cannon", RAM],
	Projectile = ["rail gun", PROJECTILE],
	EMP = ["EMP", EMP],
}

var location = Vector2.ZERO


func get_weapon_name():
	return stats_map[owner.get_weapon()][0]


func get_damage_type():
	return stats_map[owner.get_weapon()][1]


func shoot():
	match owner.level.location_type(location):
		Level.FLOOR:
			if location.distance_squared_to(owner.location) < owner.stats.weapon * owner.stats.weapon:
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


