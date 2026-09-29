extends Node


func _ready() -> void:
	print("========================================")
	print("WORLD PERSISTENCE TEST")
	print("========================================")

	var persistence := WorldPersistence.new(
		"user://world_test"
	)

	var original := ChunkData.new()

	original.coord = Vector2i(3, -2)
	original.initialize(32)

	for i in original.terrain.size():
		original.terrain[i] = i % 5
		original.biome[i] = (i / 100) % 3

	print("Original chunk: ", original.coord)

	# SAVE

	var saved := persistence.save_chunk(original)

	print("Saved: ", saved)
	print(
		"Exists after save: ",
		persistence.has_chunk(original.coord)
	)

	# LOAD

	var restored := persistence.load_chunk(
		original.coord
	)

	if restored == null:
		push_error("Failed to load chunk.")
		return

	print("Restored chunk: ", restored.coord)
	print("Restored size: ", restored.size)
	print(
		"Restored terrain count: ",
		restored.terrain.size()
	)
	print(
		"Restored biome count: ",
		restored.biome.size()
	)

	# VALIDATE

	var mismatches := 0

	if restored.coord != original.coord:
		mismatches += 1

	if restored.size != original.size:
		mismatches += 1

	for i in original.terrain.size():
		if restored.terrain[i] != original.terrain[i]:
			mismatches += 1

	for i in original.biome.size():
		if restored.biome[i] != original.biome[i]:
			mismatches += 1

	print("----------------------------------------")
	print("PERSISTENCE RESULT")
	print("----------------------------------------")
	print("Mismatches: ", mismatches)

	if mismatches == 0:
		print("SAVE/LOAD SUCCESS")
	else:
		print("SAVE/LOAD FAILED")
