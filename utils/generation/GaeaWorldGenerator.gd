class_name GaeaWorldGenerator
extends RefCounted


signal chunk_generated(chunk: ChunkData)
signal chunk_generation_discarded(coord: Vector2i)

var _generator: GaeaGenerator
var _mapping: GaeaMappingRegistry
var _importer: GaeaChunkImporter
var _chunk_size: int
var _required_chunks: Dictionary = {}
var _required_chunks_configured: bool = false
var _generation_tasks: Array[GaeaTask] = []


func _init(
	generator: GaeaGenerator,
	mapping: GaeaMappingRegistry,
	chunk_size: int
) -> void:
	_generator = generator
	_mapping = mapping
	_chunk_size = chunk_size
	_importer = GaeaChunkImporter.new()

	_generator.generation_finished.connect(
		_on_generation_finished
	)


func set_required_chunks(coords: Dictionary) -> void:
	_required_chunks_configured = true
	_required_chunks = coords.duplicate()


func generate_chunk(chunk_coord: Vector2i) -> GaeaTask:
	if _generator.graph == null:
		push_error("Cannot generate chunk: GaeaGenerator has no graph assigned.")
		return null
	var world_rect := ChunkMath.chunk_to_world_rect(
		chunk_coord,
		_chunk_size
	)

	var area := AABB(
		Vector3(
			world_rect.position.x,
			world_rect.position.y,
			0
		),
		Vector3(
			world_rect.size.x,
			world_rect.size.y,
			1
		)
	)
	# Use the serialized generator settings for all chunk requests. Randomizing
	# per call would make chunks use different seeds, unlike one coherent world.
	if _generator.settings == null:
		_generator.settings = GaeaGenerationSettings.new()
	_generator.settings.random_seed_on_generate = false

	print("[WorldGenerator] Generate ", chunk_coord, " | area: ", area)

	var task: GaeaTask = _generator.generate_area(area)
	if task != null:
		task.set_meta("chunk_coord", chunk_coord)
		_generation_tasks.append(task)
	return task


func _on_generation_finished(grid: GaeaGrid) -> void:
	var chunk_coord := _detect_chunk_coord(grid)

	if chunk_coord == Vector2i(
		2147483647,
		2147483647
	):
		push_error(
			"Could not determine chunk coordinate from GaeaGrid."
		)
		return

	if _required_chunks_configured and not _required_chunks.has(chunk_coord):
		print("[WorldGenerator] Discard obsolete result ", chunk_coord)
		chunk_generation_discarded.emit(chunk_coord)
		return
	print("[WorldGenerator] Finished ", chunk_coord)
	var chunk := _importer.import_grid(
		grid,
		chunk_coord,
		_chunk_size,
		_mapping
	)


	chunk_generated.emit(chunk)


func _detect_chunk_coord(grid: GaeaGrid) -> Vector2i:
	var layer_map: GaeaValue.Map = grid.get_layer(0)
	var cells := layer_map.get_cells()

	if cells.is_empty():
		return Vector2i(
			2147483647,
			2147483647
		)

	var min_x := cells[0].x
	var min_y := cells[0].y

	for cell in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)

	return ChunkMath.world_to_chunk(
		Vector2i(min_x, min_y),
		_chunk_size
	)
