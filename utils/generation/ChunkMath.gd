##Tile: coordenada absoluta del mundo → Vector2i
##Chunk: coordenada → Vector2i
##Local tile: [0, chunk_size)
##Índice lineal: index = y * chunk_size + x

class_name ChunkMath
extends RefCounted


static func chunk_to_world_origin(
	chunk: Vector2i,
	chunk_size: int
) -> Vector2i:
	return chunk * chunk_size


static func chunk_to_world_rect(
	chunk: Vector2i,
	chunk_size: int
) -> Rect2i:
	return Rect2i(
		chunk_to_world_origin(chunk, chunk_size),
		Vector2i(chunk_size, chunk_size)
	)


static func local_to_index(
	local: Vector2i,
	chunk_size: int
) -> int:
	return local.y * chunk_size + local.x


static func index_to_local(
	index: int,
	chunk_size: int
) -> Vector2i:
	return Vector2i(
		index % chunk_size,
		floori(float(index) / float(chunk_size))
	)


static func local_to_world(
	chunk: Vector2i,
	local: Vector2i,
	chunk_size: int
) -> Vector2i:
	return chunk_to_world_origin(chunk, chunk_size) + local


static func world_to_chunk(
	world: Vector2i,
	chunk_size: int
) -> Vector2i:
	return Vector2i(
		floori(float(world.x) / chunk_size),
		floori(float(world.y) / chunk_size)
	)


static func world_to_local(
	world: Vector2i,
	chunk_size: int
) -> Vector2i:
	var chunk := world_to_chunk(world, chunk_size)
	return world - chunk_to_world_origin(chunk, chunk_size)
