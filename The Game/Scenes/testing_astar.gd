extends Node2D

@onready var tile_map = $TileMap
@onready var Character = preload("res://Prefabs/entity.tscn")

var character
var astar_grid: AStarGrid2D


func _ready():
	astar_grid = AStarGrid2D.new()
	astar_grid.region = tile_map.get_used_rect()
	astar_grid.cell_size = Vector2(16, 16)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()
	
	for cell in tile_map.get_used_cells(0):
		if tile_map.get_cell_tile_data(0, cell).get_custom_data("Wall"):
			astar_grid.set_point_solid(cell)
	
	
	character = Character.instantiate()
	add_child(character)
	character.position = Vector2(16,16)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if Input.is_action_just_pressed("click"):
		
		show_path(astar_grid.get_id_path(
			Vector2i(1, 1),
			tile_map.local_to_map(get_global_mouse_position())
			))
			
			
func show_path(shrinps):
	
	for i in range (len(shrinps)):
		var sprite = Sprite2D.new()
		sprite.texture = load("res://Graphics/_Test_Floor.png")
		add_child(sprite)
		sprite.position = shrinps[i]*16
		sprite.self_modulate = Color(1, 1, 1)*i*1.0/len(shrinps)
		sprite.self_modulate.a = 1
		sprite.centered = false
		
	
	
	
	
