class_name PathOverlay
extends Node2D

## Draws the walk trayecto toward a chosen tile: a translucent square per step
## and a highlighted marker on the destination. Pure view — it reads nothing and
## only renders what it is told.

## Pixel size of one tile; must match the world TileSet and GaeaChunkRenderer.
var tile_size: int = 16

var _path: Array[Vector2i] = []
var _start: Vector2i = Vector2i.ZERO
var _destination: Vector2i = Vector2i.ZERO
var _destination_color: Color = Color(1, 1, 1, 1)
var _visible_marker: bool = false

const STEP_COLOR: Color = Color(0.35, 0.85, 1.0, 0.2)


func set_path(path: Array[Vector2i], start: Vector2i, destination: Vector2i, destination_color: Color) -> void:
	# Keep each tile only once and retain the route origin so the visual can be a
	# single polyline rather than adjacent translucent rectangles.
	_path.clear()
	var seen: Dictionary = {}
	for tile: Vector2i in path:
		if seen.has(tile):
			continue
		seen[tile] = true
		_path.append(tile)
	_start = start
	_destination = destination
	_destination_color = destination_color
	_visible_marker = true
	queue_redraw()


func clear() -> void:
	if _path.is_empty() and not _visible_marker:
		return
	_path.clear()
	_visible_marker = false
	queue_redraw()


func _draw() -> void:
	if not _visible_marker:
		return
	var cell := Vector2(tile_size, tile_size)
	if not _path.is_empty():
		var points := PackedVector2Array()
		points.append((Vector2(_start) + Vector2(0.5, 0.5)) * float(tile_size))
		for tile: Vector2i in _path:
			points.append((Vector2(tile) + Vector2(0.5, 0.5)) * float(tile_size))
		if points.size() >= 2:
			draw_polyline(points, STEP_COLOR, 2.0, false)
	var marker := Rect2(Vector2(_destination) * float(tile_size), cell)
	draw_rect(marker, Color(_destination_color.r, _destination_color.g, _destination_color.b, 0.4), true)
	draw_rect(marker, _destination_color, false, 2.0)