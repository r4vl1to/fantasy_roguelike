extends Node


@onready var gaea_generator: GaeaGenerator = $"../GaeaGenerator"
@onready var world_manager: GaeaWorldManager = $"../GaeaWorldManager"


var mapping: GaeaMappingRegistry
var database: WorldDatabase
var persistence: WorldPersistence

var streamer: ChunkStreamer


func _ready() -> void:
	print("========================================")
	print("GAEA WORLD MANAGER G.4 TEST")
	print("========================================")

	# --------------------------------------------------
	# CREAR DEPENDENCIAS
	# --------------------------------------------------

	mapping = GaeaMappingRegistry.new()
	mapping.build_from_graph(
		gaea_generator.graph
	)

	database = WorldDatabase.new()

	persistence = WorldPersistence.new(
		"user://world_chunks"
	)

	# --------------------------------------------------
	# CONFIGURAR WORLD MANAGER
	# --------------------------------------------------

	world_manager.setup(
		gaea_generator,
		mapping,
		database,
		persistence,
		32
	)

	# --------------------------------------------------
	# CREAR STREAMER
	# --------------------------------------------------

	streamer = ChunkStreamer.new(1)

	streamer.chunks_to_load.connect(
		_on_chunks_to_load
	)

	streamer.chunks_to_unload.connect(
		_on_chunks_to_unload
	)

	world_manager.chunk_ready.connect(
		_on_chunk_ready
	)

	world_manager.chunk_generation_started.connect(
		_on_chunk_generation_started
	)

	world_manager.chunk_generation_failed.connect(
		_on_chunk_generation_failed
	)

	# --------------------------------------------------
	# TEST
	# --------------------------------------------------

	print("----------------------------------------")
	print("PLAYER -> (10, 0)")
	print("----------------------------------------")

	streamer.update_player_chunk(
		Vector2i(10, 0)
	)

	# Esperar a que Gaea termine las generaciones.
	await get_tree().create_timer(3.0).timeout

	print("----------------------------------------")
	print("PLAYER -> (11, 0)")
	print("----------------------------------------")

	streamer.update_player_chunk(
		Vector2i(11, 0)
	)

	print("========================================")
	print("G.4 TEST REQUESTS SENT")
	print("========================================")


func _on_chunks_to_load(
	chunks: Array[Vector2i]
) -> void:

	print("----------------------------------------")
	print("STREAMER -> LOAD")
	print("----------------------------------------")

	for coord in chunks:
		print("Requesting chunk: ", coord)

		world_manager.request_chunk(
			coord
		)


func _on_chunks_to_unload(
	chunks: Array[Vector2i]
) -> void:

	print("----------------------------------------")
	print("STREAMER -> UNLOAD")
	print("----------------------------------------")

	for coord in chunks:
		print("Unloading chunk: ", coord)

		var success := world_manager.unload_chunk(
			coord
		)

		print(
			"Unload result: ",
			success
		)


func _on_chunk_generation_started(
	coord: Vector2i
) -> void:

	print("----------------------------------------")
	print("GENERATION STARTED")
	print("Coord: ", coord)
	print("----------------------------------------")


func _on_chunk_generation_failed(
	coord: Vector2i
) -> void:

	print("----------------------------------------")
	print("GENERATION FAILED")
	print("Coord: ", coord)
	print("----------------------------------------")


func _on_chunk_ready(
	chunk: ChunkData
) -> void:

	print("----------------------------------------")
	print("CHUNK READY")
	print("Coord: ", chunk.coord)
	print("Size: ", chunk.size)
	print("Terrain: ", chunk.terrain.size())
	print("Biome: ", chunk.biome.size())
	print("----------------------------------------")
