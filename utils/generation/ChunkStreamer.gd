class_name ChunkStreamer
extends RefCounted

signal chunks_to_load(chunks: Array[Vector2i])
signal chunks_to_unload(chunks: Array[Vector2i])

var loading_radius: int = 1
var current_chunk: Vector2i = Vector2i.ZERO

var active_chunks: Dictionary = {}


func _init(p_loading_radius: int = 1) -> void:
	loading_radius = p_loading_radius


func update_player_chunk(chunk_coord: Vector2i) -> void:
	if chunk_coord == current_chunk and not active_chunks.is_empty():
		return

	current_chunk = chunk_coord

	var required_chunks := get_required_chunks()

	var required_set: Dictionary = {}

	for coord in required_chunks:
		required_set[coord] = true

	var load_list: Array[Vector2i] = []
	var unload_list: Array[Vector2i] = []

	# Chunks nuevos.
	for coord in required_set.keys():
		if not active_chunks.has(coord):
			load_list.append(coord)

	# Chunks que ya no son necesarios.
	for coord in active_chunks.keys():
		if not required_set.has(coord):
			unload_list.append(coord)

	# Actualizamos nuestro estado lógico.
	for coord in load_list:
		active_chunks[coord] = true

	for coord in unload_list:
		active_chunks.erase(coord)

	if not load_list.is_empty():
		chunks_to_load.emit(load_list)

	if not unload_list.is_empty():
		chunks_to_unload.emit(unload_list)


func get_required_chunks() -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for y in range(
		current_chunk.y - loading_radius,
		current_chunk.y + loading_radius + 1
	):
		for x in range(
			current_chunk.x - loading_radius,
			current_chunk.x + loading_radius + 1
		):
			result.append(Vector2i(x, y))

	return result
