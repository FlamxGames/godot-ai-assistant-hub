extends AITool

var _directory:String
var _missing_dirs:Array[String]


func execute() -> bool:
	_directory = _parameter_values.get("directory_path", "")
	
	if _directory.is_empty():
		_errors.append("No path was supplied.")
		return false
	
	# Validate path against allowed and prohibited lists
	var allowed_paths:PackedStringArray = _read_option("allowed_paths")
	var prohibited_paths:PackedStringArray = _read_option("prohibited_paths")
	
	if not AIToolFileUtils.validate_allowed_paths(_directory, allowed_paths, _errors, true):
		return false
	if not AIToolFileUtils.validate_prohibited_paths(_directory, prohibited_paths, _errors, true):
		return false
	
	# Check if directory already exists
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_directory)):
		_errors.append("Directory already exists at: %s" % _directory)
		return false
	
	# Create the directory by using a fake file in create_required_dirs
	var ghost_file = _directory.path_join("a")
	var dirs_ok := AIToolFileUtils.create_required_dirs(ghost_file, _missing_dirs, _errors)
	if not dirs_ok:
		return false
		
	var execution_id := _register_undo()
	_success_message = "Directory created at: %s\nExecution Id: %s" % [ _directory, execution_id ]
	EditorInterface.get_resource_filesystem().scan()
	return true


func undo() -> bool:
	# Validate against path restrictions before deletion
	var allowed_paths:PackedStringArray = _read_option("allowed_paths")
	var prohibited_paths:PackedStringArray = _read_option("prohibited_paths")
	
	var delete_success := AIToolFileUtils.delete_directories_recursive(_missing_dirs, allowed_paths, prohibited_paths, _errors)
	if not delete_success:
		return false
	
	if _missing_dirs.size() == 1:
		_success_message = "Directory deleted at: %s" % _directory
	else:
		_success_message = "Directory deleted at: %s. Parent directories previously created by this tool were also deleted." % _directory
	return true
