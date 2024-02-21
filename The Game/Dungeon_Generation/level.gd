extends TileMap



#This is where the chunk combination logic will live.


# Each chunk should "tagged" by being added to groups - these can be determined by components of the chunk automatically.
# trasure (has a chest spawn)
# size (determined by area?)
# puzzle components (might get specific) (determined by specific puzzle types)
# Entry
# Exit
# Trap Room
# Puzzle Room (solution in this room)

@onready var Chunks = preload("res://Dungeon_Generation/Chunks.tscn") #? might want to look into a better way?
@onready var chunk_areas = $Chunk_Areas
@onready var test_area = $Test_Area

@onready var cam = $Camera2D

enum {
	FLOOR_LAYER,
	WALL_LAYER,
	AIR_LAYER,
	EXTRA_LAYER
}

enum theme {
	BASIC,
	ROCK
}

var all_chunks: Node2D

var spawn: bool = true
var accept_frame: bool = false
var num_chunks: int = 20
#var cur_chunks: int = 1 # always start with spawn
var targ_pos: Vector2i = Vector2i.ZERO

var exit_list: Array[Vector2i] = []
var exit_dir_list: Array[Vector2i] = []
var exit_weights: Array[float] = []

#var temp_list: Array[Vector2i] = [] #! should be removable... but it breaks.
var temp_weights: Array[float] = []
var temp_inds: Array[int] = []

var level_seed: int = 0

var chunk_pool: Array[TileMap]
var chunk_forcing: Array #! generate a list of necessary chunk types (fill extra rooms with 0), then scramble it and force them one by one.

var generate: bool = true
var checking: bool = false
var cleared: bool = false

var cam_speed: float = 5

var phys_frame: int = 0
var check_phys_frame: int = 0

var chunk_list: Array[Rect2i] = []

var show_extra: bool = true

var level_themes: int = theme.BASIC



func _ready():
	randomize()
	if level_seed == 0:
		level_seed = randi()%1000000
	seed(level_seed)
	
	load_theme(theme.BASIC)
	
	all_chunks = Chunks.instantiate()
	add_child(all_chunks)
	
	var total_chunk_count = all_chunks.get_child_count()
	
	load_chunks(num_chunks,[])
	update_autotile()
	
	


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


func load_theme(theme_ind:int) -> void:
	print("res://Graphics/Walls/" + theme.keys()[theme_ind] + "_Wall.png")
	tile_set.get_source(1).texture = load("res://Graphics/Level_Themes/Walls/" + theme.keys()[theme_ind] + "_Wall.png")
	#tile_set.get_source(1).texture = load("res://Graphics/Walls" + theme.keys()[theme_ind] + "_Floor.png")
	

func get_collision(new_chunk:Rect2i, chunk_list:Array[Rect2i]) -> bool:
	for rect in chunk_list:
		if !(new_chunk.position.x + new_chunk.size.x <= rect.position.x
		or new_chunk.position.x >= rect.position.x + rect.size.x
		or new_chunk.position.y + new_chunk.size.y <= rect.position.y
		or new_chunk.position.y >= rect.position.y + rect.size.y):
			return true
	return false
	
func reset_temp() -> void:
	#temp_list = exit_list
	temp_weights = exit_weights.duplicate()
	temp_inds = []
	for i in range(len(exit_list)):
		temp_inds += [i]

func use_exit(ind:int) -> void:
	var weight: float = exit_weights[ind] - exit_weights[max(ind-1, 0)]
	exit_list.pop_at(ind)
	exit_weights.pop_at(ind)
	exit_dir_list.pop_at(ind)
	for i in range(ind,exit_weights.size()):
		exit_weights[i] -= weight
	reset_temp()

func ban_exit(ind:int) -> void:
	var weight: float = temp_weights[ind] - temp_weights[max(ind-1, 0)]
	#temp_list.pop_at(ind)
	temp_weights.pop_at(ind)
	temp_inds.pop_at(ind)
	for i in range(ind,temp_weights.size()):
		temp_weights[i] -= weight



func create_hitbox(chunk:TileMap, final_spawn_pos:Vector2i) -> CollisionShape2D:
	#!- Just debug now... shows the starting room
	# Make a collision shape at the final_spawn_pos - add it to the test area, but return so we can reparent it later.
	# generate the hitbox for this chunk:
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = chunk.get_used_rect().size*gb.tile_size - Vector2i.ONE*2
	collider.shape = shape
	collider.position = final_spawn_pos*gb.tile_size + chunk.get_used_rect().size*gb.tile_size/2
	test_area.add_child(collider)
	return collider

func get_chunk_entrances(chunk:TileMap, exit_dir:Vector2i) -> Array[Vector2i]:
	var entrances: Array[Vector2i] = []
	for cell_pos in chunk.get_used_cells(EXTRA_LAYER):
		var entrance_dir: Vector2i = chunk.get_cell_tile_data(EXTRA_LAYER, cell_pos).get_custom_data("Exit_Dir")
		if entrance_dir + exit_dir == Vector2i.ZERO and chunk.get_cell_tile_data(EXTRA_LAYER, cell_pos).get_custom_data("Exit_Weight") != 0:
			entrances += [cell_pos]
	return entrances

func check_chunk(chunk:TileMap, spawn_pos:Vector2i, exit_dir:Vector2i) -> Array:
	# compare the target chunk area to the target draw location. Return selected entrance if the target chunk fits (does not collide)
	# this will check all chunk exits that align with the exit_dir of the selected exit.
	var chunk_entrances: Array[Vector2i] = get_chunk_entrances(chunk, exit_dir)
	# Shuffle the entrance order to avoid bias:
	chunk_entrances.shuffle()
	var chunk_box: Rect2i = chunk.get_used_rect()
	
	for entrance_pos in chunk_entrances:
		chunk_box.position = spawn_pos-entrance_pos
		if !get_collision(chunk_box, chunk_list):
			chunk_list += [chunk_box]
			return [true, entrance_pos]
	return [false]

func load_chunks(num_chunks:int, spawn_data:Array) -> void:
	#! come back to spawn_data later...
	var total_chunk_count = all_chunks.get_child_count()
	
	# create spawn room:
	var start_chunk: TileMap = all_chunks.get_child(randi_range(0,total_chunk_count-1)) #! limit this to only spawns later.
	create_hitbox(start_chunk, Vector2i.ZERO)
	chunk_list += [start_chunk.get_used_rect()]
	draw_chunk(start_chunk, Vector2i.ZERO, Vector2i.ZERO)
	add_exits(start_chunk, Vector2i.ZERO, Vector2i.ZERO) #! use ZERO as entrance... top corner will not be used.. 
	reset_temp()
	
	var cur_chunks: int = 1
	var target_exit: int
	var temp_ind: int
	
	while cur_chunks < num_chunks:
		var tempi = randf_range(0.0, temp_weights[-1])
		temp_ind = temp_weights.bsearch(tempi) # randomly select an exit based on weights.
		target_exit = temp_inds[temp_ind] # get the true index of that (using the temp index value)
		targ_pos = exit_list[target_exit]
	
		#! need this to check all available chunks.... then move on to ban the exit.
		var found: bool = false
		for exit in exit_list:
			var targ_chunk: TileMap = all_chunks.get_child(randi_range(0,total_chunk_count-1))
			var chunk_results: Array = check_chunk(targ_chunk, targ_pos, exit_dir_list[target_exit])
			if chunk_results[0]:
				use_exit(target_exit)
				draw_chunk(targ_chunk, targ_pos, chunk_results[1])
				add_exits(targ_chunk, targ_pos, chunk_results[1]) #! use ZERO as entrance... top corner will not be used.. 
				cur_chunks += 1
				found = true
				break
		if !found:
			ban_exit(temp_ind)
		reset_temp()



func draw_chunk(chunk:TileMap, spawn_pos:Vector2i, entrance_offset:Vector2i) -> void:
	# copy the new chunk to the existing level tilemap.
	for layer in range(chunk.get_layers_count()):
		for cell_pos in chunk.get_used_cells(layer):
			var world_pos: Vector2i = spawn_pos-entrance_offset + cell_pos
			var atlas_coord = chunk.get_cell_atlas_coords(layer, cell_pos)
			if layer == FLOOR_LAYER and (world_pos.x+world_pos.y)%2 == 0:
				atlas_coord.x += 3 #! change floor color
			set_cell(layer, world_pos, chunk.get_cell_source_id(layer, cell_pos),atlas_coord)

func add_exits(chunk:TileMap, spawn_pos:Vector2i, used_entrance:Vector2i) -> void:
	for cell_pos in chunk.get_used_cells(EXTRA_LAYER):
		var world_pos: Vector2i = spawn_pos + cell_pos - used_entrance
		var cell_weight: float = chunk.get_cell_tile_data(EXTRA_LAYER, cell_pos).get_custom_data("Exit_Weight")
		var exit_dir: Vector2i = chunk.get_cell_tile_data(EXTRA_LAYER, cell_pos).get_custom_data("Exit_Dir")
		if exit_dir != Vector2i.ZERO and cell_pos != used_entrance and cell_weight != 0:
			#exits.push_front(world_pos + get_cell_tile_data(AIR_LAYER, world_pos).get_custom_data("Exit_Dir"))
			#weights.push_front(cell_weight)
			exit_list += [world_pos + exit_dir]
			if exit_weights == []:
				exit_weights = [cell_weight]
			else:
				exit_weights += [cell_weight + exit_weights[-1]]
			exit_dir_list += [exit_dir]

func break_exit_walls() -> void:
	for cell_pos in get_used_cells(EXTRA_LAYER):
		var exit_dir: Vector2i = get_cell_tile_data(EXTRA_LAYER, cell_pos).get_custom_data("Exit_Dir")
		if get_cell_tile_data(EXTRA_LAYER, cell_pos + exit_dir) != null and get_cell_tile_data(EXTRA_LAYER, cell_pos + exit_dir).get_custom_data("Exit_Dir") + exit_dir == Vector2i(0,0):
			set_cells_terrain_connect(WALL_LAYER, [cell_pos, cell_pos+exit_dir], 0, -1)
			erase_cell(WALL_LAYER, cell_pos)
			erase_cell(WALL_LAYER, cell_pos + exit_dir)

func update_autotile() -> void:
	# only update the wall layer... for now?:
	#! fix removed tiles (exits, spawners, etc,)... if there are any here.
	break_exit_walls()
	set_cells_terrain_connect(WALL_LAYER,get_used_cells(WALL_LAYER),0,0,false) #! these zeros will probably need to change with other terrains?
