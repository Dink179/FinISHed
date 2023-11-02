extends Node2D


# Load other scenes from here:
var autoload: bool = true
var scene_name: String = "res://Prefabs/entity.tscn"


func _ready():
	if autoload:
		get_tree().change_scene_to_file(scene_name)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_pressed():
	get_tree().change_scene_to_file(scene_name)
	pass # Replace with function body.
