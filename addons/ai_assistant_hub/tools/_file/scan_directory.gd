extends AITool

var _directory:String
var _file_filter:String
var _max_depth:int
var _allowed_paths:PackedStringArray
var _prohibited_paths:PackedStringArray


func execute() -> bool:
	_directory = _parameter_values.get("path", "")
	_file_filter = _parameter_values.get("file_filter", "")
	_max_depth = _parameter_values.get("max_depth", -1)  # -1 means unlimited depth

	var valid := _validate_parameters()
	if not valid:
		return false

	var found_paths := PackedStringArray()

	if not _directory.ends_with("//"):
		_directory = _directory.trim_suffix("/")
	
	var success := _scan_dir(_directory, 0, found_paths)
	if not success:
		return false

	_success_message = "Scanned %d items from %s. Results:\n%s" % [found_paths.size(), _directory, "\n".join(found_paths)]
	return true


func _validate_parameters() -> bool:
	if _directory == "":
		_errors.append("No path was supplied.")
		return false

	# Check that the path exists and is a directory
	var dir = DirAccess.open(_directory)
	if dir == null:
		var err:= DirAccess.get_open_error()
		_errors.append("Cannot open directory: %s. Error: %s" % [_directory, error_string(err)])
		return false

	# Max depth must be -1 (unlimited) or >= 0
	if _max_depth < -1:
		_errors.append("max_depth must be null (unlimited) or >= 0.")
		return false

	# Read options
	_allowed_paths = _read_option("allowed_paths")
	_prohibited_paths = _read_option("prohibited_paths")

	# Root must be under allowed paths
	if not AIToolFileUtils.validate_allowed_paths(_directory, _allowed_paths, _errors, false):
		return false

	# Root must not be under prohibited paths
	if not AIToolFileUtils.validate_prohibited_paths(_directory, _prohibited_paths, _errors, false):
		return false
	
	return true


func _is_prohibited(path:String) -> bool:
	for entry in _prohibited_paths:
		if path.begins_with(entry):
			return true
	return false


func _scan_dir(dir:String, depth:int, out:PackedStringArray) -> bool:
	AIHubPlugin.print_msg("Scanning: %s" % dir)
	var dir_access := DirAccess.open(dir)
	if dir_access == null:
		_errors.append("Error when trying to read directory %s" % dir)
		return false

	for dir_name in dir_access.get_directories():
		out.append(dir.path_join(dir_name))

	# Process files in the current directory
	for file_name in dir_access.get_files():
		if not _file_filter.is_empty() and not file_name.match(_file_filter):
			continue
		var file_path := dir.path_join(file_name)
		out.append(file_path)

	# Recurse into subdirectories if allowed
	var all_success := true
	for sub_dir in dir_access.get_directories():
		if sub_dir == "." or sub_dir == "..":
			continue
		var sub_path := dir.path_join(sub_dir)
		if _is_prohibited(sub_path):
			continue
		if _max_depth != -1 and depth + 1 > _max_depth:
			continue
		all_success = all_success and _scan_dir(sub_path, depth + 1, out) # <-- Recursion
		if not all_success:
			break
	out.sort()
	return all_success
