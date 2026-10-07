class_name S_Vision
extends System

## Perception system: hides rendered entities that are outside the vision cone
## of the vision-source entities (those carrying C_Vision).
##
## Scope is deliberately narrow — this is pure gameplay perception, not drawing:
##   - It only toggles the `visible` flag of C_Sprite_Render sprites.
##   - It never touches terrain/chunks: the fixed world is always visible.
##   - The cone itself is drawn separately by VisionOverlay (a shader). Keeping
##     the two apart means the "remembered terrain" rule cannot be broken by the
##     visual effect, and the effect cannot be broken by gameplay state.
##
## A vision source is always visible to itself. When C_Vision.enabled is false
## nothing is hidden.


func query() -> QueryBuilder:
	return q.with_all([C_Vision, C_Position]).iterate([C_Vision, C_Position])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	if components.size() < 2:
		return
	var visions: Array = components[0]
	var source_positions: Array = components[1]

	var targets: Array = q.with_all([C_Position, C_Sprite_Render]).execute()
	for target: Entity in targets:
		var render: C_Sprite_Render = target.get_component(C_Sprite_Render) as C_Sprite_Render
		if render == null or render.sprite == null or not is_instance_valid(render.sprite):
			continue
		var target_position: C_Position = target.get_component(C_Position) as C_Position
		if target_position == null:
			continue
		render.sprite.visible = _is_perceived(target, target_position, entities, visions, source_positions)


func _is_perceived(
	target: Entity,
	target_position: C_Position,
	sources: Array[Entity],
	visions: Array,
	source_positions: Array
) -> bool:
	for index: int in range(sources.size()):
		var vision: C_Vision = visions[index] as C_Vision
		var source_position: C_Position = source_positions[index] as C_Position
		if vision == null or source_position == null:
			continue
		if not vision.enabled:
			return true
		if target == sources[index]:
			return true
		if _is_inside_cone(target_position.world_position, source_position.world_position, vision):
			return true
	return false


## True when `target_tile` lies inside the cone from `source_tile`. Positions are
## in tile space.
func _is_inside_cone(target_tile: Vector2, source_tile: Vector2, vision: C_Vision) -> bool:
	var cone_origin: Vector2 = source_tile + vision.facing.normalized() * 0.5
	var to_target: Vector2 = target_tile - cone_origin
	var distance: float = to_target.length()
	if distance > vision.radius_tiles:
		return false
	if (target_tile - source_tile).length() <= 0.75:
		return true
	if distance < 0.0001:
		return true
	var half_angle: float = deg_to_rad(vision.cone_angle_degrees) * 0.5
	var angle: float = absf(vision.facing.normalized().angle_to(to_target / distance))
	return angle <= half_angle