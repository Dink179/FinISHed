extends Node2D

class_name Entity

enum state {
	IDL, # IDLE
	MOV, # MOVE
	ATK, # ATTACK
	STK, # SPECIAL ATTACK (variation)
	DTH, # DEATH
	HIT  # TAKE DAMAGE
}

@onready var animator = $AnimationPlayer
@onready var audio = $AudioStreamPlayer2D

@onready var sprite = $Sprite2D
@onready var facing_indicator = $Facing_Indicator

@onready var check_cast = $Check_Cast

@onready var hitbox = $Hitbox

@export var max_hp: int = 10 #!!

@export var stats: Array = [0,0,0,0,0,1,1,1]
#enum stat {
#	PHS_ATK,	# Physical Attack
#	PHS_DEF,	# Physical Defense
#	MAG_ATK,	# Magical Attack
#	MAG_DEF,	# Magical Defense
#	HEALING,	# Healing
#	RNG_MLT,	# Range Multiplier
#	AOE_MLT,	# AOE Multiplier
#	MOV_MLT		# Move Multiplier #! dont need?
#}

var tween : Tween

@export var exp_on_kill: int = 0
@export var loot_table: Array = []

var cur_hp: int
var cur_state: int = state.IDL
var facing: int = 0

func _ready():
	# create tween for position animations:
	tween = create_tween()
	tween.stop()
	cur_hp = max_hp
	

func _process(delta):
	# only accept inputs when not currently animating:
	if not tween.is_running():
		if Input.is_action_just_pressed("ui_up"):
			move(0)
		if Input.is_action_just_pressed("ui_right"):
			move(1)
		if Input.is_action_just_pressed("ui_down"):
			move(2)
		if Input.is_action_just_pressed("ui_left"):
			move(3)
	print(hitbox.get_overlapping_areas())
			

func get_hit(skill:Skill) -> bool:
	# triggered when hitbox is overlapped by a skill
	#! add in statistics here... eventually...
	match skill.type:
		gb.sk_type.PHS:
			cur_hp = max(cur_hp - min(skill.power-stats[gb.stat.PHS_DEF], 0), 0)
			cur_state = state.HIT
			#! call animator to do this.
			#! transition back to idle
		gb.sk_type.MAG:
			cur_hp = max(cur_hp - min(skill.power-stats[gb.stat.MAG_DEF], 0), 0)
			cur_state = state.HIT
			#! call animator to do this.
			#! transition back to idle
		gb.sk_type.HEL:
			cur_hp = min(cur_hp + skill.power, max_hp)
	return check_death()

func check_death() -> bool:
	if cur_hp == 0:
		gb.level_exp_pool += exp_on_kill
		cur_state = state.DTH
		#! call animator to do this.
		#! Deal with loot!!
		return true
	return false

func move(move_dir:int) -> bool:
	# returns if the move succeeded.
	check_cast.rotation = move_dir*PI*.5
	#! COLLISION MASK - 2 = walls, 3 = entities
	check_cast.force_raycast_update()
	if not check_cast.is_colliding():
		var new_pos: Vector2 = position
		match move_dir:
			0: new_pos.y -= 16
			1: new_pos.x += 16
			2: new_pos.y += 16
			3: new_pos.x -= 16
		turn(move_dir)
		animove(new_pos)
	return false
	# check for wall/entity
	# update facing direction
	# update animation to walk
	# update position (tween??)

func animove(new_pos:Vector2) -> void:
	tween = create_tween()
	tween.tween_property(self, "position", new_pos, .5)
	#! change animations
	
#	if tween:
#		pass
#	else:
#		tween = create_tween()
#		tween.tween_property(self, "position", new_pos, .5)
		
#	if tween.is_running():
#		print("yup")
#		pass
#	else:
#		tween = get_tree().create_tween()
#		tween.tween_property(self, "position", new_pos, .5)
	#position = new_pos



func turn(new_dir:int) -> void:
	facing_indicator.rotation = new_dir*PI*.5
	# only flip texture on left/right changes:
	match new_dir:
		1: sprite.flip_h = false
		3: sprite.flip_h = true
			



func _on_hitbox_area_entered(area):
	#! MAKE SURE THIS IS LINKED TO THE RIGHT NODE... MIGHT NEED TO DO THIS IN ONREADY TO LINK TO LEVEL
	if area.is_in_group("Skill"):
		get_hit(area)
