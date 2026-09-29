class_name GaeaWorldManager
extends Node


signal chunk_ready(chunk: ChunkData)
signal chunk_generation_started(coord: Vector2i)
signal chunk_generation_failed(coord: Vector2i)


var gaea_generator: GaeaGenerator
var mapping: GaeaMappingRegistry
var world_generator: GaeaWorldGenerator
var database: WorldDatabase
var persistence: WorldPersistence

var chunk_size: int = 32
var entity_lifecycle: ChunkEntityLifecycle

# Diccionario usado como conjunto de chunks pendientes.
# Key   = Vector2i
# Value = true
var _pending_chunks: Dictionary = {}
var _required_chunks: Dictionary = {}
var _required_chunks_configured: bool = false
var _generation_tasks: Dictionary = {}


func setup(
	p_generator: GaeaGenerator,
	p_mapping: GaeaMappingRegistry,
	p_database: WorldDatabase,
	p_persistence: WorldPersistence,
	p_chunk_size: int = 32
) -> void:

	gaea_generator = p_generator
	mapping = p_mapping
	database = p_database
	persistence = p_persistence
	chunk_size = p_chunk_size

	world_generator = GaeaWorldGenerator.new(
		gaea_generator,
		mapping,
		chunk_size
	)

	if not world_generator.chunk_generated.is_connected(
		_on_chunk_generated
	):
		world_generator.chunk_generated.connect(
			_on_chunk_generated
		)
	if not world_generator.chunk_generation_discarded.is_connected(_on_chunk_generation_discarded):
		world_generator.chunk_generation_discarded.connect(_on_chunk_generation_discarded)


func _on_chunk_generation_discarded(coord: Vector2i) -> void:
	_pending_chunks.erase(coord)
	_generation_tasks.erase(coord)


func configure_entity_lifecycle(p_lifecycle: ChunkEntityLifecycle) -> void:
	entity_lifecycle = p_lifecycle


func set_required_chunks(coords: Array) -> void:
	_required_chunks_configured = true
	_required_chunks.clear()
	for coord_variant: Variant in coords:
		var coord: Vector2i = coord_variant as Vector2i
		_required_chunks[coord] = true
	if world_generator != null:
		world_generator.set_required_chunks(_required_chunks)


func is_required_chunk(coord: Vector2i) -> bool:
	return not _required_chunks_configured or _required_chunks.has(coord)


func request_chunk(coord: Vector2i) -> void:
	print("[WorldManager] Request ", coord)

	# --------------------------------------------------
	# 1. COMPROBAR RAM
	# --------------------------------------------------

	if database.has_chunk(coord):
		print("[WorldManager] Source RAM ", coord)

		var chunk_from_ram: ChunkData = database.get_chunk(coord)

		if chunk_from_ram != null:
			if entity_lifecycle != null:
				entity_lifecycle.restore_chunk_entities(coord)
			chunk_ready.emit(chunk_from_ram)
			return

	# --------------------------------------------------
	# 2. COMPROBAR DISCO
	# --------------------------------------------------

	if persistence.has_chunk(coord):
		print("[WorldManager] Source DISK ", coord)

		var chunk_from_disk: ChunkData = persistence.load_chunk(coord)

		if chunk_from_disk != null:
			database.store_chunk(chunk_from_disk)
			if entity_lifecycle != null:
				entity_lifecycle.restore_chunk_entities(coord)
			chunk_ready.emit(chunk_from_disk)
			return

		print(
			"WARNING: Chunk exists on disk but could not be loaded."
		)

	# --------------------------------------------------
	# 3. GENERAR CON GAEA
	# --------------------------------------------------

	print("[WorldManager] Source GAEA ", coord)

	if _required_chunks_configured and not _required_chunks.has(coord):
		return

	if _pending_chunks.has(coord):
		print(
			"Generation already pending: ",
			coord
		)
		return

	_pending_chunks[coord] = true
	chunk_generation_started.emit(coord)

	print("Requesting Gaea generation...")

	var generation_task: GaeaTask = world_generator.generate_chunk(coord)
	_generation_tasks[coord] = generation_task


func _on_chunk_generated(chunk: ChunkData) -> void:
	if chunk == null:
		push_warning("Discarded an obsolete generation result.")
		return

	var chunk_coord: Vector2i = chunk.coord
	if not _pending_chunks.has(chunk_coord):
		if _required_chunks_configured and _required_chunks.has(chunk_coord):
			_pending_chunks[chunk_coord] = true
		else:
			push_warning("Received generated chunk that was not pending: %s" % chunk_coord)
			return

	if chunk.size != chunk_size or chunk.terrain.size() != chunk_size * chunk_size:
		_pending_chunks.erase(chunk_coord)
		chunk_generation_failed.emit(chunk_coord)
		push_error("Generated chunk has invalid dimensions: %s" % chunk_coord)
		return

	if _required_chunks_configured and not _required_chunks.has(chunk_coord):
		_pending_chunks.erase(chunk_coord)
		_generation_tasks.erase(chunk_coord)
		print("[WorldManager] Discarded obsolete generated chunk ", chunk_coord)
		return

	database.store_chunk(chunk)
	var saved: bool = persistence.save_chunk(chunk)
	if not saved:
		push_warning("Failed to persist generated chunk: %s" % chunk_coord)

	_pending_chunks.erase(chunk_coord)
	if entity_lifecycle != null:
		entity_lifecycle.restore_chunk_entities(chunk_coord)
	print("[WorldManager] Ready ", chunk.coord, " | tiles: ", chunk.terrain.size(), " | persisted: ", saved)
	chunk_ready.emit(chunk)


func unload_chunk(coord: Vector2i) -> bool:
	print("[WorldManager] Unload ", coord)

	if not database.has_chunk(coord):
		if entity_lifecycle != null:
			var pending_entity_count: int = entity_lifecycle.unload_chunk_entities(coord)
			if pending_entity_count < 0:
				push_error("Could not persist chunk entities before unload: %s" % coord)
				return false
		print("Chunk is not loaded in RAM; unload request ignored.")
		return false

	if entity_lifecycle != null:
		var entity_count: int = entity_lifecycle.unload_chunk_entities(coord)
		if entity_count < 0:
			push_error("Could not persist chunk entities before unload: %s" % coord)
			return false

	var chunk := database.get_chunk(coord)

	if chunk == null:
		push_error(
            "Database reported chunk exists but returned null: "
			+ str(coord)
		)
		return false

	# Guardamos el estado actual antes de sacarlo de RAM.
	var saved := persistence.save_chunk(chunk)

	if not saved:
		push_error(
            "Could not persist chunk before unload: "
			+ str(coord)
		)
		return false

	database.remove_chunk(coord)

	print("Chunk persisted.")
	print("Chunk removed from RAM.")

	return true


## Read-only terrain lookup for gameplay (e.g. click info), keeping the
## RAM/disk ownership inside the manager. It checks RAM, then disk, and never
## triggers Gaea generation. Returns -1 when the tile is not currently known.
func get_terrain_at(world_tile: Vector2i) -> int:
	var coord: Vector2i = ChunkMath.world_to_chunk(world_tile, chunk_size)
	var chunk: ChunkData = null

	if database != null and database.has_chunk(coord):
		chunk = database.get_chunk(coord)
	elif persistence != null and persistence.has_chunk(coord):
		chunk = persistence.load_chunk(coord)

	if chunk == null:
		return -1

	var local: Vector2i = ChunkMath.world_to_local(world_tile, chunk_size)
	if not chunk.contains_local(local):
		return -1

	return chunk.terrain_get(local)
