extends TextureRect


signal move(position)
signal click(position, button)


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		emit_signal("click", event.position, event.button_index)
	if event is InputEventMouseMotion:
		emit_signal("move", event.position)
