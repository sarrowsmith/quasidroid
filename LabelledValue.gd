extends HBoxContainer


export(String) var label = ""
export(String) var default = ""


func _ready():
	$Label.text = label
	set_value(default)


func set_value(value):
	$Value.text = str(value)
