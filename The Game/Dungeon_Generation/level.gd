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

var all_chunks: Node2D

var spawn: bool = true
var accept_frame: bool = false
var num_chunks: int = 100
var cur_chunks: int = 1 # always start with spawn
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

# Full Process:
#1. create hitbox
#2. wait one physics frame
#3. determine if hitbox is colliding
#4. if not, move it to permanent and add UNUSED exits to the exit list. If so, jump back to #1 for a new chunk.
#5. 


func _ready():
	randomize()
	if level_seed == 0:
		level_seed = randi()%1000000
	seed(level_seed)
	
	all_chunks = Chunks.instantiate()
	add_child(all_chunks)
	
	var total_chunk_count = all_chunks.get_child_count()
	
	load_chunks2(num_chunks,[])
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
		if entrance_dir + exit_dir == Vector2i.ZERO:
			entrances += [cell_pos]
	return entrances

func check_chunk3(chunk, spawn_pos:Vector2i, exit_dir:Vector2i) -> Array:
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

func load_chunks2(num_chunks:int, spawn_data:Array) -> void:
	#! come back to spawn_data later...
	var total_chunk_count = all_chunks.get_child_count()
	
	# create spawn room:
	var start_chunk: TileMap = all_chunks.get_child(randi_range(0,total_chunk_count-1)) #! limit this to only spawns later.
	create_hitbox(start_chunk, Vector2i.ZERO)
	chunk_list += [start_chunk.get_used_rect()]
	draw_chunk2(start_chunk, Vector2i.ZERO, Vector2i.ZERO)
	add_exits2(start_chunk, Vector2i.ZERO, Vector2i.ZERO) #! use ZERO as entrance... top corner will not be used.. 
	reset_temp()
	
	var cur_chunks: int = 1
	var target_exit: int
	var temp_ind: int
	
	while cur_chunks < num_chunks:
		var tempi = randf_range(0.0, temp_weights[-1])
		temp_ind = temp_weights.bsearch(tempi) # randomly select an exit based on weights.
		print(temp_ind)
		target_exit = temp_inds[temp_ind] # get the true index of that (using the temp index value)
		targ_pos = exit_list[target_exit]

		print(targ_pos)
		#! need this to check all available chunks.... then move on to ban the exit.
		var found: bool = false
		for exit in exit_list:
			var targ_chunk: TileMap = all_chunks.get_child(randi_range(0,total_chunk_count-1))
			var chunk_results: Array = await check_chunk3(targ_chunk, targ_pos, exit_dir_list[target_exit])
			if chunk_results[0]:
				use_exit(target_exit)
				draw_chunk2(targ_chunk, targ_pos, chunk_results[1])
				add_exits2(targ_chunk, targ_pos, chunk_results[1]) #! use ZERO as entrance... top corner will not be used.. 
				cur_chunks += 1
				found = true
				break
		if !found:
			ban_exit(temp_ind)
		reset_temp()
	
	
	# Shuffle the entrance order to avoid bias:
#	chunk_entrances.shuffle()
#
#	for entrance_pos in chunk_entrances:
#		var new_collider: CollisionShape2D = create_hitbox(chunk, spawn_pos-entrance_pos)
#		checking = true
#		check_phys_frame = phys_frame
#		print("checking set to true")
#		await get_tree().physics_frame
#		if test_area.has_overlapping_areas() and check_phys_frame != phys_frame:
#			new_collider.queue_free()
#		elif check_phys_frame != phys_frame:
#			print(check_phys_frame, " ", phys_frame)
#			new_collider.reparent(chunk_areas)
#			checking = false
#			print("checking set to false (success)")
#			return [true, entrance_pos]
#	checking = false
#	print("checking set to false (failed)")
#	return [false]


#func check_chunk2(chunk, spawn_pos:Vector2i, exit_dir:Vector2i) -> Array:
#	# compare the target chunk area to the target draw location. Return selected entrance if the target chunk fits (does not collide)
#	# this will check all chunk exits that align with the exit_dir of the selected exit.
#	var chunk_entrances: Array[Vector2i] = get_exits(chunk, exit_dir)
#	# Shuffle the entrance order to avoid bias:
#	chunk_entrances.shuffle()
#
#	for entrance_pos in chunk_entrances:
#		var new_collider: CollisionShape2D = create_hitbox(chunk, spawn_pos-entrance_pos)
#		checking = true
#		check_phys_frame = phys_frame
#		print("checking set to true")
#		await get_tree().physics_frame
#		if test_area.has_overlapping_areas() and check_phys_frame != phys_frame:
#			new_collider.queue_free()
#		elif check_phys_frame != phys_frame:
#			print(check_phys_frame, " ", phys_frame)
#			new_collider.reparent(chunk_areas)
#			checking = false
#			print("checking set to false (success)")
#			return [true, entrance_pos]
#	checking = false
#	print("checking set to false (failed)")
#	return [false]

func draw_chunk2(chunk:TileMap, spawn_pos:Vector2i, entrance_offset:Vector2i) -> void:
	# copy the new chunk to the existing level tilemap.
	for layer in range(chunk.get_layers_count()):
		for cell_pos in chunk.get_used_cells(layer):
			var atlas_coord = chunk.get_cell_atlas_coords(layer, cell_pos)
			if layer == FLOOR_LAYER and (cell_pos.x+cell_pos.y)%2 == 0:
				atlas_coord.x += 3 #! change floor color
			set_cell(layer, spawn_pos-entrance_offset + cell_pos, chunk.get_cell_source_id(layer, cell_pos),atlas_coord)

func add_exits2(chunk:TileMap, spawn_pos:Vector2i, used_entrance:Vector2i) -> void:
	for cell_pos in chunk.get_used_cells(EXTRA_LAYER):
		var world_pos: Vector2i = spawn_pos + cell_pos - used_entrance
		var cell_weight: float = chunk.get_cell_tile_data(EXTRA_LAYER, cell_pos).get_custom_data("Exit_Weight")
		var exit_dir: Vector2i = chunk.get_cell_tile_data(EXTRA_LAYER, cell_pos).get_custom_data("Exit_Dir")
		if exit_dir != Vector2i.ZERO and cell_pos != used_entrance:
			#exits.push_front(world_pos + get_cell_tile_data(AIR_LAYER, world_pos).get_custom_data("Exit_Dir"))
			#weights.push_front(cell_weight)
			exit_list += [world_pos + exit_dir]
			if exit_weights == []:
				exit_weights = [cell_weight]
			else:
				exit_weights += [cell_weight + exit_weights[-1]]
			exit_dir_list += [exit_dir]

#func load_chunks(num_chunks:int, spawn_data:Array) -> void:
#	#! come back to spawn_data later...
#	var total_chunk_count = all_chunks.get_child_count()
#
#	# create spawn room:
#
#	var start_chunk: TileMap = all_chunks.get_child(randi_range(0,total_chunk_count-1)) #! limit this to only spawns later.
#	create_hitbox(start_chunk, Vector2i.ZERO)
#	draw_chunk2(start_chunk, Vector2i.ZERO, Vector2i.ZERO)
#	add_exits2(start_chunk, Vector2i.ZERO, Vector2i.ZERO) #! use ZERO as entrance... top corner will not be used.. 
#	reset_temp()
#
#	var cur_chunks: int = 1
#	var target_exit: int
#	var temp_ind: int
#
#	while cur_chunks < num_chunks:
#		var tempi = randf_range(0.0, temp_weights[-1])
#		temp_ind = temp_weights.bsearch(tempi) # randomly select an exit based on weights.
#		target_exit = temp_inds[temp_ind] # get the true index of that (using the temp index value)
#		targ_pos = exit_list[target_exit]
#
#		print(targ_pos)
#		#! need this to check all available chunks.... then move on to ban the exit.
#		for exit in exit_list:
#			var targ_chunk: TileMap = all_chunks.get_child(randi_range(0,total_chunk_count-1))
#			var chunk_results: Array = await check_chunk2(targ_chunk, targ_pos, exit_dir_list[target_exit])
#			if chunk_results[0]:
#				use_exit(target_exit)
#				draw_chunk2(targ_chunk, targ_pos, chunk_results[1])
#				add_exits2(targ_chunk, targ_pos, chunk_results[1]) #! use ZERO as entrance... top corner will not be used.. 
#				cur_chunks += 1
#				break
#			else:
#				ban_exit(temp_ind)
#		reset_temp()






#func check_chunk(chunk_id:int, spawn_pos:Vector2i, exit_dir:Vector2i) -> bool:
#	# compare the target chunk area to the target draw location. Return true if the target chunk fits (does not collide)
#	#! there will also be an offset for the specific join location
#	var chunk: TileMap = all_chunks.get_child(chunk_id)
#	var exits: Array[Vector2i] = get_exits(chunk, exit_dir)
#
#	for exit_pos in exits:
#		# generate the hitbox for this chunk:
#		var collider: CollisionShape2D = CollisionShape2D.new()
#		var shape: RectangleShape2D = RectangleShape2D.new()
#		var global_pos: Vector2i = spawn_pos-exit_pos
#		shape.size = chunk.get_used_rect().size*gb.tile_size - Vector2i.ONE*2
#		collider.shape = shape
#		collider.position = global_pos*gb.tile_size + chunk.get_used_rect().size*gb.tile_size/2
#		test_area.add_child(collider)
#		await get_tree().physics_frame
#		print(collider.position)
#		if test_area.has_overlapping_areas():
#			collider.queue_free()
#		else:
#			collider.reparent(chunk_areas)
#			draw_chunk(chunk_id, global_pos)
#			add_exits(chunk, global_pos)
#			return true
#	return false

#func spawn_entry(chunk_id:int) -> void:
#	var chunk: TileMap = all_chunks.get_child(chunk_id)
#	var collider: CollisionShape2D = CollisionShape2D.new()
#	var shape: RectangleShape2D = RectangleShape2D.new()
#	shape.size = chunk.get_used_rect().size*gb.tile_size - Vector2i.ONE*2
#	collider.shape = shape
#	collider.position = chunk.get_used_rect().size*gb.tile_size/2
#	chunk_areas.add_child(collider)
#	draw_chunk(chunk_id, Vector2i.ZERO)
#	add_exits(chunk, Vector2i.ZERO)

#func draw_chunk(chunk_id:int, spawn_pos:Vector2i) -> void:
#	# copy the new chunk to the existing level tilemap.
#	var chunk: TileMap = all_chunks.get_child(chunk_id)
#	var curr_pos: Vector2i = Vector2i(0,0)
#	var rect_dims: Vector2i = chunk.get_used_rect().size
#	#! probably have to do this for multiple layers eventually:
#	for layer in range(chunk.get_layers_count()):
#		for cell_pos in chunk.get_used_cells(layer):
#			var atlas_coord = chunk.get_cell_atlas_coords(layer, cell_pos)
#			if layer == FLOOR_LAYER and (cell_pos.x+cell_pos.y)%2 == 0:
#				atlas_coord.x += 3 #! change floor color
#			set_cell(layer, spawn_pos + cell_pos, chunk.get_cell_source_id(layer, cell_pos),atlas_coord)


#func get_entrances(chunk:TileMap, dir:Vector2i) -> Array:
#	var entrances: Array[Vector2i] = []
#	var weights: Array[int] = []
#	var dirs: Array[Vector2i] = []
#	for cell_pos in chunk.get_used_cells(EXTRA_LAYER):
#		var cell_weight: float = chunk.get_cell_tile_data(EXTRA_LAYER, cell_pos).get_custom_data("Exit_Weight")
#		var exit_dir: Vector2i = chunk.get_cell_tile_data(EXTRA_LAYER, cell_pos).get_custom_data("Exit_Dir")
#		if cell_weight != 0 and dir + exit_dir == Vector2i.ZERO:
#			#exits.push_front(world_pos + get_cell_tile_data(AIR_LAYER, world_pos).get_custom_data("Exit_Dir"))
#			#weights.push_front(cell_weight)
#			entrances += [cell_pos]
#	return entrances

#func add_exits(chunk:TileMap, spawn_pos:Vector2i) -> void:
#	for cell_pos in chunk.get_used_cells(AIR_LAYER):
#		var world_pos: Vector2i = spawn_pos + cell_pos
#		var cell_weight: float = get_cell_tile_data(AIR_LAYER, world_pos).get_custom_data("Exit_Weight")
#		var exit_dir: Vector2i = get_cell_tile_data(AIR_LAYER, world_pos).get_custom_data("Exit_Dir")
#		if cell_weight != 0:
#			#exits.push_front(world_pos + get_cell_tile_data(AIR_LAYER, world_pos).get_custom_data("Exit_Dir"))
#			#weights.push_front(cell_weight)
#			exit_list += [world_pos + exit_dir]
#			if exit_weights == []:
#				exit_weights = [cell_weight]
#			else:
#				exit_weights += [cell_weight + exit_weights[-1]]
#			exit_dir_list += [exit_dir]


func update_autotile() -> void:
	# only update the wall layer... for now?:
	#! fix removed tiles (exits, spawners, etc,)... if there are any here.
	set_cells_terrain_connect(WALL_LAYER,get_used_cells(WALL_LAYER),0,0,false) #! these zeros will probably need to change with other terrains?
