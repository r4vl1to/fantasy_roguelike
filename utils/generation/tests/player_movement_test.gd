extends Node

## Regression test for player input-driven movement (S_PlayerMovement) and its
## integration with chunk streaming (S_ChunkStreaming -> GaeaChunkStreamer).
##
## Runs standalone: a Node script that self-quits with code 0 (pass) / 1 (fail).
## It does not need the full world scene, so it stays fast and deterministic.

const CHUNK_SIZE: int = 32
const TILE_SIZE: int = 16

var failed: bool = false
var world: World
var streamer: GaeaChunkStreamer
var player: E_Player
var position: C_Position
var current_chunk: C_CurrentChunk
var move_target: C_MoveTarget
var move_speed: C_MoveSpeed
var movement_system: S_PlayerMovement
var click_system: S_ClickToMove
var camera: Camera2D


func _ready() -> void:
	print("=== PLAYER MOVEMENT TEST ===")
	_setup()
	await _test_keyboard_steps_one_tile()
	await _test_keyboard_diagonal_step()
	_test_no_input_no_movement()
	_test_pending_does_not_walk()
	_test_confirmed_walks_tile_by_tile()
	await _test_keyboard_cancels_pending()
	await _test_click_maps_screen_to_tile()
	_test_preview_path_is_contiguous()
	_test_movement_drives_chunk_streaming()
	print("=== PLAYER MOVEMENT TEST %s ===" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _setup() -> void:
	world = World.new()
	world.name = "MovementTestWorld"
	add_child(world)
	ECS.world = world

	streamer = GaeaChunkStreamer.new()
	streamer.stream_radius = 1
	add_child(streamer)
	streamer.update_player_chunk(Vector2i.ZERO)

	var streaming_system: S_ChunkStreaming = S_ChunkStreaming.new()
	streaming_system.configure(streamer, CHUNK_SIZE)
	world.add_system(streaming_system)

	movement_system = S_PlayerMovement.new()
	world.add_system(movement_system)

	camera = Camera2D.new()
	camera.name = "Camera2D"
	add_child(camera)
	camera.make_current()

	click_system = S_ClickToMove.new()
	click_system.tile_size = TILE_SIZE
	add_child(click_system)

	player = E_Player.new()
	player.name = "Player"
	world.add_entity(player)
	position = player.get_component(C_Position) as C_Position
	current_chunk = player.get_component(C_CurrentChunk) as C_CurrentChunk
	move_target = player.get_component(C_MoveTarget) as C_MoveTarget
	move_speed = player.get_component(C_MoveSpeed) as C_MoveSpeed
	position.world_position = Vector2.ZERO
	current_chunk.coord = Vector2i.ZERO
	_assert(move_speed.speed > 0.0, "Player has a positive move speed")
	_assert(move_target != null, "Player has a click move target")


func _reset_to(tile: Vector2i) -> void:
	position.world_position = Vector2(tile)
	move_target.active = false
	move_target.pending = false
	movement_system.reset_step_delay()
	current_chunk.coord = ChunkMath.world_to_chunk(tile, CHUNK_SIZE)
	streamer.update_player_chunk(current_chunk.coord)


func _test_keyboard_steps_one_tile() -> void:
	_reset_to(Vector2i(2, 5))
	Input.action_press("move_right")
	ECS.process(0.5)
	Input.action_release("move_right")
	_assert(position.world_position == Vector2(3, 5), "Key press steps exactly one tile right")
	_assert(is_equal_approx(position.world_position.x, roundf(position.world_position.x)), "Position stays snapped to the tile grid")
	# Let the frame advance so the "just pressed" edge does not leak into the next test.
	await get_tree().process_frame


func _test_keyboard_diagonal_step() -> void:
	_reset_to(Vector2i(2, 5))
	Input.action_press("move_right")
	Input.action_press("move_up")
	ECS.process(0.5)
	Input.action_release("move_right")
	Input.action_release("move_up")
	_assert(position.world_position == Vector2(3, 4), "Simultaneous horizontal and vertical keys advance one diagonal tile")
	await get_tree().process_frame


func _test_no_input_no_movement() -> void:
	_reset_to(Vector2i(2, 5))
	movement_system.input_enabled = false
	ECS.process(0.5)
	movement_system.input_enabled = true
	_assert(position.world_position == Vector2(2, 5), "No input leaves position unchanged")


func _test_pending_does_not_walk() -> void:
	_reset_to(Vector2i(2, 5))
	move_target.target = Vector2i(5, 5)
	move_target.pending = true
	for _i: int in range(5):
		ECS.process(1.0)
	_assert(position.world_position == Vector2(2, 5), "A pending (unconfirmed) destination does not move the player")


func _test_confirmed_walks_tile_by_tile() -> void:
	_reset_to(Vector2i(2, 5))
	move_target.target = Vector2i(4, 5)
	move_target.pending = false
	move_target.active = true
	ECS.process(1.0)
	_assert(position.world_position == Vector2(3, 5), "Confirmed destination walks one tile per step")
	ECS.process(1.0)
	_assert(position.world_position == Vector2(4, 5), "Confirmed destination reaches the chosen tile")
	ECS.process(1.0)
	_assert(not move_target.active, "Confirmed destination is cleared on arrival")


func _test_keyboard_cancels_pending() -> void:
	_reset_to(Vector2i(2, 5))
	move_target.target = Vector2i(5, 5)
	move_target.pending = true
	Input.action_press("move_left")
	ECS.process(1.0)
	Input.action_release("move_left")
	_assert(position.world_position == Vector2(1, 5), "Keyboard moves while a destination is pending")
	_assert(not move_target.pending, "Keyboard input cancels the pending destination")
	await get_tree().process_frame


func _test_click_maps_screen_to_tile() -> void:
	# Camera centered on tile (3, 4): its centre is at pixel (3.5, 4.5) * 16.
	camera.global_position = Vector2(3.5, 4.5) * float(TILE_SIZE)
	await get_tree().process_frame
	var viewport: Viewport = get_viewport()
	var screen_center: Vector2 = viewport.get_visible_rect().size * 0.5
	var tile: Vector2i = click_system.screen_to_tile(screen_center)
	_assert(tile == Vector2i(3, 4), "Screen center maps to the camera's tile")


func _test_preview_path_is_contiguous() -> void:
	var path: Array[Vector2i] = _build_path(Vector2i(2, 5), Vector2i(5, 3))
	_assert(path.back() == Vector2i(5, 3), "Preview path ends at the destination tile")
	var previous: Vector2i = Vector2i(2, 5)
	var contiguous: bool = true
	for tile: Vector2i in path:
		if maxi(absi(tile.x - previous.x), absi(tile.y - previous.y)) != 1:
			contiguous = false
		previous = tile
	_assert(contiguous, "Preview path uses adjacent tiles including diagonals")


func _build_path(from_tile: Vector2i, to_tile: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var tile: Vector2i = from_tile
	while tile != to_tile:
		tile = S_PlayerMovement.step_toward(tile, to_tile)
		path.append(tile)
	return path


func _test_movement_drives_chunk_streaming() -> void:
	# Start on the last tile of chunk (0, 0) and step across the boundary.
	_reset_to(Vector2i(CHUNK_SIZE - 1, 0))
	Input.action_press("move_right")
	ECS.process(0.0)
	Input.action_release("move_right")
	ECS.process(0.0)
	_assert(current_chunk.coord == Vector2i(1, 0), "Crossing a chunk boundary updates C_CurrentChunk")
	_assert(streamer.current_player_chunk == Vector2i(1, 0), "Streaming center follows the player chunk")
	_assert(streamer.required_chunks.size() == 9, "Active set stays 3x3 after crossing a boundary")
	_assert(streamer.is_required(Vector2i(1, 0)), "New center chunk is required")
	_assert(not streamer.is_required(Vector2i(-2, 0)), "Chunk outside radius is not required")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
		return
	failed = true
	push_error("[FAIL] " + message)