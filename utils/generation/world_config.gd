class_name WorldConfig
extends Resource

@export var world_seed: int = 0

@export_range(1, 1024, 1)
var chunk_size: int = 32

@export var tile_size: int = 16

@export var generation_version: int = 1
