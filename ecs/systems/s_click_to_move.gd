class_name S_ClickToMove
extends System

## Turns a click into a PENDING tile destination for player-controlled entities.
##
## Converts the click from screen space to world space through the active
## camera, maps it to a tile coordinate and stores it in C_MoveTarget with
## `pending = true`. The entity does not move yet: the UI shows the tile, its
## terrain and the trayecto and asks for confirmation. Once confirmed,
## S_PlayerMovement walks the entity there, one tile at a time.

const ACTION: StringName = &"move_click"

## Pixel size of one tile; must match the world TileSet and GaeaChunkRenderer.
var tile_size: int = 16

## Screen-space rectangles (e.g. the confirmation panel) whose clicks must be
## left to the GUI instead of selecting a world tile.
var blocking_rects: Array[Rect2] = []


func query() -> QueryBuilder:
	return q.with_all([C_PlayerControl, C_MoveTarget]).iterate([C_MoveTarget])


func process(_entities: Array[Entity], components: Array, _delta: float) -> void:
	if not Input.is_action_just_pressed(ACTION):
		return
	if components.size() < 1:
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var screen_position: Vector2 = viewport.get_mouse_position()
	if _is_blocked(screen_position):
		return
	var tile: Vector2i = screen_to_tile(screen_position)
	var targets: Array = components[0]
	for index: int in range(targets.size()):
		var move_target: C_MoveTarget = targets[index] as C_MoveTarget
		if move_target == null:
			continue
		move_target.target = tile
		move_target.active = false
		move_target.pending = true


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
