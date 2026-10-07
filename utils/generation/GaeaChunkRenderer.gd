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
var _render_queue: Array[ChunkData] = []
var _queued_chunk_coords: Dictionary = {}
var _render_queue_active: bool = false
var _terrain_cells_for_current: Dictionary = {}
@export_range(1, 32, 1) var cells_per_frame: int = 128

const ATLAS_SOURCE_ID: int = 0


func _ready() -> void:
	if shared_tile_set == null:
		push_error("GaeaChunkRenderer requires a shared TileSet from the world scene.")


func _process(_delta: float) -> void:
	_process_render_queue()


## Adds a chunk to the incremental renderer queue.
func render_chunk(chunk: ChunkData) -> void:
	if chunk == null:
		return
	if _queued_chunk_coords.has(chunk.coord):
		for queued_chunk: ChunkData in _render_queue:
			if queued_chunk.coord == chunk.coord:
				return
		_queued_chunk_coords.erase(chunk.coord)
	_render_queue.append(chunk)
	_queued_chunk_coords[chunk.coord] = true


func _process_render_queue() -> void:
	if _render_queue.is_empty():
		_render_queue_active = false
		return
	var chunk: ChunkData = _render_queue[0]
	if not _render_queue_active:
		if _rendered_chunks.has(chunk.coord):
			var previous_layer: TileMapLayer = _rendered_chunks[chunk.coord] as TileMapLayer
			if is_instance_valid(previous_layer):
				previous_layer.queue_free()
			_rendered_chunks.erase(chunk.coord)
		if shared_tile_set == null:
			push_error("Cannot render chunk without a shared TileSet.")
			_finish_current_render()
			return
		var layer: TileMapLayer = TileMapLayer.new()
		layer.name = "Chunk_%d_%d" % [chunk.coord.x, chunk.coord.y]
		layer.tile_set = shared_tile_set
		var origin: Vector2i = ChunkMath.chunk_to_world_origin(chunk.coord, chunk.size)
		layer.position = Vector2(origin) * tile_size
		add_child(layer)
		_rendered_chunks[chunk.coord] = layer
		chunk.metadata["__render_cursor"] = 0
		_terrain_cells_for_current.clear()
		_render_queue_active = true
	var current_layer: TileMapLayer = _rendered_chunks.get(chunk.coord) as TileMapLayer
	if current_layer == null:
		_finish_current_render()
		return
	var cursor: int = int(chunk.metadata.get("__render_cursor", 0))
	var processed: int = 0
	while cursor < chunk.terrain.size() and processed < cells_per_frame:
		_render_cell(current_layer, chunk, cursor)
		cursor += 1
		processed += 1
	chunk.metadata["__render_cursor"] = cursor
	if cursor >= chunk.terrain.size():
		for terrain_key: Vector2i in _terrain_cells_for_current:
			current_layer.set_cells_terrain_connect(_terrain_cells_for_current[terrain_key], terrain_key.x, terrain_key.y, false)
		chunk.metadata.erase("__render_cursor")
		_terrain_cells_for_current.clear()
		_finish_current_render()


func _finish_current_render() -> void:
	if _render_queue.is_empty():
		_render_queue_active = false
		return
	var completed: ChunkData = _render_queue.pop_front()
	_queued_chunk_coords.erase(completed.coord)
	_render_queue_active = false
	print("[GaeaChunkRenderer] Rendered chunk ", completed.coord, " | tiles: ", completed.terrain.size())


func _render_cell(layer: TileMapLayer, chunk: ChunkData, index: int) -> void:
	var terrain_id: int = chunk.terrain[index]
	if not terrain_materials.has(terrain_id):
		return
	var material_data: Dictionary = terrain_materials[terrain_id]
	var tile_metadata: Variant = chunk.metadata.get("tile_%d" % index, null)
	if tile_metadata is Dictionary:
		material_data = tile_metadata
	var local: Vector2i = ChunkMath.index_to_local(index, chunk.size)
	var material_type: int = int(material_data["type"])
	if material_type == TileMapGaeaMaterial.Type.TERRAIN:
		var terrain_key: Vector2i = Vector2i(int(material_data["terrain_set"]), int(material_data["terrain"]))
		_terrain_cells_for_current.get_or_add(terrain_key, []).append(local)
		return
	var source_id: int = int(material_data["source_id"])
	var atlas_coords: Vector2i = material_data["atlas_coords"] as Vector2i
	if not _has_atlas_tile(source_id, atlas_coords):
		push_error("TileSet source %d has no tile at atlas coordinate %s." % [source_id, atlas_coords])
		return
	layer.set_cell(local, source_id, atlas_coords, int(material_data["alternative_tile"]))


func _has_atlas_tile(source_id: int, atlas_coords: Vector2i) -> bool:
	if not shared_tile_set.has_source(source_id):
		return false
	var source: TileSetSource = shared_tile_set.get_source(source_id)
	return source is TileSetAtlasSource and (source as TileSetAtlasSource).has_tile(atlas_coords)


## Removes a chunk's TileMapLayer.
func unrender_chunk(coord: Vector2i) -> void:
	for queued_index: int in range(_render_queue.size() - 1, -1, -1):
		if _render_queue[queued_index].coord == coord:
			_render_queue.remove_at(queued_index)
			_queued_chunk_coords.erase(coord)
			if queued_index == 0:
				_render_queue_active = false
	if not _rendered_chunks.has(coord):
		return
	var layer: TileMapLayer = _rendered_chunks[coord]
	layer.queue_free()
	_rendered_chunks.erase(coord)
	print("[GaeaChunkRenderer] Unrendered chunk ", coord)


func is_rendered(coord: Vector2i) -> bool:
	return _rendered_chunks.has(coord)


func clear_all() -> void:
	_render_queue.clear()
	_queued_chunk_coords.clear()
	_render_queue_active = false
	_terrain_cells_for_current.clear()
	for coord: Vector2i in _rendered_chunks.keys():
		var layer: TileMapLayer = _rendered_chunks[coord]
		layer.queue_free()
	_rendered_chunks.clear()
	print("[GaeaChunkRenderer] Cleared all rendered chunks.")
