class_name GaeaChunkImporter
extends RefCounted


static var _variant_cache: Dictionary = {}


func import_grid(
	grid: GaeaGrid,
	chunk_coord: Vector2i,
	chunk_size: int,
	mapping: GaeaMappingRegistry,
	_variant_source: TileSetAtlasSource = null
) -> ChunkData:

	var chunk := ChunkData.new()

	chunk.coord = chunk_coord
	chunk.initialize(chunk_size)

	var layer_map: GaeaValue.Map = grid.get_layer(0)
	if layer_map == null:
		push_error("Gaea grid has no output layer 0 for chunk %s." % chunk_coord)
		return chunk
	var chunk_origin: Vector2i = ChunkMath.chunk_to_world_origin(chunk_coord, chunk_size)
	var imported_cell_count: int = 0

	for cell in layer_map.get_cells():
		var world_position := Vector2i(
			cell.x,
			cell.y
		)

		var local: Vector2i = world_position - chunk_origin

		if not chunk.contains_local(local):
			push_error(
                "Gaea cell %s is outside chunk %s."
				% [cell, chunk_coord]
			)
			continue

		var material: GaeaMaterial = layer_map.get_cell(cell)
		if not mapping.has_material(material):
			push_error("Gaea material has no TerrainId mapping at %s." % world_position)
			continue

		var terrain_id: int = mapping.terrain_id_from_material(material)
		var index: int = ChunkMath.local_to_index(local, chunk_size)
		chunk.terrain[index] = terrain_id
		imported_cell_count += 1
		if material is TileMapGaeaMaterial:
			var tile_material: TileMapGaeaMaterial = material as TileMapGaeaMaterial
			var chosen_atlas_coords: Vector2i = tile_material.atlas_coord
			if _variant_source != null and tile_material.type == TileMapGaeaMaterial.Type.SINGLE_CELL and tile_material.source_id == 0:
				chosen_atlas_coords = choose_visual_variant(_variant_source, tile_material.atlas_coord, world_position, terrain_id)
			chunk.metadata["tile_%d" % index] = {
				"type": tile_material.type,
				"source_id": tile_material.source_id,
				"atlas_coords": chosen_atlas_coords,
				"alternative_tile": tile_material.alternative_tile,
				"terrain_set": tile_material.terrain_set,
				"terrain": tile_material.terrain,
			}

	if imported_cell_count == 0:
		push_warning("Gaea graph produced no mapped cells for chunk %s." % chunk_coord)

	return chunk


static func choose_visual_variant(
	source: TileSetAtlasSource,
	base_coords: Vector2i,
	world_position: Vector2i,
	terrain_id: int
) -> Vector2i:
	if source == null or not source.has_tile(base_coords):
		return base_coords
	var choices: Array[Vector2i] = _get_variant_coords(source, base_coords)
	if choices.size() <= 1:
		return base_coords
	var seed_text: String = "%d:%d:%d:%d" % [world_position.x, world_position.y, terrain_id, base_coords.x * 1000 + base_coords.y]
	var seed_value: int = seed_text.hash()
	return choices[posmod(seed_value, choices.size())]


static func _get_variant_coords(source: TileSetAtlasSource, base_coords: Vector2i) -> Array[Vector2i]:
	var key: String = "%d:%d:%d" % [source.get_instance_id(), base_coords.x, base_coords.y]
	if _variant_cache.has(key):
		return _variant_cache[key]
	var choices: Array[Vector2i] = _get_horizontal_variant_coords(source, base_coords)
	if base_coords == Vector2i(1, 5):
		var water_variant: Vector2i = Vector2i(3, 5)
		if source.has_tile(water_variant) and not choices.has(water_variant):
			choices.append(water_variant)
		choices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	if choices.size() <= 1:
		var base_data: TileData = source.get_tile_data(base_coords, 0)
		var terrain_set: int = base_data.terrain_set if base_data != null else -1
		var terrain: int = base_data.terrain if base_data != null else -1
		for tile_index: int in range(source.get_tiles_count()):
			var coords: Vector2i = source.get_tile_id(tile_index)
			if coords == base_coords or source.get_tile_animation_frames_count(coords) > 1:
				continue
			var candidate_data: TileData = source.get_tile_data(coords, 0)
			if candidate_data == null or candidate_data.terrain_set != terrain_set or candidate_data.terrain != terrain:
				continue
			choices.append(coords)
		if not choices.has(base_coords):
			choices.append(base_coords)
		choices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if a.y == base_coords.y:
				return a.x < b.x
			return a.y < base_coords.y
		)
	_variant_cache[key] = choices
	return choices


static func _get_horizontal_variant_coords(
	source: TileSetAtlasSource,
	base_coords: Vector2i
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var base_row: Array[Vector2i] = []
	for tile_index: int in range(source.get_tiles_count()):
		var coords: Vector2i = source.get_tile_id(tile_index)
		if coords.y == base_coords.y:
			base_row.append(coords)
	base_row.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var include_next: bool = false
	var previous_x: int = base_coords.x - 1
	for coords: Vector2i in base_row:
		if coords == base_coords:
			include_next = true
			result.append(coords)
			previous_x = coords.x
			continue
		if include_next:
			if coords.x != previous_x + 1:
				break
			result.append(coords)
			previous_x = coords.x
	return result
