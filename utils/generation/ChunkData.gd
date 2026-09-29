class_name ChunkData
extends RefCounted

var coord: Vector2i
var size: int

var terrain: PackedInt32Array
var biome: PackedInt32Array

var objects: Array = []
var entities: Array = []

var metadata: Dictionary = {}


func initialize(chunk_size: int) -> void:
	size = chunk_size

	var cell_count := size * size

	terrain.resize(cell_count)
	biome.resize(cell_count)


func terrain_get(local: Vector2i) -> int:
	return terrain[ChunkMath.local_to_index(local, size)]


func terrain_set(local: Vector2i, value: int) -> void:
	terrain[ChunkMath.local_to_index(local, size)] = value


func biome_get(local: Vector2i) -> int:
	return biome[ChunkMath.local_to_index(local, size)]


func biome_set(local: Vector2i, value: int) -> void:
	biome[ChunkMath.local_to_index(local, size)] = value


func contains_local(local: Vector2i) -> bool:
	return (
		local.x >= 0
		and local.y >= 0
		and local.x < size
		and local.y < size
	)


func contains_index(index: int) -> bool:
	return index >= 0 and index < size * size


func world_origin() -> Vector2i:
	return ChunkMath.chunk_to_world_origin(coord, size)


func world_position(local: Vector2i) -> Vector2i:
	return ChunkMath.local_to_world(coord, local, size)
