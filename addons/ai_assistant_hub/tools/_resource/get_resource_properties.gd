extends AITool

var _resource_path: String
var _mode: String
var _filter: String


func execute() -> bool:
	# Retrieve parameters
	_resource_path = _parameter_values.get("resource_path", "")
	_mode = _parameter_values.get("mode", "Simple")
	_filter = _parameter_values.get("filter", "")
	
	if _mode != "Simple" and _mode != "Detailed":
			_errors.append("Valid modes are Simple and Detailed.")
			return false
	
	if _resource_path.is_empty():
		_errors.append("resource_path is required.")
		return false
	
	# Validate paths
	if not AIToolFileUtils.validate_allowed_paths(_resource_path, _read_option("allowed_paths"), _errors, false):
		return false
	if not AIToolFileUtils.validate_prohibited_paths(_resource_path, _read_option("prohibited_paths"), _errors, false):
		return false
	
	# Load the resource
	if not ResourceLoader.exists(_resource_path):
		_errors.append("Resource file does not exist: %s" % _resource_path)
		return false
	var resource = load(_resource_path)
	if not is_instance_valid(resource) or not resource is Resource:
		_errors.append("Failed to load resource from: %s" % _resource_path)
		return false
	
	var prohibited_props:= AIToolOption.get_array_from_multiline_string(_read_option("prohibited_properties"))
	
	var resource_scanner := AIToolPropertyScanner.new()
	resource_scanner.scan(resource, _filter, prohibited_props)
	
	if _mode == "Simple":
		_success_message = "\n".join(resource_scanner.properties_list)
	else:
		_success_message = str(resource_scanner.properties_details)
	
	return true
