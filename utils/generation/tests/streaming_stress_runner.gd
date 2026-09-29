extends Node

const PROFILE_SCRIPT: Script = preload("res://utils/generation/tests/streaming_stress_profile.gd")


func _ready() -> void:
	var profiler: Node = PROFILE_SCRIPT.new()
	add_child(profiler)
