extends Node2D


var active = false


func reset():
	active = true
	$Reset.set_visible(true)
	$Base.set_visible(false)
	$Audio.play()
