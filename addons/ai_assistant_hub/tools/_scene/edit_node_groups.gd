extends AITool

var _scene_path: String
var _group_name: String
var _action: String
var _target_node: Node

const ADD_OPTION = "Add"


func execute() -> bool:
	# Retrieve parameters
	_scene_path = _parameter_values.get("scene_path", "")
	var node_path = _parameter_values.get("node_path", "")
	_group_name = _parameter_values.get("group_name", "")
	_action = _parameter_values.get("action", ADD_OPTION)
	
	# Validate paths
	if not AIToolFileUtils.validate_allowed_paths(_scene_path, _read_option("allowed_paths"), _errors, false):
		return false

	if not AIToolFileUtils.validate_prohibited_paths(_scene_path, _read_option("prohibited_paths"), _errors, false):
		return false
	
	for f in _read_option("prohibited_files"):
		if _scene_path == f:
			_errors.append("The file is protected, you cannot edit it.")
			return false
	
	# Validate required parameters
	if _scene_path.is_empty():
		_errors.append("scene_path is required.")
		return false
	
	if node_path.is_empty():
		_errors.append("node_path is required.")
		return false
		
	if _group_name.is_empty():
		_errors.append("group_name is required.")
		return false
		
	
	if not ResourceLoader.exists(_scene_path):
		_errors.append("Scene file does not exist: %s" % _scene_path)
		return false
	
	# Load and open the scene in the editor
	EditorInterface.open_scene_from_path(_scene_path)
	var scene_root = EditorInterface.get_edited_scene_root()
	
	if not is_instance_valid(scene_root) or scene_root.scene_file_path != _scene_path:
		_errors.append("Scene failed to open. Verify the path: %s" % _scene_path)
		return false
	
	# Find emitter node
	if not scene_root.has_node(node_path):
		_errors.append("Node '%s' not found in scene." % node_path)
		return false
	_target_node = scene_root.get_node(node_path)
	
	var success := _add_remove_from_group(_action == ADD_OPTION)
	if success:
		var execution_id := _register_undo()
		_success_message = "Success.\nExecution id: %s\nUpdated list of groups: %s" % [execution_id, str(_target_node.get_groups())]
	else:
		_errors.append("The operation failed. Is the group name correct?")
	return success


func _add_remove_from_group(add:bool) -> bool:
	var undo_redo: EditorUndoRedoManager = AIHubPlugin.instance.get_undo_redo()
	undo_redo.create_action("Node group assignment changes (by AI assistant)")
	if add:
		undo_redo.add_do_method(_target_node, "add_to_group", _group_name, true)
		undo_redo.add_undo_method(_target_node, "remove_from_group", _group_name)
		undo_redo.commit_action()
		return _target_node.is_in_group(_group_name)
	else:
		undo_redo.add_do_method(_target_node, "remove_from_group", _group_name)
		undo_redo.add_undo_method(_target_node, "add_to_group", _group_name, true)
		undo_redo.commit_action()
		return not _target_node.is_in_group(_group_name)


func undo() -> bool:
	var success := _add_remove_from_group(_action != ADD_OPTION)
	if success:
		_success_message = "Undo success.\nUpdated list of groups:%s" % str(_target_node.get_groups())
	else:
		_errors.append("The undo operation failed.")
	return success
