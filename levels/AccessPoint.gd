extends Node2D


var active = false


func reset():
	if not (active or $Audio.playing):
		$Audio.play()
	active = true
	$Reset.set_visible(true)
	$Base.set_visible(false)
