class_name UniversalPanel
extends PanelContainer

## Reusable floating UI panel. Children can be added to `content` in _ready()
## after calling super._ready(), or supplied as scene children under Content.
## Drag the header to move, use the bottom-right grip to resize, and lock the
## panel from the header button. Position and size persist per panel_id.

@export var panel_title: String = "Panel"
@export var panel_id: String = "universal_panel"
@export var initial_position: Vector2 = Vector2(16.0, 16.0)
@export var initial_size: Vector2 = Vector2(300.0, 180.0)
@export var minimum_panel_size: Vector2 = Vector2(24.0, 24.0)
@export var allow_content_to_define_minimum_size: bool = false
@export var locked: bool = false
@export var show_lock_button: bool = true

const CONFIG_PATH: String = "user://ui_panels.cfg"

var content: VBoxContainer
var _header: Control
var _title_label: Label
var _lock_button: Button
var _resize_grip: Control
var _dragging: bool = false
var _resizing: bool = false
var _pointer_origin: Vector2 = Vector2.ZERO
var _position_origin: Vector2 = Vector2.ZERO
var _size_origin: Vector2 = Vector2.ZERO
var _config: ConfigFile


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	minimum_panel_size = Vector2(maxf(1.0, minimum_panel_size.x), maxf(1.0, minimum_panel_size.y))
	custom_minimum_size = minimum_panel_size
	clip_contents = true
	_config = ConfigFile.new()
	_config.load(CONFIG_PATH)
	_build_panel()
	_restore_layout()
	_update_lock_ui()
	visibility_changed.connect(_on_visibility_changed)


func _build_panel() -> void:
	var root: Control = Control.new()
	root.name = "PanelLayout"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_header = Control.new()
	_header.name = "Header"
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_header)
	_header.gui_input.connect(_on_header_gui_input)

	_title_label = Label.new()
	_title_label.text = panel_title
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(_title_label)

	_lock_button = Button.new()
	_lock_button.name = "LockButton"
	_lock_button.focus_mode = Control.FOCUS_NONE
	_lock_button.pressed.connect(_toggle_locked)
	_header.add_child(_lock_button)
	_lock_button.visible = show_lock_button

	content = VBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_theme_constant_override("separation", 6)
	root.add_child(content)

	_resize_grip = Control.new()
	_resize_grip.name = "ResizeGrip"
	_resize_grip.custom_minimum_size = Vector2(8.0, 8.0)
	_resize_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_resize_grip.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_resize_grip.gui_input.connect(_on_grip_gui_input)
	_resize_grip.draw.connect(_draw_resize_grip)
	root.add_child(_resize_grip)
	_resize_grip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_resize_grip.size = Vector2(8.0, 8.0)


func _restore_layout() -> void:
	var section: String = _section_name()
	var saved_position: Variant = _config.get_value(section, "position", initial_position)
	var saved_size: Variant = _config.get_value(section, "size", initial_size)
	position = saved_position as Vector2
	var restored_size: Vector2 = saved_size as Vector2
	size = Vector2(maxf(minimum_panel_size.x, restored_size.x), maxf(minimum_panel_size.y, restored_size.y))
	locked = bool(_config.get_value(section, "locked", locked))
	custom_minimum_size = minimum_panel_size
	_layout_children()


func _get_effective_minimum_size() -> Vector2:
	var effective: Vector2 = minimum_panel_size
	if allow_content_to_define_minimum_size:
		effective = effective.max(content.get_combined_minimum_size())
	return effective


func _get_available_size() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(maxf(_get_effective_minimum_size().x, viewport_size.x - position.x), maxf(_get_effective_minimum_size().y, viewport_size.y - position.y))


func _layout_children() -> void:
	var width: float = size.x
	var height: float = size.y
	var grip_size: float = minf(12.0, minf(width, height))
	var header_height: float = minf(24.0, height)
	_header.position = Vector2.ZERO
	_header.size = Vector2(width, header_height)
	var lock_size: Vector2 = Vector2(minf(22.0, width), minf(header_height, 22.0))
	_lock_button.position = Vector2(maxf(0.0, width - lock_size.x), 0.0)
	_lock_button.size = lock_size
	_title_label.position = Vector2(2.0, 0.0)
	_title_label.size = Vector2(maxf(0.0, width - lock_size.x - 4.0), header_height)
	content.position = Vector2(0.0, header_height)
	content.size = Vector2(width, maxf(0.0, height - header_height))
	_resize_grip.position = Vector2(maxf(0.0, width - grip_size), maxf(0.0, height - grip_size))
	_resize_grip.size = Vector2(grip_size, grip_size)
	_update_compact_mode()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_children()


func _on_header_gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_pointer_origin = get_global_mouse_position()
			_position_origin = position
			_header.accept_event()
		else:
			_dragging = false
			_save_layout()
			_header.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		position = _clamp_position(_position_origin + get_global_mouse_position() - _pointer_origin)
		_header.accept_event()


func _on_grip_gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_resizing = true
			_pointer_origin = get_global_mouse_position()
			_size_origin = size
			_resize_grip.accept_event()
		else:
			_resizing = false
			_save_layout()
			_resize_grip.accept_event()
	elif event is InputEventMouseMotion and _resizing:
		var desired_size: Vector2 = _size_origin + get_global_mouse_position() - _pointer_origin
		var minimum_size: Vector2 = _get_effective_minimum_size()
		var maximum_size: Vector2 = _get_available_size()
		size = Vector2(clampf(desired_size.x, minimum_size.x, maximum_size.x), clampf(desired_size.y, minimum_size.y, maximum_size.y))
		_layout_children()
		_resize_grip.accept_event()


func _update_compact_mode() -> void:
	var is_compact: bool = size.x < 90.0 or size.y < 60.0
	content.visible = not is_compact
	_title_label.visible = not is_compact
	_lock_button.visible = show_lock_button and size.x >= 26.0 and size.y >= 20.0
	# Keep the resize handle available even at minimum dimensions, unless locked.
	_resize_grip.visible = not locked


func _toggle_locked() -> void:
	locked = not locked
	_update_lock_ui()
	_save_layout()


func set_locked(value: bool) -> void:
	locked = value
	_update_lock_ui()
	_save_layout()


func _update_lock_ui() -> void:
	if _lock_button != null:
		_lock_button.text = "🔒" if locked else "🔓"
		_lock_button.tooltip_text = "Desbloquear panel" if locked else "Bloquear posición y tamaño"
	if _header != null:
		_header.mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_MOVE
	if _resize_grip != null:
		_resize_grip.visible = not locked


func _draw_resize_grip() -> void:
	var grip_color: Color = Color(0.85, 0.9, 1.0, 0.85)
	_resize_grip.draw_line(Vector2(1.0, _resize_grip.size.y - 1.0), Vector2(_resize_grip.size.x - 1.0, 1.0), grip_color, 1.5)
	_resize_grip.draw_line(Vector2(_resize_grip.size.x * 0.45, _resize_grip.size.y - 1.0), Vector2(_resize_grip.size.x - 1.0, _resize_grip.size.y * 0.45), grip_color, 1.5)


func _clamp_position(proposed: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var max_position: Vector2 = Vector2(maxf(0.0, viewport_size.x - size.x), maxf(0.0, viewport_size.y - size.y))
	return Vector2(clampf(proposed.x, 0.0, max_position.x), clampf(proposed.y, 0.0, max_position.y))


func _save_layout() -> void:
	if _config == null:
		return
	var section: String = _section_name()
	_config.set_value(section, "position", position)
	_config.set_value(section, "size", size)
	_config.set_value(section, "locked", locked)
	var error: Error = _config.save(CONFIG_PATH)
	if error != OK:
		push_warning("UniversalPanel: could not save layout (%s)" % error_string(error))


func _on_visibility_changed() -> void:
	if not visible:
		_dragging = false
		_resizing = false


func _section_name() -> String:
	var safe_id: String = panel_id.strip_edges().replace(" ", "_")
	return "panel:%s" % safe_id
