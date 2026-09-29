extends Node

const CHUNK_SIZE: int = 32
const ENTITY_COUNTS: Array[int] = [10, 100, 500, 1000]
const WARMUP_RUNS: int = 10
const MEASURE_RUNS: int = 100


func _ready() -> void:
	_run_profile()


func _run_profile() -> void:
	print("=== ENTITY SERIALIZATION PROFILE ===")
	for entity_count: int in ENTITY_COUNTS:
		var entities: Array[Entity] = _make_entities(entity_count)
		for warmup: int in range(WARMUP_RUNS):
			ChunkEntityPersistence.serialize_entities(entities)
		var started_usec: int = Time.get_ticks_usec()
		var serialized_records: Array[Dictionary] = []
		for iteration: int in range(MEASURE_RUNS):
			serialized_records = ChunkEntityPersistence.serialize_entities(entities)
		var elapsed_usec: int = Time.get_ticks_usec() - started_usec
		var average_usec: float = float(elapsed_usec) / float(MEASURE_RUNS)
		var json_size_bytes: int = JSON.stringify(serialized_records).to_utf8_buffer().size()
		print("entities=%d avg_serialize_us=%.2f json_bytes=%d" % [entity_count, average_usec, json_size_bytes])
		for entity: Entity in entities:
			entity.free()
	print("=== ENTITY SERIALIZATION PROFILE COMPLETE ===")
	get_tree().quit(0)


func _make_entities(count: int) -> Array[Entity]:
	var entities: Array[Entity] = []
	for index: int in range(count):
		var entity: Entity = E_ChunkProbe.new()
		entity.name = "ProfileProbe%d" % index
		var position: C_Position = C_Position.new()
		position.world_position = Vector2(float(index), float(-index))
		var chunk: C_CurrentChunk = C_CurrentChunk.new()
		chunk.coord = ChunkMath.world_to_chunk(Vector2i(index, -index), CHUNK_SIZE)
		entity.add_component(position)
		entity.add_component(chunk)
		entity.add_component(C_ChunkResident.new())
		entities.append(entity)
	return entities
