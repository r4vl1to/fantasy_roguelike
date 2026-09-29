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

# Diccionario usado como conjunto de chunks pendientes.
# Key   = Vector2i
# Value = true
var _pending_chunks: Dictionary = {}


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


func request_chunk(coord: Vector2i) -> void:
	print("[WorldManager] Request ", coord)

	# --------------------------------------------------
	# 1. COMPROBAR RAM
	# --------------------------------------------------

	if database.has_chunk(coord):
		print("[WorldManager] Source RAM ", coord)

		var chunk_from_ram: ChunkData = database.get_chunk(coord)

		if chunk_from_ram != null:
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

	

			chunk_ready.emit(chunk_from_disk)
			return

		print(
			"WARNING: Chunk exists on disk but could not be loaded."
		)

	# --------------------------------------------------
	# 3. GENERAR CON GAEA
	# --------------------------------------------------

	print("[WorldManager] Source GAEA ", coord)

	if _pending_chunks.has(coord):
		print(
			"Generation already pending: ",
			coord
		)
		return

	_pending_chunks[coord] = true

	chunk_generation_started.emit(coord)

	print("Requesting Gaea generation...")

	world_generator.generate_chunk(coord)


func _on_chunk_generated(chunk: ChunkData) -> void:
	if chunk == null:
		push_error("WorldManager received null ChunkData from GaeaWorldGenerator.")
		return

	var chunk_coord: Vector2i = chunk.coord
	if not _pending_chunks.has(chunk_coord):
		push_warning("Received generated chunk that was not pending: %s" % chunk_coord)
		return

	if chunk.size != chunk_size or chunk.terrain.size() != chunk_size * chunk_size:
		_pending_chunks.erase(chunk_coord)
		chunk_generation_failed.emit(chunk_coord)
		push_error("Generated chunk has invalid dimensions: %s" % chunk_coord)
		return

	database.store_chunk(chunk)
	var saved: bool = persistence.save_chunk(chunk)
	if not saved:
		push_warning("Failed to persist generated chunk: %s" % chunk_coord)

	_pending_chunks.erase(chunk_coord)
	print("[WorldManager] Ready ", chunk.coord, " | tiles: ", chunk.terrain.size(), " | persisted: ", saved)
	chunk_ready.emit(chunk)


func unload_chunk(coord: Vector2i) -> bool:
	print("[WorldManager] Unload ", coord)

	if not database.has_chunk(coord):
		print("Chunk is not loaded in RAM.")
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
