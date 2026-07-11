extends AITool

var _scene_path: String
var _node_path: String
var _parent_path: String
var _is_copy: bool
var _new_name: String
var _old_name: String
var _node_to_move: Node
var _parent_node: Node
var _old_parent_node: Node
var _scene_root: Node
#var _new_node_name: String


func execute() -> bool:
	# Retrieve parameters
	_scene_path = _parameter_values.get("scene_path", "")
	_node_path = _parameter_values.get("node_path", "")
	_parent_path = _parameter_values.get("parent_path", "")
	_is_copy = _parameter_values.get("is_copy", false)
	_new_name = _parameter_values.get("new_name", "")

	# Validate required parameters
	if _scene_path.is_empty():
		_errors.append("scene_path is required.")
		return false

	if _node_path.is_empty():
		_errors.append("node_path is required.")
		return false
		
	if _node_path == ".":
		_errors.append("Root node cannot be moved.")
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
	_scene_root = EditorInterface.get_edited_scene_root()

	if not is_instance_valid(_scene_root) or _scene_root.scene_file_path != _scene_path:
		_errors.append("Scene failed to open. Verify the path: %s" % _scene_path)
		return false

	# Find node to move
	if not _scene_root.has_node(_node_path):
		_errors.append("Node to move '%s' not found in scene." % _node_path)
		return false
	_node_to_move = _scene_root.get_node(_node_path)
	
	if _parent_path.is_empty():
		_parent_path = _scene_root.get_path_to(_node_to_move.get_parent())
	
	if _new_name.is_empty():
		_new_name = _node_to_move.name
	_old_name = _node_to_move.name

	# Find parent node
	if not _scene_root.has_node(_parent_path):
		_errors.append("Parent node '%s' not found in scene." % _parent_path)
		return false
	_parent_node = _scene_root.get_node(_parent_path)

	# Execute operation
	var undo_redo: EditorUndoRedoManager = AIHubPlugin.instance.get_undo_redo()

	if _is_copy:
		_node_to_move = _node_to_move.duplicate()
		undo_redo.create_action("Copy node (by AI assistant)")
		undo_redo.add_do_method(_parent_node, "add_child", _node_to_move, true)
		undo_redo.add_do_property(_node_to_move, "name", _new_name)
		undo_redo.add_do_method(self, "_set_owner_recursive", _node_to_move)
		undo_redo.add_undo_method(_parent_node, "remove_child", _node_to_move)
		undo_redo.commit_action()
	else:
		# Move (cut) operation
		_old_parent_node = _node_to_move.get_parent()
		undo_redo.create_action("Move node in scene (by AI assistant)")
		undo_redo.add_do_method(_node_to_move, "reparent", _parent_node)
		undo_redo.add_do_property(_node_to_move, "name", _new_name)
		undo_redo.add_undo_method(_node_to_move, "reparent", _old_parent_node)
		undo_redo.add_undo_property(_node_to_move, "name", _old_name)
		undo_redo.commit_action()

	var execution_id := _register_undo()
	_success_message = "Tool executed.\nExecution Id: %s\nNew node path: %s" % [
		execution_id, str(_scene_root.get_path_to(_node_to_move))
	]

	return true


func _set_owner_recursive(node: Node) -> void:
	node.owner = _scene_root
	for child in node.get_children():
		_set_owner_recursive(child)


func undo() -> bool:
	# Open the scene to get the edited root
	EditorInterface.open_scene_from_path(_scene_path)
	var scene_root = EditorInterface.get_edited_scene_root()

	if not is_instance_valid(scene_root) or scene_root.scene_file_path != _scene_path:
		_errors.append("Scene failed to open for undo.")
		return false
	
	if _node_to_move.get_parent() != _parent_node:
		_errors.append("Node %s is not under the parent node %s anymore." % [ _node_to_move.name, _parent_node.name ])
		return false
	
	if not is_instance_valid(_parent_node):
		_errors.append("The parent node is no longer valid.")
		return false

	# Remove node using undo
	var undo_redo: EditorUndoRedoManager = AIHubPlugin.instance.get_undo_redo()

	if _is_copy:
		undo_redo.create_action("Undo copy node (by AI assistant)")
		undo_redo.add_do_method(_parent_node, "remove_child", _node_to_move)
		undo_redo.add_undo_method(_parent_node, "add_child", _node_to_move, true)
		undo_redo.add_undo_method(self, "_set_owner_recursive", _node_to_move)
		undo_redo.commit_action()
		_success_message = "Undo executed."
	else:
		if not is_instance_valid(_old_parent_node):
			_errors.append("The previous parent node is no longer valid.")
			return false
		
		# Move (cut) operation
		undo_redo.create_action("Move node in scene (by AI assistant)")
		undo_redo.add_do_method(_node_to_move, "reparent", _old_parent_node)
		undo_redo.add_do_property(_node_to_move, "name", _old_name)
		undo_redo.add_undo_method(_node_to_move, "reparent", _parent_node)
		undo_redo.add_undo_property(_node_to_move, "name", _new_name)
		undo_redo.commit_action()
		_success_message = "Undo executed.\nNew node path: %s" % str(_scene_root.get_path_to(_node_to_move))
	
	return true
