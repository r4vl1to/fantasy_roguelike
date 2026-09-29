class_name ChunkEntityPersistence
extends RefCounted

const ENTITY_DATA_VERSION: int = 1

## Built-in Resource properties that must not be persisted as component data.
const IGNORED_PROPERTIES: Array[String] = [
	"script",
	"resource_name",
	"resource_path",
	"resource_local_to_scene",
	"resource_scene_unique_id",
]


static func serialize_entities(entities: Array[Entity]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for entity: Entity in entities:
		if entity == null or not is_instance_valid(entity):
			continue
		var components: Array[Dictionary] = []
		for component: Variant in entity.components.values():
			if not (component is Component):
				continue
			var component_script: Script = component.get_script() as Script
			if component_script == null or component_script.resource_path.is_empty():
				continue
			components.append({
				"script": component_script.resource_path,
				"data": _serialize_properties(component)
			})
		var entity_script: Script = entity.get_script() as Script
		records.append({
			"version": ENTITY_DATA_VERSION,
			"name": String(entity.name),
			"scene_path": entity.scene_file_path,
			"entity_script": entity_script.resource_path if entity_script != null else "",
			"alias": String(entity.alias),
			"components": components
		})
	return records


static func deserialize_entities(records: Array) -> Array[Entity]:
	var entities: Array[Entity] = []
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if int(record.get("version", 0)) != ENTITY_DATA_VERSION:
			push_warning("Skipping entity record with unsupported version.")
			continue
		var entity: Entity = _instantiate_entity(
			str(record.get("scene_path", "")),
			str(record.get("entity_script", ""))
		)
		entity.name = str(record.get("name", "Entity"))
		entity.alias = StringName(str(record.get("alias", "")))
		for component_variant: Variant in record.get("components", []):
			if not (component_variant is Dictionary):
				continue
			var component_record: Dictionary = component_variant
			var script_path: String = str(component_record.get("script", ""))
			if script_path.is_empty() or not ResourceLoader.exists(script_path):
				push_warning("Skipping component with missing script: %s" % script_path)
				continue
			var component_script: Script = load(script_path) as Script
			if component_script == null or not component_script.can_instantiate():
				push_warning("Skipping non-instantiable component script: %s" % script_path)
				continue
			var component: Component = component_script.new() as Component
			if component == null:
				continue
			_restore_properties(component, component_record.get("data", {}))
			entity.add_component(component)
		entities.append(entity)
	return entities


static func save_chunk_entities(path: String, entities: Array[Entity]) -> bool:
	var directory: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
		var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		if mkdir_error != OK:
			push_error("Unable to create entity data directory: %s" % directory)
			return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write chunk entity data: %s" % path)
		return false
	file.store_string(JSON.stringify({"version": ENTITY_DATA_VERSION, "entities": serialize_entities(entities)}))
	file.close()
	return true


static func load_chunk_entities(path: String) -> Array[Entity]:
	if not FileAccess.file_exists(path):
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to read chunk entity data: %s" % path)
		return []
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not (json.data is Dictionary):
		push_error("Invalid chunk entity data: %s" % path)
		return []
	var payload: Dictionary = json.data
	if int(payload.get("version", 0)) != ENTITY_DATA_VERSION:
		push_error("Unsupported chunk entity data version in %s" % path)
		return []
	var records: Variant = payload.get("entities", [])
	return deserialize_entities(records as Array)


static func _serialize_properties(resource: Resource) -> Dictionary:
	var data: Dictionary = {}
	for property: Dictionary in resource.get_property_list():
		var usage: int = int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if String(property.name) in IGNORED_PROPERTIES:
			continue
		var value: Variant = resource.get(property.name)
		if value is Vector2:
			value = {"__type": "Vector2", "x": value.x, "y": value.y}
		elif value is Vector2i:
			value = {"__type": "Vector2i", "x": value.x, "y": value.y}
		elif value is Object and not (value is Resource):
			continue
		if value is Resource:
			var nested: Resource = value as Resource
			if nested != null and not nested.resource_path.is_empty():
				value = {"__resource_path": nested.resource_path}
			else:
				continue
		data[String(property.name)] = value
	return data


static func _restore_properties(resource: Resource, data: Variant) -> void:
	if not (data is Dictionary):
		return
	for property_name: Variant in data:
		var value: Variant = data[property_name]
		if value is Dictionary and value.has("__resource_path"):
			var resource_path: String = str(value["__resource_path"])
			if not ResourceLoader.exists(resource_path):
				continue
			value = load(resource_path)
		elif value is Dictionary and value.get("__type") == "Vector2":
			value = Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
		elif value is Dictionary and value.get("__type") == "Vector2i":
			value = Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
		resource.set(StringName(str(property_name)), value)


static func _instantiate_entity(scene_path: String, entity_script_path: String) -> Entity:
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		var packed_scene: PackedScene = load(scene_path) as PackedScene
		if packed_scene != null:
			var instance: Node = packed_scene.instantiate()
			if instance is Entity:
				return instance as Entity
	if not entity_script_path.is_empty() and ResourceLoader.exists(entity_script_path):
		var entity_script: Script = load(entity_script_path) as Script
		if entity_script != null and entity_script.can_instantiate():
			var scripted_entity: Node = entity_script.new() as Node
			if scripted_entity is Entity:
				return scripted_entity as Entity
	return Entity.new()
