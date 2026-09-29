extends Node


@onready var gaea_generator: GaeaGenerator = $"../GaeaGenerator"


var manager: GaeaWorldManager
var request_count := 0


func _ready() -> void:
	print("========================================")
	print("GAEA WORLD MANAGER TEST")
	print("========================================")

	# --------------------------------------------------
	# MAPPING
	# --------------------------------------------------

	var mapping := GaeaMappingRegistry.new()

	mapping.build_from_graph(
		gaea_generator.graph
	)

	# --------------------------------------------------
	# DATABASE
	# --------------------------------------------------

	var database := WorldDatabase.new()

	# --------------------------------------------------
	# PERSISTENCE
	# --------------------------------------------------

	var persistence := WorldPersistence.new(
		"user://world_manager_test"
	)

	# --------------------------------------------------
	# MANAGER
	# --------------------------------------------------

	manager = GaeaWorldManager.new()

	add_child(manager)

	manager.setup(
		gaea_generator,
		mapping,
		database,
		persistence,
		32
	)

	# --------------------------------------------------
	# SIGNALS
	# --------------------------------------------------

	manager.chunk_ready.connect(
		_on_chunk_ready
	)

	manager.chunk_generation_started.connect(
		_on_chunk_generation_started
	)

	manager.chunk_generation_failed.connect(
		_on_chunk_generation_failed
	)

	# --------------------------------------------------
	# FIRST REQUEST
	# --------------------------------------------------

	var coord := Vector2i(10, 0)

	print("----------------------------------------")
	print("REQUESTING CHUNK")
	print("Coord: ", coord)
	print("----------------------------------------")

	manager.request_chunk(coord)


func _on_chunk_generation_started(
	coord: Vector2i
) -> void:

	print("----------------------------------------")
	print("GENERATION STARTED")
	print("Coord: ", coord)
	print("----------------------------------------")


func _on_chunk_ready(
	chunk: ChunkData
) -> void:

	request_count += 1

	print("========================================")
	print("CHUNK READY")
	print("========================================")

	print("Request count: ", request_count)
	print("Coord: ", chunk.coord)
	print("Size: ", chunk.size)
	print("Terrain count: ", chunk.terrain.size())
	print("Biome count: ", chunk.biome.size())

	# --------------------------------------------------
	# SECOND REQUEST
	# --------------------------------------------------
	#
	# La primera petición debería venir de:
	#
	#   DISK
	#
	# y después quedar en RAM.
	#
	# La segunda petición debería venir de:
	#
	#   RAM
	#
	# --------------------------------------------------

	if request_count == 1:

		print("----------------------------------------")
		print("REQUESTING SAME CHUNK AGAIN")
		print("----------------------------------------")

		manager.request_chunk(
			chunk.coord
		)

	elif request_count == 2:

		print("========================================")
		print("RAM CACHE TEST COMPLETE")
		print("========================================")


func _on_chunk_generation_failed(
	coord: Vector2i
) -> void:

	print("========================================")
	print("CHUNK GENERATION FAILED")
	print("========================================")

	print("Coord: ", coord)
