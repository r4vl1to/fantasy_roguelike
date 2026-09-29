extends Node


func _ready() -> void:
	print("========================================")
	print("WORLD DATABASE TEST")
	print("========================================")

	var database := WorldDatabase.new()

	var coord := Vector2i(3, -2)

	print("Has chunk before store: ", database.has_chunk(coord))

	var chunk := ChunkData.new()

	chunk.coord = coord
	chunk.initialize(32)

	database.store_chunk(chunk)

	print("Has chunk after store: ", database.has_chunk(coord))

	var loaded := database.get_chunk(coord)

	if loaded == null:
		push_error("Chunk was not loaded from database.")
		return

	print("Loaded chunk coord: ", loaded.coord)
	print("Loaded chunk size: ", loaded.size)
	print("Loaded terrain count: ", loaded.terrain.size())

	database.remove_chunk(coord)

	print("Has chunk after remove: ", database.has_chunk(coord))
