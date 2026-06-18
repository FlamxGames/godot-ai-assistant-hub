extends AITool

var _scene_path: String
var _node_class: String
var _node_name: String
var _parent_path: String
var _new_node: Node
var _parent_node:Node


func execute() -> bool:
	# Retrieve parameters
	_scene_path = _parameter_values.get("scene_path", "")
	_node_class = _parameter_values.get("node_class", "")
	_node_name = _parameter_values.get("node_name", "")
	_parent_path = _parameter_values.get("parent_path", "")
	
	# Validate required parameters
	if _scene_path.is_empty():
		_errors.append("scene_path is required.")
		return false
	
	if _node_class.is_empty():
		_errors.append("node_class is required.")
		return false
	
	if _node_name.is_empty():
		_errors.append("node_name is required.")
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
	
	# Find parent node (default to scene root if not specified)
	if not _parent_path.is_empty():
		if not scene_root.has_node(_parent_path):
			_errors.append("Parent node '%s' not found in scene." % _parent_path)
			return false
		_parent_node = scene_root.get_node(_parent_path)
	else:
		_parent_node = scene_root
	
	# Create dynamic loader for the node class
	var dynamic_class_loader := GDScript.new()
	dynamic_class_loader.set_source_code("static func eval(): return " + _node_class)
	var error := dynamic_class_loader.reload()
	if error != OK:
		_errors.append("Failed to load class: %s. Error: %s" % [_node_class, error_string(error)])
		return false
	
	# Instantiate the node
	_new_node = dynamic_class_loader.eval().new()
	if not (_new_node is Node):
		_errors.append("%s is not a valid node class." % _node_class)
		return false
	
	# Set node name
	_new_node.name = _node_name
	
	# Add node to scene with undo support
	var undo_redo: EditorUndoRedoManager = AIHubPlugin.instance.get_undo_redo()
	undo_redo.create_action("Add node to scene (by AI assistant)")
	
	undo_redo.add_do_method(_parent_node, "add_child", _new_node, true)
	undo_redo.add_do_property(_new_node, "owner", scene_root)
	undo_redo.add_undo_method(_parent_node, "remove_child", _new_node)
	undo_redo.commit_action()
	
	# Register undo for the tool
	var execution_id := _register_undo()
	
	# Set success message
	_success_message = "Tool executed.\nExecution Id: %s\nNode Class: %s\nNode Name: %s\nParent: %s" % [
		execution_id, _node_class, _node_name, _parent_path
	]
	
	return true


func undo() -> bool:
	# Open the scene to get the edited root
	EditorInterface.open_scene_from_path(_scene_path)
	var scene_root = EditorInterface.get_edited_scene_root()
	
	if not is_instance_valid(scene_root) or scene_root.scene_file_path != _scene_path:
		_errors.append("Scene failed to open for undo.")
		return false
	
	# Find the new node
	if not _parent_node.has_node(_node_name):
		_errors.append("Node to remove not found in parent node: %s" % _node_name)
		return false
	
	var node_to_remove = _parent_node.get_node(_node_name)
	
	# Remove node using undo
	var undo_redo: EditorUndoRedoManager = AIHubPlugin.instance.get_undo_redo()
	undo_redo.create_action("Remove node from scene (by AI assistant)")
	
	undo_redo.add_do_method(_parent_node, "remove_child", node_to_remove)
	undo_redo.add_undo_method(_parent_node, "add_child", node_to_remove, true)
	
	undo_redo.commit_action()
	
	_success_message = "Node removed from scene.\nNode Name: %s\nParent: %s" % [
		_node_name, _parent_path
	]
	return true
