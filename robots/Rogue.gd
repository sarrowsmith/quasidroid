extends Robot


func _ready():
	state = DONE
	equip(true)


func turn():
	.turn()
	state = DONE
