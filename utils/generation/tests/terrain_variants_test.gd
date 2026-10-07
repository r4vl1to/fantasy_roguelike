extends Node

const TEST_ROOT: String = "user://terrain_variants_test"
const CHUNK_SIZE: int = 8

var failed: bool = false
var variant_atlas: TileSetAtlasSource


func _ready() -> void:
	_run()


func _run() -> void:
	var root: Node = get_node("GameFixture")
	var generator: GaeaGenerator = root.get_node("GaeaGenerator") as GaeaGenerator
	var renderer: GaeaChunkRenderer = root.get_node("GaeaChunkRenderer") as GaeaChunkRenderer
	var graph: GaeaGraph = generator.graph
	var tile_set: TileSet = renderer.shared_tile_set
	var atlas: TileSetAtlasSource = tile_set.get_source(0) as TileSetAtlasSource
	variant_atlas = atlas
	var mapping: GaeaMappingRegistry = GaeaMappingRegistry.new()
	mapping.build_from_graph(graph)
	var chunk: ChunkData = ChunkData.new()
	chunk.coord = Vector2i.ZERO
	chunk.initialize(CHUNK_SIZE)
	var base: Vector2i = (graph.get(&"dirt") as TileMapGaeaMaterial).atlas_coord
	var allowed: Array[Vector2i] = GaeaChunkImporter._get_variant_coords(atlas, base)
	var water_base: Vector2i = (graph.get(&"water") as TileMapGaeaMaterial).atlas_coord
	var water_variant: Vector2i = Vector2i(3, 5)
	var water_choice_a: Vector2i = GaeaChunkImporter.choose_visual_variant(atlas, water_base, Vector2i(1, 2), TerrainId.WATER)
	var water_choice_b: Vector2i = GaeaChunkImporter.choose_visual_variant(atlas, water_base, Vector2i(1, 2), TerrainId.WATER)
	_assert(atlas.has_tile(water_variant), "Water variant tile exists at atlas coordinate (3,5)")
	_assert(water_choice_a == water_choice_b, "Water choice remains deterministic")
	_assert([water_base, water_variant].has(water_choice_a), "Water selection uses base or confirmed variant, not animation frames")
	var grass_base: Vector2i = (graph.get(&"grass") as TileMapGaeaMaterial).atlas_coord
	var distinct: Dictionary = {}
	for index: int in range(CHUNK_SIZE * CHUNK_SIZE):
		var world_position: Vector2i = ChunkMath.index_to_local(index, CHUNK_SIZE)
		var coords: Vector2i = _select_variant(allowed, world_position, TerrainId.DIRT)
		chunk.terrain[index] = TerrainId.DIRT
		chunk.metadata["tile_%d" % index] = _tile_metadata(coords)
		distinct[coords] = true
	_assert(allowed.size() > 1, "Atlas row has multiple consecutive tile entries")
	_assert(distinct.size() > 1, "Deterministic coordinate selection produces variation")
	_assert(_all_in_allowed(chunk, allowed), "Every selected coordinate belongs to this terrain's contiguous row")
	_assert(not allowed.has(grass_base), "Dirt choices do not mix with the adjacent terrain's base tile")
	for coords: Vector2i in allowed:
		_assert(atlas.get_tile_animation_frames_count(coords) <= 1, "Dirt variation excludes animation frame tiles")

	var persistence: WorldPersistence = WorldPersistence.new(TEST_ROOT)
	if persistence.has_chunk(chunk.coord):
		persistence.delete_chunk(chunk.coord)
	_assert(persistence.save_chunk(chunk), "Chunk with selected variants is saved")
	var restored: ChunkData = persistence.load_chunk(chunk.coord)
	_assert(restored != null, "Saved variant chunk reloads")
	if restored != null:
		_assert(_metadata_matches(restored.metadata, chunk.metadata), "Selected per-cell atlas coordinates survive serialization")
		var restored_distinct: Dictionary = {}
		for index: int in range(restored.terrain.size()):
			var metadata: Dictionary = restored.metadata["tile_%d" % index]
			var coords: Vector2i = metadata["atlas_coords"] as Vector2i
			restored_distinct[coords] = true
			var local: Vector2i = ChunkMath.index_to_local(index, restored.size)
			_assert(_select_variant(allowed, local, TerrainId.DIRT) == coords, "Reloaded cell retains deterministic choice")
		_assert(restored_distinct.size() > 1, "Reloaded chunk still contains visual variety")

	print("=== TERRAIN VARIANTS TEST %s ===" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _select_variant(allowed: Array[Vector2i], world_position: Vector2i, terrain_id: int) -> Vector2i:
	return GaeaChunkImporter.choose_visual_variant(
		variant_atlas,
		allowed[0],
		world_position,
		terrain_id
	)


func _tile_metadata(coords: Vector2i) -> Dictionary:
	return {
		"type": TileMapGaeaMaterial.Type.SINGLE_CELL,
		"source_id": 0,
		"atlas_coords": coords,
		"alternative_tile": 0,
		"terrain_set": 0,
		"terrain": 0,
	}


func _all_in_allowed(chunk: ChunkData, allowed: Array[Vector2i]) -> bool:
	for index: int in range(chunk.terrain.size()):
		var metadata: Dictionary = chunk.metadata["tile_%d" % index]
		if not allowed.has(metadata["atlas_coords"] as Vector2i):
			return false
	return true


func _metadata_matches(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key: Variant in expected:
		if not actual.has(key):
			return false
		var actual_data: Dictionary = actual[key]
		var expected_data: Dictionary = expected[key]
		if actual_data.get("atlas_coords") != expected_data.get("atlas_coords"):
			return false
	return true


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
		return
	failed = true
	push_error("[FAIL] " + message)
