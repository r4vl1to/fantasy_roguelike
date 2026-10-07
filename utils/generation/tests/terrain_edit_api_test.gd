extends Node

const TEST_ROOT: String = "user://terrain_edit_api_test"
const TEST_CHUNK: Vector2i = Vector2i(-1, 1)
const CHUNK_SIZE: int = 8

var failed: bool = false
var manager: GaeaWorldManager
var database: WorldDatabase
var persistence: WorldPersistence


func _ready() -> void:
	print("=== TERRAIN EDIT API TEST ===")
	_setup_manager()
	test_rejects_unknown_chunk()
	test_changes_and_persists_ram_chunk()
	test_loads_chunk_from_disk_before_edit()
	test_rejects_invalid_terrain_id()
	print("=== TERRAIN EDIT API TEST %s ===" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _setup_manager() -> void:
	database = WorldDatabase.new()
	persistence = WorldPersistence.new(TEST_ROOT)
	manager = GaeaWorldManager.new()
	manager.chunk_size = CHUNK_SIZE
	manager.database = database
	manager.persistence = persistence
	_clear_test_chunk()


func _clear_test_chunk() -> void:
	if persistence.has_chunk(TEST_CHUNK):
		persistence.delete_chunk(TEST_CHUNK)
	var test_dir: String = ProjectSettings.globalize_path(TEST_ROOT)
	if DirAccess.dir_exists_absolute(test_dir):
		DirAccess.remove_absolute(test_dir)


func test_rejects_unknown_chunk() -> void:
	var result: bool = manager.set_terrain_at(Vector2i(80, 80), TerrainId.GRASS)
	_assert(not result, "Returns false when target chunk is unknown")


func test_changes_and_persists_ram_chunk() -> void:
	var chunk: ChunkData = _make_chunk(TEST_CHUNK)
	var local: Vector2i = Vector2i(2, 3)
	var index: int = ChunkMath.local_to_index(local, CHUNK_SIZE)
	chunk.terrain_set(local, TerrainId.DIRT)
	chunk.metadata["tile_%d" % index] = _tile_metadata()
	database.store_chunk(chunk)
	var changed_chunks: Array[ChunkData] = []
	manager.chunk_changed.connect(func(changed: ChunkData) -> void:
		changed_chunks.append(changed)
	)

	var result: bool = manager.set_terrain_at(ChunkMath.local_to_world(TEST_CHUNK, local, CHUNK_SIZE), TerrainId.MUSHROOM)
	_assert(result, "Returns true after editing a loaded chunk")
	_assert(manager.get_terrain_at(ChunkMath.local_to_world(TEST_CHUNK, local, CHUNK_SIZE)) == TerrainId.MUSHROOM, "RAM terrain lookup returns the new TerrainId")
	_assert(not chunk.metadata.has("tile_%d" % index), "Old per-cell tile metadata is removed after the terrain changes")
	_assert(changed_chunks.size() == 1 and changed_chunks[0] == chunk, "Emits chunk_changed with the edited chunk")

	var restored: ChunkData = persistence.load_chunk(TEST_CHUNK)
	_assert(restored != null and restored.terrain_get(local) == TerrainId.MUSHROOM, "Changed terrain is persisted to disk")
	_assert(restored != null and not restored.metadata.has("tile_%d" % index), "Metadata cleanup survives serialization")


func test_loads_chunk_from_disk_before_edit() -> void:
	var second_coord: Vector2i = Vector2i(2, -2)
	var on_disk: ChunkData = _make_chunk(second_coord)
	var local: Vector2i = Vector2i(1, 1)
	on_disk.terrain_set(local, TerrainId.GRASS)
	persistence.save_chunk(on_disk)
	var world_tile: Vector2i = ChunkMath.local_to_world(second_coord, local, CHUNK_SIZE)

	var result: bool = manager.set_terrain_at(world_tile, TerrainId.STONE)
	_assert(result, "Can edit a chunk that was only on disk")
	_assert(database.has_chunk(second_coord), "Disk-loaded chunk is cached in RAM")
	_assert(manager.get_terrain_at(world_tile) == TerrainId.STONE, "Disk-loaded chunk exposes the edited terrain")
	var restored: ChunkData = persistence.load_chunk(second_coord)
	_assert(restored != null and restored.terrain_get(local) == TerrainId.STONE, "Disk-only chunk edit is persisted")


func test_rejects_invalid_terrain_id() -> void:
	var result: bool = manager.set_terrain_at(Vector2i(-6, 11), 999)
	_assert(not result, "Returns false for an invalid TerrainId")


func _make_chunk(coord: Vector2i) -> ChunkData:
	var chunk: ChunkData = ChunkData.new()
	chunk.coord = coord
	chunk.initialize(CHUNK_SIZE)
	for index: int in range(chunk.terrain.size()):
		chunk.terrain[index] = TerrainId.GRASS
	return chunk


func _tile_metadata() -> Dictionary:
	return {
		"type": 0,
		"source_id": 1,
		"atlas_coords": Vector2i(0, 2),
		"alternative_tile": 0,
		"terrain_set": 0,
		"terrain": 0,
	}


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
		return
	failed = true
	push_error("[FAIL] " + message)
