extends Node


@onready var gaea_generator: GaeaGenerator = $"../GaeaGenerator"


func _ready() -> void:
	print("GAEA INSPECTOR READY")

	gaea_generator.generation_finished.connect(
		_on_gaea_generator_generation_finished
	)

	print("SIGNAL CONNECTED")

	gaea_generator.generate()


func _on_gaea_generator_generation_finished(grid: GaeaGrid) -> void:
	print("========================================")
	print("GENERATION FINISHED")
	print("========================================")

	#inspect_graph_properties()
	#inspect_graph_methods()
	#inspect_graph_parameters_property()
	#inspect_graph_named_parameters()
	#inspect_material_identity(grid)
	#inspect_map_axes(grid)
	inspect_material_dictionary(grid)


func inspect_grid(grid) -> void:
	print("========================================")
	print("GAEA GRID")
	print("========================================")

	print("Class: ", grid.get_class())
	print("Script: ", grid.get_script())

	var layer_count: int = grid.get_layers_count()

	print("Layer count: ", layer_count)

	var enabled_layers: Array[int] = grid.get_enabled_layers_indexes()

	print("Enabled layers: ", enabled_layers)

	for layer_index in range(layer_count):
		inspect_layer(grid, layer_index)


func inspect_layer(grid: GaeaGrid, layer_index: int) -> void:
	print("----------------------------------------")
	print("LAYER ", layer_index)
	print("----------------------------------------")

	var layer_map = grid.get_layer(layer_index)

	print("Map class: ", layer_map.get_class())
	print("Map script: ", layer_map.get_script())

	var cell_count: int = layer_map.get_cell_count()
	print("Cell count: ", cell_count)

	var cells = layer_map.get_cells()
	print("Cells type: ", typeof(cells))

	inspect_cells(layer_map, cells)
	inspect_unique_materials(layer_map, cells)
	inspect_material_distribution(layer_map, cells)
	inspect_map_methods(layer_map)


func inspect_cells(layer_map, cells) -> void:
	print("========================================")
	print("CELLS")
	print("========================================")

	var count_to_print: int = min(10, cells.size())

	print("First ", count_to_print, " positions:")

	for i in range(count_to_print):
		var cell: Vector3i = cells[i]

		print("  [", i, "] ", cell)

	print("========================================")
	print("CELL VALUES")
	print("========================================")

	for i in range(count_to_print):
		var cell: Vector3i = cells[i]

		var material: GaeaMaterial = layer_map.get_cell(cell)

		print("Cell: ", cell)

		if material == null:
			print("  Material: NULL")
			continue

		print("  Material class: ", material.get_class())
		print("  Material script: ", material.get_script())
		print("  Material path: ", material.resource_path)


func inspect_map_methods(layer_map) -> void:
	print("========================================")
	print("MAP METHODS")
	print("========================================")

	for method in layer_map.get_method_list():
		if (
			method.name == "get_cell"
			or method.name == "get_xyz"
			or method.name == "get_cells"
			or method.name == "get_cell_count"
			or method.name == "has"
		):
			print(method)


func inspect_material(material: GaeaMaterial) -> void:
	if material == null:
		print("Material is NULL")
		return

	print("Class: ", material.get_class())
	print("Script: ", material.get_script())
	print("Resource path: ", material.resource_path)

	print("Properties:")

	for property in material.get_property_list():
		print(
			"  ",
			property.name,
			" | type=",
			property.type,
			" | class=",
			property.class_name,
			" | hint=",
			property.hint_string
		)

	print("Relevant methods:")

	for method in material.get_method_list():
		if (
			method.name.contains("tile")
			or method.name.contains("material")
			or method.name.contains("terrain")
			or method.name.contains("id")
			or method.name.contains("name")
		):
			print("  ", method)


func inspect_material_properties(material: GaeaMaterial) -> void:
	print("========================================")
	print("MATERIAL PROPERTIES")
	print("========================================")

	print("Resource path: ", material.resource_path)

	for property in material.get_property_list():
		print(
			"  ",
			property.name,
			" | type=",
			property.type,
			" | class=",
			property.class_name,
			" | hint=",
			property.hint_string
		)


func inspect_unique_materials(layer_map, cells) -> void:
	print("========================================")
	print("UNIQUE MATERIALS")
	print("========================================")

	var materials: Dictionary = {}

	for cell in cells:
		var material: GaeaMaterial = layer_map.get_cell(cell)

		if material == null:
			continue

		var path: String = material.resource_path

		if not materials.has(path):
			materials[path] = material

	print("Unique material count: ", materials.size())

	for path in materials:
		var material: GaeaMaterial = materials[path]

		print("----------------------------------------")
		print("Material path: ", path)

		inspect_material_values(material)


func inspect_material_values(material: GaeaMaterial) -> void:
	print("  resource_name: ", material.resource_name)
	print("  type: ", material.type)
	print("  source_id: ", material.source_id)
	print("  atlas_coord: ", material.atlas_coord)
	print("  alternative_tile: ", material.alternative_tile)
	print("  terrain_set: ", material.terrain_set)
	print("  terrain: ", material.terrain)
	print("  pattern_index: ", material.pattern_index)
	print("  pattern_offset: ", material.pattern_offset)
	print("  preview_color: ", material.preview_color)


func inspect_material_distribution(layer_map, cells) -> void:
	print("========================================")
	print("MATERIAL DISTRIBUTION")
	print("========================================")

	var materials: Dictionary = {}
	var counts: Dictionary = {}

	for cell in cells:
		var material: GaeaMaterial = layer_map.get_cell(cell)

		if material == null:
			continue

		var path: String = material.resource_path

		if not materials.has(path):
			materials[path] = material
			counts[path] = 0

		counts[path] += 1

	for path in materials:
		var material: GaeaMaterial = materials[path]

		print("----------------------------------------")
		print("Path: ", path)
		print("Count: ", counts[path])
		print("source_id: ", material.source_id)
		print("atlas_coord: ", material.atlas_coord)
		print("alternative_tile: ", material.alternative_tile)


func inspect_graph_parameters() -> void:
	print("========================================")
	print("GRAPH PARAMETERS")
	print("========================================")

	var graph = gaea_generator.graph

	if graph == null:
		print("Graph: NULL")
		return

	print("Graph class: ", graph.get_class())
	print("Graph script: ", graph.get_script())

	var parameters: Dictionary = graph._parameters

	print("Parameter count: ", parameters.size())

	for parameter_name in parameters:
		print("----------------------------------------")
		print("Parameter name: ", parameter_name)

		var parameter = parameters[parameter_name]

		print("Value type: ", typeof(parameter))
		print("Value: ", parameter)

		if parameter is Dictionary:
			inspect_dictionary(parameter, "  ")

		elif parameter is Object:
			print("  Class: ", parameter.get_class())
			print("  Script: ", parameter.get_script())


func inspect_dictionary(dictionary: Dictionary, indent: String) -> void:
	for key in dictionary:
		var value = dictionary[key]

		print(
			indent,
			"Key: ",
			key,
			" | type=",
			typeof(value),
			" | value=",
			value
		)

		if value is Dictionary:
			inspect_dictionary(value, indent + "  ")

		elif value is Object:
			print(
				indent,
				"  Class: ",
				value.get_class()
			)

			print(
				indent,
				"  Script: ",
				value.get_script()
			)


func inspect_graph_material_parameters() -> void:
	print("========================================")
	print("GRAPH MATERIAL PARAMETERS")
	print("========================================")

	var graph = gaea_generator.graph
	var parameters: Dictionary = graph._parameters

	for parameter_name in parameters:
		var parameter: Dictionary = parameters[parameter_name]

		var value = parameter.get("value", null)

		print("----------------------------------------")
		print("Parameter: ", parameter_name)
		print("Value type: ", typeof(value))

		if value is GaeaMaterial:
			var material: GaeaMaterial = value

			print("Material path: ", material.resource_path)
			print("source_id: ", material.source_id)
			print("atlas_coord: ", material.atlas_coord)
			print("alternative_tile: ", material.alternative_tile)
		else:
			print("Value is not GaeaMaterial")


func inspect_graph_methods() -> void:
	print("========================================")
	print("GRAPH METHODS")
	print("========================================")

	var graph = gaea_generator.graph

	for method in graph.get_method_list():
		print(method)


func inspect_graph_properties() -> void:
	print("========================================")
	print("GRAPH PROPERTIES")
	print("========================================")

	var graph = gaea_generator.graph

	for property in graph.get_property_list():
		print(
			property.name,
			" | type=",
			property.type,
			" | class=",
			property.class_name,
			" | usage=",
			property.usage
		)


func inspect_graph_parameters_property() -> void:
	print("========================================")
	print("GRAPH PARAMETERS PROPERTY")
	print("========================================")

	var graph = gaea_generator.graph
	var parameters = graph.parameters

	print("Type: ", typeof(parameters))
	print("Value: ", parameters)

	if parameters is Dictionary:
		print("Parameter count: ", parameters.size())

		for key in parameters.keys():
			var value = parameters[key]

			print("----------------------------------------")
			print("Key: ", key)
			print("Value type: ", typeof(value))
			print("Value: ", value)

			if value is Dictionary:
				for sub_key in value.keys():
					print("  ", sub_key, " => ", value[sub_key])


func inspect_graph_named_parameters() -> void:
	print("========================================")
	print("GRAPH NAMED PARAMETERS")
	print("========================================")

	var graph = gaea_generator.graph

	var names := [
		&"dirt",
		&"grass",
		&"sand",
		&"stone",
		&"water"
	]

	for name in names:
		var value = graph.get(name)

		print("----------------------------------------")
		print("Name: ", name)
		print("Type: ", typeof(value))
		print("Value: ", value)

		if value != null:
			print("Script: ", value.get_script())


func inspect_material_identity(grid: GaeaGrid) -> void:
	var graph = gaea_generator.graph

	var named_materials := {
		&"dirt": graph.get(&"dirt"),
		&"grass": graph.get(&"grass"),
		&"sand": graph.get(&"sand"),
		&"stone": graph.get(&"stone"),
		&"water": graph.get(&"water"),
	}

	var layer_map: GaeaValue.Map = grid.get_layer(0)
	var cells := layer_map.get_cells()

	print("========================================")
	print("MATERIAL IDENTITY TEST")
	print("========================================")

	for name in named_materials:
		var named_material: GaeaMaterial = named_materials[name]

		var found := false

		for cell in cells:
			var cell_material: GaeaMaterial = layer_map.get_cell(cell)

			if cell_material == named_material:
				found = true
				break

		print(name, " found by == : ", found)


func inspect_map_axes(grid: GaeaGrid) -> void:
	var layer_map: GaeaValue.Map = grid.get_layer(0)
	var cells := layer_map.get_cells()

	var min_x := cells[0].x
	var max_x := cells[0].x
	var min_y := cells[0].y
	var max_y := cells[0].y
	var min_z := cells[0].z
	var max_z := cells[0].z

	for cell in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)

		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

		min_z = mini(min_z, cell.z)
		max_z = maxi(max_z, cell.z)

	print("========================================")
	print("GAEA MAP AXES")
	print("========================================")

	print("Cell count: ", cells.size())

	print("X range: ", min_x, " .. ", max_x)
	print("Y range: ", min_y, " .. ", max_y)
	print("Z range: ", min_z, " .. ", max_z)

	print("First cell: ", cells[0])
	print("Last cell: ", cells[cells.size() - 1])


func inspect_material_dictionary(grid: GaeaGrid) -> void:
	var graph: GaeaGraph = gaea_generator.graph
	var layer_map: GaeaValue.Map = grid.get_layer(0)

	var material_to_name: Dictionary = {
		graph.get(&"dirt"): "dirt",
		graph.get(&"grass"): "grass",
		graph.get(&"sand"): "sand",
		graph.get(&"stone"): "stone",
		graph.get(&"water"): "water",
	}

	print("========================================")
	print("GAEA MATERIAL DICTIONARY TEST")
	print("========================================")

	var cells := layer_map.get_cells()

	for cell in cells:
		var material: GaeaMaterial = layer_map.get_cell(cell)

		if material_to_name.has(material):
			print(
				"Cell ",
				cell,
				" → ",
				material_to_name[material]
			)
		else:
			print(
				"UNKNOWN MATERIAL at ",
				cell,
				": ",
				material
			)

		# Sólo necesitamos unas pocas celdas.
		if cell.x >= 2 and cell.y >= 2:
			break
