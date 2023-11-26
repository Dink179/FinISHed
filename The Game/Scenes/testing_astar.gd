extends Node2D

@onready var Character = preload("res://Prefabs/entity.tscn")

# Load other scenes from here:
var autoload: bool = true
var scene_name: String = "res://Dungeon_Generation/ED_1_test.tscn"

var character


func _ready():
	if autoload:
		get_tree().change_scene_to_file(scene_name)
	var astar_grid = AStarGrid2D.new()
	astar_grid.cell_size = Vector2(200, 200)
	astar_grid.cell_size = Vector2(16, 16)
	astar_grid.update()
	
	astar_grid.set_point_solid(Vector2i(1,1), true)
	
	print(astar_grid.get_id_path(
		Vector2i(0, 0),
		Vector2i(3, 4)
	))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_pressed():
	get_tree().change_scene_to_file(scene_name)
	pass # Replace with function body.
