extends Node2D


@onready var loaded_chunk: TileMap = $Loaded_Chunk
@onready var chunk_area: CollisionShape2D = $Loaded_Chunk/Chunk_Area/CollisionShape2D


func _ready():
	chunk_area.shape.size = loaded_chunk.get_used_rect().size*16
	chunk_area.position = loaded_chunk.get_used_rect().size*8
	pass

func save_to_file() -> void:
	var packed_scene = PackedScene.new()
	packed_scene.pack(loaded_chunk)
	#ResourceSaver.save("res://my_scene.tscn", packed_scene)
	print("saved as..")

func load_from_file(chunk_id:String) -> void:
	# search through id numbers or chunk names
	pass
	print("loaded")
