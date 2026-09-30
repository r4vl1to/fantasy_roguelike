class_name S_SpriteRender
extends System

## Keeps an entity's visual node positioned at its C_Position.
## Pure view sync: gameplay owns C_Position (in tile units), this system only
## mirrors it into pixel space using the shared tile size.
##
## If the entity carries C_Vision, the sprite also turns with the view: it is
## mirrored horizontally to match the facing direction, so turning the view turns
## the character.

## Pixel size of one tile; must match the world TileSet and GaeaChunkRenderer.
var tile_size: int = 16


func query() -> QueryBuilder:
	return q.with_all([C_Position, C_Sprite_Render]).iterate([C_Position, C_Sprite_Render])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	if components.size() < 2:
		return
	var positions: Array = components[0]
	var renders: Array = components[1]
	for index: int in range(positions.size()):
		var position: C_Position = positions[index] as C_Position
		var render: C_Sprite_Render = renders[index] as C_Sprite_Render
		if position == null or render == null or render.sprite == null:
			continue
		if not is_instance_valid(render.sprite):
			continue
		# Center the sprite on the middle of its tile (position is in tile units).
		render.sprite.global_position = (position.world_position + Vector2(0.5, 0.5)) * float(tile_size)
		# Mirror the source sprite to face left or right; this character artwork is
		# side-facing and should not be rotated into diagonal orientations.
		var vision: C_Vision = entities[index].get_component(C_Vision) as C_Vision
		if vision != null and absf(vision.facing.x) > 0.0001:
			render.sprite.flip_h = vision.facing.x < 0.0
