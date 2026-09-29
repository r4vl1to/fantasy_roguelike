## Renders chunks with the project's shared atlas TileSet.
class_name GaeaChunkRenderer
extends Node

## Pixel size of one terrain tile; must match WorldConfig.tile_size.
var tile_size: int = 16

## Shared TileSet resource taken from the world TileMapLayer.
@export var shared_tile_set: TileSet

## TerrainId to Gaea material render descriptor: {source_id, atlas_coords, alternative_tile}.
var terrain_materials: Dictionary = {}

## Chunk coordinate to its TileMapLayer node.
var _rendered_chunks: Dictionary = {}

const ATLAS_SOURCE_ID: int = 0


func _ready() -> void:
	if shared_tile_set == null:
		push_error("GaeaChunkRenderer requires a shared TileSet from the world scene.")


## Renders a chunk if it is not already present.
func render_chunk(chunk: ChunkData) -> void:
	if _rendered_chunks.has(chunk.coord):
		return
	if shared_tile_set == null:
		push_error("Cannot render chunk without a shared TileSet.")
		return

	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "Chunk_%d_%d" % [chunk.coord.x, chunk.coord.y]
	layer.tile_set = shared_tile_set
	var origin: Vector2i = ChunkMath.chunk_to_world_origin(chunk.coord, chunk.size)
	layer.position = Vector2(origin) * tile_size
	add_child(layer)

	var terrain_cells: Dictionary = {}
	for index: int in chunk.terrain.size():
		var terrain_id: int = chunk.terrain[index]
		if not terrain_materials.has(terrain_id):
			push_warning("No Gaea material mapping for TerrainId %d; skipping tile." % terrain_id)
			continue
		var material_data: Dictionary = terrain_materials[terrain_id]
		var material_type: int = int(material_data["type"])
		var local: Vector2i = ChunkMath.index_to_local(index, chunk.size)
		if material_type == TileMapGaeaMaterial.Type.TERRAIN:
			var terrain_key: Vector2i = Vector2i(int(material_data["terrain_set"]), int(material_data["terrain"]))
			terrain_cells.get_or_add(terrain_key, []).append(local)
			continue
		var source_id: int = int(material_data["source_id"])
		var atlas_coords: Vector2i = material_data["atlas_coords"]
		var alternative_tile: int = int(material_data["alternative_tile"])
		if not _has_atlas_tile(source_id, atlas_coords):
			push_error("TileSet source %d has no tile at atlas coordinate %s." % [source_id, atlas_coords])
			layer.queue_free()
			return
		layer.set_cell(local, source_id, atlas_coords, alternative_tile)
	for terrain_key: Vector2i in terrain_cells:
		layer.set_cells_terrain_connect(terrain_cells[terrain_key], terrain_key.x, terrain_key.y, false)

	_rendered_chunks[chunk.coord] = layer
	print("[GaeaChunkRenderer] Rendered chunk ", chunk.coord,
		" | tiles: ", chunk.terrain.size(), " | origin px: ", layer.position)


func _has_atlas_tile(source_id: int, atlas_coords: Vector2i) -> bool:
	if not shared_tile_set.has_source(source_id):
		return false
	var source: TileSetSource = shared_tile_set.get_source(source_id)
	return source is TileSetAtlasSource and (source as TileSetAtlasSource).has_tile(atlas_coords)


## Removes a chunk's TileMapLayer.
func unrender_chunk(coord: Vector2i) -> void:
	if not _rendered_chunks.has(coord):
		return
	var layer: TileMapLayer = _rendered_chunks[coord]
	layer.queue_free()
	_rendered_chunks.erase(coord)
	print("[GaeaChunkRenderer] Unrendered chunk ", coord)


func is_rendered(coord: Vector2i) -> bool:
	return _rendered_chunks.has(coord)


func clear_all() -> void:
	for coord: Vector2i in _rendered_chunks.keys():
		var layer: TileMapLayer = _rendered_chunks[coord]
		layer.queue_free()
	_rendered_chunks.clear()
	print("[GaeaChunkRenderer] Cleared all rendered chunks.")
