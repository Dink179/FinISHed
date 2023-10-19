extends Node2D

class_name Card

@onready var front = $Front
@onready var back = $Back
@onready var extra = $Extra

var value = 0
var targ_pos: Vector2 = Vector2.ZERO

var cur_state: int = gb.crd_side.BACK


func _ready():
	flip(gb.crd_side.BACK, false)
	targ_pos.x = 5*value
	position = targ_pos
	pass # Replace with function body.


func flip(new_state:int, animation:bool) -> void:
	# default to be hidden, set only new state to be visible.
	#! add flip animation that triggers this...
	#if new_state != cur_state:
	front.visible = false
	back.visible = false
	extra.visible = false
	match new_state:
		gb.crd_side.FRONT: front.visible = true
		gb.crd_side.BACK: back.visible = true
		gb.crd_side.EXTRA: extra.visible = true
	if animation:
		#! CALL ANIMATION
		pass
	if new_state == gb.crd_side.FRONT:
		position.y = -20
	else:
		position.y = 0
		

func play() -> void:
	flip(gb.crd_side.FRONT, true)
	print(value, "!")

