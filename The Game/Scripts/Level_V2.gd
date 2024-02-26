extends TileMap

@onready var Chunks = preload("res://Dungeon_Generation/Chunks_V2.tscn") #? might want to look into a better way?
@onready var chunk_areas = $Chunk_Areas
@onready var test_area = $Test_Area
@onready var cam = $Camera2D

@onready var label = $CanvasLayer/Label

@export var cam_speed:float = 5
@export var level_seed:int = 0
@export var level_theme:Level_Theme
@export var num_chunks:int = 20
@export var branch_factor:float = .75

enum {
	SUMMARY_LAYER,
	FLOOR_LAYER,
	WALL_LAYER,
	AIR_LAYER,
	EXTRA_LAYER
}

var all_chunks: Node2D

var show_extra:bool = true
var loading:bool = false

# load slower:
var slow_load:float = .2
var frame:int = 0

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

var connected_walls: Array[Vector2i] = []
var connected_pits: Array[Vector2i] = []

var temp = [] #!


func _ready():
	# Set randomization seed:
	randomize()
	if level_seed == 0:
		level_seed = randi()%1000000
	seed(level_seed)
	
	
	# Add chunks master list to the scene to reference during generation:


	all_chunks = Chunks.instantiate()
#	add_child(all_chunks)
#	all_chunks.visible = false
#
#	# Generate level using desired theme:
	load_theme(level_theme)
	loading = true
	
	#draw_chunk(all_chunks.get_child(0), Vector2i(0,0), Vector2i(0,0))
	#break_exit_walls()
	#fix_textures()

func _physics_process(delta):
	if Input.is_action_pressed("ui_up"):
		cam.position.y -= cam_speed
	if Input.is_action_pressed("ui_down"):
		cam.position.y += cam_speed
	if Input.is_action_pressed("ui_left"):
		cam.position.x -= cam_speed
	if Input.is_action_pressed("ui_right"):
		cam.position.x += cam_speed
	if Input.is_action_just_pressed("Zoom_In"):
		cam.zoom += Vector2.ONE
	if Input.is_action_just_pressed("Zoom_Out"):
		cam.zoom -= Vector2.ONE
	if Input.is_action_just_pressed("ui_accept"):
		show_extra = !show_extra
		set_layer_enabled(EXTRA_LAYER, show_extra)
	if Input.is_action_pressed("click"):
		#set_cells_terrain_connect(WALL_LAYER,[local_to_map(get_global_mouse_position())], 1, 0)
		label.text = str(local_to_map(get_global_mouse_position()))
	
	# Handle lazy chunk generation:
	if loading:
		if slow_load > 0:
			if frame%(int(60*slow_load)) == 0:
				print("loading...", curr_chunks/num_chunks)
				loading = load_next_chunk([])
			frame += 1
		else:
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
	
	var total_chunk_count = all_chunks.get_child_count()-2
	
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
		add_exits(start_chunk, Vector2i.ZERO, Vector2i.ZERO)
		found = true
		curr_chunks += 1
	
	reset_temp()
	print(temp_weights, "temp weights")
	while !found: 
		if temp_weights.size() == 0:
			print("Not Good... Aborting")
			# ideally restart the process... or something.
			return false
		randf = randf_range(0.0, temp_weights[-1])
		temp_ind = temp_weights.bsearch(randf) # randomly select an exit based on weights.
		target_exit = temp_inds[temp_ind] # get the true index of that (using the temp index value)
		targ_pos = exit_list[target_exit]

		for exit in exit_list:
			var targ_chunk: TileMap = all_chunks.get_child(randi_range(0,total_chunk_count-1)) #! update to draw from chunk pools
			var chunk_results: Array = check_chunk(targ_chunk, targ_pos, exit_dir_list[target_exit])
			if chunk_results[0]:
				use_exit(target_exit)
				draw_chunk(targ_chunk, targ_pos, chunk_results[1])
				add_exits(targ_chunk, targ_pos, chunk_results[1])
				curr_chunks += 1
				found = true
				break
		if !found:
			ban_exit(temp_ind)
	
	if curr_chunks == num_chunks:#-1:
		#! force force exit spawn.
		print("Finishing...")
		break_exit_walls()
		#set_layer_enabled(WALL_LAYER, false)
		#set_layer_enabled(AIR_LAYER, false)
		fix_textures()
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
			elif cell_pos.x == chunk.get_used_rect().size.x-1: 	entrance_dir = Vector2i(1, 0)
			elif cell_pos.y == chunk.get_used_rect().size.y-1: 	entrance_dir = Vector2i(0, 1)
			elif cell_pos.x == 0: 								entrance_dir = Vector2i(-1,0)
			
			if entrance_dir + exit_dir == Vector2i.ZERO and chunk.get_cell_tile_data(SUMMARY_LAYER, cell_pos).get_custom_data("Exit_Weight") != 0:
				entrances += [cell_pos]
	return entrances
			


# Exit weight management:
func add_exits(chunk:TileMap, spawn_pos:Vector2i, used_entrance:Vector2i) -> void:
	print(used_entrance, "ENTRANCE")
	for cell_pos in chunk.get_used_cells(SUMMARY_LAYER):
		var exit_dir:Vector2i
		# If it's an exit tile:
		if chunk.get_cell_tile_data(SUMMARY_LAYER, cell_pos).get_custom_data("Exit_Dir") != Vector2i.ZERO:
			# Get actual exit direction:
			if cell_pos.y == 0: 								exit_dir = Vector2i(0,-1)
			elif cell_pos.x == chunk.get_used_rect().size.x-1: 	exit_dir = Vector2i(1, 0)
			elif cell_pos.y == chunk.get_used_rect().size.y-1: 	exit_dir = Vector2i(0, 1)
			elif cell_pos.x == 0: 								exit_dir = Vector2i(-1,0)
			var world_pos: Vector2i = spawn_pos + cell_pos - used_entrance
			var cell_weight: float = chunk.get_cell_tile_data(SUMMARY_LAYER, cell_pos).get_custom_data("Exit_Weight")
			
			if cell_pos != used_entrance and cell_weight != 0:
				exit_list += [world_pos + exit_dir]
			
				if exit_weights == []:
					exit_weights = [cell_weight]
				else:
					exit_weights += [cell_weight + exit_weights[-1]]
				exit_dir_list += [exit_dir]
	print(exit_list, "exit list")
func use_exit(ind:int) -> void:
	var weight: float = exit_weights[ind] - exit_weights[max(ind-1, 0)]
	print(exit_weights, "weights before", exit_list)
	exit_list.pop_at(ind)
	exit_weights.pop_at(ind)
	exit_dir_list.pop_at(ind)
	for i in range(ind,exit_weights.size()):
		exit_weights[i] -= weight
	print(exit_weights, "weights after", exit_list)
	for i in range(exit_weights.size()):
		exit_weights[i] *= branch_factor
	#! exit_weights[i] *= .5 # each room halves the previous weights.. could make that a var for branching.
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
		print("repopulating..", temp_weights.size()-1, " ", i)
		print(exit_weights, "exit_weights, ", exit_list, "exit_list")
		temp_inds += [i]
			


func draw_chunk(chunk:TileMap, spawn_pos:Vector2i, entrance_offset:Vector2i) -> void:
	# copy the new chunk to the existing level tilemap.
	#create_hitbox(chunk, spawn_pos-entrance_offset) #! debug
	var test_walls:Array[Vector2i] = []
	var test_pits:Array[Vector2i] = []
	for cell_pos in chunk.get_used_cells(SUMMARY_LAYER):
		var world_pos:Vector2i = spawn_pos-entrance_offset + cell_pos
		var atlas_coord = chunk.get_cell_atlas_coords(SUMMARY_LAYER, cell_pos)
		var cell_td:TileData = chunk.get_cell_tile_data(SUMMARY_LAYER, cell_pos)
		var tile_type:String = cell_td.get_custom_data("Tile_Type")
		
		match tile_type:
			"Floor":
				set_cell(FLOOR_LAYER, world_pos, FLOOR_LAYER, Vector2i(0,0)) # floor
				set_cell(WALL_LAYER, world_pos, WALL_LAYER, Vector2i(11,11)) # empty side wall
				set_cell(AIR_LAYER, world_pos, WALL_LAYER, Vector2i(25,3)) # empty top wall
				# set floor layer terrain to alternating floors... do this later.
			"Wall":
				set_cell(FLOOR_LAYER, world_pos, FLOOR_LAYER, Vector2i(0,0)) # floor
				set_cell(WALL_LAYER, world_pos, WALL_LAYER, Vector2i(0,8)) # side wall
				set_cell(AIR_LAYER, world_pos, WALL_LAYER, Vector2i(0,0)) # top wall
				connected_walls += [world_pos]
				test_walls += [world_pos]
			"Pit":
				set_cell(FLOOR_LAYER, world_pos, WALL_LAYER, Vector2i(0,4)) # pit wall floor
				set_cell(WALL_LAYER, world_pos, WALL_LAYER, Vector2i(11,11)) # empty side wall
				set_cell(AIR_LAYER, world_pos, WALL_LAYER, Vector2i(25,3)) # empty top wall
				connected_pits += [world_pos]
				test_pits += [world_pos]
			"Trap":
				set_cell(FLOOR_LAYER, world_pos, FLOOR_LAYER, Vector2i(0,3)) # trap floor
				set_cell(WALL_LAYER, world_pos, WALL_LAYER, Vector2i(11,11)) # empty side wall
				set_cell(AIR_LAYER, world_pos, WALL_LAYER, Vector2i(25,3)) # empty top wall
			"Treasure":
				set_cell(FLOOR_LAYER, world_pos, FLOOR_LAYER, Vector2i(0,0)) # floor
				set_cell(WALL_LAYER, world_pos, WALL_LAYER, Vector2i(11,11)) # empty side wall
				set_cell(AIR_LAYER, world_pos, WALL_LAYER, Vector2i(25,3)) # empty top wall
				set_cell(EXTRA_LAYER, world_pos, EXTRA_LAYER, Vector2i(0,4)) #! add treasure spawner to extra layer
			"Spawner":
				set_cell(FLOOR_LAYER, world_pos, FLOOR_LAYER, Vector2i(0,0)) # floor
				set_cell(WALL_LAYER, world_pos, WALL_LAYER, Vector2i(11,11)) # empty side wall
				set_cell(AIR_LAYER, world_pos, WALL_LAYER, Vector2i(25,3)) # empty top wall
				set_cell(EXTRA_LAYER, world_pos, EXTRA_LAYER, Vector2i(1,4)) #! add monster spawner to extra layer
			"Exit":
				# Update the direction of all summary exits (each has a value set for Direction:
				var atlas_y:int = -1 # Will always be updated.
				if cell_pos.y == 0: 								atlas_y = 0
				elif cell_pos.x == chunk.get_used_rect().size.x-1: 	atlas_y = 1
				elif cell_pos.x == 0: 								atlas_y = 2
				elif cell_pos.y == chunk.get_used_rect().size.y-1: 	atlas_y = 3
				
				set_cell(FLOOR_LAYER, world_pos, FLOOR_LAYER, Vector2i(0,0)) # floor
				set_cell(WALL_LAYER, world_pos, WALL_LAYER, Vector2i(0,8)) # side wall
				set_cell(AIR_LAYER, world_pos, WALL_LAYER, Vector2i(0,0)) # top wall
				var atlas_x:int = 0
				if world_pos == spawn_pos:
					atlas_x += 4
				set_cell(EXTRA_LAYER, world_pos, EXTRA_LAYER, Vector2i(atlas_coord.x+atlas_x, atlas_y))
				
				#eventually use this to generate walls in unconnected exits.
				connected_walls += [world_pos]
				test_walls += [world_pos]
	#fix_chunk_textures(chunk.get_used_rect().size, spawn_pos-entrance_offset, test_walls, test_pits)
		

#! Delete this:
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

func break_exit_walls() -> void:
	for cell_pos in get_used_cells(EXTRA_LAYER):
		var exit_dir: Vector2i = get_cell_tile_data(EXTRA_LAYER, cell_pos).get_custom_data("Exit_Dir")
		# make sure this extra tile is an exit, then make sure it's pointing at another exit:
		if  exit_dir != Vector2i.ZERO and get_cell_tile_data(EXTRA_LAYER, cell_pos + exit_dir) != null and get_cell_tile_data(EXTRA_LAYER, cell_pos + exit_dir).get_custom_data("Exit_Dir") != Vector2i.ZERO:
			set_cell(WALL_LAYER, cell_pos, WALL_LAYER, Vector2i(11,11)) # empty side wall
			set_cell(AIR_LAYER, cell_pos, WALL_LAYER, Vector2i(25,3)) # empty top wall
			connected_walls.erase(cell_pos)
			connected_pits.erase(cell_pos)
			#set_cells_terrain_connect(WALL_LAYER, get_surrounding_cells(cell_pos), WALL_LAYER, 0)
			#set_cells_terrain_connect(AIR_LAYER, get_surrounding_cells(cell_pos), AIR_LAYER, 0)

func fix_chunk_textures(chunk_box:Vector2i, spawn_pos:Vector2i, connect_walls:Array[Vector2i], connect_pits:Array[Vector2i]) -> void:
	# first pass at connected textures:
	set_cells_terrain_connect(AIR_LAYER, connect_walls, 2,0, false) # connect top walls
	set_cells_terrain_connect(WALL_LAYER, connect_walls, 1,0) # connect side walls
	set_cells_terrain_connect(FLOOR_LAYER, connect_pits, 0,2, false) # connect pits
	
	for y in range(spawn_pos.y-1,spawn_pos.y+chunk_box.y+1):
		for x in range(spawn_pos.x-1,spawn_pos.x+chunk_box.x+1):
			
			# alternate floor colors:
			var cell_pos:Vector2i = Vector2i(x, y)
			var atlas_coord:Vector2i = get_cell_atlas_coords(FLOOR_LAYER, cell_pos)
			if get_cell_source_id(FLOOR_LAYER, cell_pos) == 1 and (x+y)%2 == 0 and (cell_pos.y >= spawn_pos.y and cell_pos.y <= spawn_pos.y+chunk_box.y-1) and (cell_pos.x >= spawn_pos.x and cell_pos.x <= spawn_pos.x+chunk_box.x-1):
				# shift atlas by 3:
				atlas_coord.x += 3
				set_cell(FLOOR_LAYER, cell_pos, 1, atlas_coord)
			
			# updating truly empty cells fixes connection issues:
			if get_cell_source_id(AIR_LAYER, Vector2i(x,y)) == -1:
				set_cells_terrain_connect(AIR_LAYER, [Vector2i(x,y)], 2,0) # top walls
				set_cells_terrain_connect(WALL_LAYER, [Vector2i(x,y)], 1,0) # always external so side walls #! this might not work... pits should be external too.

func fix_textures() -> void:
	# alternate floor colors:
	for floor in get_used_cells(FLOOR_LAYER):
		var floor_type: int = get_cell_source_id(FLOOR_LAYER, floor)
		var atlas_coord: Vector2i = get_cell_atlas_coords(FLOOR_LAYER, floor)
		if floor_type == 1 and (floor.x+floor.y)%2 == 0:
			# shift atlas by 3:
			atlas_coord.x += 3
			set_cell(FLOOR_LAYER, floor, floor_type, atlas_coord)
	
	# update connected textures:
	set_cells_terrain_connect(AIR_LAYER, connected_walls, 2,0, false) # connect top walls
	set_cells_terrain_connect(WALL_LAYER, connected_walls, 1,0) # connect side walls
	set_cells_terrain_connect(FLOOR_LAYER, connected_pits, 0,2, false) # connect pits
	var rect:Rect2i = self.get_used_rect()
	var update_cells:Array[Vector2i] = []
	for y in range(rect.position.y-1, rect.position.y+rect.size.y+1):
		for x in range(rect.position.x-1, rect.position.x+rect.size.x+1):
			# updating truly empty cells fixes connection issues:
			if get_cell_source_id(AIR_LAYER, Vector2i(x,y)) == -1:
				set_cells_terrain_connect(AIR_LAYER, [Vector2i(x,y)], 2,0) # top walls
				set_cells_terrain_connect(WALL_LAYER, [Vector2i(x,y)], 1,0) # always external so side walls
	
	
