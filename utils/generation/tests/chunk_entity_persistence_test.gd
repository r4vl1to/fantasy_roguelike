extends Node

const TEST_ROOT: String = "user://chunk_entity_persistence_test"


func _ready() -> void:
	print("=== CHUNK ENTITY PERSISTENCE TEST ===")
	var failed: bool = false
	var source_entity: Entity = E_ChunkProbe.new()
	source_entity.name = "PersistentProbe"
	source_entity.add_component(C_Position.new())
	source_entity.add_component(C_CurrentChunk.new())
	source_entity.add_component(C_ChunkResident.new())
	var source_position: C_Position = source_entity.get_component(C_Position) as C_Position
	var source_chunk: C_CurrentChunk = source_entity.get_component(C_CurrentChunk) as C_CurrentChunk
	source_position.world_position = Vector2(65.5, -31.0)
	source_chunk.coord = Vector2i(2, -1)

	var records: Array[Dictionary] = ChunkEntityPersistence.serialize_entities([source_entity])
	failed = _check(records.size() == 1, "One entity record produced") or failed

	var restored: Array[Entity] = ChunkEntityPersistence.deserialize_entities(records)
	failed = _check(restored.size() == 1, "One entity restored") or failed
	if not restored.is_empty():
		failed = _check(restored[0] is E_ChunkProbe, "Restored entity keeps its script type") or failed
		failed = _check(restored[0].has_component(C_ChunkResident), "Resident marker preserved") or failed
		var restored_position: C_Position = restored[0].get_component(C_Position) as C_Position
		var restored_chunk: C_CurrentChunk = restored[0].get_component(C_CurrentChunk) as C_CurrentChunk
		failed = _check(restored_position != null and restored_position.world_position == source_position.world_position, "Vector2 position round-trips") or failed
		failed = _check(restored_chunk != null and restored_chunk.coord == source_chunk.coord, "Vector2i chunk coord round-trips") or failed

	var file_path: String = TEST_ROOT + "/entities/2_-1.json"
	failed = _check(ChunkEntityPersistence.save_chunk_entities(file_path, [source_entity]), "Entities written to disk") or failed
	var disk_entities: Array[Entity] = ChunkEntityPersistence.load_chunk_entities(file_path)
	failed = _check(disk_entities.size() == 1, "Entities loaded from disk") or failed
	if not disk_entities.is_empty():
		var disk_position: C_Position = disk_entities[0].get_component(C_Position) as C_Position
		failed = _check(disk_position != null and disk_position.world_position == Vector2(65.5, -31.0), "Disk round-trip preserves position") or failed

	var world: World = World.new()
	add_child(world)
	ECS.world = world
	var lifecycle: ChunkEntityLifecycle = ChunkEntityLifecycle.new()
	lifecycle.configure(world, TEST_ROOT)
	for entity: Entity in disk_entities:
		world.add_entity(entity, null, false)
	var active_position: C_Position = disk_entities[0].get_component(C_Position) as C_Position
	active_position.world_position = Vector2(90.25, -44.5)
	var created_during_streaming: Entity = E_ChunkProbe.new()
	created_during_streaming.name = "CreatedDuringStreaming"
	created_during_streaming.add_component(C_Position.new())
	created_during_streaming.add_component(C_CurrentChunk.new())
	created_during_streaming.add_component(C_ChunkResident.new())
	var created_position: C_Position = created_during_streaming.get_component(C_Position) as C_Position
	created_position.world_position = Vector2(96.0, -40.0)
	var created_chunk: C_CurrentChunk = created_during_streaming.get_component(C_CurrentChunk) as C_CurrentChunk
	created_chunk.coord = Vector2i(2, -1)
	world.add_entity(created_during_streaming, null, false)
	failed = _check(lifecycle.unload_chunk_entities(Vector2i(2, -1)) == 2, "Unload captures residents created and mutated during the active streaming period") or failed
	failed = _check(world.entities.is_empty(), "ECS holds no residents after unload") or failed
	var changed_before_unload: Array[Entity] = ChunkEntityPersistence.load_chunk_entities(file_path)
	var changed_before_position: C_Position = changed_before_unload[0].get_component(C_Position) as C_Position if not changed_before_unload.is_empty() else null
	failed = _check(changed_before_position != null and changed_before_position.world_position == Vector2(90.25, -44.5), "Mutation immediately before unload is persisted") or failed
	failed = _check(lifecycle.restore_chunk_entities(Vector2i(2, -1)) == 2, "Restore brings all current residents back") or failed
	failed = _check(world.entities.size() == 2, "ECS holds both restored residents") or failed
	var restored_entity: Entity = _find_entity("PersistentProbe")
	var restored_position_component: C_Position = restored_entity.get_component(C_Position) as C_Position if restored_entity != null else null
	if restored_position_component != null:
		restored_position_component.world_position = Vector2(101.75, -52.0)
	var restored_created: Entity = _find_entity("CreatedDuringStreaming")
	if restored_created != null:
		world.remove_entity(restored_created)
	failed = _check(lifecycle.unload_chunk_entities(Vector2i(2, -1)) == 1, "Entity destruction before unload is reflected in the saved resident set") or failed
	var after_destruction: Array[Entity] = ChunkEntityPersistence.load_chunk_entities(file_path)
	failed = _check(after_destruction.size() == 1, "Destroyed entity is not retained in persisted data") or failed
	failed = _check(lifecycle.restore_chunk_entities(Vector2i(2, -1)) == 1, "Restore succeeds after resident destruction") or failed
	var restored_after_mutation: Entity = _find_entity("PersistentProbe")
	var restored_after_position: C_Position = restored_after_mutation.get_component(C_Position) as C_Position if restored_after_mutation != null else null
	failed = _check(restored_after_position != null and restored_after_position.world_position == Vector2(101.75, -52.0), "Mutation immediately after restore survives the next unload/restore") or failed

	print("=== CHUNK ENTITY PERSISTENCE TEST %s ===" % ("PASS" if not failed else "FAIL"))
	get_tree().quit(0 if not failed else 1)


func _find_entity(entity_name: String) -> Entity:
	for entity: Entity in ECS.world.entities:
		if entity.name == entity_name:
			return entity
	return null


func _check(condition: bool, message: String) -> bool:
	if condition:
		print("[PASS] ", message)
		return false
	push_error("[FAIL] " + message)
	return true
