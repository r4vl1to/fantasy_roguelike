class_name ChunkEntityLifecycle
extends RefCounted

var ecs_world: World
var entity_root_path: String
var _active_chunks: Dictionary = {}


func configure(p_world: World, p_root_path: String) -> void:
	ecs_world = p_world
	entity_root_path = p_root_path.trim_suffix("/")


func restore_chunk_entities(coord: Vector2i) -> int:
	if ecs_world == null or _active_chunks.has(coord):
		return 0
	_active_chunks[coord] = true
	var loaded: Array[Entity] = ChunkEntityPersistence.load_chunk_entities(_entity_path(coord))
	if loaded.is_empty():
		return 0
	var residents: Array[Entity] = []
	for entity: Entity in loaded:
		var position: C_Position = entity.get_component(C_Position) as C_Position
		var current_chunk: C_CurrentChunk = entity.get_component(C_CurrentChunk) as C_CurrentChunk
		if position == null or current_chunk == null or current_chunk.coord != coord:
			push_warning("Skipping persisted entity with invalid chunk membership: %s" % entity.name)
			continue
		residents.append(entity)
	for entity: Entity in residents:
		ecs_world.add_entity(entity, null, false)
	_active_chunks[coord] = true
	return residents.size()


func unload_chunk_entities(coord: Vector2i) -> int:
	if ecs_world == null:
		return 0
	var matches: Array[Entity] = ecs_world.query.with_all([C_ChunkResident, C_CurrentChunk]).execute()
	var residents: Array[Entity] = []
	for entity: Entity in matches:
		var current_chunk: C_CurrentChunk = entity.get_component(C_CurrentChunk) as C_CurrentChunk
		if current_chunk != null and current_chunk.coord == coord:
			residents.append(entity)
	if residents.is_empty():
		if FileAccess.file_exists(_entity_path(coord)):
			var delete_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(_entity_path(coord)))
			if delete_error != OK:
				push_error("Unable to remove stale entity data for chunk %s" % coord)
				return -1
	else:
		if not ChunkEntityPersistence.save_chunk_entities(_entity_path(coord), residents):
			return -1
	for entity: Entity in residents:
		ecs_world.remove_entity(entity)
	_active_chunks.erase(coord)
	return residents.size()


func _entity_path(coord: Vector2i) -> String:
	return "%s/entities/%d_%d.json" % [entity_root_path, coord.x, coord.y]
