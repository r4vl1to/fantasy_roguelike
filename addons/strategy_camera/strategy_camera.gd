class_name StrategyCamera
extends Camera2D

# Upstream StrategyCamera by Thomas "Thomas 737" Walsh (MIT; see LICENSE.md).
# Camera input actions are created by _ensure_input_actions(); bind keys/buttons
# in Project Settings > Input Map to select your preferred controls.
# Defaults for keyboard axes use IJKL, +/-, and middle mouse button for dragging.

@export var allow_mouse_controls: bool = true
@export var allow_keyboard_controls: bool = true

const DEFAULT_KEY_BINDINGS: Dictionary = {
	"cam_left": KEY_J,
	"cam_right": KEY_L,
	"cam_up": KEY_I,
	"cam_down": KEY_K,
	"cam_zoom_out": KEY_MINUS,
	"cam_zoom_in": KEY_EQUAL,
}

@export_group("Keyboard Controls")
## Camera zoom speed when controlled with keys
@export var key_zoom_speed: float = 2.0
## Translation speed when controlled by keys
@export var translation_speed: float = 100.0

@export_group("Camera Zoom Variables")
## Relative zoom in every scroll wheel tick.
@export var zoom_step: float = 0.2
## Speed at which the camera reaches the next target zoom. Really funky things can happen
## if x and y are set to different values...
@export var zoom_speed: Vector2 = Vector2(10, 10)

@export_group("Directional Limits")
## Top-left limit of the camera position/movement (applied to the top-left of the camera).
## If this and limit_BR set to Vector2.ZERO, no limits will be applied
@export var limit_TL: Vector2 = Vector2.ZERO
## Bottom-right limit of the camera position/movement (applied to the bottom-right of the camera).
## If this and limit_TL set to Vector2.ZERO, no limits will be applied
@export var limit_BR: Vector2 = Vector2.ZERO

var camera_TL: Vector2 = Vector2(-576, -324)
var camera_BR: Vector2 = Vector2(576, 324)
var target_zoom: Vector2 = Vector2.ONE
var _mouse_dragging: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_ensure_input_actions()
	target_zoom = zoom
	get_viewport().size_changed.connect(_on_resolution_change)
	call_deferred("_on_resolution_change")

func _ensure_input_actions() -> void:
	for action_name: String in DEFAULT_KEY_BINDINGS:
		var action: StringName = StringName(action_name)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var key_event: InputEventKey = InputEventKey.new()
			key_event.keycode = DEFAULT_KEY_BINDINGS[action_name]
			key_event.physical_keycode = DEFAULT_KEY_BINDINGS[action_name]
			InputMap.action_add_event(action, key_event)
	if not InputMap.has_action(&"cam_drag"):
		InputMap.add_action(&"cam_drag")
	if InputMap.action_get_events(&"cam_drag").is_empty():
		var drag_event: InputEventMouseButton = InputEventMouseButton.new()
		drag_event.button_index = MOUSE_BUTTON_MIDDLE
		InputMap.action_add_event(&"cam_drag", drag_event)


func _on_resolution_change() -> void:
	if not is_inside_tree():
		return
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	camera_TL = -viewport_size / 2.0
	camera_BR = viewport_size / 2.0

func _input(event: InputEvent) -> void:
	if not allow_mouse_controls:
		return
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE):
		_mouse_dragging = event.pressed
		_last_mouse_position = event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _mouse_dragging or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			var viewport_motion: Vector2 = event.position - _last_mouse_position
			_last_mouse_position = event.position
			var screen_transform: Transform2D = get_viewport().get_screen_transform()
			var local_motion: Vector2 = screen_transform.affine_inverse().basis_xform(viewport_motion)
			position -= local_motion / zoom
			get_viewport().set_input_as_handled()
		else:
			_last_mouse_position = event.position
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(zoom_step)
			target_zoom = target_zoom.clamp(Vector2.ONE * 0.5, Vector2(4.0, 4.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(-zoom_step)
			target_zoom = target_zoom.clamp(Vector2.ONE * 0.5, Vector2(4.0, 4.0))

func _process(delta: float) -> void:
	if allow_keyboard_controls:
		var pan_direction: Vector2 = Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
		position += pan_direction * translation_speed * delta
		var camera_zoom_direction: float = Input.get_axis("cam_zoom_out", "cam_zoom_in")
		if not is_zero_approx(camera_zoom_direction):
			zoom_camera(camera_zoom_direction * key_zoom_speed * delta)
			target_zoom = target_zoom.clamp(Vector2.ONE * 0.5, Vector2(4.0, 4.0))

	if target_zoom.length()-0.001 <= zoom.length() and zoom.length() <= target_zoom.length()+0.001:
		zoom = target_zoom
	else:
		increment_zoom((target_zoom-zoom) * zoom_speed * delta)
	
	var screen_centre: Vector2 = get_screen_center_position()
	var actual_TL: Vector2 = screen_centre + camera_TL / target_zoom
	var actual_BR: Vector2 = screen_centre + camera_BR / target_zoom
	
	
	if limit_BR == Vector2.ZERO and limit_TL == Vector2.ZERO:
		return
	
	# Camera limit application
	if actual_TL.x < limit_TL.x:
		position.x += limit_TL.x - actual_TL.x
	if actual_TL.y < limit_TL.y:
		position.y += limit_TL.y - actual_TL.y
	
	if actual_BR.x > limit_BR.x:
		position.x -= actual_BR.x - limit_BR.x
	if actual_BR.y > limit_BR.y:
		position.y -= actual_BR.y - limit_BR.y

func zoom_camera(zoom_amount: float) -> void:
	target_zoom *= pow(10.0, zoom_amount)

func increment_zoom(zoom_direction: Vector2) -> void:
	var previous_mouse_position: Vector2 = get_local_mouse_position()
	zoom += zoom_direction

	var diff: Vector2 = previous_mouse_position - get_local_mouse_position()
	offset += diff
