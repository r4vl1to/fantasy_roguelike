class_name S_ClickToMove
extends System

## Turns a click into a PENDING tile destination for player-controlled entities.
##
## Converts the click from screen space to world space through the active
## camera, maps it to a tile coordinate and stores it in C_MoveTarget with
## `pending = true`. The entity does not move yet: the UI shows the tile, its
## terrain and the trayecto and asks for confirmation. Once confirmed,
## S_PlayerMovement walks the entity there, one tile at a time.
##
## Ctrl + click is different: it does not choose a destination. It aims the
## entity's look (C_Vision.facing) toward the clicked tile, turning the vision
## cone without moving the entity.

const ACTION: StringName = &"move_click"

## Pixel size of one tile; must match the world TileSet and GaeaChunkRenderer.
var tile_size: int = 16

## Screen-space rectangles (e.g. the confirmation panel) whose clicks must be
## left to the GUI instead of selecting a world tile.
var blocking_rects: Array[Rect2] = []


func query() -> QueryBuilder:
	return q.with_all([C_PlayerControl, C_MoveTarget, C_Position]).iterate([C_MoveTarget, C_Position])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var aiming: bool = Input.is_key_pressed(KEY_CTRL)
	var clicked: bool = Input.is_action_just_pressed(ACTION)
	if aiming:
		if components.size() < 2 or get_viewport() == null:
			return
		if _is_blocked(get_viewport().get_mouse_position()):
			return
		var aim_tile: Vector2i = screen_to_tile(get_viewport().get_mouse_position())
		var aim_targets: Array = components[0] if components.size() > 0 else []
		var aim_positions: Array = components[1] if components.size() > 1 else []
		for aim_index: int in range(aim_targets.size()):
			var aim_position: C_Position = aim_positions[aim_index] as C_Position
			if aim_position == null:
				continue
			var vision: C_Vision = entities[aim_index].get_component(C_Vision) as C_Vision
			_aim(vision, aim_position, aim_tile)
			# The aim becomes the idle facing, so releasing Ctrl keeps the
			# cone pointing in the newly selected direction.
			if vision != null:
				vision.movement_facing = vision.facing
		return
	if not clicked:
		return
	if components.size() < 2:
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var screen_position: Vector2 = viewport.get_mouse_position()
	if _is_blocked(screen_position):
		return
	var tile: Vector2i = screen_to_tile(screen_position)
	var targets: Array = components[0]
	var positions: Array = components[1]
	if not Input.is_key_pressed(KEY_CTRL):
		for release_index: int in range(targets.size()):
			var release_vision: C_Vision = entities[release_index].get_component(C_Vision) as C_Vision
			if release_vision != null:
				release_vision.facing = release_vision.movement_facing
	for index: int in range(targets.size()):
		var move_target: C_MoveTarget = targets[index] as C_MoveTarget
		var position: C_Position = positions[index] as C_Position
		if move_target == null or position == null:
			continue

		move_target.target = tile
		move_target.active = false
		move_target.pending = true


## Points the entity's vision from its tile toward `tile` (a look, not a move).
func _aim(vision: C_Vision, position: C_Position, tile: Vector2i) -> void:
	if vision == null:
		return
	var direction: Vector2 = Vector2(tile) - position.world_position
	if direction.length_squared() < 0.000001:
		return
	vision.facing = direction.normalized()


func _is_blocked(screen_position: Vector2) -> bool:
	for rect: Rect2 in blocking_rects:
		if rect.has_point(screen_position):
			return true
	return false


## Maps a screen-space position to a world tile, using the active camera.
func screen_to_tile(screen_position: Vector2) -> Vector2i:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2i.ZERO
	var world_position: Vector2 = viewport.get_canvas_transform().affine_inverse() * screen_position
	return Vector2i(
		floori(world_position.x / float(tile_size)),
		floori(world_position.y / float(tile_size))
	)
