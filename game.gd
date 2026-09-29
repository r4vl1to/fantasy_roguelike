class_name Game
extends Node2D

## Playable world scene bootstrap.
##
## Wires the verified chunk-streaming stack (GaeaGenerator -> GaeaWorldManager ->
## WorldDatabase / WorldPersistence -> GaeaChunkRenderer) to the GECS simulation
## and adds player-controlled movement. The player drives chunk streaming purely
## through its C_Position: gameplay never talks to the streamer or the database
## directly.
##
## Ownership respected:
##   - terrain generation      -> GaeaGenerator (via GaeaWorldManager)
##   - required active chunks  -> GaeaChunkStreamer
##   - chunk lifecycle / RAM / disk -> GaeaWorldManager
##   - entity simulation       -> GECS (S_ChunkStreaming, S_PlayerMovement, S_SpriteRender)

const CHUNK_SIZE: int = 32
const TILE_SIZE: int = 16
const STREAM_RADIUS: int = 1
const PERSISTENCE_ROOT: String = "user://world"
const PLAYER_SPRITE: String = "res://assets/characters/ampholk_archer.png"
const START_CHUNK: Vector2i = Vector2i.ZERO
const StrategyCameraScript = preload("res://addons/strategy_camera/strategy_camera.gd")
const PathOverlayScript = preload("res://ui/path_overlay.gd")
const MoveConfirmPanelScript = preload("res://ui/move_confirm_panel.gd")

@onready var generator: GaeaGenerator = $GaeaGenerator
@onready var manager: GaeaWorldManager = $GaeaWorldManager
@onready var renderer: GaeaChunkRenderer = $GaeaChunkRenderer
var camera: Camera2D

var database: WorldDatabase
var persistence: WorldPersistence
var streamer: GaeaChunkStreamer
var ecs_world: World
var player: E_Player
var entity_lifecycle: ChunkEntityLifecycle
var terrain_materials: Dictionary = {}
var click_system: S_ClickToMove
var path_overlay: PathOverlayScript
var move_panel: MoveConfirmPanelScript
var _camera_initialized: bool = false
var _camera_chunk: Vector2i = Vector2i(2147483647, 2147483647)


func _ready() -> void:
	_setup_camera()
	_setup_ecs()
	_setup_world()
	_setup_streaming()
	_spawn_player()
	_setup_move_ui()
	streamer.update_player_chunk(START_CHUNK)


func _process(delta: float) -> void:
	if ecs_world != null:
		ECS.process(delta)
	_update_camera()
	_handle_move_confirmation()
	_update_move_preview()
	_update_visible_chunks_for_camera()


# --- ECS world -----------------------------------------------------------------

func _setup_ecs() -> void:
	ecs_world = World.new()
	ecs_world.name = "ECSWorld"
	add_child(ecs_world)
	ECS.world = ecs_world


# --- Streaming stack -----------------------------------------------------------

func _setup_world() -> void:
	var mapping: GaeaMappingRegistry = GaeaMappingRegistry.new()
	mapping.build_from_graph(generator.graph)
	terrain_materials = _build_materials()

	database = WorldDatabase.new()
	persistence = WorldPersistence.new(PERSISTENCE_ROOT)

	manager.setup(generator, mapping, database, persistence, CHUNK_SIZE)
	manager.chunk_ready.connect(_on_chunk_ready)
	manager.chunk_generation_failed.connect(_on_chunk_generation_failed)

	renderer.tile_size = TILE_SIZE
	renderer.terrain_materials = terrain_materials

	entity_lifecycle = ChunkEntityLifecycle.new()
	entity_lifecycle.configure(ecs_world, PERSISTENCE_ROOT)
	manager.configure_entity_lifecycle(entity_lifecycle)


func _setup_streaming() -> void:
	streamer = GaeaChunkStreamer.new()
	streamer.name = "GaeaChunkStreamer"
	streamer.stream_radius = STREAM_RADIUS
	add_child(streamer)
	streamer.chunks_to_load.connect(_on_chunks_to_load)
	streamer.chunks_to_unload.connect(_on_chunks_to_unload)

	var streaming_system: S_ChunkStreaming = S_ChunkStreaming.new()
	streaming_system.configure(streamer, CHUNK_SIZE)
	ecs_world.add_system(streaming_system)


# --- Player --------------------------------------------------------------------

func _spawn_player() -> void:
	player = E_Player.new()
	player.name = "Player"
	ecs_world.add_entity(player)

	var player_position: C_Position = player.get_component(C_Position) as C_Position
	var current_chunk: C_CurrentChunk = player.get_component(C_CurrentChunk) as C_CurrentChunk
	player_position.world_position = Vector2(ChunkMath.chunk_to_world_origin(START_CHUNK, CHUNK_SIZE))
	current_chunk.coord = START_CHUNK

	var sprite: AnimatedSprite2D = _create_player_sprite()
	player.add_child(sprite)
	sprite.global_position = (player_position.world_position + Vector2(0.5, 0.5)) * float(TILE_SIZE)
	player.add_component(C_Sprite_Render.new(sprite))

	ecs_world.add_system(S_PlayerMovement.new())
	var sprite_system: S_SpriteRender = S_SpriteRender.new()
	sprite_system.tile_size = TILE_SIZE
	ecs_world.add_system(sprite_system)
	click_system = S_ClickToMove.new()
	click_system.tile_size = TILE_SIZE
	ecs_world.add_system(click_system)

	_update_camera()


func _create_player_sprite() -> AnimatedSprite2D:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	if ResourceLoader.exists(PLAYER_SPRITE):
		frames.add_frame("idle", load(PLAYER_SPRITE))
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = frames
	sprite.z_index = 10
	sprite.play("idle")
	return sprite


func _setup_camera() -> void:
	var camera_node: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if camera_node == null:
		push_error("game.tscn needs a Camera2D node to replace with StrategyCamera.")
		return
	var camera_parent: Node = camera_node.get_parent()
	var camera_index: int = camera_node.get_index()
	var camera_transform: Transform2D = camera_node.transform
	var strategy_camera: Camera2D = StrategyCameraScript.new() as Camera2D
	strategy_camera.name = "StrategyCamera"
	strategy_camera.transform = camera_transform
	strategy_camera.position_smoothing_enabled = false
	strategy_camera.allow_keyboard_controls = true
	strategy_camera.allow_mouse_controls = true
	camera_parent.remove_child(camera_node)
	camera_parent.add_child(strategy_camera)
	camera_parent.move_child(strategy_camera, camera_index)
	camera_node.queue_free()
	camera = strategy_camera


func _update_camera() -> void:
	if player == null or camera == null:
		return
	var player_position: C_Position = player.get_component(C_Position) as C_Position
	if player_position == null:
		return
	# Keep the initial camera centered on the player, but do not recenter it
	# every frame: StrategyCamera must retain user pan/zoom after game start.
	if not _camera_initialized:
		camera.global_position = (player_position.world_position + Vector2(0.5, 0.5)) * float(TILE_SIZE)
		_camera_initialized = true


# --- Streaming callbacks -------------------------------------------------------

func _update_visible_chunks_for_camera() -> void:
	if camera == null or manager == null or streamer == null:
		return
	var camera_chunk: Vector2i = ChunkMath.world_to_chunk(
		Vector2i(floori(camera.global_position.x / float(TILE_SIZE)), floori(camera.global_position.y / float(TILE_SIZE))),
		CHUNK_SIZE
	)
	if camera_chunk == _camera_chunk:
		return
	_camera_chunk = camera_chunk
	var needed: Dictionary = {}
	for coord_variant: Variant in streamer.required_chunks.keys():
		var coord: Vector2i = coord_variant as Vector2i
		needed[coord] = true
	for offset_y: int in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
		for offset_x: int in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
			needed[camera_chunk + Vector2i(offset_x, offset_y)] = true
	var combined_coords: Array[Vector2i] = []
	for coord_variant: Variant in needed.keys():
		combined_coords.append(coord_variant as Vector2i)
	manager.set_required_chunks(combined_coords)
	for coord: Vector2i in combined_coords:
		manager.request_chunk(coord)


func _on_chunks_to_load(chunks: Array[Vector2i]) -> void:
	manager.set_required_chunks(streamer.required_chunks.keys())
	for coord: Vector2i in chunks:
		manager.request_chunk(coord)


func _on_chunks_to_unload(chunks: Array[Vector2i]) -> void:
	for coord: Vector2i in chunks:
		if not _is_required_by_camera(coord):
			renderer.unrender_chunk(coord)
			manager.unload_chunk(coord)


func _is_required_by_camera(coord: Vector2i) -> bool:
	if _camera_chunk.x == 2147483647:
		return false
	return maxi(absi(coord.x - _camera_chunk.x), absi(coord.y - _camera_chunk.y)) <= STREAM_RADIUS


func _on_chunk_ready(chunk: ChunkData) -> void:
	if chunk == null:
		return
	if manager != null and manager.is_required_chunk(chunk.coord):
		renderer.render_chunk(chunk)
		return
	if streamer != null and not streamer.is_required(chunk.coord):
		# A generation can finish after its coordinate stopped being required.
		# Evict it so abandoned work never inflates RAM or the rendered set.
		manager.unload_chunk(chunk.coord)
		return
	renderer.render_chunk(chunk)


func _on_chunk_generation_failed(coord: Vector2i) -> void:
	push_error("Chunk generation failed: %s" % coord)


# --- Click-to-move intent (preview + confirmation) -----------------------------

func _setup_move_ui() -> void:
	path_overlay = PathOverlayScript.new()
	path_overlay.name = "PathOverlay"
	path_overlay.tile_size = TILE_SIZE
	path_overlay.z_index = 5
	add_child(path_overlay)

	var ui_layer: CanvasLayer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)
	move_panel = MoveConfirmPanelScript.new()
	move_panel.name = "MoveConfirmPanel"
	ui_layer.add_child(move_panel)
	move_panel.confirmed.connect(_confirm_move)
	move_panel.cancelled.connect(_cancel_move)


func _handle_move_confirmation() -> void:
	var move_target: C_MoveTarget = _player_move_target()
	if move_target == null or not move_target.pending:
		return
	if Input.is_action_just_pressed("ui_accept"):
		_confirm_move()
	elif Input.is_action_just_pressed("ui_cancel"):
		_cancel_move()


func _confirm_move() -> void:
	var move_target: C_MoveTarget = _player_move_target()
	if move_target == null or not move_target.pending:
		return
	move_target.pending = false
	move_target.active = true


func _cancel_move() -> void:
	var move_target: C_MoveTarget = _player_move_target()
	if move_target == null:
		return
	move_target.pending = false
	move_target.active = false


func _update_move_preview() -> void:
	var move_target: C_MoveTarget = _player_move_target()
	if move_target == null or not (move_target.pending or move_target.active):
		path_overlay.clear()
		move_panel.close()
		if click_system != null:
			click_system.blocking_rects.clear()
		return
	var path: Array[Vector2i] = _build_path(_player_tile(), move_target.target)
	var terrain_id: int = manager.get_terrain_at(move_target.target)
	path_overlay.set_path(path, _player_tile(), move_target.target, _terrain_color(terrain_id))
	if move_target.pending:
		move_panel.open(move_target.target, _terrain_name(terrain_id), path.size())
		if click_system != null:
			click_system.blocking_rects = [move_panel.get_blocking_rect()]
	else:
		move_panel.close()
		if click_system != null:
			click_system.blocking_rects.clear()


func _build_path(from_tile: Vector2i, to_tile: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var tile: Vector2i = from_tile
	var guard: int = 0
	while tile != to_tile and guard < 4096:
		tile = S_PlayerMovement.step_toward(tile, to_tile)
		path.append(tile)
		guard += 1
	return path


func _player_move_target() -> C_MoveTarget:
	if player == null:
		return null
	return player.get_component(C_MoveTarget) as C_MoveTarget


func _player_tile() -> Vector2i:
	var player_position: C_Position = player.get_component(C_Position) as C_Position
	return Vector2i(roundi(player_position.world_position.x), roundi(player_position.world_position.y))


func _terrain_name(terrain_id: int) -> String:
	match terrain_id:
		TerrainId.DIRT:
			return "Dirt"
		TerrainId.GRASS:
			return "Grass"
		TerrainId.SAND:
			return "Sand"
		TerrainId.STONE:
			return "Stone"
		TerrainId.WATER:
			return "Water"
	return "Desconocido"


func _terrain_color(terrain_id: int) -> Color:
	match terrain_id:
		TerrainId.DIRT:
			return Color(0.55, 0.42, 0.26)
		TerrainId.GRASS:
			return Color(0.4, 0.78, 0.35)
		TerrainId.SAND:
			return Color(0.88, 0.82, 0.5)
		TerrainId.STONE:
			return Color(0.62, 0.62, 0.68)
		TerrainId.WATER:
			return Color(0.3, 0.55, 0.9)
	return Color(0.9, 0.3, 0.3)


# --- Terrain materials ---------------------------------------------------------

func _build_materials() -> Dictionary:
	var lookup: Dictionary = {}
	for terrain_id: int in [
		TerrainId.DIRT,
		TerrainId.GRASS,
		TerrainId.SAND,
		TerrainId.STONE,
		TerrainId.WATER,
	]:
		var gaea_material: GaeaMaterial = generator.graph.get(_parameter_name(terrain_id)) as GaeaMaterial
		if gaea_material == null or not (gaea_material is TileMapGaeaMaterial):
			push_error("Missing TileMapGaeaMaterial for TerrainId %d" % terrain_id)
			continue
		var tile: TileMapGaeaMaterial = gaea_material as TileMapGaeaMaterial
		lookup[terrain_id] = {
			"type": tile.type,
			"source_id": tile.source_id,
			"atlas_coords": tile.atlas_coord,
			"alternative_tile": tile.alternative_tile,
			"terrain_set": tile.terrain_set,
			"terrain": tile.terrain,
		}
	return lookup


func _parameter_name(terrain_id: int) -> StringName:
	match terrain_id:
		TerrainId.DIRT:
			return &"dirt"
		TerrainId.GRASS:
			return &"grass"
		TerrainId.SAND:
			return &"sand"
		TerrainId.STONE:
			return &"stone"
		TerrainId.WATER:
			return &"water"
	return &""
