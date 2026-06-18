extends AITool

var _file_path: String
var _base_class: String
var _created_file_path: String
var _missing_dirs:Array[String]


func execute() -> bool:
	# Retrieve parameters
	_file_path = _parameter_values.get("file_path", "")
	_base_class = _parameter_values.get("base_class", "")
	
	# Validate parameters
	if _base_class.is_empty():
		_errors.append("No base_class was supplied.")
		return false
	
	if _file_path.is_empty():
		_errors.append("No file_path was supplied.")
		return false
	
	# Check if resource file already exists
	if FileAccess.file_exists(_file_path):
		_errors.append("Resource file already exists at: %s." % _file_path)
		return false
	
	# Validate path against allowed and prohibited lists
	if not AIToolFileUtils.validate_allowed_paths(_file_path, _read_option("allowed_paths"), _errors, true):
		return false
	if not AIToolFileUtils.validate_prohibited_paths(_file_path, _read_option("prohibited_paths"), _errors, true):
		return false
	
	# Create dynamic loader for the class
	var dynamic_class_loader := GDScript.new()
	dynamic_class_loader.set_source_code("static func eval(): return " + _base_class)
	var error := dynamic_class_loader.reload()
	if error != OK:
		_errors.append("Failed to load class: %s. Error: %s" % [_base_class, error_string(error)])
		return false
	
	var resource_instance = dynamic_class_loader.eval().new()
	if not (resource_instance is Resource):
		_errors.append("%s is not a valid resource class." % _base_class)
		return false
	
	var dirs_ok:= AIToolFileUtils.create_required_dirs(_file_path, _missing_dirs, _errors)
	if not dirs_ok:
		return false
	
	# Save the resource to the file system
	var save_result = ResourceSaver.save(resource_instance, _file_path)
	if save_result != OK:
		_errors.append("Failed to save resource. Error: %s" % error_string(save_result))
		return false
	
	# Register undo
	var execution_id := _register_undo()
	
	_created_file_path = _file_path
	_success_message = "Resource created successfully at: %s.\nExecution Id: %s" % [_file_path, execution_id]
	
	# Scan the file system
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.select_file(_created_file_path)
	
	return true


func undo() -> bool:
	# Validate against path restrictions before deletion
	var allowed_paths:PackedStringArray = _read_option("allowed_paths")
	var prohibited_paths:PackedStringArray = _read_option("prohibited_paths")
	
	if not AIToolFileUtils.validate_allowed_paths(_created_file_path, allowed_paths, _errors, true):
		return false
	if not AIToolFileUtils.validate_prohibited_paths(_created_file_path, prohibited_paths, _errors, true):
		return false
	
	var delete_success := AIToolFileUtils.delete_file_with_directories(_created_file_path, _missing_dirs, allowed_paths, prohibited_paths, _errors)
	if not delete_success:
		return false
	
	if _missing_dirs.is_empty():
		_success_message = "Resource moved to trash at: %s" % _created_file_path
	else:
		_success_message = "Resource moved to trash at: %s. Parent directories previously created by this tool were also deleted." % _created_file_path
	return true
