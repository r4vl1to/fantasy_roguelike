class_name GaeaChunkImporter
extends RefCounted


func import_grid(
	grid: GaeaGrid,
	chunk_coord: Vector2i,
	chunk_size: int,
	mapping: GaeaMappingRegistry
) -> ChunkData:

	var chunk := ChunkData.new()

	chunk.coord = chunk_coord
	chunk.initialize(chunk_size)

	var layer_map: GaeaValue.Map = grid.get_layer(0)

	for cell in layer_map.get_cells():
		var world_position := Vector2i(
			cell.x,
			cell.y
		)

		var chunk_origin := ChunkMath.chunk_to_world_origin(
			chunk_coord,
			chunk_size
		)

		var local := world_position - chunk_origin

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
		if material is TileMapGaeaMaterial:
			var tile_material: TileMapGaeaMaterial = material as TileMapGaeaMaterial
			chunk.metadata["tile_%d" % index] = {
				"type": tile_material.type,
				"source_id": tile_material.source_id,
				"atlas_coords": tile_material.atlas_coord,
				"alternative_tile": tile_material.alternative_tile,
				"terrain_set": tile_material.terrain_set,
				"terrain": tile_material.terrain,
			}


	return chunk
