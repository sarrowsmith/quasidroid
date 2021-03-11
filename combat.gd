class Bot:
	critical_stats = ('chassis', 'power', 'logic')
	def __init__(self, name, **stats):
		self.stats = {
			'chassis': 3,
			'power': 3,
			'drive_type': 1,
			'logic': 3,
			'weapon_type': None,
			'weapon': 1,
			'armour_type': 0,
			'armour': 1,
			'special_type': None
		}
		self.name = name
		self.stats.update(stats)
		self.equipment = { k[:-5]: v for k, v in self.stats.items() if k.endswith('_type') }
		for k in self.equipment:
			del self.stats[k+'_type']
		d = self.weight() - self['chassis']
		if d > 0:
			self['chassis'] += int(math.ceil(d))
		d = (self.weight() - self.drive) * self.drive - self['power']
		if d > 0:
			self['power'] += int(math.ceil(d))

	def __getattr__(self, name):
		try:
			return self.equipment[name]
		except KeyError as e:
			raise AttributeError(e)

	def __getitem__(self, name):
		return self.stats[name]

	def __setitem__(self, name, value):
		self.stats[name] = value

	def __str__(self):
		return " ".join( (v[0]+"=%d") for v in Bot.critical_stats ) % self.criticals()

	def weight(self):
		return self.drive + self.armour + math.log(self['chassis'])

	def criticals(self):
		return tuple( self.stats[k] for k in Bot.critical_stats )

	def health(self):
		return sum(self.criticals())

	def clone(self, level=1):
		stats = self.stats.copy()
		stats.update({ k+'_type': v for k, v in self.equipment.items() })
		bot = Bot(self.name, **stats)
		bot.set_level(level)
		bot.max_stats = bot.stats.copy()
		return bot

	def set_level(self, level):
		for stat in self.stats:
			self.stats[stat] *= level

	def disabled(self):
		return min(self.criticals()) < 1

	def grapple(self, initiative=0):
		# should be random with bias
		# weight penalty is effectively a trade off against armour and speed
		return self['logic'] * (initiative +  self['power']) / self.weight()

	def attack(self, other):
		if self.weapon is None:
			ram(self, other)
		else:
			self.weapon(self, other)

	def modify_attack(self, other, ac):
		attack = 1 + self['weapon'] - other.armour
		if other.armour >= ac:
			attack -= other['armour'] - 2
		return attack

	def attack_a(self, other, ac):
		attack = self.modify_attack(other, ac)
		for k in defender.stats:
			defence = defender[k] / 3 if k in Bot.critical_stats else defender[k]
			if defence > 0 and attack / defence > 0.5: # should be probability
				defender[k] -= 1

	def attack_b(self, other, ac, order=lambda x: x):
		# TODO: some randomness here would be nice (decrease effectiveness of attack)
		attack = self.modify_attack(other, ac)
		vulnerabilities = list(order(sorted( (v, k) for k, v in other.stats.items() )))
		while attack > 0 and not other.disabled():
			for v in vulnerabilities:
				other[v[1]] -= (attack if v[1] in Bot.critical_stats else 1)
				if attack == 0 or other.disabled():
					break
				attack -= 1


def ram(attacker, defender):
	attacker.attack_a(defender, 1)


def grapple(attacker, defender):
	attack = attacker.grapple(1)
	defence = defender.grapple()
	# TODO: work out how to turn attack - defence into damage


def probe(attacker, defender):
	defender['logic'] = defender['logic'] - attacker['weapon']


def blade(attacker, defender):
	attacker.attack_b(defender, 1)


def plasma(attacker, defender):
	attacker.attack_b(defender, 2)


def multi(attacker, defender):
	attacker.attack_b(defender, 2)


def laser(attacker, defender):
	attacker.attack_b(defender, 2, order=reversed)


def ion_cannon(attacker, defender):
	attacker.attack_a(defender, 3)


def projectile(attacker, defender):
	attack = attacker.modify_attack(defender, 1)
	if attack > 0:
		defender['chassis'] -= attack
		if defender['armour'] > 0:
			defender['armour'] -= 1


def emp(attacker, defender):
	attack = attacker.modify_attack(defender, 3)
	if attack > 0:
		defender['logic'] -= attack


standard_types = {
	'base': Bot('base'),
	'probe': Bot('probe', drive_type=2, weapon_type=probe, weapon=2, logic=9),
	'scout': Bot('scout', drive_type=3, logic=6),
	'sniper': Bot('sniper', drive_type=2, weapon_type=plasma, weapon=3),
	'security1': Bot('security1', weapon_type=multi, weapon=3, armour_type=1, armour=2),
	'security2': Bot('security2', weapon_type=ion_cannon, weapon=3, armour_type=1, armour=2),
	'security3': Bot('security3', weapon_type=laser, weapon=3, armour_type=1, armour=2),
	'grunt': Bot('grunt', weapon_type=blade, weapon=3, armour_type=2, armour=2),
	'fighter1': Bot('fighter1', weapon_type=multi, weapon=2, armour_type=2, armour=2),
	'fighter2': Bot('fighter2', weapon_type=ion_cannon, weapon=2, armour_type=2, armour=2),
	'fighter3': Bot('fighter3', weapon_type=laser, weapon=2, armour_type=2, armour=2),
	'tank': Bot('tank', weapon_type=projectile, weapon=2, armour_type=3, armour=2),
	'killer': Bot('killer', weapon_type=emp, weapon=2, armour_type=1, armour=2)
}

print("Attacker", *standard_types, sep=",")
for attacker_level in range(1, 4):
	for attacker_name, attacker_class in standard_types.items():
		attacker = attacker_class.clone(attacker_level)
		print(attacker_name, attacker_level, end=",")
		for defender_name, defender_class in standard_types.items():
			defender = defender_class.clone(defender_level)
			health = defender.health()
			attacker.attack(defender)
			once = str(defender)
			if defender.health() != health:
				k = 1
				while not defender.disabled():
					attacker.attack(defender)
					k += 1
			else:
				k = "-"
			print(once, "K", k, end=",")
		print()
