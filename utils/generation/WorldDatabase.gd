class_name WorldDatabase
extends RefCounted


var _chunks: Dictionary = {}


func has_chunk(chunk_coord: Vector2i) -> bool:
	return _chunks.has(chunk_coord)


func get_chunk(chunk_coord: Vector2i) -> ChunkData:
	if not _chunks.has(chunk_coord):
		return null

	return _chunks[chunk_coord]


func store_chunk(chunk: ChunkData) -> void:
	if chunk == null:
		push_error("Cannot store null ChunkData.")
		return

	_chunks[chunk.coord] = chunk


func remove_chunk(chunk_coord: Vector2i) -> void:
	_chunks.erase(chunk_coord)


func get_loaded_chunks() -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for coord in _chunks.keys():
		result.append(coord)

	return result
