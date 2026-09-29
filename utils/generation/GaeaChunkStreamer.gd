class_name GaeaChunkStreamer
extends Node

signal chunks_to_load(chunks: Array[Vector2i])
signal chunks_to_unload(chunks: Array[Vector2i])

@export_range(0, 16, 1) var stream_radius: int = 1

var required_chunks: Dictionary = {}
var current_player_chunk: Vector2i = Vector2i.ZERO
var _streamer: ChunkStreamer


func _ready() -> void:
	_streamer = ChunkStreamer.new(stream_radius)
	_streamer.chunks_to_load.connect(_on_chunks_to_load)
	_streamer.chunks_to_unload.connect(_on_chunks_to_unload)


func update_player_chunk(chunk_coord: Vector2i) -> void:
	if _streamer == null:
		_streamer = ChunkStreamer.new(stream_radius)
		_streamer.chunks_to_load.connect(_on_chunks_to_load)
		_streamer.chunks_to_unload.connect(_on_chunks_to_unload)
	_streamer.loading_radius = stream_radius
	current_player_chunk = chunk_coord
	required_chunks.clear()
	for y: int in range(chunk_coord.y - stream_radius, chunk_coord.y + stream_radius + 1):
		for x: int in range(chunk_coord.x - stream_radius, chunk_coord.x + stream_radius + 1):
			required_chunks[Vector2i(x, y)] = true
	_streamer.update_player_chunk(chunk_coord)


func is_required(coord: Vector2i) -> bool:
	return required_chunks.has(coord)


func _on_chunks_to_load(chunks: Array[Vector2i]) -> void:
	chunks_to_load.emit(chunks)


func _on_chunks_to_unload(chunks: Array[Vector2i]) -> void:
	chunks_to_unload.emit(chunks)


func get_chebyshev_distance_to_player(coord: Vector2i) -> int:
	return maxi(absi(coord.x - current_player_chunk.x), absi(coord.y - current_player_chunk.y))
