extends Node2D

@onready var Character = preload("res://Prefabs/entity.tscn")

# Load other scenes from here:
var autoload: bool = true
var scene_name: String = "res://Dungeon_Generation/ED_1_test.tscn"

var character


func _ready():
	if autoload:
		get_tree().change_scene_to_file(scene_name)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_pressed():
	get_tree().change_scene_to_file(scene_name)
	pass # Replace with function body.
