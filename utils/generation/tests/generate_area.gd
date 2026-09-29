extends Node


@onready var gaea_generator: GaeaGenerator = $"../GaeaGenerator"


var world_generator: GaeaWorldGenerator
var mapping: GaeaMappingRegistry


func _ready() -> void:
	print("========================================")
	print("GAEA WORLD GENERATOR TEST")
	print("========================================")

	mapping = GaeaMappingRegistry.new()
	mapping.build_from_graph(
		gaea_generator.graph
	)

	world_generator = GaeaWorldGenerator.new(
		gaea_generator,
		mapping,
		32
	)

	world_generator.chunk_generated.connect(
		_on_chunk_generated
	)

	world_generator.generate_chunk(
		Vector2i(1, 0)
	)

	world_generator.generate_chunk(
		Vector2i(2, 0)
	)


func _on_chunk_generated(chunk: ChunkData) -> void:
	print("========================================")
	print("CHUNK GENERATED")
	print("========================================")

	print("Chunk coord: ", chunk.coord)
	print("Chunk size: ", chunk.size)
	print("Terrain count: ", chunk.terrain.size())
