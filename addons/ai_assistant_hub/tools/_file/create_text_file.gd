extends AITool

var _file_path:String
var _content:String
var _created_file_path:String
var _missing_dirs:Array[String]


func execute() -> bool:
	_file_path = _parameter_values.get("file_path", "")
	_content = _parameter_values.get("content", "")
	
	var valid := _validate_parameters()
	if not valid:
		return false
	
	# Check if file already exists
	if FileAccess.file_exists(_file_path):
		_errors.append("File already exists at: %s" % _file_path)
		return false
	
	# Create required directories
	var dirs_ok:= AIToolFileUtils.create_required_dirs(_file_path, _missing_dirs, _errors)
	if not dirs_ok:
		return false
	
	# Open file for writing
	var file = FileAccess.open(_file_path, FileAccess.WRITE)
	if not file:
		var err = FileAccess.get_open_error()
		_errors.append("Failed to create file at %s. Error: %d" % [_file_path, err])
		return false
	
	# Write content to file
	file.store_string(_content)
	file.close()
	
	var execution_id := _register_undo()
	_success_message = "File created successfully at: %s\nExecution Id: %s" % [ _file_path, execution_id ]
	_created_file_path = _file_path
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.select_file(_created_file_path)
	return true


func _validate_parameters() -> bool:
	if _file_path == "":
		_errors.append("No file_path was supplied.")
		return false
	
	if _file_path.get_extension() == ".gd":
		_errors.append("To create scripts you must use the specific tool designed for that.")
		return false
	
	# Validate path against allowed and prohibited lists
	var allowed_paths:PackedStringArray = _read_option("allowed_paths")
	var prohibited_paths:PackedStringArray = _read_option("prohibited_paths")
	
	if not AIToolFileUtils.validate_allowed_paths(_file_path, allowed_paths, _errors, true):
		return false
	if not AIToolFileUtils.validate_prohibited_paths(_file_path, prohibited_paths, _errors, true):
		return false
	
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
		_success_message = "File moved to trash at: %s" % _created_file_path
	else:
		_success_message = "File moved to trash at: %s. Parent directories previously created by this tool were also deleted." % _created_file_path
	return true
