class_name WorldPersistence
extends RefCounted


var _root_path: String


func _init(root_path: String) -> void:
	_root_path = root_path


func save_chunk(chunk: ChunkData) -> bool:
	if chunk == null:
		push_error("Cannot save null ChunkData.")
		return false

	var path := _get_chunk_path(chunk.coord)

	var directory := path.get_base_dir()

	if not DirAccess.dir_exists_absolute(directory):
		var error := DirAccess.make_dir_recursive_absolute(directory)

		if error != OK:
			push_error(
				"Could not create directory: %s"
				% directory
			)
			return false

	var data := ChunkSerializer.serialize(chunk)

	if data.is_empty():
		push_error(
			"Could not serialize chunk: %s"
			% chunk.coord
		)
		return false

	var file := FileAccess.open(
		path,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"Could not open file for writing: %s"
			% path
		)
		return false

	file.store_string(
		JSON.stringify(data)
	)

	file.close()

	return true


func load_chunk(chunk_coord: Vector2i) -> ChunkData:
	var path := _get_chunk_path(chunk_coord)

	if not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"Could not open chunk file: %s"
			% path
		)
		return null

	var json_text := file.get_as_text()

	file.close()

	var json := JSON.new()

	var error := json.parse(json_text)

	if error != OK:
		push_error(
			"Could not parse chunk file: %s"
			% path
		)
		return null

	var data = json.data

	if typeof(data) != TYPE_DICTIONARY:
		push_error(
			"Chunk file does not contain a Dictionary: %s"
			% path
		)
		return null

	return ChunkSerializer.deserialize(data)


func has_chunk(chunk_coord: Vector2i) -> bool:
	return FileAccess.file_exists(
		_get_chunk_path(chunk_coord)
	)


func delete_chunk(chunk_coord: Vector2i) -> bool:
	var path := _get_chunk_path(chunk_coord)

	if not FileAccess.file_exists(path):
		return false

	var error := DirAccess.remove_absolute(path)

	return error == OK


func _get_chunk_path(chunk_coord: Vector2i) -> String:
	return "%s/chunks/%d_%d.json" % [
		_root_path,
		chunk_coord.x,
		chunk_coord.y
	]
