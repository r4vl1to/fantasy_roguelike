extends Node

var generator: GaeaGenerator
var manager: GaeaWorldManager
var renderer: GaeaChunkRenderer

const CHUNK_SIZE: int = 32
const TEST_ROOT: String = "user://streaming_stress_profile"
const RADII: Array[int] = [1, 2, 4]
const PATH: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 1), Vector2i(3, 0), Vector2i(2, -2), Vector2i(-1, -1)]

var database: WorldDatabase
var persistence: WorldPersistence
var streamer: GaeaChunkStreamer
var failed: bool = false
var started_at_usec: int = 0


func _ready() -> void:
	var world: Node = get_parent().get_node("World")
	generator = world.get_node("GaeaGenerator") as GaeaGenerator
	manager = world.get_node("GaeaWorldManager") as GaeaWorldManager
	renderer = world.get_node("GaeaChunkRenderer") as GaeaChunkRenderer
	if generator == null or manager == null or renderer == null:
		push_error("Stress profiling requires this node to be instanced under world.tscn")
		get_tree().quit(1)
		return
	var mapping: GaeaMappingRegistry = GaeaMappingRegistry.new()
	mapping.build_from_graph(generator.graph)
	database = WorldDatabase.new()
	persistence = WorldPersistence.new(TEST_ROOT)
	manager.setup(generator, mapping, database, persistence, CHUNK_SIZE)
	manager.chunk_ready.connect(_on_chunk_ready)
	manager.chunk_generation_failed.connect(_on_chunk_failed)
	renderer.shared_tile_set = _get_shared_tileset()
	streamer = GaeaChunkStreamer.new()
	add_child(streamer)
	streamer.chunks_to_load.connect(_on_load)
	streamer.chunks_to_unload.connect(_on_unload)
	print("=== STREAMING STRESS / MEMORY PROFILE ===")
	for radius: int in RADII:
		streamer.stream_radius = radius
		started_at_usec = Time.get_ticks_usec()
		for center: Vector2i in PATH:
			streamer.update_player_chunk(center)
			manager.set_required_chunks(streamer.required_chunks.keys())
			await get_tree().process_frame
			await get_tree().process_frame
		await _wait_stable()
		var elapsed_ms: float = float(Time.get_ticks_usec() - started_at_usec) / 1000.0
		var cell_count: int = database.get_loaded_chunks().size() * CHUNK_SIZE * CHUNK_SIZE
		var estimated_bytes: int = cell_count * 8
		print("radius=%d active=%d rendered=%d estimated_terrain_bytes=%d path_elapsed_ms=%.2f" % [radius, database.get_loaded_chunks().size(), renderer._rendered_chunks.size(), estimated_bytes, elapsed_ms])
		if database.get_loaded_chunks().size() != (radius * 2 + 1) * (radius * 2 + 1):
			failed = true
			push_error("Unexpected loaded chunk count at radius %d" % radius)
	print("=== STREAMING STRESS / MEMORY PROFILE %s ===" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _get_shared_tileset() -> TileSet:
	var world: Node = get_node("World")
	var candidate: Node = world.find_child("TileMapLayer", true, false)
	if candidate is TileMapLayer:
		return (candidate as TileMapLayer).tile_set
	return null


func _on_load(coords: Array[Vector2i]) -> void:
	manager.set_required_chunks(streamer.required_chunks.keys())
	for coord: Vector2i in coords:
		manager.request_chunk(coord)


func _on_unload(coords: Array[Vector2i]) -> void:
	for coord: Vector2i in coords:
		renderer.unrender_chunk(coord)
		manager.unload_chunk(coord)


func _on_chunk_ready(chunk: ChunkData) -> void:
	if streamer.is_required(chunk.coord):
		renderer.render_chunk(chunk)
	else:
		manager.unload_chunk(chunk.coord)


func _on_chunk_failed(coord: Vector2i) -> void:
	failed = true
	push_error("Chunk generation failed: %s" % coord)


func _wait_stable() -> void:
	var elapsed: float = 0.0
	while elapsed < 60.0:
		var all_loaded: bool = true
		for coord: Vector2i in streamer.required_chunks.keys():
			if not database.has_chunk(coord):
				all_loaded = false
		if all_loaded and renderer._rendered_chunks.size() == streamer.required_chunks.size():
			return
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	failed = true
	push_error("Timed out waiting for profile stream")
