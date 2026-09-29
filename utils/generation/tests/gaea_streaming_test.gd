extends Node

@onready var generator: GaeaGenerator = get_node("../GaeaGenerator")
@onready var manager: GaeaWorldManager = get_node("../GaeaWorldManager")
@onready var renderer: GaeaChunkRenderer = get_node("../GaeaChunkRenderer")

const CHUNK_SIZE: int = 32
const TILE_SIZE: int = 16
const TEST_ROOT: String = "user://real_streaming_test"
const WAIT_SECONDS: float = 30.0

var database: WorldDatabase
var persistence: WorldPersistence
var streamer: GaeaChunkStreamer
var material_lookup: Dictionary = {}
var failed: bool = false
var ready_coords: Dictionary = {}
var generation_started: Dictionary = {}
var stream_events: Array[Dictionary] = []
var ecs_world: World
var player: E_Player
var chunk_streaming_system: S_ChunkStreaming
var entity_lifecycle: ChunkEntityLifecycle
var persistent_probes: Array[Entity] = []
var lifecycle_test_root: String = "user://real_streaming_test"


func _ready() -> void:
	print("STREAM TEST ACTIVE SCRIPT VERSION 4")
	print("=== REAL STREAMING TEST ===")
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	var mapping: GaeaMappingRegistry = GaeaMappingRegistry.new()
	mapping.build_from_graph(generator.graph)
	_build_materials(mapping)
	database = WorldDatabase.new()
	_clear_test_data()
	persistence = WorldPersistence.new(TEST_ROOT)
	manager.setup(generator, mapping, database, persistence, CHUNK_SIZE)
	manager.chunk_ready.connect(_on_chunk_ready)
	manager.chunk_generation_started.connect(_on_generation_started)
	manager.chunk_generation_failed.connect(_on_generation_failed)
	renderer.tile_size = TILE_SIZE
	renderer.terrain_materials = material_lookup
	streamer = GaeaChunkStreamer.new()
	streamer.stream_radius = 1
	add_child(streamer)
	streamer.chunks_to_load.connect(_on_chunks_to_load)
	streamer.chunks_to_unload.connect(_on_chunks_to_unload)
	_setup_gecs_streaming()
	entity_lifecycle = ChunkEntityLifecycle.new()
	entity_lifecycle.configure(ecs_world, TEST_ROOT)
	manager.configure_entity_lifecycle(entity_lifecycle)
	for index: int in range(3):
		var probe: Entity = E_ChunkProbe.new()
		probe.name = "PersistentProbe%d" % index
		probe.add_component(C_Position.new())
		probe.add_component(C_CurrentChunk.new())
		probe.add_component(C_ChunkResident.new())
		var probe_position: C_Position = probe.get_component(C_Position) as C_Position
		var probe_chunk: C_CurrentChunk = probe.get_component(C_CurrentChunk) as C_CurrentChunk
		probe_position.world_position = Vector2(8.0 + float(index) * 5.0, 8.0 + float(index) * 7.0)
		probe_chunk.coord = Vector2i.ZERO
		persistent_probes.append(probe)
		ecs_world.add_entity(probe, null, false)

	var player_chunk: C_CurrentChunk = player.get_component(C_CurrentChunk) as C_CurrentChunk
	player_chunk.coord = Vector2i(-1, 0)
	_set_player_chunk(Vector2i.ZERO)
	await _run_rapid_streaming_test()
	if failed:
		print("=== RAPID STREAMING TEST FAIL ===")
		get_tree().quit(1)
		return
	_check_state(Vector2i(5, 0))
	_validate_coords(Vector2i(5, 0))
	_assert(_residents_in_chunk(Vector2i.ZERO).is_empty(), "All chunk residents removed from GECS when their chunk unloads")
	_assert(FileAccess.file_exists(_entity_path(Vector2i.ZERO)), "All chunk residents persisted to disk on unload")
	var persisted_entities: Array[Entity] = ChunkEntityPersistence.load_chunk_entities(_entity_path(Vector2i.ZERO))
	_assert(persisted_entities.size() == persistent_probes.size(), "Disk contains every resident entity record")
	print("=== RAPID STREAMING TEST PASS ===")
	_set_player_chunk(Vector2i.ZERO)
	await _wait_stable(9)
	if failed:
		print("=== REAL STREAMING TEST FAIL ===")
		get_tree().quit(1)
		return
	_check_state(Vector2i.ZERO)
	_validate_coords(Vector2i.ZERO)
	var restored_on_return: Array[Entity] = _residents_in_chunk(Vector2i.ZERO)
	_assert(restored_on_return.size() == persistent_probes.size(), "All chunk residents restored to GECS when their chunk is loaded again")
	for index: int in range(min(restored_on_return.size(), persistent_probes.size())):
		var restored_probe: Entity = _find_entity_by_name(restored_on_return, "PersistentProbe%d" % index)
		_assert(restored_probe != null, "Resident %d restored with its identity" % index)
		if restored_probe != null:
			var restored_position: C_Position = restored_probe.get_component(C_Position) as C_Position
			var expected_position: Vector2 = Vector2(8.0 + float(index) * 5.0, 8.0 + float(index) * 7.0)
			_assert(restored_position != null and restored_position.world_position == expected_position, "Resident %d retains serialized position" % index)
	await _move_and_check(Vector2i(1, 0), 3, 3)
	await _move_and_check(Vector2i(2, 0), 3, 3)
	await _move_and_check(Vector2i(2, 1), 3, 3)
	print("RETURN TO VISITED AREA")
	var generated_before: int = generation_started.size()
	_set_player_chunk(Vector2i(1, 0))
	await _wait_stable(9)
	_check_state(Vector2i(1, 0))
	_assert(generation_started.size() == generated_before, "Visited area restored without new Gaea generation")
	_assert(failed == false, "No chunk generation failures")
	if not failed:
		print("=== REAL STREAMING TEST PASS ===")
		var player_controlled: Array[Entity] = ecs_world.query.with_all([C_PlayerControl, C_Position, C_CurrentChunk]).execute()
		_assert(player_controlled.size() == 1, "Player remains in GECS and is not treated as chunk-resident")
	else:
		print("=== REAL STREAMING TEST FAIL ===")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0 if not failed else 1)


func _setup_gecs_streaming() -> void:
	ecs_world = World.new()
	add_child(ecs_world)
	ECS.world = ecs_world
	player = E_Player.new()
	player.name = "Player"
	ecs_world.add_entity(player)
	var position: C_Position = player.get_component(C_Position) as C_Position
	var current_chunk: C_CurrentChunk = player.get_component(C_CurrentChunk) as C_CurrentChunk
	position.world_position = Vector2.ZERO
	current_chunk.coord = Vector2i.ZERO
	chunk_streaming_system = S_ChunkStreaming.new()
	chunk_streaming_system.configure(streamer, CHUNK_SIZE)
	ecs_world.add_system(chunk_streaming_system)


func _set_player_chunk(coord: Vector2i) -> void:
	var position: C_Position = player.get_component(C_Position) as C_Position
	position.world_position = Vector2(ChunkMath.chunk_to_world_origin(coord, CHUNK_SIZE))
	ECS.process(0.0)


func _residents_in_chunk(coord: Vector2i) -> Array[Entity]:
	var result: Array[Entity] = []
	var residents: Array[Entity] = ecs_world.query.with_all([C_ChunkResident, C_CurrentChunk]).execute()
	for resident: Entity in residents:
		var resident_chunk: C_CurrentChunk = resident.get_component(C_CurrentChunk) as C_CurrentChunk
		if resident_chunk != null and resident_chunk.coord == coord:
			result.append(resident)
	return result


func _find_entity_by_name(entities: Array[Entity], entity_name: String) -> Entity:
	for entity: Entity in entities:
		if entity.name == entity_name:
			return entity
	return null


func _entity_path(coord: Vector2i) -> String:
	return "%s/entities/%d_%d.json" % [TEST_ROOT, coord.x, coord.y]


func _build_materials(_mapping: GaeaMappingRegistry) -> void:
	for terrain_id: int in [TerrainId.DIRT, TerrainId.GRASS, TerrainId.SAND, TerrainId.STONE, TerrainId.WATER]:
		var material: GaeaMaterial = generator.graph.get(_parameter_name(terrain_id)) as GaeaMaterial
		if material == null or not (material is TileMapGaeaMaterial):
			push_error("Missing TileMapGaeaMaterial for TerrainId %d" % terrain_id)
			failed = true
			continue
		var tile: TileMapGaeaMaterial = material as TileMapGaeaMaterial
		material_lookup[terrain_id] = {"type": tile.type, "source_id": tile.source_id, "atlas_coords": tile.atlas_coord, "alternative_tile": tile.alternative_tile, "terrain_set": tile.terrain_set, "terrain": tile.terrain}


func _parameter_name(terrain_id: int) -> StringName:
	match terrain_id:
		TerrainId.DIRT: return &"dirt"
		TerrainId.GRASS: return &"grass"
		TerrainId.SAND: return &"sand"
		TerrainId.STONE: return &"stone"
		TerrainId.WATER: return &"water"
	return &""


func _run_rapid_streaming_test() -> void:
	print("=== RAPID STREAMING: (0,0) -> (5,0), no waits ===")
	var event_count_before: int = stream_events.size()
	var rapid_path: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 0),
		Vector2i(4, 0),
		Vector2i(5, 0),
	]
	for coord: Vector2i in rapid_path:
		_set_player_chunk(coord)
	_assert(streamer.required_chunks.size() == 9, "Rapid movement ends with exactly 9 required chunks")
	_assert(stream_events.size() == event_count_before + 5, "All five rapid transitions emitted load events")
	await _wait_stable(9)
	_check_state(Vector2i(5, 0))
	_validate_coords(Vector2i(5, 0))
	_assert(manager._pending_chunks.is_empty(), "No chunk generation remains pending after rapid movement")
	for coord: Vector2i in ready_coords.keys():
		if not streamer.is_required(coord):
			_assert(not renderer.is_rendered(coord), "Abandoned chunk is not rendered: %s" % coord)
	for coord: Vector2i in renderer._rendered_chunks.keys():
		_assert(streamer.is_required(coord), "No stale rendered chunk after rapid movement: %s" % coord)
	var player_chunk: C_CurrentChunk = player.get_component(C_CurrentChunk) as C_CurrentChunk
	_assert(player_chunk.coord == Vector2i(5, 0), "GECS player chunk state follows streaming transitions")
	print("=== RAPID STREAMING STABLE ===")


func _move_and_check(coord: Vector2i, expected_load: int, expected_unload: int) -> void:
	var before_events: int = stream_events.size()
	print("TEST MOVING PLAYER TO: ", coord)
	_set_player_chunk(coord)
	print("TRANSITION EMITTED; EVENTS: ", stream_events.size())
	await _wait_stable(9)
	print("TRANSITION STABLE: ", coord)
	if failed:
		return
	_assert(stream_events.size() == before_events + 1, "One incremental transition recorded")
	if stream_events.size() > before_events:
		var event: Dictionary = stream_events[-1]
		_assert((event["load"] as Array).size() == expected_load, "Expected load count at %s" % coord)
		_assert((event["unload"] as Array).size() == expected_unload, "Expected unload count at %s" % coord)
	_check_state(coord)
	_validate_coords(coord)


func _check_state(player_chunk: Vector2i) -> void:
	var required: Array[Vector2i] = _expected_coords(player_chunk)
	_assert(streamer.required_chunks.size() == 9, "Required count is 9 at %s" % player_chunk)
	_assert(renderer._rendered_chunks.size() == 9, "Rendered count is 9 at %s" % player_chunk)
	_assert(database.get_loaded_chunks().size() == 9, "RAM count is 9 at %s" % player_chunk)
	for coord: Vector2i in required:
		_assert(streamer.is_required(coord), "Required coordinate %s" % coord)
		_assert(renderer.is_rendered(coord), "Rendered coordinate %s" % coord)
		_assert(database.has_chunk(coord), "RAM coordinate %s" % coord)
	print("PLAYER CHUNK: ", player_chunk, " | Required: 9 | Rendered: 9 | RAM: 9")


func _validate_coords(_center: Vector2i) -> void:
	for coord: Vector2i in renderer._rendered_chunks.keys():
		_assert(streamer.is_required(coord), "No rendered chunk outside radius: %s" % coord)


func _expected_coords(center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(center.y - 1, center.y + 2):
		for x: int in range(center.x - 1, center.x + 2):
			result.append(Vector2i(x, y))
	return result


func _wait_stable(target: int) -> void:
	print("WAIT STABLE: target=", target, " render=", renderer._rendered_chunks.size(), " ram=", database.get_loaded_chunks().size(), " required=", streamer.required_chunks.size())
	var elapsed: float = 0.0
	while elapsed < WAIT_SECONDS:
		var all_ready: bool = true
		for coord: Vector2i in streamer.required_chunks.keys():
			if not renderer.is_rendered(coord) or not database.has_chunk(coord):
				all_ready = false
		if all_ready and renderer._rendered_chunks.size() == target and database.get_loaded_chunks().size() == target:
			if all_ready:
				return
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	_assert(false, "Timed out waiting for stream to stabilize")


func _on_chunks_to_load(chunks: Array[Vector2i]) -> void:
	manager.set_required_chunks(streamer.required_chunks.keys())
	var event: Dictionary = {"load": chunks.duplicate(), "unload": []}
	stream_events.append(event)
	print("LOAD: ", chunks.size(), " ", chunks)
	for coord: Vector2i in chunks:
		manager.request_chunk(coord)


func _on_chunks_to_unload(chunks: Array[Vector2i]) -> void:
	var event: Dictionary = stream_events.back() if not stream_events.is_empty() else {"load": [], "unload": []}
	event["unload"] = chunks.duplicate()
	print("UNLOAD: ", chunks.size(), " ", chunks)
	for coord: Vector2i in chunks:
		renderer.unrender_chunk(coord)
		manager.unload_chunk(coord)


func _on_chunk_ready(chunk: ChunkData) -> void:
	if chunk == null:
		push_error("chunk_ready was null")
		failed = true
		return
	ready_coords[chunk.coord] = true
	if streamer == null or streamer.is_required(chunk.coord):
		renderer.render_chunk(chunk)
	else:
		# A generation can finish after its coordinate was unloaded while Gaea was busy.
		# Evict it immediately so abandoned work cannot inflate the final RAM set.
		manager.unload_chunk(chunk.coord)


func _on_generation_started(coord: Vector2i) -> void:
	generation_started[coord] = true


func _on_generation_failed(coord: Vector2i) -> void:
	failed = true
	push_error("Generation failed for %s" % coord)


func _clear_test_data() -> void:
	for subdirectory: String in ["/chunks", "/entities"]:
		var root: String = ProjectSettings.globalize_path(TEST_ROOT + subdirectory)
		if not DirAccess.dir_exists_absolute(root):
			continue
		var dir: DirAccess = DirAccess.open(root)
		if dir == null:
			continue
		dir.list_dir_begin()
		var filename: String = dir.get_next()
		while not filename.is_empty():
			if not dir.current_is_dir() and filename.ends_with(".json"):
				DirAccess.remove_absolute(root.path_join(filename))
			filename = dir.get_next()
		dir.list_dir_end()


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error("[FAIL] " + message)
