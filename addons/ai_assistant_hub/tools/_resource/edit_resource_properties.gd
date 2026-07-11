extends AITool

var _resource_path: String
var _property_values:Array
var _do_values_map: Dictionary
var _undo_values_map: Dictionary

var _edited_resource: Resource
var _do_obj_property_values:Dictionary
var _undo_obj_property_values:Dictionary


func execute() -> bool:
	# Retrieve parameters
	_resource_path = _parameter_values.get("resource_path", "")
	_property_values = _parameter_values.get("property_values", [])
	
	var valid := _validate_parameters()
	if not valid:
		return false
	
	var prohibited_props:= AIToolOption.get_array_from_multiline_string(_read_option("prohibited_properties"))
	
	var prop_value_map:= {}
	var success := AIToolPropertiesUtils.read_property_values_input(_property_values, prop_value_map, prohibited_props, _errors)
	if not success:
		return false
	
	# The tool's do/undo has a dictionary entry for each resource modified, the entry value is a new dictionary of property names and values
	success = AIToolPropertiesUtils.apply_changes_to_object(_edited_resource, prop_value_map, null, _do_obj_property_values, _undo_obj_property_values, _errors)
	if not success:
		return false
	
	# We process resource properties after making changes to the node, so that resources can be created and edited in the same call
	# Get resources' properties - this populates res_prop_value_map
	var res_prop_value_map := {}
	var get_res_prop_success := AIToolPropertiesUtils.get_resource_prop_values(_edited_resource, prop_value_map, res_prop_value_map, _errors)
	if not get_res_prop_success:
		AIToolPropertiesUtils.apply_all_property_changes(_undo_obj_property_values, _do_obj_property_values) #Undo what was done so far
		return false
	
	# Parse resources properties and apply
	for resource in res_prop_value_map.keys():
		success = AIToolPropertiesUtils.apply_changes_to_object(resource, res_prop_value_map[resource], null, _do_obj_property_values, _undo_obj_property_values, _errors)
		if not success:
			return false
	
	# Get status after change
	var new_values := _get_resource_values_list()
	
	var execution_id := _register_undo()
	_success_message = "Properties set.\nExecution Id:%s\nReview the values after tool execution:\n%s" % [ execution_id, "\n".join(new_values) ]
	
	return true


func _validate_parameters() -> bool:
	if _resource_path.is_empty():
		_errors.append("resource_path is required.")
		return false
	
	# Validate paths
	if not AIToolFileUtils.validate_allowed_paths(_resource_path, _read_option("allowed_paths"), _errors, false):
		return false

	if not AIToolFileUtils.validate_prohibited_paths(_resource_path, _read_option("prohibited_paths"), _errors, false):
		return false

	for f in _read_option("prohibited_files"):
		if _resource_path == f:
			_errors.append("The file is protected, you cannot edit it.")
			return false

	if not ResourceLoader.exists(_resource_path):
		_errors.append("Resource file does not exist: %s" % _resource_path)
		return false
	
	_edited_resource = load(_resource_path)
	if not is_instance_valid(_edited_resource) or not _edited_resource is Resource:
		_errors.append("Failed to load resource from: %s" % _resource_path)
		return false

	if _property_values.is_empty():
		_errors.append("property_values cannot be empty.")
		return false

	return true


func _get_resource_values_list() -> PackedStringArray:
	var new_values:PackedStringArray
	for obj in _do_obj_property_values.keys():
		if obj is Resource:
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
	messages.append_array(_get_resource_values_list())
	
	_success_message = "\n".join(messages)
	return true
