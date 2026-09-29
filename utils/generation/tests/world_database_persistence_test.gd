extends Node


func _ready() -> void:
	print("========================================")
	print("WORLD DATABASE + PERSISTENCE TEST")
	print("========================================")

	var database := WorldDatabase.new()
	var persistence := WorldPersistence.new(
		"user://world_test"
	)

	# --------------------------------------------------
	# 1. CREAR CHUNK ORIGINAL
	# --------------------------------------------------

	var original := ChunkData.new()

	original.coord = Vector2i(3, -2)
	original.initialize(32)

	for i in original.terrain.size():
		original.terrain[i] = i % 5
		original.biome[i] = (i / 100) % 3

	print("----------------------------------------")
	print("ORIGINAL")
	print("----------------------------------------")
	print("Coord: ", original.coord)
	print("Size: ", original.size)
	print("Terrain count: ", original.terrain.size())
	print("Biome count: ", original.biome.size())

	# --------------------------------------------------
	# 2. GUARDAR EN RAM
	# --------------------------------------------------

	database.store_chunk(original)

	print("----------------------------------------")
	print("DATABASE")
	print("----------------------------------------")
	print(
		"Has chunk after RAM store: ",
		database.has_chunk(original.coord)
	)

	# --------------------------------------------------
	# 3. GUARDAR EN DISCO
	# --------------------------------------------------

	var saved := persistence.save_chunk(original)

	print("----------------------------------------")
	print("PERSISTENCE")
	print("----------------------------------------")
	print("Saved to disk: ", saved)
	print(
		"Exists on disk: ",
		persistence.has_chunk(original.coord)
	)

	# --------------------------------------------------
	# 4. ELIMINAR DE RAM
	# --------------------------------------------------

	database.remove_chunk(original.coord)

	print("----------------------------------------")
	print("RAM CLEARED")
	print("----------------------------------------")
	print(
		"Has chunk in RAM: ",
		database.has_chunk(original.coord)
	)

	# --------------------------------------------------
	# 5. COMPROBAR QUE SIGUE EN DISCO
	# --------------------------------------------------

	print(
		"Has chunk on disk: ",
		persistence.has_chunk(original.coord)
	)

	# --------------------------------------------------
	# 6. CARGAR DESDE DISCO
	# --------------------------------------------------

	var loaded := persistence.load_chunk(
		original.coord
	)

	if loaded == null:
		push_error("FAILED: Could not load chunk from disk.")
		return

	print("----------------------------------------")
	print("LOADED FROM DISK")
	print("----------------------------------------")
	print("Coord: ", loaded.coord)
	print("Size: ", loaded.size)
	print("Terrain count: ", loaded.terrain.size())
	print("Biome count: ", loaded.biome.size())

	# --------------------------------------------------
	# 7. VOLVER A GUARDAR EN RAM
	# --------------------------------------------------

	database.store_chunk(loaded)

	print("----------------------------------------")
	print("RESTORED TO RAM")
	print("----------------------------------------")
	print(
		"Has chunk in RAM: ",
		database.has_chunk(loaded.coord)
	)

	# --------------------------------------------------
	# 8. RECUPERAR DESDE DATABASE
	# --------------------------------------------------

	var restored := database.get_chunk(
		original.coord
	)

	if restored == null:
		push_error("FAILED: Could not retrieve chunk from database.")
		return

	# --------------------------------------------------
	# 9. COMPARAR
	# --------------------------------------------------

	var mismatches := 0

	if restored.coord != original.coord:
		mismatches += 1

	if restored.size != original.size:
		mismatches += 1

	if restored.terrain.size() != original.terrain.size():
		mismatches += 1
	else:
		for i in original.terrain.size():
			if restored.terrain[i] != original.terrain[i]:
				mismatches += 1

	if restored.biome.size() != original.biome.size():
		mismatches += 1
	else:
		for i in original.biome.size():
			if restored.biome[i] != original.biome[i]:
				mismatches += 1

	# --------------------------------------------------
	# RESULTADO
	# --------------------------------------------------

	print("========================================")
	print("DATABASE + PERSISTENCE RESULT")
	print("========================================")
	print("Mismatches: ", mismatches)

	if mismatches == 0:
		print("INTEGRATION SUCCESS")
	else:
		print("INTEGRATION FAILED")
