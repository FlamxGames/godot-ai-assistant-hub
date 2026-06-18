class_name AIToolFileUtils


static func open_file_in_code_editor(file_path:String, errors:PackedStringArray) -> bool:
	var curr_file_path := get_current_script_editor_file_path()
	if curr_file_path.is_empty() or curr_file_path != file_path:
		if ResourceLoader.exists(file_path):
			var script_res = load(file_path)
			EditorInterface.edit_resource(script_res)
			var root = EditorInterface.get_base_control()
			await root.get_tree().process_frame
			await root.get_tree().process_frame
			curr_file_path = get_current_script_editor_file_path()
			if curr_file_path.is_empty() or curr_file_path != file_path:
				errors.append("File `%s` could not be loaded, it may not be supported by the code editor." % file_path)
				return false
		else:
			errors.append("File `%s` does not exist or cannot be loaded." % file_path)
			return false
	return true


static func get_current_script_editor_file_path() -> String:
	var script_editor = EditorInterface.get_script_editor()
	
	# Fallback first: If it is a real script, get it directly
	var current_script = script_editor.get_current_script()
	if current_script and not current_script.resource_path.is_empty():
		return current_script.resource_path
	else:
		# Catch-all: Check the open sub-editor workspaces for text/markdown files
		var open_editors = script_editor.get_open_script_editors()
		for editor in open_editors:
			# Godot visibility dictates which file is actually focused
			if editor.is_visible_in_tree(): 
				if editor.has_meta("_edit_res_path"):
					return editor.get_meta("_edit_res_path")
	return ""


static func validate_allowed_paths(path: String, allowed_paths: PackedStringArray, errors: PackedStringArray, is_file: bool = true) -> bool:
	if not allowed_paths.is_empty():
		var path_ok = false
		var norm_path = path
		if not is_file and not norm_path.ends_with("/"):
			norm_path += "/"
		for entry in allowed_paths:
			var norm_entry = entry
			if not is_file and not norm_entry.ends_with("/"):
				norm_entry += "/"
			if norm_path.begins_with(norm_entry):
				path_ok = true
				break
		if not path_ok:
			var error_message := "The path %s is not under the allowed paths defined by the user. Allowed paths:" % path
			for p in allowed_paths:
				error_message += "\n%s" % p
			errors.append(error_message)
			return false
	return true


static func validate_prohibited_paths(path: String, prohibited_paths: PackedStringArray, errors: PackedStringArray, is_file: bool = true) -> bool:
	var norm_path = path
	if not is_file and not norm_path.ends_with("/"):
		norm_path += "/"
	for entry in prohibited_paths:
		var norm_entry = entry
		if not is_file and not norm_entry.ends_with("/"):
			norm_entry += "/"
		if norm_path.begins_with(norm_entry):
			var error_message := "The path %s is under the following directories restricted by the user. Restricted paths:" % path
			for p in prohibited_paths:
				error_message += "\n%s" % p
			errors.append(error_message)
			return false
	return true


static func create_required_dirs(file_path:String, missing_dirs:Array[String], errors:PackedStringArray) -> bool:
	# Safety counter to prevent infinite directory creation loops
	var safety_counter = 0
	const MAX_DIRECTORY_CREATIONS = 50
	
	# Find what are all the directories to be created. Start from the deepest path and work up to root
	var exiting_parent:String
	var current_path = file_path.get_base_dir()
	while not current_path.is_empty():
		var d := DirAccess.open(current_path)
		if d != null:
			exiting_parent = current_path
			break # Directory exists
		safety_counter += 1
		if safety_counter > MAX_DIRECTORY_CREATIONS:
			errors.append("Directory creation safety limit exceeded. Stopping at: %s" % current_path)
			return false
		missing_dirs.append(current_path)
		current_path = current_path.get_base_dir()
	
	if exiting_parent != file_path.get_base_dir():
		AIHubPlugin.print_msg("Creating missing directories recursively: %s" % "\n".join(missing_dirs))
		var dir := DirAccess.open(exiting_parent)
		if dir == null:
			errors.append("Existing parent directory could not be opened: %s. Error: %s" % [ exiting_parent, error_string(DirAccess.get_open_error()) ])
			return false
		var error := dir.make_dir_recursive(file_path.get_base_dir())
		if error != OK:
			errors.append("Missing directories recursive creation failed: %s. Error: %s" % [ file_path.get_base_dir(), error_string(error) ])
			return false
	return true


static func delete_file_with_directories(file_path:String, dirs:Array[String], allowed_paths:PackedStringArray, prohibited_paths:PackedStringArray, errors:PackedStringArray) -> bool:
	var error := OS.move_to_trash(ProjectSettings.globalize_path(file_path))
	if error != OK:
		errors.append("Error moving %s to trash. Error: %d" % [file_path, error_string(error)])
		return false
	return delete_directories_recursive(dirs, allowed_paths, prohibited_paths, errors)


static func delete_directories_recursive(dirs:Array[String], allowed_paths:PackedStringArray, prohibited_paths:PackedStringArray, errors:PackedStringArray) -> bool:
	for dir_path in dirs:
		var dir = DirAccess.open(dir_path)
		if dir == null:
			errors.append("Parent directory could not be read for undo: %s. Error: %s" % [ dir_path, error_string(DirAccess.get_open_error()) ])
			return false
		
		if not AIToolFileUtils.validate_allowed_paths(dir_path, allowed_paths, errors, false):
			return false
		if not AIToolFileUtils.validate_prohibited_paths(dir_path, prohibited_paths, errors, false):
			return false
			
		# Check if directory is empty
		var existing_files := DirAccess.get_files_at(dir_path)
		var existing_dirs := DirAccess.get_directories_at(dir_path)
		if not (existing_files.is_empty() and existing_dirs.is_empty()):
			errors.append("Cannot delete directory %s, the directory is not empty. The file was removed, but one or more parent directories could not be removed." % dir_path)
			EditorInterface.get_resource_filesystem().scan()
			return false
		
		var remove_error = dir.remove(dir_path)
		if remove_error != OK:
			errors.append("Error removing directory at %s. Error code: %d" % [dir_path, error_string(remove_error)])
	
	EditorInterface.get_resource_filesystem().scan()
	return true
