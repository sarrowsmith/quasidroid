class_name Lift
extends Node2D


enum {LOCKED, CLOSED, OPEN}

var location = Vector2.ZERO
var from = null
var to = null
var state = LOCKED
