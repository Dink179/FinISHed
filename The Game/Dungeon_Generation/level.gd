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
	AIR_LAYER
}

var all_chunks: Node2D

var spawn: bool = true
var accept_frame: bool = false
var num_chunks: int = 5
var targ_pos: Vector2i = Vector2i.ZERO

var exit_list: Array[Vector2i] = []
var exit_dir_list: Array[Vector2i] = []
var exit_weights: Array[float] = []
var temp_list: Array[Vector2i] = [] #! should be removable... but it breaks.
var temp_weights: Array[float] = []
var temp_inds: Array[int] = []

var level_seed: int = 0

func _ready():
	randomize()
	if level_seed == 0:
		level_seed = randi()%1000000
	seed(level_seed)
	
	all_chunks = Chunks.instantiate()
	add_child(all_chunks)
	
	var cur_chunks: int = 0
	var total_chunk_count = all_chunks.get_child_count()
	var target_exit: int
	var temp_ind: int
	while cur_chunks < num_chunks:
		if exit_list.is_empty():
			#! spawn entry room:
			spawn_entry(randi_range(0,total_chunk_count-1))
			cur_chunks += 1
			reset_temp()
			print(temp_weights)
		else:
			temp_ind = temp_weights.bsearch(randf_range(0.0, temp_weights[-1]))
			target_exit = temp_inds[temp_ind]
			targ_pos = exit_list[target_exit]
			#! need this to check all available chunks.... then move on to ban the exit.
			if await check_chunk(randi_range(0,total_chunk_count-1), targ_pos, exit_dir_list[target_exit]):
				cur_chunks += 1
				use_exit(target_exit)
				#print(len(temp_inds), len(temp_list))
			else:
				ban_exit(temp_ind)
	
	
	update_autotile()
#	for exit in exit_list:
#		var temp_sprite = Sprite2D.new()
#		temp_sprite.texture = load("res://Graphics/_Test_Floor.png")
#		temp_sprite.position = exit*gb.tile_size
#		temp_sprite.centered = false
#		add_child(temp_sprite)
	
	# delete unnecessary nodes:
	chunk_areas.queue_free()
	test_area.queue_free()
	all_chunks.queue_free()
	# duplicate tilemap, shift up, change texture to get the walls working.

func _physics_process(delta):
	if Input.is_action_pressed("ui_up"):
		cam.position.y -= 1
	if Input.is_action_pressed("ui_down"):
		cam.position.y += 1
	if Input.is_action_pressed("ui_left"):
		cam.position.x -= 1
	if Input.is_action_pressed("ui_right"):
		cam.position.x += 1

func load_chunks(num_chunks:int, spawn_data:Array) -> void:
	pass
	#! come back to spawn_data later...
	
	
func reset_temp() -> void:
	temp_list = exit_list
	temp_weights = exit_weights
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
	temp_list.pop_at(ind)
	temp_weights.pop_at(ind)
	temp_inds.pop_at(ind)
	for i in range(ind,temp_weights.size()):
		temp_weights[i] -= weight


func check_chunk(chunk_id:int, spawn_pos:Vector2i, exit_dir:Vector2i) -> bool:
	# compare the target chunk area to the target draw location. Return true if the target chunk fits (does not collide)
	#! there will also be an offset for the specific join location
	var chunk: TileMap = all_chunks.get_child(chunk_id)
	var exits: Array[Vector2i] = get_exits(chunk, exit_dir)
	
	for exit_pos in exits:
		# generate the hitbox for this chunk:
		var collider: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		var global_pos: Vector2i = spawn_pos-exit_pos
		shape.size = chunk.get_used_rect().size*gb.tile_size - Vector2i.ONE*2
		collider.shape = shape
		collider.position = global_pos*gb.tile_size + chunk.get_used_rect().size*gb.tile_size/2
		test_area.add_child(collider)
		await get_tree().physics_frame
		print(collider.position)
		if test_area.has_overlapping_areas():
			collider.queue_free()
		else:
			collider.reparent(chunk_areas)
			draw_chunk(chunk_id, global_pos)
			add_exits(chunk, global_pos)
			return true
	return false

func spawn_entry(chunk_id:int) -> void:
	var chunk: TileMap = all_chunks.get_child(chunk_id)
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = chunk.get_used_rect().size*gb.tile_size - Vector2i.ONE*2
	collider.shape = shape
	collider.position = chunk.get_used_rect().size*gb.tile_size/2
	chunk_areas.add_child(collider)
	draw_chunk(chunk_id, Vector2i.ZERO)
	add_exits(chunk, Vector2i.ZERO)

func draw_chunk(chunk_id:int, spawn_pos:Vector2i) -> void:
	# copy the new chunk to the existing level tilemap.
	var chunk: TileMap = all_chunks.get_child(chunk_id)
	var curr_pos: Vector2i = Vector2i(0,0)
	var rect_dims: Vector2i = chunk.get_used_rect().size
	#! probably have to do this for multiple layers eventually:
	for layer in range(chunk.get_layers_count()):
		for cell_pos in chunk.get_used_cells(layer):
			var atlas_coord = chunk.get_cell_atlas_coords(layer, cell_pos)
			if layer == FLOOR_LAYER and (cell_pos.x+cell_pos.y)%2 == 0:
				atlas_coord.x += 3 #! change floor color
			set_cell(layer, spawn_pos + cell_pos, chunk.get_cell_source_id(layer, cell_pos),atlas_coord)


func get_exits(chunk:TileMap, dir:Vector2i) -> Array:
	var exits: Array[Vector2i] = []
	var weights: Array[int] = []
	var dirs: Array[Vector2i] = []
	for cell_pos in chunk.get_used_cells(AIR_LAYER):
		var cell_weight: float = chunk.get_cell_tile_data(AIR_LAYER, cell_pos).get_custom_data("Exit_Weight")
		var exit_dir: Vector2i = chunk.get_cell_tile_data(AIR_LAYER, cell_pos).get_custom_data("Exit_Dir")
		if cell_weight != 0 and dir + exit_dir == Vector2i.ZERO:
			#exits.push_front(world_pos + get_cell_tile_data(AIR_LAYER, world_pos).get_custom_data("Exit_Dir"))
			#weights.push_front(cell_weight)
			exits += [cell_pos]
	return exits

func add_exits(chunk:TileMap, spawn_pos:Vector2i) -> void:
	for cell_pos in chunk.get_used_cells(AIR_LAYER):
		var world_pos: Vector2i = spawn_pos + cell_pos
		var cell_weight: float = get_cell_tile_data(AIR_LAYER, world_pos).get_custom_data("Exit_Weight")
		var exit_dir: Vector2i = get_cell_tile_data(AIR_LAYER, world_pos).get_custom_data("Exit_Dir")
		if cell_weight != 0:
			#exits.push_front(world_pos + get_cell_tile_data(AIR_LAYER, world_pos).get_custom_data("Exit_Dir"))
			#weights.push_front(cell_weight)
			exit_list += [world_pos + exit_dir]
			if exit_weights == []:
				exit_weights = [cell_weight]
			else:
				exit_weights += [cell_weight + exit_weights[-1]]
			exit_dir_list += [exit_dir]


func update_autotile() -> void:
	# only update the wall layer... for now?:
	#! fix removed tiles (exits, spawners, etc,)... if there are any here.
	set_cells_terrain_connect(1,get_used_cells(1),0,0,false) #! these zeros will probably need to change with other terrains?
