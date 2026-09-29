class_name S_ChunkStreaming
extends System

var streamer: GaeaChunkStreamer
var chunk_size: int = 32


func configure(p_streamer: GaeaChunkStreamer, p_chunk_size: int) -> void:
	streamer = p_streamer
	chunk_size = p_chunk_size


func query() -> QueryBuilder:
	return q.with_all([C_Position, C_CurrentChunk, C_PlayerControl]).iterate([C_Position, C_CurrentChunk])


func process(_entities: Array[Entity], components: Array, _delta: float) -> void:
	if streamer == null or chunk_size <= 0 or components.size() < 2:
		return
	var positions: Array = components[0]
	var current_chunks: Array = components[1]
	for index: int in range(positions.size()):
		var position: C_Position = positions[index] as C_Position
		var current_chunk: C_CurrentChunk = current_chunks[index] as C_CurrentChunk
		var calculated_chunk: Vector2i = ChunkMath.world_to_chunk(
			Vector2i(floori(position.world_position.x), floori(position.world_position.y)),
			chunk_size
		)
		if calculated_chunk == current_chunk.coord:
			continue
		current_chunk.coord = calculated_chunk
		streamer.update_player_chunk(calculated_chunk)
