class_name GaeaWorldGenerator
extends RefCounted


signal chunk_generated(chunk: ChunkData)

var _generator: GaeaGenerator
var _mapping: GaeaMappingRegistry
var _importer: GaeaChunkImporter
var _chunk_size: int


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


func generate_chunk(chunk_coord: Vector2i) -> void:
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

	print("[WorldGenerator] Generate ", chunk_coord, " | area: ", area)

	_generator.generate_area(area)


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
