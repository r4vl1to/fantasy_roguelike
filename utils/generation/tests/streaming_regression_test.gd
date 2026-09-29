extends Node

var failed: bool = false
var streamer: GaeaChunkStreamer
var load_events: Array[Array] = []
var unload_events: Array[Array] = []


func _ready() -> void:
	streamer = GaeaChunkStreamer.new()
	add_child(streamer)
	streamer.stream_radius = 1
	streamer.chunks_to_load.connect(_on_load)
	streamer.chunks_to_unload.connect(_on_unload)
	var path: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 1), Vector2i(2, 0), Vector2i(2, -1), Vector2i(-2, 2), Vector2i(5, -3), Vector2i.ZERO]
	for coord: Vector2i in path:
		streamer.update_player_chunk(coord)
		_assert(streamer.required_chunks.size() == 9, "Diagonal/rapid position retains 3x3 active set")
		_assert(streamer.is_required(coord), "Player center remains required")
		for required_variant: Variant in streamer.required_chunks.keys():
			var required_coord: Vector2i = required_variant
			_assert(maxi(absi(required_coord.x - coord.x), absi(required_coord.y - coord.y)) <= 1, "No required chunk outside square radius")
	_assert(load_events.size() == path.size(), "Every fast direction transition emitted load work")
	_assert(streamer.required_chunks.has(Vector2i.ZERO), "Return-to-origin diagonal route includes origin")
	print("=== STREAMING DIRECTION REGRESSION %s ===" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _on_load(coords: Array[Vector2i]) -> void:
	load_events.append(coords.duplicate())


func _on_unload(coords: Array[Vector2i]) -> void:
	unload_events.append(coords.duplicate())


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("[FAIL] " + message)
