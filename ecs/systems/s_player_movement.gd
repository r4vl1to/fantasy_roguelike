class_name S_PlayerMovement
extends System

## Traditional roguelike grid movement. Player-controlled entities always occupy
## exactly one tile: keyboard input advances one tile per step (repeating while a
## key is held), and a click (handled by S_ClickToMove) sets C_MoveTarget so the
## entity walks tile by tile toward the clicked tile — one tile per step.
##
## Chunk streaming reacts to the resulting C_Position through S_ChunkStreaming,
## so gameplay never touches the streaming layer directly.

## When false the system reads no input (used by deterministic tests).
var input_enabled: bool = true

## Delay between consecutive tiles when walking toward a click target.
## Keyboard steps are instantaneous (one tile per press).
var _step_cooldown: float = 0.0


func query() -> QueryBuilder:
	return q.with_all([C_Position, C_PlayerControl, C_MoveSpeed, C_MoveTarget]).iterate([C_Position, C_MoveSpeed, C_MoveTarget])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	if components.size() < 3:
		return
	_step_cooldown = maxf(0.0, _step_cooldown - delta)
	var positions: Array = components[0]
	var speeds: Array = components[1]
	var targets: Array = components[2]
	var direction: Vector2i = _read_direction()
	var ctrl_held: bool = Input.is_key_pressed(KEY_CTRL)
	var facing_input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	for index: int in range(positions.size()):
		var position: C_Position = positions[index] as C_Position
		var move_speed: C_MoveSpeed = speeds[index] as C_MoveSpeed
		var move_target: C_MoveTarget = targets[index] as C_MoveTarget
		if position == null or move_speed == null or move_target == null:
			continue
		var vision: C_Vision = entities[index].get_component(C_Vision) as C_Vision
		var current: Vector2i = _tile_of(position)
		if direction != Vector2i.ZERO:
			# Keyboard: one tile per step, repeating while a key is held.
			# Any keyboard input cancels a pending click destination.
			move_target.active = false
			move_target.pending = false
			# Track travel independently from aim. Holding Ctrl allows backpedaling;
			# otherwise facing follows movement, and releasing Ctrl restores it.
			if vision != null:
				vision.movement_facing = Vector2(direction).normalized()
				if not ctrl_held:
					vision.facing = vision.movement_facing
			if _step_cooldown > 0.0:
				continue
			position.world_position = Vector2(current + direction)
			_step_cooldown = 1.0 / maxf(move_speed.speed, 0.001)
			continue
		if vision != null and not ctrl_held:
			vision.facing = vision.movement_facing
		if direction == Vector2i.ZERO and vision != null and not ctrl_held:
			if facing_input.length_squared() > 0.000001:
				vision.movement_facing = facing_input.normalized()
				vision.facing = vision.movement_facing
		if not move_target.active:
			continue
		if current == move_target.target:
			move_target.active = false
			continue
		if _step_cooldown > 0.0:
			continue
		var next: Vector2i = step_toward(current, move_target.target)
		_position_and_face(position, vision, next)
		_step_cooldown = 1.0 / maxf(move_speed.speed, 0.001)


## Moves the entity to `tile` and turns its vision toward the step direction.
func _position_and_face(position: C_Position, vision: C_Vision, tile: Vector2i) -> void:
	var ctrl_held: bool = Input.is_key_pressed(KEY_CTRL)
	var direction: Vector2 = Vector2(tile) - position.world_position
	if vision != null and direction.length_squared() > 0.000001:
		vision.movement_facing = direction.normalized()
		if not ctrl_held:
			vision.facing = vision.movement_facing
	position.world_position = Vector2(tile)



func _read_direction() -> Vector2i:
	if not input_enabled:
		return Vector2i.ZERO
	var vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if vector == Vector2.ZERO:
		return Vector2i.ZERO
	# Preserve both axes so simultaneous horizontal and vertical input advances
	# one diagonal tile instead of discarding the weaker axis.
	return Vector2i(int(signf(vector.x)), int(signf(vector.y)))


## Clears the pending step delay so the next step happens immediately.
func reset_step_delay() -> void:
	_step_cooldown = 0.0


func _tile_of(position: C_Position) -> Vector2i:
	return Vector2i(roundi(position.world_position.x), roundi(position.world_position.y))


## Returns the next grid tile from `current` toward `target`, advancing on both
## axes when possible so click-to-move uses diagonal steps too.
static func step_toward(current: Vector2i, target: Vector2i) -> Vector2i:
	var offset: Vector2i = target - current
	return current + Vector2i(signi(offset.x), signi(offset.y))