extends Node

## Standalone regression test for the player vision cone perception (S_Vision)
## and the C_Vision component.
##
## Runs as a Node script that self-quits with code 0 (pass) / 1 (fail). It checks
## only the gameplay rule: entities inside the cone are visible, entities outside
## (behind, beyond range, or outside the angular opening) are hidden. Terrain is
## not part of this system.

const TILE_SIZE: int = 16

var failed: bool = false
var world: World
var player: E_Player
var vision: C_Vision
var position: C_Position
var vision_system: S_Vision


func _ready() -> void:
	print("=== VISION TEST ===")
	_setup()
	_test_entity_inside_cone_is_visible()
	_test_entity_behind_is_hidden()
	_test_entity_beyond_range_is_hidden()
	_test_entity_outside_opening_is_hidden()
	_test_entity_inside_angle_is_visible()
	_test_disabled_vision_hides_nothing()
	print("=== VISION TEST %s ===" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _setup() -> void:
	world = World.new()
	world.name = "VisionTestWorld"
	add_child(world)
	ECS.world = world

	vision_system = S_Vision.new()
	world.add_system(vision_system)

	player = E_Player.new()
	player.name = "Player"
	world.add_entity(player)
	position = player.get_component(C_Position) as C_Position
	vision = player.get_component(C_Vision) as C_Vision
	position.world_position = Vector2(5, 5)
	vision.facing = Vector2.RIGHT
	vision.radius_tiles = 5.0
	vision.cone_angle_degrees = 90.0
	vision.enabled = true


func _spawn_target(tile: Vector2i) -> C_Sprite_Render:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	add_child(sprite)
	var entity: Entity = Entity.new()
	world.add_entity(entity)
	var target_position: C_Position = C_Position.new()
	target_position.world_position = Vector2(tile)
	var render: C_Sprite_Render = C_Sprite_Render.new(sprite)
	entity.add_component(target_position)
	entity.add_component(render)
	return render


func _free_target(render: C_Sprite_Render) -> void:
	if render != null and is_instance_valid(render.sprite):
		render.sprite.queue_free()


func _test_entity_inside_cone_is_visible() -> void:
	var render: C_Sprite_Render = _spawn_target(Vector2i(7, 5)) # right, in front
	ECS.process(0.0)
	_assert(render.sprite.visible, "An entity straight ahead inside the cone is visible")
	_free_target(render)


func _test_entity_behind_is_hidden() -> void:
	var render: C_Sprite_Render = _spawn_target(Vector2i(3, 5)) # left, behind
	ECS.process(0.0)
	_assert(not render.sprite.visible, "An entity behind the facing direction is hidden")
	_free_target(render)


func _test_entity_beyond_range_is_hidden() -> void:
	var render: C_Sprite_Render = _spawn_target(Vector2i(5 + 6, 5)) # in front but out of range
	ECS.process(0.0)
	_assert(not render.sprite.visible, "An entity ahead but beyond the vision radius is hidden")
	_free_target(render)


func _test_entity_outside_opening_is_hidden() -> void:
	# 90 degree cone => +/-45 degrees. (5, 12) is nearly straight down (90 deg).
	var render: C_Sprite_Render = _spawn_target(Vector2i(5, 9))
	ECS.process(0.0)
	_assert(not render.sprite.visible, "An entity within range but outside the cone opening is hidden")
	_free_target(render)


func _test_entity_inside_angle_is_visible() -> void:
	# (7, 4) is up-and-right, ~26.5 degrees from right; inside the 90 degree cone.
	var render: C_Sprite_Render = _spawn_target(Vector2i(7, 4))
	ECS.process(0.0)
	_assert(render.sprite.visible, "An entity within the cone opening is visible")
	_free_target(render)


func _test_disabled_vision_hides_nothing() -> void:
	vision.enabled = false
	var render: C_Sprite_Render = _spawn_target(Vector2i(2, 2)) # behind and far
	ECS.process(0.0)
	_assert(render.sprite.visible, "With vision disabled nothing is hidden")
	_free_target(render)
	vision.enabled = true


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		print("[FAIL] ", message)