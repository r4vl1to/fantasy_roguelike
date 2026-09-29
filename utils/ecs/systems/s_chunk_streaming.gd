class_name ChunkStreamingSystem
extends System

var streamer: GaeaChunkStreamer
var chunk_size: int = 32


func configure(p_streamer: GaeaChunkStreamer, p_chunk_size: int) -> void:
	streamer = p_streamer
	chunk_size = p_chunk_size


func query() -> QueryBuilder:
	return q.with_all([C_Position, C_CurrentChunk])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	if streamer == null or chunk_size <= 0:
		return
	for entity: Entity in entities:
		var position: C_Position = entity.get_component(C_Position) as C_Position
		var current_chunk: C_CurrentChunk = entity.get_component(C_CurrentChunk) as C_CurrentChunk
		if position == null or current_chunk == null:
			continue
		var calculated_chunk: Vector2i = ChunkMath.world_to_chunk(Vector2i(floori(position.world_position.x), floori(position.world_position.y)), chunk_size)
		if calculated_chunk == current_chunk.coord:
			continue
		current_chunk.coord = calculated_chunk
		streamer.update_player_chunk(calculated_chunk)
