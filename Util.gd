tool
extends Node

# Util.choose(["one", "two"])   returns one or two
func choose(choices):
	return choices[randi_range(0, len(choices))]


# the percent chance something happens
func chance(num):
	return randf() < 0.01 * num


# returns random int between low and high
func randi_range(low, high):
	return floor(rand_range(low, high))


# shuffle the order of an array
func shuffle(array):
	var shuffled = array.duplicate()
	shuffled.shuffle()
	return shuffled
