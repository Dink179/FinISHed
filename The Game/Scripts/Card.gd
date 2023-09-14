extends Node2D

class_name Card

@onready var front = $Front
@onready var back = $Back
@onready var extra = $Extra

var value = 0
var targ_pos: Vector2 = Vector2.ZERO


enum s {
	FRONT,
	BACK,
	EXTRA
}

var cur_state: int = s.BACK


func _ready():
	flip(s.BACK, false)
	targ_pos.x = 5*value
	position = targ_pos
	front.frame = 8+value
	pass # Replace with function body.


func flip(new_state:int, animation:bool) -> void:
	# default to be hidden, set only new state to be visible.
	#! add flip animation that triggers this...
	#if new_state != cur_state:
	front.visible = false
	back.visible = false
	extra.visible = false
	match new_state:
		s.FRONT: front.visible = true
		s.BACK: back.visible = true
		s.EXTRA: extra.visible = true
	if animation:
		#! CALL ANIMATION
		pass
	if new_state == s.FRONT:
		position.y = -20
	else:
		position.y = 0
		

func play() -> void:
	flip(s.FRONT, true)
	print(value, "!")

