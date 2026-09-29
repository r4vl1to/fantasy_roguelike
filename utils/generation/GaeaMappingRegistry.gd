class_name GaeaMappingRegistry
extends RefCounted

var _material_to_terrain: Dictionary = {}


func build_from_graph(graph: GaeaGraph) -> void:
	_material_to_terrain.clear()

	_register(graph.get(&"dirt"), TerrainId.DIRT)
	_register(graph.get(&"grass"), TerrainId.GRASS)
	_register(graph.get(&"sand"), TerrainId.SAND)
	_register(graph.get(&"stone"), TerrainId.STONE)
	_register(graph.get(&"water"), TerrainId.WATER)


func _register(material: GaeaMaterial, terrain_id: int) -> void:
	if material == null:
		push_error("Cannot register null GaeaMaterial.")
		return

	_material_to_terrain[material] = terrain_id


func has_material(material: GaeaMaterial) -> bool:
	return _material_to_terrain.has(material)


func terrain_id_from_material(material: GaeaMaterial) -> int:
	if not _material_to_terrain.has(material):
		push_error("Unknown GaeaMaterial: %s" % material)
		return -1

	return _material_to_terrain[material]
