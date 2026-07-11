extends AITool

var _file_path:String
var _script_content:String
var _created_file_path:String
var _missing_dirs:Array[String]


func execute() -> bool:
	_file_path = _parameter_values.get("file_path", "")
	_script_content = _parameter_values.get("script_content", "")
	
	var valid := _validate_parameters()
	if not valid:
		return false
	
	if FileAccess.file_exists(_file_path):
		_errors.append("File already exists at: %s" % _file_path)
		return false
	
	# Create new GDScript
	var new_script := GDScript.new()
	new_script.source_code = _script_content
	
	# Reload the script
	new_script.reload()
	
	var dirs_ok:= AIToolFileUtils.create_required_dirs(_file_path, _missing_dirs, _errors)
	if not dirs_ok:
		return false
		
	var error := ResourceSaver.save(new_script, _file_path)
	if error == OK:
		var execution_id := _register_undo()
		_success_message = "Script created successfully at: %s\nExecution Id: %s" % [ _file_path, execution_id ]
		_created_file_path = _file_path
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.select_file(_created_file_path)
		return true
	else:
		_errors.append("Error saving script at %s. Error: %d" % [_file_path, error_string(error)])
		return false


func _validate_parameters() -> bool:
	if _file_path == "":
		_errors.append("No file_path was supplied.")
		return false
	
	var allowed_paths:PackedStringArray = _read_option("allowed_paths")
	var prohibited_paths:PackedStringArray = _read_option("prohibited_paths")

	# Validate file path against allowed and prohibited lists
	if not AIToolFileUtils.validate_allowed_paths(_file_path, allowed_paths, _errors, true):
		return false
	if not AIToolFileUtils.validate_prohibited_paths(_file_path, prohibited_paths, _errors, true):
		return false
	
	var banned_code_lines:String = _read_option("banned_code")

	if not _script_content.is_empty() and banned_code_lines != "":
		var banned_parts := banned_code_lines.split("\n")
		for part in banned_parts:
			part = part.strip_edges()
			if not part.is_empty() and _script_content.find(part) != -1:
				_errors.append("Banned keyword defined by the user detected in new content: '%s'." % part)
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
		_success_message = "Script moved to trash at: %s" % _created_file_path
	else:
		_success_message = "Script moved to trash at: %s. Parent directories previously created by this tool were also deleted." % _created_file_path
	return true
