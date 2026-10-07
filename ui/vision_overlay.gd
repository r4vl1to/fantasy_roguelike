class_name VisionOverlay
extends ColorRect

## Full-screen overlay that represents the player's vision cone: an opaque mist
## covers the whole view and the cone — the C_Vision area — is carved out.
##
## Pure representation: it reads C_Vision and the camera each frame and pushes
## uniforms to the shader; it never changes gameplay state. C_Vision is the
## source of truth; this node only draws it.

const SHADER_PATH: String = "res://ui/vision_overlay.gdshader"

## Pixel size of one tile; must match the world TileSet and GaeaChunkRenderer.
var tile_size: float = 16.0

## Camera whose transform maps world pixels to the screen. Required to place the
## cone: the shader works in screen space.
var camera: Camera2D

## Colour/alpha of the mist outside the cone. Translucent: it only reduces how
## well the world reads outside the cone (alpha 1 would erase the tiles).
var mist_color: Color = Color(0.10, 0.11, 0.16, 0.75)

## Width in pixels of the soft transition at the cone's arc and edges.
var edge_softness: float = 10.0

## Radius in tiles that remains clear around the player independently of facing.
@export_range(0.0, 8.0, 0.1) var inner_radius_tiles: float = 1.0

var _material: ShaderMaterial = null
@export_range(0.1, 30.0, 0.1) var turn_speed: float = 8.0
var _display_facing: Vector2 = Vector2.RIGHT
var _has_display_facing: bool = false

func _ready() -> void:
	# A Control parented to a CanvasLayer does not get an anchor rect from the
	# viewport on its own, so we size it to the viewport explicitly.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	material = _material
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	visible = false


func _fit_to_viewport() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	position = Vector2.ZERO
	size = viewport.get_visible_rect().size


## Recomputes the cone uniforms for this frame. `source_tile` is the vision
## source's tile (C_Position.world_position, in tile units).
func update_cone(vision: C_Vision, source_tile: Vector2, delta: float = 0.016) -> void:
	if _material == null or camera == null or vision == null or not vision.enabled:
		visible = false
		return
	visible = true

	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var world_px: Vector2 = (source_tile + Vector2(0.5, 0.5)) * tile_size
	var center_px: Vector2 = canvas * world_px
	var zoom: Vector2 = canvas.get_scale()

	var target_facing: Vector2 = canvas.basis_xform(vision.facing)
	if target_facing.length_squared() < 0.000001:
		target_facing = Vector2.RIGHT
	target_facing = target_facing.normalized()
	if not _has_display_facing:
		_display_facing = target_facing
		_has_display_facing = true
	else:
		var turn_weight: float = 1.0 - exp(-turn_speed * maxf(delta, 0.0))
		var angle_delta: float = wrapf(target_facing.angle() - _display_facing.angle(), -PI, PI)
		_display_facing = _display_facing.rotated(angle_delta * turn_weight).normalized()

	_material.set_shader_parameter("resolution", size)
	_material.set_shader_parameter("center", center_px)
	_material.set_shader_parameter("radius", vision.radius_tiles * tile_size * maxf(zoom.x, 0.0001))
	_material.set_shader_parameter("facing", _display_facing)
	_material.set_shader_parameter("half_angle", deg_to_rad(vision.cone_angle_degrees) * 0.5)
	_material.set_shader_parameter("softness", edge_softness)
	_material.set_shader_parameter("inner_radius", inner_radius_tiles * tile_size * maxf(zoom.x, 0.0001))
	# Cone begins at the rear of the 16x16 character sprite. Calculate the
	# support distance of its square bounds opposite the facing direction.
	var rear_edge_offset: float = tile_size * 0.5 * (
		absf(_display_facing.x) + absf(_display_facing.y)
	) * maxf(zoom.x, 0.0001)
	_material.set_shader_parameter("rear_edge_offset", rear_edge_offset)
	_material.set_shader_parameter("mist_color", mist_color)