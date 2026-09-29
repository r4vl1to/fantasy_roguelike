extends Node

var streamer: ChunkStreamer


func _ready() -> void:
	print("========================================")
	print("CHUNK STREAMER G.3 TEST")
	print("========================================")

	streamer = ChunkStreamer.new(1)

	streamer.chunks_to_load.connect(
		_on_chunks_to_load
	)

	streamer.chunks_to_unload.connect(
		_on_chunks_to_unload
	)

	print("----------------------------------------")
	print("STEP 1")
	print("----------------------------------------")

	streamer.update_player_chunk(
		Vector2i(0, 0)
	)

	print("----------------------------------------")
	print("STEP 2")
	print("----------------------------------------")

	streamer.update_player_chunk(
		Vector2i(1, 0)
	)

	print("----------------------------------------")
	print("STEP 3")
	print("----------------------------------------")

	streamer.update_player_chunk(
		Vector2i(2, 0)
	)

	print("========================================")
	print("G.3 TEST COMPLETE")
	print("========================================")


func _on_chunks_to_load(
	chunks: Array[Vector2i]
) -> void:
	print("SIGNAL: chunks_to_load")

	for coord in chunks:
		print("  LOAD: ", coord)


func _on_chunks_to_unload(
	chunks: Array[Vector2i]
) -> void:
	print("SIGNAL: chunks_to_unload")

	for coord in chunks:
		print("  UNLOAD: ", coord)
