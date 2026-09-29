class_name MoveConfirmPanel
extends UniversalPanel

## Non-modal info box for click-to-move. Shows the destination tile, the terrain
## there and the trayecto length, with a single "Aceptar" button and an "✕" that
## cancels the trayecto. It does NOT block the screen: only its own small box
## absorbs clicks (see get_blocking_rect), so clicking another tile simply
## overwrites the trayecto. Emits `confirmed` / `cancelled`; holds no state itself.

signal confirmed
signal cancelled

var _title: Label
var _terrain: Label
var _distance: Label
var _confirm_button: Button
var _cancel_button: Button


func _ready() -> void:
	panel_title = "Destino"
	panel_id = "move_confirm"
	initial_position = Vector2(12.0, 12.0)
	initial_size = Vector2(250.0, 170.0)
	minimum_panel_size = Vector2(24.0, 24.0)
	super._ready()
	visible = false
	_build_content()


func _build_content() -> void:

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)

	_cancel_button = Button.new()
	_cancel_button.text = "✕"
	_cancel_button.tooltip_text = "Cancelar el trayecto"
	_cancel_button.focus_mode = Control.FOCUS_NONE
	_cancel_button.pressed.connect(func() -> void: cancelled.emit())
	header.add_child(_cancel_button)

	_terrain = Label.new()
	content.add_child(_terrain)

	_distance = Label.new()
	content.add_child(_distance)

	_confirm_button = Button.new()
	_confirm_button.text = "Aceptar"
	_confirm_button.focus_mode = Control.FOCUS_NONE
	_confirm_button.pressed.connect(func() -> void: confirmed.emit())
	content.add_child(_confirm_button)


## Shows the info box for a chosen destination tile.
func open(tile: Vector2i, terrain_name: String, distance: int) -> void:
	_title.text = "Tile (%d, %d)" % [tile.x, tile.y]
	_terrain.text = "Terreno: %s" % terrain_name
	_distance.text = "Trayecto: %d tiles" % distance
	visible = true


func close() -> void:
	visible = false


## Screen-space rect of the info box only (not the whole screen), so the click
## system ignores clicks landing on the box while still letting the player click
## another tile to overwrite the trayecto.
func get_blocking_rect() -> Rect2:
	return get_global_rect()
