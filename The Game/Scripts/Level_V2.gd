extends TileMap

@onready var Chunks = preload("res://Dungeon_Generation/Chunks_V2.tscn") #? might want to look into a better way?
@onready var chunk_areas = $Chunk_Areas
@onready var test_area = $Test_Area
@onready var cam = $Camera2D

@export var cam_speed:float = 5
@export var level_theme:Level_Theme

enum {
	FLOOR_LAYER,
	WALL_LAYER,
	AIR_LAYER,
	EXTRA_LAYER
}

var level_seed:int = 0
var show_extra:bool = false



func _ready():
	# Set randomization seed:
	randomize()
	if level_seed == 0:
		level_seed = randi()%1000000
	seed(level_seed)
	
	# Load theme:
	load_theme(level_theme)

func _physics_process(delta):
	
	if Input.is_action_pressed("ui_up"):
		cam.position.y -= cam_speed
	if Input.is_action_pressed("ui_down"):
		cam.position.y += cam_speed
	if Input.is_action_pressed("ui_left"):
		cam.position.x -= cam_speed
	if Input.is_action_pressed("ui_right"):
		cam.position.x += cam_speed
	if Input.is_action_just_pressed("ui_accept"):
		show_extra = !show_extra
		set_layer_enabled(EXTRA_LAYER, show_extra)


func load_theme(new_theme:Level_Theme) -> void:
	tile_set.get_source(1).texture = level_theme.floor_textures
	tile_set.get_source(2).texture = level_theme.wall_textures
	tile_set.get_source(3).texture = level_theme.air_textures
	tile_set.get_source(4).texture = level_theme.extra_textures

# change all relevant layers when reading in a chunk.
