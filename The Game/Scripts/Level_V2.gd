extends TileMap

@onready var Chunks = preload("res://Dungeon_Generation/Chunks_V2.tscn") #? might want to look into a better way?
@onready var chunk_areas = $Chunk_Areas
@onready var test_area = $Test_Area
@onready var cam = $Camera2D

@export var cam_speed:float = 5
@export var level_seed:int = 0
@export var level_theme:Level_Theme
@export var num_chunks:int = 1

enum {
	SUMMARY_LAYER,
	FLOOR_LAYER,
	WALL_LAYER,
	AIR_LAYER,
	EXTRA_LAYER
}

var all_chunks: Node2D

var show_extra:bool = false
var loading:bool = false

#var exit_dict:Dictionary = {
#	"positions" = [],
#	"directions" = [],
#	"weights" = []
#}

# Exit list weighting mess:
var exit_list: Array[Vector2i] = []
var exit_dir_list: Array[Vector2i] = []
var exit_weights: Array[float] = []
var temp_weights: Array[float] = []
var temp_inds: Array[int] = []

var chunk_list: Array[Rect2i] = []

var curr_chunks:int = 0



func _ready():
	# Set randomization seed:
	randomize()
	if level_seed == 0:
		level_seed = randi()%1000000
	seed(level_seed)
	
	
	# Add chunks master list to the scene to reference during generation:
	all_chunks = Chunks.instantiate()
	add_child(all_chunks)
	all_chunks.visible = false
	
	# Generate level using desired theme:
	load_theme(level_theme)
	loading = true
	

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
		
	# Handle lazy chunk generation:
	if loading:
		loading = load_next_chunk([])
		



func load_theme(new_theme:Level_Theme) -> void:
	tile_set.get_source(1).texture = level_theme.floor_textures
	tile_set.get_source(2).texture = level_theme.wall_textures
	#!tile_set.get_source(3).texture = level_theme.air_textures
	tile_set.get_source(4).texture = level_theme.extra_textures
	
	
func check_chunk(chunk:TileMap, spawn_pos:Vector2i, exit_dir:Vector2i) -> Array:
	# Compare the target chunk area to the target draw location. Return selected entrance if the target chunk fits (does not collide)
	# this will check all chunk exits that align with the exit_dir of the selected exit.
	var chunk_entrances: Array[Vector2i] = get_entrance_positions(chunk, exit_dir)
	# Shuffle the entrance order to avoid bias:
	chunk_entrances.shuffle()
	var chunk_box: Rect2i = chunk.get_used_rect()
	
	for entrance_pos in chunk_entrances:
		chunk_box.position = spawn_pos-entrance_pos
		if !test_collision(chunk_box, chunk_list):
			chunk_list += [chunk_box]
			return [true, entrance_pos]
	return [false]

func test_collision(new_chunk:Rect2i, chunk_list:Array[Rect2i]) -> bool:
	for rect in chunk_list:
		if !(new_chunk.position.x + new_chunk.size.x <= rect.position.x
		or new_chunk.position.x >= rect.position.x + rect.size.x
		or new_chunk.position.y + new_chunk.size.y <= rect.position.y
		or new_chunk.position.y >= rect.position.y + rect.size.y):
			return true
	return false

func load_next_chunk(spawn_data:Array) -> bool:
	#.5 add all chunk exits to entrance list.
	# for each entrance matched to an exit:
	#1 test collision
	#2 load
	#3 add exits to dict.
	
	# loop over all exits - for each one (chosen by random weight)
	
	var total_chunk_count = all_chunks.get_child_count()-1
	
	var cur_chunks: int = 1
	var target_exit: int
	var temp_ind: int
	var randf:float
	var targ_pos:Vector2i 
	
	var found:bool = false
	
	# Force first spawn:
	if curr_chunks == 0:
		targ_pos = Vector2i.ZERO 
		# create spawn room:
		var start_chunk: TileMap = all_chunks.get_child(randi_range(0,total_chunk_count-1)) #! limit this to only spawns later.
		chunk_list += [start_chunk.get_used_rect()]
		draw_chunk(start_chunk, Vector2i.ZERO, Vector2i.ZERO)
		add_exits(start_chunk, Vector2i.ZERO, Vector2i.ZERO) #! use ZERO as entrance... top corner will not be used.. 
		found = true
	
	reset_temp()
	print(temp_weights)
	while !found: 
		randf = randf_range(0.0, temp_weights[-1])
		temp_ind = temp_weights.bsearch(randf) # randomly select an exit based on weights.
		target_exit = temp_inds[temp_ind] # get the true index of that (using the temp index value)
		targ_pos = exit_list[target_exit]

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
	
	curr_chunks += 1
	if curr_chunks == num_chunks:#-1:
		#! force force exit spawn.
		return false
	return true



func get_chunk_possibilities(room_tags:Array[String]) -> Array[TileMap]:
	var valid_chunks:Array[TileMap] = []
	for chunk in all_chunks.get_children():
		for group in room_tags:
			if chunk.is_in_group(group):
				valid_chunks += [chunk]
				break
	return valid_chunks

func get_entrance_positions(chunk:TileMap, exit_dir:Vector2i) -> Array[Vector2i]:
	# Returns the list of entrance positions in the given chunk that line up with the given exit_dir.
	var entrances: Array[Vector2i] = []
	for cell_pos in chunk.get_used_cells(SUMMARY_LAYER):
		var entrance_dir:Vector2i
		if chunk.get_cell_tile_data(SUMMARY_LAYER, cell_pos).get_custom_data("Exit_Dir") != Vector2i.ZERO:
			# Get actual exit direction:
			if cell_pos.y == 0: 								entrance_dir = Vector2i(0,-1)
			elif cell_pos.x == chunk.get_used_rect().size.x: 	entrance_dir = Vector2i(1, 0)
			elif cell_pos.y == chunk.get_used_rect().size.y: 	entrance_dir = Vector2i(-1,0)
			elif cell_pos.x == 0: 								entrance_dir = Vector2i(0, 1)
			
			if entrance_dir + exit_dir == Vector2i.ZERO and chunk.get_cell_tile_data(SUMMARY_LAYER, cell_pos).get_custom_data("Exit_Weight") != 0:
				entrances += [cell_pos]
	return entrances
			


# Exit weight management:
func add_exits(chunk:TileMap, spawn_pos:Vector2i, used_entrance:Vector2i) -> void:
	for cell_pos in chunk.get_used_cells(SUMMARY_LAYER):
		# If it's an exit tile:
		if chunk.get_cell_tile_data(SUMMARY_LAYER, cell_pos).get_custom_data("Exit_Dir") != Vector2i.ZERO:
			var world_pos: Vector2i = spawn_pos + cell_pos - used_entrance
			var cell_weight: float = chunk.get_cell_tile_data(SUMMARY_LAYER, cell_pos).get_custom_data("Exit_Weight")
			var exit_dir: Vector2i = chunk.get_cell_tile_data(SUMMARY_LAYER, cell_pos).get_custom_data("Exit_Dir")
			
			if cell_pos != used_entrance and cell_weight != 0:
				exit_list += [world_pos + exit_dir]
			
			if exit_weights == []:
				exit_weights = [cell_weight]
			else:
				exit_weights += [cell_weight + exit_weights[-1]]
			exit_dir_list += [exit_dir]
	print(exit_list, "THIS")
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
func reset_temp() -> void:
	temp_weights = exit_weights.duplicate()
	temp_inds = []
	for i in range(len(exit_list)):
		temp_inds += [i]
			


func draw_chunk(chunk:TileMap, spawn_pos:Vector2i, entrance_offset:Vector2i) -> void:
	# copy the new chunk to the existing level tilemap.
	for cell_pos in chunk.get_used_cells(SUMMARY_LAYER):
		var world_pos: Vector2i = spawn_pos-entrance_offset + cell_pos
		var atlas_coord = chunk.get_cell_atlas_coords(SUMMARY_LAYER, cell_pos)
		var cell_td:TileData = chunk.get_cell_tile_data(SUMMARY_LAYER, cell_pos)
		print(cell_td.terrain)
		var tile_type:String = cell_td.get_custom_data("Tile_Type")
		print(tile_type)
		#?! it may be possible to combine these into an array and do them all together? not sure whats better.
		match tile_type:
			"Floor":
				set_cells_terrain_connect(FLOOR_LAYER, [cell_pos], 0, 0) # normal floor
				set_cells_terrain_connect(WALL_LAYER, [cell_pos], 1, 1) # empty side wall
				set_cells_terrain_connect(AIR_LAYER, [cell_pos], 2, 2) # empty top wall
				# set floor layer terrain to alternating floors... do this later.
				# set wall layers to empty.
			"Wall":
				set_cells_terrain_connect(FLOOR_LAYER, [cell_pos], 0, 1) #unwalkable floor
				set_cells_terrain_connect(WALL_LAYER, [cell_pos], 1, 0) # side wall
				set_cells_terrain_connect(AIR_LAYER, [cell_pos], 2, 0) # top wall
				# set floor layer terrain to unwalkable.
				# set wall layers to 1
			"Pit":
				set_cells_terrain_connect(FLOOR_LAYER, [cell_pos], 0, 1) #unwalkable floor
				set_cells_terrain_connect(WALL_LAYER, [cell_pos], 1, 1) # empty side wall
				set_cells_terrain_connect(AIR_LAYER, [cell_pos], 2, 2) # empty top wall
				# set wall to empty
				# set floor to unwalkable? shouldnt matter... maybe just dont.
			"Trap":
				set_cells_terrain_connect(FLOOR_LAYER, [cell_pos], 0, 2) #unwalkable floor
				set_cells_terrain_connect(WALL_LAYER, [cell_pos], 1, 1) # empty side wall
				set_cells_terrain_connect(AIR_LAYER, [cell_pos], 2, 2) # empty top wall
				# Set floor to trap
				# set wall to empty
			"Treasure":
				set_cells_terrain_connect(FLOOR_LAYER, [cell_pos], 0, 0) # normal floor
				set_cells_terrain_connect(WALL_LAYER, [cell_pos], 1, 1) # empty side wall
				set_cells_terrain_connect(AIR_LAYER, [cell_pos], 2, 2) # empty top wall
				#!set_cell(EXTRA_LAYER, cell_pos, EXTRA_LAYER, Vector2i(0,5))
				#set_cells_terrain_connect(EXTRA_LAYER, [cell_pos], 0, 0) # normal floor
				#set floor to floor..
				# set extra to treasure
				#! eventually worry about spawning
			"Spawner":
				set_cells_terrain_connect(FLOOR_LAYER, [cell_pos], 0, 0) # normal floor
				set_cells_terrain_connect(WALL_LAYER, [cell_pos], 1, 1) # empty side wall
				set_cells_terrain_connect(AIR_LAYER, [cell_pos], 2, 2) # empty top wall
				#!set_cell(EXTRA_LAYER, cell_pos, EXTRA_LAYER, Vector2i(0,6))
				# set floor to floor..
				# set extra to spawner
				#! eventually worry about spawning
			"Exit":
				# Update the direction of all summary exits (each has a value set for Direction:
				var atlas_y:int = -1 # Will always be updated.
				if cell_pos.y == 0: 								atlas_y = 0
				elif cell_pos.x == chunk.get_used_rect().size.x: 	atlas_y = 1
				elif cell_pos.y == chunk.get_used_rect().size.y: 	atlas_y = 2
				elif cell_pos.x == 0: 								atlas_y = 3
				# set extra to exit.
				chunk.set_cell(EXTRA_LAYER, cell_pos, EXTRA_LAYER, Vector2i(chunk.get_cell_atlas_coords(SUMMARY_LAYER, cell_pos).x, atlas_y))
				#eventually use this to generate walls in unconnected exits.
	#set_cells_terrain_connect(FLOOR_LAYER,get_used_cells(FLOOR_LAYER),1,0,false)
	#set_cells_terrain_connect(WALL_LAYER,get_used_cells(WALL_LAYER),1,0,false) #! this will currently break pits.
	#set_cells_terrain_connect(AIR_LAYER,get_used_cells(AIR_LAYER),1,0,false) #! this will currently break pits.
	self.force_update()
	print("this actually happened")
#		if layer == FLOOR_LAYER and (world_pos.x+world_pos.y)%2 == 0:
#			atlas_coord.x += 3 #! change floor color
#		set_cell(layer, world_pos, chunk.get_cell_source_id(layer, cell_pos),atlas_coord)


#			#	# Update the direction of all summary exits (each has a value set for Direction:
#			var atlas_y:int = -1 # Will always be updated.
#			if cell_pos.y == 0: 								atlas_y = 0
#			elif cell_pos.x == chunk.get_used_rect().size.x: 	atlas_y = 1
#			elif cell_pos.y == chunk.get_used_rect().size.y: 	atlas_y = 2
#			elif cell_pos.x == 0: 								atlas_y = 3
#			chunk.set_cell(SUMMARY_LAYER, cell_pos, EXTRA_LAYER, Vector2i(chunk.get_cell_atlas_coords(SUMMARY_LAYER, cell_pos).x, atlas_y))
#			entrance_dir = chunk.get_cell_tile_data(SUMMARY_LAYER, cell_pos).get_custom_data("Exit_Dir")
			

