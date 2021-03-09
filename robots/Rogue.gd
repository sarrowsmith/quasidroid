extends Robot


func _ready():
	state = State.DONE
	equip(true)


func turn():
	.turn()
	state = State.DONE
