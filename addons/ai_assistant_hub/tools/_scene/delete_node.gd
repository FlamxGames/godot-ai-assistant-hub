extends AITool

var _scene_path: String
var _node_path: String
var _node_to_delete: Node
var _parent_node: Node


func execute() -> bool:
	# Retrieve parameters
	_scene_path = _parameter_values.get("scene_path", "")
	_node_path = _parameter_values.get("node_path", "")
	
	# Validate required parameters
	if _scene_path.is_empty():
		_errors.append("scene_path is required.")
		return false
	
	if _node_path.is_empty():
		_errors.append("node_path is required.")
		return false
	
	# Validate file path against allowed and prohibited lists
	if not AIToolFileUtils.validate_allowed_paths(_scene_path, _read_option("allowed_paths"), _errors, true):
		return false
	if not AIToolFileUtils.validate_prohibited_paths(_scene_path, _read_option("prohibited_paths"), _errors, true):
		return false
	
	for f in _read_option("prohibited_files"):
		if _scene_path == f:
			_errors.append("The file is protected, you cannot edit it.")
			return false
	
	# Validate scene file exists
	if not ResourceLoader.exists(_scene_path):
		_errors.append("Scene file does not exist: %s" % _scene_path)
		return false
	
	# Open and validate the scene
	EditorInterface.open_scene_from_path(_scene_path)
	var scene_root := EditorInterface.get_edited_scene_root()
	
	if not is_instance_valid(scene_root) or scene_root.scene_file_path != _scene_path:
		_errors.append("Scene failed to open. Verify the path: %s" % _scene_path)
		return false
	
	# Find node to delete
	if not scene_root.has_node(_node_path):
		_errors.append("Node to delete '%s' not found in scene." % _node_path)
		return false
	_node_to_delete = scene_root.get_node(_node_path)
	
	if _node_to_delete == scene_root:
		_errors.append("You cannot delete the root node.")
		return false
	
	_parent_node = _node_to_delete.get_parent()
	
	# Validate node is a valid Node instance
	if not (_node_to_delete is Node):
		_errors.append("Node at path '%s' is not a valid node instance." % _node_path)
		return false
	
	# Remove node with undo support
	var undo_redo: EditorUndoRedoManager = AIHubPlugin.instance.get_undo_redo()
	undo_redo.create_action("Delete node from scene (by AI assistant)")
	
	undo_redo.add_do_method(_parent_node, "remove_child", _node_to_delete)
	undo_redo.add_undo_method(_parent_node, "add_child", _node_to_delete, true)
	undo_redo.add_undo_property(_node_to_delete, "owner", scene_root)
	
	undo_redo.commit_action()
	
	# Register undo for the tool
	var execution_id := _register_undo()
	
	# Set success message
	_success_message = "Tool executed.\nExecution Id: %s\nNode Path: %s\nNode Name: %s" % [
		execution_id, _node_path, _node_to_delete.name
	]
	
	return true


func undo() -> bool:
	# Open the scene to get the edited root
	EditorInterface.open_scene_from_path(_scene_path)
	var scene_root = EditorInterface.get_edited_scene_root()
	
	if not is_instance_valid(scene_root) or scene_root.scene_file_path != _scene_path:
		_errors.append("Scene failed to open for undo.")
		return false
	
	# Re-add the node to its parent
	var undo_redo: EditorUndoRedoManager = AIHubPlugin.instance.get_undo_redo()
	undo_redo.create_action("Add node to scene (by AI assistant)")
	
	undo_redo.add_do_method(_parent_node, "add_child", _node_to_delete, true)
	undo_redo.add_do_property(_node_to_delete, "owner", scene_root)
	undo_redo.add_undo_method(_parent_node, "remove_child", _node_to_delete)
	
	undo_redo.commit_action()
	
	_success_message = "Node added back to scene.\nNode Path: %s\nNode Name: %s" % [
		_node_path, _node_to_delete.name
	]
	return true
