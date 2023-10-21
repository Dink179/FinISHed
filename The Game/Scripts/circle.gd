extends "res://Scripts/skill_shape.gd"

@onready var particles = $GPUParticles2D

func _ready():
	shapes_fun()
	be_a_circle()

func _process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		print(particles.emitting)
		particles.emitting = true
		print(particles.emitting)
		print("yuip")
	


func be_a_circle():
	print("Im a circle")
