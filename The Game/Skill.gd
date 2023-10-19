extends Node2D

class_name Skill

#! look into this... abstract class - doesn't start with one but needs one.
@onready var area = $Area2D #! SHOULD BE A DIFFERENT CLASS WITH DEFINED SHAPES

@export var power: int = 0
@export var type: int = 0	#gb.sk_type
@export var range: float = 0

@export var wpn_class: int = gb.wpn.NUL
@export var element: int = gb.elm.NUL

@export var stat_buff: Array = []


@export var effects: Array = [] # complicated...

var user: Entity


func _ready():
	position = user.position
	scale = Vector2.ONE * user.stats[gb.stat.AOE_MLT]
	scale.y *= user.stats[gb.stat.RNG_MLT]

func _process(delta):
	pass

func sample(targ_pos:Vector2) -> bool:
	rotation = position.angle_to_point(targ_pos)
	if position.distance_to(targ_pos) < range*user.stats[gb.stat.RNG_MLT]:
		#! highlight affected floor tiles GREEN
		return true
	#! highlight affected floor tiles RED
	return false
		

func cast(targ_pos:Vector2) -> bool:
	rotation = position.angle_to_point(targ_pos)
	#! maybe for now, each tile can have it's own effect? not sure if this is good.
	#just not sure how to get the texture right. maybe all skills can be particles???
	return true
