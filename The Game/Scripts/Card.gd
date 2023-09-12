extends Node2D

@onready var front = $Front
@onready var back = $Back
@onready var extra = $Extra

enum s {
	FRONT,
	BACK,
	EXTRA
}

func _ready():
	pass # Replace with function body.


func _process(delta):
	pass





func flip(new_state:int) -> void:
	# default to be hidden, set only new state to be visible.
	#! add flip animation that triggers this...
	front.visible = false
	back.visible = false
	extra.visible = false
	match new_state:
		s.FRONT: front.visible = true
		s.BACK: back.visible = true
		s.EXTRA: extra.visible = true


