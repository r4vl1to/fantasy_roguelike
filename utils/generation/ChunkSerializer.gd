class_name ChunkSerializer
extends RefCounted


static func serialize(chunk: ChunkData) -> Dictionary:
	if chunk == null:
		push_error("Cannot serialize null ChunkData.")
		return {}

	return {
		"coord_x": chunk.coord.x,
		"coord_y": chunk.coord.y,
		"size": chunk.size,
		"terrain": Array(chunk.terrain),
		"biome": Array(chunk.biome),
		"metadata": _encode_metadata(chunk.metadata),
	}


static func _encode_metadata(value: Variant) -> Variant:
	if value is Vector2i:
		return {"__type": "Vector2i", "x": value.x, "y": value.y}
	if value is Vector2:
		return {"__type": "Vector2", "x": value.x, "y": value.y}
	if value is Dictionary:
		var encoded: Dictionary = {}
		for key: Variant in value:
			encoded[str(key)] = _encode_metadata(value[key])
		return encoded
	if value is Array:
		var encoded_array: Array = []
		for item: Variant in value:
			encoded_array.append(_encode_metadata(item))
		return encoded_array
	return value


static func _decode_metadata(value: Variant) -> Variant:
	if value is Dictionary:
		var typed: Dictionary = value
		var type_name: String = str(typed.get("__type", ""))
		if type_name == "Vector2i":
			return Vector2i(int(typed.get("x", 0)), int(typed.get("y", 0)))
		if type_name == "Vector2":
			return Vector2(float(typed.get("x", 0.0)), float(typed.get("y", 0.0)))
		var decoded: Dictionary = {}
		for key: Variant in typed:
			decoded[key] = _decode_metadata(typed[key])
		return decoded
	if value is Array:
		var decoded_array: Array = []
		for item: Variant in value:
			decoded_array.append(_decode_metadata(item))
		return decoded_array
	return value


static func deserialize(data: Dictionary) -> ChunkData:
	if data.is_empty():
		push_error("Cannot deserialize empty chunk data.")
		return null

	if not data.has("coord_x"):
		push_error("Missing coord_x.")
		return null

	if not data.has("coord_y"):
		push_error("Missing coord_y.")
		return null

	if not data.has("size"):
		push_error("Missing size.")
		return null

	if not data.has("terrain"):
		push_error("Missing terrain.")
		return null

	if not data.has("biome"):
		push_error("Missing biome.")
		return null

	var chunk := ChunkData.new()

	chunk.coord = Vector2i(
		int(data["coord_x"]),
		int(data["coord_y"])
	)

	chunk.initialize(
		int(data["size"])
	)

	var terrain_data: Array = data["terrain"]
	var biome_data: Array = data["biome"]

	if terrain_data.size() != chunk.terrain.size():
		push_error(
			"Invalid terrain count. Expected %d, got %d."
			% [
				chunk.terrain.size(),
				terrain_data.size()
			]
		)
		return null

	if biome_data.size() != chunk.biome.size():
		push_error(
			"Invalid biome count. Expected %d, got %d."
			% [
				chunk.biome.size(),
				biome_data.size()
			]
		)
		return null

	for i in terrain_data.size():
		chunk.terrain[i] = int(terrain_data[i])

	for i in biome_data.size():
		chunk.biome[i] = int(biome_data[i])

	var metadata_data: Variant = data.get("metadata", {})
	if metadata_data is Dictionary:
		chunk.metadata = _decode_metadata(metadata_data) as Dictionary

	return chunk
