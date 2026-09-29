extends Node

func _ready() -> void:
	print("#test_chunk_origin#")
	test_chunk_origin()
	print("#test_local_to_world#")
	test_local_to_world()
	print("#test_negative_world_to_chunk#")
	test_negative_world_to_chunk()
	print("#test_index_round_trip#")
	test_index_round_trip()
	print("#test_world_round_trip#")
	test_world_round_trip()
	print("#test_chunk_boundaries#")
	test_chunk_boundaries()

func test_chunk_origin() -> void:
	assert(
		ChunkMath.chunk_to_world_origin(
			Vector2i(2, 3),
			16
		) == Vector2i(32, 48)
	)


func test_local_to_world() -> void:
	assert(
		ChunkMath.local_to_world(
			Vector2i(2, 3),
			Vector2i(5, 7),
			16
		) == Vector2i(37, 55)
	)


func test_negative_world_to_chunk() -> void:
	assert(
		ChunkMath.world_to_chunk(
			Vector2i(-1, 0),
			16
		) == Vector2i(-1, 0)
	)

	assert(
		ChunkMath.world_to_local(
			Vector2i(-1, 0),
			16
		) == Vector2i(15, 0)
	)


func test_index_round_trip() -> void:
	var size := 16

	for y in range(size):
		for x in range(size):
			var local := Vector2i(x, y)
			var index := ChunkMath.local_to_index(local, size)
			var restored := ChunkMath.index_to_local(index, size)

			assert(restored == local)


func test_world_round_trip() -> void:
	var size := 16

	var chunks := [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(-2, -3),
		Vector2i(10, -20)
	]

	var locals := [
		Vector2i(0, 0),
		Vector2i(1, 1),
		Vector2i(15, 0),
		Vector2i(0, 15),
		Vector2i(15, 15),
	]

	for chunk in chunks:
		for local in locals:
			var world := ChunkMath.local_to_world(
				chunk,
				local,
				size
			)

			var restored_chunk := ChunkMath.world_to_chunk(
				world,
				size
			)

			var restored_local := ChunkMath.world_to_local(
				world,
				size
			)

			assert(restored_chunk == chunk)
			assert(restored_local == local)


func test_chunk_boundaries() -> void:
	var size := 16
	var chunk := Vector2i(2, -3)

	assert(
		ChunkMath.local_to_world(
			chunk,
			Vector2i(0, 0),
			size
		) == Vector2i(32, -48)
	)

	assert(
		ChunkMath.local_to_world(
			chunk,
			Vector2i(15, 0),
			size
		) == Vector2i(47, -48)
	)

	assert(
		ChunkMath.local_to_world(
			chunk,
			Vector2i(0, 15),
			size
		) == Vector2i(32, -33)
	)

	assert(
		ChunkMath.local_to_world(
			chunk,
			Vector2i(15, 15),
			size
		) == Vector2i(47, -33)
	)
