extends AITool

var _scene_path: String
var _node_path: String
var _target_node: Node
var _property_values:Array

var _do_obj_property_values:Dictionary
var _undo_obj_property_values:Dictionary
var _scene_root:Node


func execute() -> bool:
	# Retrieve parameters
	_scene_path = _parameter_values.get("scene_path", "")
	_node_path = _parameter_values.get("node_path", "")
	_property_values = _parameter_values.get("property_values", [])
	
	var valid := _validate_parameters()
	if not valid:
		return false
		
	var prohibited_props:= AIToolOption.get_array_from_multiline_string(_read_option("prohibited_properties"))
	
	var prop_value_map:= {}
	var success := AIToolPropertiesUtils.read_property_values_input(_property_values, prop_value_map, prohibited_props, _errors)
	if not success:
		return false
	
	# The tool's do/undo has a dictionary entry for the node + one entry for each resource modified, the entry value is a new dictionary of property names and values
	success = AIToolPropertiesUtils.apply_changes_to_object(_target_node, prop_value_map, _scene_root, _do_obj_property_values, _undo_obj_property_values, _errors)
	if not success:
		return false
	
	# We process resource properties after making changes to the node, so that resources can be created and edited in the same call
	# Get resources' properties - this populates res_prop_value_map
	var res_prop_value_map := {}
	var get_res_prop_success := AIToolPropertiesUtils.get_resource_prop_values(_target_node, prop_value_map, res_prop_value_map, _errors)
	if not get_res_prop_success:
		AIToolPropertiesUtils.apply_all_property_changes(_undo_obj_property_values, _do_obj_property_values) #Undo what was done so far
		return false
	
	# Parse resources properties and apply
	for resource in res_prop_value_map.keys():
		success = AIToolPropertiesUtils.apply_changes_to_object(resource, res_prop_value_map[resource], _scene_root, _do_obj_property_values, _undo_obj_property_values, _errors)
		if not success:
			return false
	
	# Get status after change
	var new_values := _get_objects_values_list()
	
	var execution_id := _register_undo()
	_success_message = "Properties set.\nExecution Id:%s\nReview the values after tool execution:\n%s" % [ execution_id, "\n".join(new_values) ]
	
	return true


func _validate_parameters() -> bool:
	if _scene_path.is_empty():
		_errors.append("scene_path is required.")
		return false
	
	# Validate paths
	if not AIToolFileUtils.validate_allowed_paths(_scene_path, _read_option("allowed_paths"), _errors, false):
		return false

	if not AIToolFileUtils.validate_prohibited_paths(_scene_path, _read_option("prohibited_paths"), _errors, false):
		return false
	
	for f in _read_option("prohibited_files"):
		if _scene_path == f:
			_errors.append("The file is protected, you cannot edit it.")
			return false

	if not ResourceLoader.exists(_scene_path):
		_errors.append("Scene file does not exist: %s" % _scene_path)
		return false
	
	if _property_values.is_empty():
		_errors.append("property_values cannot be empty.")
		return false

	# Load and open the scene in the editor
	EditorInterface.open_scene_from_path(_scene_path)
	_scene_root = EditorInterface.get_edited_scene_root()
	
	if not is_instance_valid(_scene_root) or _scene_root.scene_file_path != _scene_path:
		_errors.append("Scene failed to open. Verify the path: %s" % _scene_path)
		return false
	
	if not _scene_root.has_node(_node_path):
		_errors.append("Node '%s' not found in scene." % _node_path)
		return false
	_target_node = _scene_root.get_node(_node_path)
	
	return true


func _get_objects_values_list() -> PackedStringArray:
	var new_values:PackedStringArray
	for obj in _do_obj_property_values.keys():
		if obj is Node:
			new_values.append("Node %s:" % obj.name)
		elif obj is Resource:
			new_values.append("Resource %s:" % obj.resource_path)
		else:
			new_values.append(str(obj)) #Unexpected, but allow
		var values_dict:Dictionary = _do_obj_property_values[obj]
		var node_scanner := AIToolPropertyScanner.new()
		var values_list := node_scanner.scan_and_get_values_list(obj, values_dict.keys())
		new_values.append_array(values_list)
	return new_values


func undo() -> bool:
	AIToolPropertiesUtils.apply_all_property_changes(_undo_obj_property_values, _do_obj_property_values)
	
	var messages := PackedStringArray()
	messages.append("Status after undo:")
	messages.append_array(_get_objects_values_list())
	
	_success_message = "\n".join(messages)
	return true
