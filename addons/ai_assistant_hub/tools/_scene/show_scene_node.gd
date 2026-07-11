extends AITool

var _scene_path: String
var _node_path: String

func execute() -> bool:
	# Retrieve parameters
	_scene_path = _parameter_values.get("scene_path", "")
	_node_path = _parameter_values.get("node_path", "")

	# Validate paths
	if not AIToolFileUtils.validate_allowed_paths(_scene_path, _read_option("allowed_paths"), _errors, false):
		return false

	if not AIToolFileUtils.validate_prohibited_paths(_scene_path, _read_option("prohibited_paths"), _errors, false):
		return false

	if _scene_path.is_empty() and _node_path.is_empty():
		_errors.append("Both scene_path and node_path are empty.")
		return false

	var root : Node
	if not _scene_path.is_empty():
		if not ResourceLoader.exists(_scene_path):
			_errors.append("Scene file does not exist: %s" % _scene_path)
			return false

		# Load and open the scene in the editor
		EditorInterface.open_scene_from_path(_scene_path)
		root = EditorInterface.get_edited_scene_root()
		if not is_instance_valid(root) or root.scene_file_path != _scene_path:
			_errors.append("Scene failed to open. Verify the path: %s" % _scene_path)
			return false
	else:
		root = EditorInterface.get_edited_scene_root()
		if not is_instance_valid(root):
			_errors.append("Unable to find the scene root. Is there a scene opened?")
			return false

	if not _node_path.is_empty():
		if not root.has_node(_node_path):
			_errors.append("Node '%s' not found in scene." % _node_path)
			return false

		var target : Node = root.get_node(_node_path)

		# Highlight the node in the Scene panel
		var selection := EditorInterface.get_selection()
		if selection:
			selection.clear()
			selection.add_node(target)

		EditorInterface.edit_node(target)

		_success_message = "Opened scene %s and selected node %s." % [_scene_path, _node_path]
	else:
		_success_message = "Opened scene %s." % _scene_path

	return true
