## End-to-end integration test for GaeaWorldManager's real chunk lifecycle.
## Uses an isolated persistence directory and verifies Gaea -> RAM -> disk -> RAM,
## streaming/unload behavior, and rendering based on the Gaea material parameters.
extends Node

@onready var gaea_generator: GaeaGenerator = $"../GaeaGenerator"
@onready var world_manager: GaeaWorldManager = $"../GaeaWorldManager"
@onready var renderer: GaeaChunkRenderer = $"../GaeaChunkRenderer"

const CHUNK_SIZE: int = 32
const TILE_SIZE: int = 16
const TEST_ROOT: String = "user://world_manager_integration_test"
const START_CHUNK: Vector2i = Vector2i(10, 0)
const CHUNK_PX: int = CHUNK_SIZE * TILE_SIZE
const WAIT_TIMEOUT_SECONDS: float = 18.0
const STREAMING_RADIUS: int = 0
const CAPTURE_HOLD_SECONDS: float = 5.0

var mapping: GaeaMappingRegistry
var database: WorldDatabase
var persistence: WorldPersistence
var streamer: ChunkStreamer
var camera: Camera2D
var _materials_by_id: Dictionary = {}
var _ready_chunks: Dictionary = {}
var _failed_coords: Dictionary = {}
var _started_coords: Dictionary = {}
var _failure_count: int = 0


func _ready() -> void:
	print("=== WORLD MANAGER INTEGRATION TEST START ===")
	_assert(gaea_generator.graph != null, "Gaea graph is assigned")
	_assert(renderer.shared_tile_set != null, "Renderer has assigned TileSet")

	mapping = GaeaMappingRegistry.new()
	mapping.build_from_graph(gaea_generator.graph)
	_build_material_lookup()
	database = WorldDatabase.new()
	_clear_test_persistence()
	persistence = WorldPersistence.new(TEST_ROOT)

	world_manager.setup(gaea_generator, mapping, database, persistence, CHUNK_SIZE)
	world_manager.chunk_ready.connect(_on_chunk_ready)
	world_manager.chunk_generation_started.connect(_on_chunk_generation_started)
	world_manager.chunk_generation_failed.connect(_on_chunk_generation_failed)

	renderer.tile_size = TILE_SIZE
	renderer.terrain_materials = _build_render_materials()
	camera = Camera2D.new()
	camera.position = Vector2(START_CHUNK * CHUNK_PX) + Vector2(CHUNK_PX * 0.5, CHUNK_PX * 0.5)
	camera.zoom = Vector2(0.75, 0.75)
	add_child(camera)
	camera.make_current()

	streamer = ChunkStreamer.new(STREAMING_RADIUS)
	streamer.chunks_to_load.connect(_on_chunks_to_load)
	streamer.chunks_to_unload.connect(_on_chunks_to_unload)

	# Test 1: radius zero forces exactly one actual Gaea generation.
	streamer.update_player_chunk(START_CHUNK)
	await _wait_for_ready_count(1)
	_assert(_ready_chunks.size() == 1, "One initial chunk becomes ready")
	_assert(_failure_count == 0, "No generation failures")
	_assert(database.get_loaded_chunks().size() == 1, "Generated chunk is in RAM")
	_assert(persistence.has_chunk(START_CHUNK), "Generated chunk persisted to disk")
	_assert(renderer._rendered_chunks.size() == 1, "Generated chunk rendered")
	_assert_render_tiles_match_materials()

	# Test 2: RAM lookup is synchronous and does not enqueue generation.
	var cached_coord: Vector2i = START_CHUNK
	var count_before_ram_request: int = int(_ready_chunks[cached_coord])
	var generation_started_before_ram_request: int = _started_coords.size()
	world_manager.request_chunk(cached_coord)
	_assert(int(_ready_chunks[cached_coord]) == count_before_ram_request + 1, "RAM emits chunk_ready")
	_assert(_started_coords.size() == generation_started_before_ram_request, "RAM hit skips Gaea generation")

	# Test 3: unload then request proves disk restore and metadata serialization.
	var preserved_chunk: ChunkData = database.get_chunk(cached_coord)
	var preserved_terrain: PackedInt32Array = preserved_chunk.terrain.duplicate()
	var preserved_metadata: Dictionary = preserved_chunk.metadata.duplicate(true)
	_assert(not preserved_metadata.is_empty(), "Chunk stores Gaea tile material metadata")
	_assert(world_manager.unload_chunk(cached_coord), "Unload succeeds")
	_assert(not database.has_chunk(cached_coord), "Unload removes RAM entry")
	_assert(persistence.has_chunk(cached_coord), "Unload preserves disk entry")
	world_manager.request_chunk(cached_coord)
	_assert(database.has_chunk(cached_coord), "Disk hit restores RAM entry")
	var restored_chunk: ChunkData = database.get_chunk(cached_coord)
	_assert(restored_chunk.terrain == preserved_terrain, "Disk restore preserves terrain")
	_assert(_metadata_matches(restored_chunk.metadata, preserved_metadata), "Disk restore preserves Gaea metadata")
	_assert_render_chunk_uses_materials(restored_chunk)

	# Test 4: move one chunk to force unload/save and generation of the next chunk.
	var ready_count_before_move: int = _total_ready_events()
	camera.position.x += CHUNK_PX
	streamer.update_player_chunk(START_CHUNK + Vector2i.RIGHT)
	await _wait_until_stream_stable(1, ready_count_before_move + 1)
	var next_coord: Vector2i = START_CHUNK + Vector2i.RIGHT
	_assert(renderer._rendered_chunks.size() == 1, "Streaming keeps one chunk at radius zero")
	_assert(database.get_loaded_chunks().size() == 1, "Streaming keeps one RAM chunk at radius zero")
	_assert(renderer.is_rendered(next_coord), "Incoming chunk is rendered")
	_assert(database.has_chunk(next_coord), "Incoming chunk is in RAM")
	_assert(not renderer.is_rendered(START_CHUNK), "Outgoing chunk renderer removed")
	_assert(not database.has_chunk(START_CHUNK), "Outgoing chunk removed from RAM")
	_assert(persistence.has_chunk(START_CHUNK), "Outgoing chunk remains persisted")
	_assert(_failure_count == 0, "No failures during streaming")

	# Keep the last frame available to run_scene's capture instead of exiting.
	if _failure_count == 0:
		print("[TEST RESULT] PASS | Gaea generation, RAM, disk, metadata, rendering, streaming")
	else:
		print("[TEST RESULT] FAIL | generation failures: %d" % _failure_count)
	await get_tree().create_timer(CAPTURE_HOLD_SECONDS).timeout


func _build_render_materials() -> Dictionary:
	var result: Dictionary = {}
	for terrain_id: int in _materials_by_id.keys():
		var material: GaeaMaterial = _materials_by_id[terrain_id] as GaeaMaterial
		if not (material is TileMapGaeaMaterial):
			continue
		var tile_material: TileMapGaeaMaterial = material as TileMapGaeaMaterial
		result[terrain_id] = {
			"type": tile_material.type,
			"source_id": tile_material.source_id,
			"atlas_coords": tile_material.atlas_coord,
			"alternative_tile": tile_material.alternative_tile,
			"terrain_set": tile_material.terrain_set,
			"terrain": tile_material.terrain,
		}
	return result


func _build_material_lookup() -> void:
	for terrain_id: int in [TerrainId.DIRT, TerrainId.GRASS, TerrainId.SAND, TerrainId.STONE, TerrainId.WATER]:
		var material: GaeaMaterial = gaea_generator.graph.get(_parameter_name(terrain_id)) as GaeaMaterial
		_assert(material != null, "Graph material exists for TerrainId %d" % terrain_id)
		_materials_by_id[terrain_id] = material


func _parameter_name(terrain_id: int) -> StringName:
	match terrain_id:
		TerrainId.DIRT: return &"dirt"
		TerrainId.GRASS: return &"grass"
		TerrainId.SAND: return &"sand"
		TerrainId.STONE: return &"stone"
		TerrainId.WATER: return &"water"
	return &""


func _assert_render_tiles_match_materials() -> void:
	var coords: Array = renderer._rendered_chunks.keys()
	if not coords.is_empty():
		var coord: Vector2i = coords[0]
		var chunk: ChunkData = database.get_chunk(coord)
		_assert_render_chunk_uses_materials(chunk)


func _assert_render_chunk_uses_materials(chunk: ChunkData) -> void:
	var layer: TileMapLayer = renderer._rendered_chunks.get(chunk.coord) as TileMapLayer
	_assert(layer != null, "Rendered layer exists for %s" % chunk.coord)
	if layer == null:
		return
	var validated_terrain_ids: Dictionary = {}
	for index: int in chunk.terrain.size():
		var terrain_id: int = chunk.terrain[index]
		if validated_terrain_ids.has(terrain_id) or not _materials_by_id.has(terrain_id):
			continue
		var material: GaeaMaterial = _materials_by_id[terrain_id] as GaeaMaterial
		if not (material is TileMapGaeaMaterial):
			continue
		var tile_material: TileMapGaeaMaterial = material as TileMapGaeaMaterial
		if tile_material.type != TileMapGaeaMaterial.Type.SINGLE_CELL:
			continue
		var local: Vector2i = ChunkMath.index_to_local(index, chunk.size)
		_assert(layer.get_cell_source_id(local) == tile_material.source_id, "Terrain %d uses Gaea material source id" % terrain_id)
		_assert(layer.get_cell_atlas_coords(local) == tile_material.atlas_coord, "Terrain %d uses Gaea atlas coordinate" % terrain_id)
		_assert(layer.get_cell_alternative_tile(local) == tile_material.alternative_tile, "Terrain %d uses Gaea alternative" % terrain_id)
		validated_terrain_ids[terrain_id] = true
	_assert(not validated_terrain_ids.is_empty(), "At least one single-cell material tile validated")


func _metadata_matches(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key: Variant in expected:
		if not actual.has(key):
			return false
		var actual_value: Variant = actual[key]
		var expected_value: Variant = expected[key]
		if actual_value is Dictionary and expected_value is Dictionary:
			if not _metadata_matches(actual_value, expected_value):
				return false
		elif actual_value is Vector2i or expected_value is Vector2i:
			if Vector2i(actual_value) != Vector2i(expected_value):
				return false
		elif actual_value != expected_value:
			return false
	return true


func _clear_test_persistence() -> void:
	var root: String = ProjectSettings.globalize_path(TEST_ROOT + "/chunks")
	if not DirAccess.dir_exists_absolute(root):
		return
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			DirAccess.remove_absolute(root.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func _wait_for_ready_count(target: int) -> void:
	var elapsed: float = 0.0
	while _ready_chunks.size() < target and _failure_count == 0 and elapsed < WAIT_TIMEOUT_SECONDS:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	_assert(_ready_chunks.size() >= target, "Received %d of %d expected chunk_ready signals" % [_ready_chunks.size(), target])


func _wait_until_stream_stable(target_render_count: int, minimum_ready_events: int) -> void:
	var elapsed: float = 0.0
	while elapsed < WAIT_TIMEOUT_SECONDS:
		if renderer._rendered_chunks.size() == target_render_count and _total_ready_events() >= minimum_ready_events:
			return
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	_assert(false, "Timed out waiting for streamed chunks")


func _total_ready_events() -> int:
	var total: int = 0
	for count: int in _ready_chunks.values():
		total += count
	return total


func _coords_left_after_move() -> Array[Vector2i]:
	var old_coords: Array[Vector2i] = []
	for y: int in range(START_CHUNK.y - 1, START_CHUNK.y + 2):
		old_coords.append(Vector2i(START_CHUNK.x - 1, y))
	return old_coords


func _on_chunks_to_load(chunks: Array[Vector2i]) -> void:
	for coord: Vector2i in chunks:
		world_manager.request_chunk(coord)


func _on_chunks_to_unload(chunks: Array[Vector2i]) -> void:
	for coord: Vector2i in chunks:
		renderer.unrender_chunk(coord)
		var unloaded: bool = world_manager.unload_chunk(coord)
		_assert(unloaded, "WorldManager unload succeeds for %s" % coord)


func _on_chunk_ready(chunk: ChunkData) -> void:
	_ready_chunks[chunk.coord] = int(_ready_chunks.get(chunk.coord, 0)) + 1
	renderer.render_chunk(chunk)


func _on_chunk_generation_started(coord: Vector2i) -> void:
	_started_coords[coord] = true


func _on_chunk_generation_failed(coord: Vector2i) -> void:
	_failure_count += 1
	_failed_coords[coord] = true
	push_error("WorldManager failed generating chunk %s" % coord)


func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] ", description)
	else:
		push_error("[FAIL] " + description)
